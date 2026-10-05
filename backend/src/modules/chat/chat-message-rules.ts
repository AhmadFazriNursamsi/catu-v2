export const MAX_CHAT_TEXT = 4000;

/** Pesan chat sah: TEXT wajib berisi teks; IMAGE/DOCUMENT wajib berlampiran; LOCATION wajib berisi lokasi. */
export function chatMessageError(dto: { messageType?: string; message?: string; attachmentUrl?: string }): string | null {
  const text = (dto.message ?? '').trim();
  const attachment = (dto.attachmentUrl ?? '').trim();
  if (text.length > MAX_CHAT_TEXT) return `Pesan maksimal ${MAX_CHAT_TEXT} karakter.`;
  switch (dto.messageType) {
    case 'TEXT':
      return text ? null : 'Pesan tidak boleh kosong.';
    case 'IMAGE':
    case 'DOCUMENT':
      return attachment ? null : 'Lampiran wajib disertakan.';
    case 'LOCATION':
      return text || attachment ? null : 'Lokasi wajib disertakan.';
    default:
      return 'Jenis pesan tidak valid.';
  }
}
