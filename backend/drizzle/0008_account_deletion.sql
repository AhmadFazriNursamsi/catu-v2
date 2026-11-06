-- 0008_account_deletion: akun yang dihapus pemiliknya sendiri (syarat App Store 5.1.1(v)). Baris akun tetap ada agar
-- riwayat pelayanan paroki utuh, tetapi data pribadinya dianonimkan dan akun tidak bisa dipakai lagi. Idempoten.
ALTER TABLE public.auth_users ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Akun terhapus tidak dapat dihidupkan kembali lewat jalur mana pun (persetujuan, ganti peran/status oleh admin,
-- ubah nomor/kata sandi). Pendaftaran ulang dengan nomor yang sama membuat akun BARU.
CREATE OR REPLACE FUNCTION public.auth_users_keep_deleted() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.deleted_at IS NOT NULL AND (
       NEW.deleted_at IS DISTINCT FROM OLD.deleted_at OR NEW.account_status IS DISTINCT FROM OLD.account_status
    OR NEW.is_active IS DISTINCT FROM OLD.is_active OR NEW.role_id IS DISTINCT FROM OLD.role_id
    OR NEW.phone_number IS DISTINCT FROM OLD.phone_number OR NEW.password_hash IS DISTINCT FROM OLD.password_hash) THEN
    RAISE EXCEPTION 'Akun % sudah dihapus pemiliknya dan tidak dapat diubah', OLD.id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_auth_users_keep_deleted ON public.auth_users;
CREATE TRIGGER trg_auth_users_keep_deleted BEFORE UPDATE ON public.auth_users
  FOR EACH ROW EXECUTE FUNCTION public.auth_users_keep_deleted();
