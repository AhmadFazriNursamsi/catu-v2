-- 0004_must_change_password: akun yang dibuat Koordinator (Romo belum terdaftar) memakai kata sandi sementara
-- dan wajib menggantinya pada login pertama. Idempoten; akun yang sudah ada tidak terpengaruh (FALSE).
ALTER TABLE public.auth_users ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;
