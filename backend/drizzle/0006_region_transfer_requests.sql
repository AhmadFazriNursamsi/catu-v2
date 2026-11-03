-- 0006_region_transfer_requests: permintaan Umat pindah lingkungan/wilayah gereja yang menunggu persetujuan pengurus lingkungan tujuan.
-- Wilayah lama disimpan agar permintaan yang ditolak dapat dikembalikan. Idempoten.
CREATE TABLE IF NOT EXISTS public.region_transfer_requests (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES public.auth_users(id) ON DELETE CASCADE,
  from_keuskupan_id integer REFERENCES public.keuskupan(id) ON DELETE SET NULL,
  from_paroki_id integer REFERENCES public.paroki(id) ON DELETE SET NULL,
  from_wilayah_id integer REFERENCES public.wilayah(id) ON DELETE SET NULL,
  from_lingkungan_id integer REFERENCES public.lingkungan(id) ON DELETE SET NULL,
  to_keuskupan_id integer REFERENCES public.keuskupan(id) ON DELETE SET NULL,
  to_paroki_id integer REFERENCES public.paroki(id) ON DELETE SET NULL,
  to_wilayah_id integer REFERENCES public.wilayah(id) ON DELETE SET NULL,
  to_lingkungan_id integer REFERENCES public.lingkungan(id) ON DELETE SET NULL,
  status varchar(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  decided_by integer REFERENCES public.auth_users(id) ON DELETE SET NULL,
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz
);
CREATE INDEX IF NOT EXISTS region_transfer_requests_user_id_idx ON public.region_transfer_requests (user_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_decided_by_idx ON public.region_transfer_requests (decided_by);
CREATE INDEX IF NOT EXISTS region_transfer_requests_from_keuskupan_idx ON public.region_transfer_requests (from_keuskupan_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_from_paroki_idx ON public.region_transfer_requests (from_paroki_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_from_wilayah_idx ON public.region_transfer_requests (from_wilayah_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_from_lingkungan_idx ON public.region_transfer_requests (from_lingkungan_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_to_keuskupan_idx ON public.region_transfer_requests (to_keuskupan_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_to_paroki_idx ON public.region_transfer_requests (to_paroki_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_to_wilayah_idx ON public.region_transfer_requests (to_wilayah_id);
CREATE INDEX IF NOT EXISTS region_transfer_requests_to_lingkungan_idx ON public.region_transfer_requests (to_lingkungan_id);
-- Satu permintaan terbuka per pengguna.
CREATE UNIQUE INDEX IF NOT EXISTS region_transfer_requests_one_pending_idx ON public.region_transfer_requests (user_id) WHERE status = 'PENDING';
