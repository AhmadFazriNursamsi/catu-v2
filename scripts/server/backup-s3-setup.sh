#!/usr/bin/env bash
# backup-s3-setup.sh - siapkan bucket S3 + kunci khusus untuk salinan cadangan CATU di cloud. Dijalankan SEKALI, DI MAC,
# oleh pemilik akun AWS (butuh hak admin S3/IAM). Hasilnya folder konfigurasi yang lalu disalin ke server (~/.catu-backup).
#
#   AWS_PROFILE=<profil-admin> scripts/server/backup-s3-setup.sh <nama-bucket> [region]
#   contoh: AWS_PROFILE=catu-backup scripts/server/backup-s3-setup.sh catu-backup-xxxx ap-southeast-1
#
# Bila profil itu tidak punya hak IAM: admin akun AWS membuat user catu-backup-writer + kebijakan + access key di Console
# (lihat README), unduh CSV kuncinya, lalu jalankan ulang dengan CATU_S3_KEY_CSV=<berkas.csv> agar langkah IAM dilewati.
#
# Yang dibuat:
#   - Bucket privat (blokir akses publik, enkripsi SSE-S3, versioning) + aturan simpan: daily/ dihapus setelah
#     CATU_S3_KEEP_DAYS hari (bawaan 90), versi lama 7 hari.
#   - User IAM catu-backup-writer yang HANYA boleh s3:PutObject ke s3://<bucket>/daily/* (tidak bisa membaca/menghapus,
#     sehingga server yang dibobol pun tidak bisa merusak cadangan lama).
#   - Folder lokal (bawaan ~/Backups/catu-s3/server-config, izin 700/600):
#       s3.conf          bucket & region
#       aws-credentials  kunci user catu-backup-writer (TIDAK dicetak)
#       passphrase       kunci enkripsi acak. SIMPAN JUGA DI PENGELOLA SANDI: tanpa ini cadangan cloud tidak bisa dibuka.
set -euo pipefail

BUCKET="${1:-}"; REGION="${2:-ap-southeast-1}"
KEEP_DAYS="${CATU_S3_KEEP_DAYS:-90}"
OUT="${CATU_S3_OUT:-$HOME/Backups/catu-s3/server-config}"
IAM_USER="catu-backup-writer"
[ -n "$BUCKET" ] || { echo "Pakai: AWS_PROFILE=<profil> $0 <nama-bucket> [region]"; exit 2; }
command -v aws >/dev/null && command -v openssl >/dev/null || { echo "Butuh aws CLI dan openssl."; exit 1; }
[ ! -e "$OUT/aws-credentials" ] || { echo "$OUT/aws-credentials sudah ada. Hapus/pindahkan dulu bila memang ingin membuat ulang."; exit 1; }

say() { printf '==> %s\n' "$*"; }
say "Akun AWS: $(aws sts get-caller-identity --query Account --output text)  region: $REGION  bucket: $BUCKET"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  say "Bucket sudah ada, pengaturan diperbarui."
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  say "Bucket dibuat."
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration "{\"Rules\":[{\"ID\":\"catu-daily\",
  \"Status\":\"Enabled\",\"Filter\":{\"Prefix\":\"daily/\"},\"Expiration\":{\"Days\":$KEEP_DAYS},
  \"NoncurrentVersionExpiration\":{\"NoncurrentDays\":7},\"AbortIncompleteMultipartUpload\":{\"DaysAfterInitiation\":1}}]}"
say "Bucket: privat, terenkripsi, versioning, daily/ disimpan $KEEP_DAYS hari."

umask 077; mkdir -p "$OUT"; chmod 700 "$OUT"
if [ -n "${CATU_S3_KEY_CSV:-}" ]; then
  # CSV dari Console IAM: baris 2 = "Access key ID,Secret access key". Kunci tidak dicetak.
  [ -s "$CATU_S3_KEY_CSV" ] || { echo "CATU_S3_KEY_CSV tidak ditemukan: $CATU_S3_KEY_CSV"; exit 1; }
  KEYS=$(sed -n 2p "$CATU_S3_KEY_CSV" | tr -d '\r' | awk -F, '{print $1"\t"$2}')
  [ -n "$(cut -f2 <<<"$KEYS")" ] || { echo "Format CSV tidak dikenali (harus berisi Access key ID,Secret access key)."; exit 1; }
  say "Kunci diambil dari $CATU_S3_KEY_CSV (langkah IAM dilewati)."
else
  aws iam get-user --user-name "$IAM_USER" >/dev/null 2>&1 || { aws iam create-user --user-name "$IAM_USER" >/dev/null; say "User IAM $IAM_USER dibuat."; }
  aws iam put-user-policy --user-name "$IAM_USER" --policy-name catu-backup-put-only --policy-document "{\"Version\":\"2012-10-17\",
    \"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/daily/*\"}]}"
  say "Izin $IAM_USER: hanya s3:PutObject ke s3://$BUCKET/daily/*."
  KEYS=$(aws iam create-access-key --user-name "$IAM_USER" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
fi
printf '[default]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$(cut -f1 <<<"$KEYS")" "$(cut -f2 <<<"$KEYS")" > "$OUT/aws-credentials"
unset KEYS
[ -s "$OUT/passphrase" ] || openssl rand -base64 48 | tr -d '\n' > "$OUT/passphrase"
printf 'CATU_S3_BUCKET=%s\nCATU_S3_REGION=%s\n' "$BUCKET" "$REGION" > "$OUT/s3.conf"
chmod 600 "$OUT"/*
say "Konfigurasi server tersimpan di $OUT (kunci tidak ditampilkan)."
say "PENTING: simpan isi $OUT/passphrase di pengelola sandi. Tanpa itu cadangan cloud tidak bisa dibuka."
say "Pasang ke server: scp -r \"$OUT\" <server>:~/.catu-backup && ssh <server> 'chmod 700 ~/.catu-backup && chmod 600 ~/.catu-backup/*'"
