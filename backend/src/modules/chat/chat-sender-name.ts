/**
 * Nama pengirim pesan untuk tampilan chat (butuh alias `m` = chat_messages, `p` = user_profiles pengirim).
 * Romo diberi awalan "Romo" agar Romo yang bertugas mudah dikenali di daftar chat & gelembung pesan,
 * kecuali namanya sudah diawali "Romo"/"Rm.".
 */
export const SENDER_NAME_SQL = `CASE WHEN (SELECT r.code FROM auth_users su JOIN roles r ON r.id = su.role_id WHERE su.id = m.sender_id) LIKE 'ROMO%'
  AND p.full_name !~* '^(romo|rm\\.?)\\s' THEN 'Romo ' || p.full_name ELSE p.full_name END`;
