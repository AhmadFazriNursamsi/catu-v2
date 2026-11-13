import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { normalizePhone } from '../escalation/romo-registration-rules';

/** "Nama Romo (0812...)" -> nama & nomor (format aplikasi saat mengalihkan ke Romo Eksternal). */
export function splitExternalRomo(raw: string): { name: string; phone: string | null } {
  const m = String(raw ?? '').trim().match(/^(.*?)\s*\(([^()]*)\)\s*$/);
  if (!m) return { name: String(raw ?? '').trim(), phone: null };
  return { name: m[1].trim(), phone: normalizePhone(m[2]) };
}

const fmtDate = (raw: any): string => {
  const d = raw instanceof Date ? raw : raw ? new Date(`${String(raw).slice(0, 10)}T00:00:00`) : null;
  return d && !isNaN(d.getTime()) ? d.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) : '';
};
const fmtTime = (raw: any): string => (raw ? String(raw).slice(0, 5).replace(':', '.') : '');

/**
 * Romo Eksternal tidak memakai aplikasi CATU, jadi detail pelayanan yang dialihkan kepadanya dikirim lewat WhatsApp.
 * Kegagalan kirim tidak membatalkan pengalihan; hasilnya dilaporkan ke Romo yang mengalihkan.
 */
@Injectable()
export class ExternalRomoWaService {
  private readonly logger = new Logger(ExternalRomoWaService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly wa: WhatsappService,
  ) {}

  async notify(orderId: number, itemId: number | null, rawName: string, prevRomoName: string): Promise<{ sent: boolean; note: string }> {
    const { name, phone } = splitExternalRomo(rawName);
    if (!phone) return { sent: false, note: `Nomor WhatsApp Romo ${name} tidak diisi/valid, mohon kabari beliau langsung.` };
    const rows = await this.dataSource.query(
      `SELECT o.order_number, sc.name AS category, oi.item_name,
              COALESCE(oi.scheduled_date, o.scheduled_date) AS day,
              COALESCE(oi.scheduled_time_start::text, o.scheduled_time::text) AS time_start, oi.scheduled_time_end::text AS time_end,
              COALESCE(NULLIF(oi.location_name, ''), o.location_name) AS location, o.address_detail,
              p.full_name AS pemohon, u.phone_number AS pemohon_phone
       FROM orders o JOIN service_categories sc ON sc.id = o.service_category_id
       LEFT JOIN order_items oi ON oi.id = $2 AND oi.order_id = o.id
       LEFT JOIN user_profiles p ON p.user_id = o.user_id LEFT JOIN auth_users u ON u.id = o.user_id
       WHERE o.id = $1`,
      [orderId, itemId],
    );
    if (rows.length === 0) return { sent: false, note: '' };
    const sent = await this.wa.send(phone, this.text(name, prevRomoName, rows[0]), { priority: 'normal' });
    if (sent.ok) return { sent: true, note: `Detail pelayanan sudah dikirim lewat WhatsApp ke Romo ${name}.` };
    this.logger.warn(`WhatsApp ke Romo Eksternal order ${orderId} gagal: ${sent.code}`);
    return { sent: false, note: `WhatsApp ke Romo ${name} gagal terkirim, mohon kabari beliau langsung.` };
  }

  private text(name: string, prevRomoName: string, r: any): string {
    const service = [r.category, r.item_name && r.item_name !== r.category ? `- ${r.item_name}` : ''].filter(Boolean).join(' ');
    const time = [fmtTime(r.time_start), fmtTime(r.time_end)].filter(Boolean).join('–');
    const lines = [
      `*CATU* - Shalom Romo ${name},`,
      '',
      `Romo ${prevRomoName} berhalangan dan mengalihkan pelayanan berikut kepada Romo:`,
      '',
      `Pelayanan: ${service} (${r.order_number})`,
      fmtDate(r.day) ? `Tanggal: ${fmtDate(r.day)}` : null,
      time ? `Jam: ${time} WIB` : null,
      r.location ? `Tempat: ${r.location}` : null,
      r.address_detail ? `Alamat: ${r.address_detail}` : null,
      r.pemohon ? `Pemohon: ${r.pemohon}${r.pemohon_phone ? ` (${r.pemohon_phone})` : ''}` : null,
      '',
      'Mohon hubungi pemohon untuk koordinasi. Terima kasih, Romo.',
    ];
    return lines.filter((l) => l !== null).join('\n');
  }
}
