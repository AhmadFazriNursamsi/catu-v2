import { chatMessageError } from './chat-message-rules';

describe('chatMessageError', () => {
  it('pesan teks wajib berisi', () => {
    expect(chatMessageError({ messageType: 'TEXT', message: 'Halo' })).toBeNull();
    for (const message of ['', '   ', undefined]) expect(chatMessageError({ messageType: 'TEXT', message })).toMatch(/kosong/);
  });

  it('gambar dan dokumen wajib berlampiran; teks pendamping opsional', () => {
    expect(chatMessageError({ messageType: 'IMAGE', message: 'Foto', attachmentUrl: 'data:image/png;base64,AAA' })).toBeNull();
    expect(chatMessageError({ messageType: 'IMAGE', message: 'Foto' })).toMatch(/Lampiran/);
    expect(chatMessageError({ messageType: 'DOCUMENT', attachmentUrl: 'https://x/y.pdf' })).toBeNull();
  });

  it('lokasi wajib berisi', () => {
    expect(chatMessageError({ messageType: 'LOCATION', message: '-6.2,106.8' })).toBeNull();
    expect(chatMessageError({ messageType: 'LOCATION' })).toMatch(/Lokasi/);
  });

  it('batas panjang dan jenis tidak valid', () => {
    expect(chatMessageError({ messageType: 'TEXT', message: 'x'.repeat(4001) })).toMatch(/maksimal/);
    expect(chatMessageError({ messageType: 'BOGUS', message: 'x' })).toMatch(/tidak valid/);
  });
});
