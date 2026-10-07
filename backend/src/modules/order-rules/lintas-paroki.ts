/**
 * Pelayanan LINTAS PAROKI: paroki penerima yang dipilih pemohon berbeda dari paroki domisili pemohon.
 * Aturannya (tanpa parameter jeda): hanya Romo Ordo tujuan (kota pelayanan) yang berwenang; Romo Paroki mana pun
 * (asal maupun tujuan) tidak. Pengurus lingkungan pemohon tetap memantau dan masuk grup chat; Koordinator keuskupan
 * pemohon DAN Koordinator keuskupan tujuan ikut masuk grup chat.
 */
export function isLintasParoki(orderParokiId: number | string | null | undefined, pemohonParokiId: number | string | null | undefined): boolean {
  if (orderParokiId == null || orderParokiId === '') return false;
  return String(orderParokiId) !== String(pemohonParokiId ?? '');
}

/**
 * SQL: keuskupan yang berwenang sebagai Koordinator atas sebuah pelayanan — keuskupan pemohon, ditambah keuskupan
 * paroki tujuan bila pelayanan lintas paroki. Mengembalikan kolom keuskupan_id. [orderIdExpr] berupa "$1" atau "o.id".
 */
export const orderKeuskupanSql = (orderIdExpr: string): string => `
  SELECT COALESCE(ox.keuskupan_id, px.keuskupan_id) AS keuskupan_id
  FROM orders ox LEFT JOIN user_profiles px ON px.user_id = ox.user_id WHERE ox.id = ${orderIdExpr}
  UNION
  SELECT parx.keuskupan_id
  FROM orders ox JOIN paroki parx ON parx.id = ox.paroki_id WHERE ox.id = ${orderIdExpr} AND ox.lintas_paroki`;
