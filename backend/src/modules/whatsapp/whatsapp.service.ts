import { Injectable, Logger } from '@nestjs/common';

export type WaPriority = 'otp' | 'normal';
export type WaSendResult = { ok: true; id: string; status: string } | { ok: false; code: string; message: string };

/**
 * Klien ke WAGate (gateway WhatsApp milik sendiri). Nonaktif bila WAGATE_URL atau WAGATE_API_KEY kosong.
 * WAGATE_URL adalah alamat lengkap endpoint kirim; kunci dikirim lewat header `x-api-key`.
 */
@Injectable()
export class WhatsappService {
  private readonly logger = new Logger(WhatsappService.name);
  private readonly url = (process.env.WAGATE_URL ?? '').trim();
  private readonly apiKey = (process.env.WAGATE_API_KEY ?? '').trim();

  get enabled(): boolean {
    return this.url.length > 0 && this.apiKey.length > 0;
  }

  /** WAGate memakai format internasional tanpa tanda plus (62812...). */
  private normalize(to: string): string {
    const digits = String(to).replace(/\D/g, '');
    return digits.startsWith('0') ? `62${digits.slice(1)}` : digits;
  }

  async send(to: string, text: string, _opts: { priority?: WaPriority; key?: string } = {}): Promise<WaSendResult> {
    if (!this.enabled) return { ok: false, code: 'DISABLED', message: 'Layanan WhatsApp belum dikonfigurasi.' };
    try {
      const res = await fetch(this.url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-api-key': this.apiKey },
        body: JSON.stringify({ numbers: [this.normalize(to)], force: false, messages: [text] }),
        signal: AbortSignal.timeout(10_000),
      });
      const body: any = await res.json().catch(() => ({}));
      if (res.ok) return { ok: true, id: String(body.id ?? body.messageId ?? ''), status: String(body.status ?? 'sent') };
      return { ok: false, code: body.code ?? `HTTP_${res.status}`, message: body.message ?? 'Pesan WhatsApp gagal dikirim.' };
    } catch (e: any) {
      this.logger.warn(`WAGate tidak dapat dihubungi: ${e?.message ?? e}`);
      return { ok: false, code: 'UNREACHABLE', message: 'Layanan WhatsApp tidak dapat dihubungi.' };
    }
  }
}
