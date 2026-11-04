-- 0007_news_categories_seed: kategori berita bawaan. Database baru tidak punya baris ini, padahal penyimpanan berita
-- memakai kategori sebagai foreign key (tanpa kategori, semua artikel gagal disimpan). Idempoten: yang sudah ada dilewati.
INSERT INTO public.news_categories (name, slug, description, icon_name, display_order, is_active)
SELECT v.name, v.slug, v.description, v.icon_name, v.display_order, true
FROM (VALUES
  ('Semua', 'semua', 'Semua warta dan berita Katolik terbaru', 'newspaper', 1),
  ('Vatikan & Paus', 'vatikan-dan-paus', 'Warta dari Tahta Suci Vatikan dan Bapa Suci', 'location_city', 2),
  ('Gereja Indonesia', 'gereja-indonesia', 'Kabar keuskupan dan paroki se-Indonesia', 'church', 3),
  ('Liturgi & Doa', 'liturgi-dan-doa', 'Panduan liturgi, sakramen, dan doa harian', 'menu_book', 4),
  ('Renungan Oase', 'renungan-oase', 'Renungan sabda harian dan inspirasi rohani', 'wb_sunny', 5),
  ('Orang Muda Katolik', 'orang-muda-katolik', 'Kegiatan, komunitas, dan pastoral OMK', 'groups', 6)
) AS v(name, slug, description, icon_name, display_order)
WHERE NOT EXISTS (SELECT 1 FROM public.news_categories c WHERE c.slug = v.slug);
