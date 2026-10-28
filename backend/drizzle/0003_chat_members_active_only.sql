-- 0003_chat_members_active_only: akun yang belum/tidak aktif tidak boleh menjadi anggota grup chat pelayanan.
-- Idempoten; hanya membersihkan keanggotaan lama Pengurus Lingkungan dan Romo Paroki berstatus bukan APPROVED.
-- Aturan untuk grup baru ada di kueri pemilihan anggota (orders, assignments, chat).

DELETE FROM chat_group_members m
USING auth_users u
WHERE u.id = m.user_id
  AND u.account_status <> 'APPROVED'
  AND m.role_in_group IN ('PENGURUS_LINGKUNGAN', 'ROMO_PAROKI');
