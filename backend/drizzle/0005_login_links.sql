-- 0005_login_links: tautan masuk sekali pakai yang dikirim lewat WhatsApp ke Romo yang didaftarkan Koordinator.
-- Hanya hash token yang disimpan; token mentah tidak pernah masuk database. Idempoten.
CREATE TABLE IF NOT EXISTS public.auth_login_links (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES public.auth_users(id) ON DELETE CASCADE,
  token_hash varchar(64) NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auth_login_links_user_id_idx ON public.auth_login_links (user_id);
