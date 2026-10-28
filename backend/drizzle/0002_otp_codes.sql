-- Kode OTP (mis. lupa kata sandi) yang dikirim lewat WhatsApp. Kode tidak pernah disimpan apa adanya: hanya HMAC-SHA256-nya.
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id bigserial PRIMARY KEY,
  phone_number varchar(20) NOT NULL,
  purpose varchar(30) NOT NULL,
  code_hash char(64) NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  verified_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_otp_codes_purpose CHECK (purpose ~ '^[A-Z][A-Z0-9_]*$'),
  CONSTRAINT chk_otp_codes_attempts CHECK (attempts >= 0)
);

CREATE INDEX IF NOT EXISTS ix_otp_codes_phone_purpose_created ON public.otp_codes (phone_number, purpose, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_otp_codes_expires_at ON public.otp_codes (expires_at);
