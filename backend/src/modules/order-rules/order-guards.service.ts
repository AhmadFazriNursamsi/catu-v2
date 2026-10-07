import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ONGOING_STATUSES, SERVICE_STATUSES } from './order-status-machine';

export const MAX_EXTERNAL_ROMO_NAME = 100;
export const MAX_HANDOVER_REASON = 500;

interface Target {
  status: string;
  acceptedRomoId: number | null;
  rescheduleStatus: string;
  handoverStatus: string;
  scheduledDate: string | null;
}

/** Pemeriksaan keadaan pelayanan sebelum ubah jam, pelimpahan, penetapan status, dan pembuatan pelayanan. */
@Injectable()
export class OrderGuardsService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  /** Baris misa (bila itemId) atau baris order yang menjadi sasaran tindakan. */
  async target(orderId: number, itemId?: number | null): Promise<Target> {
    const rows = await this.dataSource.query(
      itemId
        ? `SELECT status::text AS status, accepted_romo_id, COALESCE(reschedule_status, 'NONE') AS reschedule_status, COALESCE(handover_status, 'NONE') AS handover_status, scheduled_date::text AS scheduled_date FROM order_items WHERE id = $1 AND order_id = $2`
        : `SELECT status::text AS status, accepted_romo_id, COALESCE(reschedule_status, 'NONE') AS reschedule_status, COALESCE(handover_status, 'NONE') AS handover_status, scheduled_date::text AS scheduled_date FROM orders WHERE id = $1`,
      itemId ? [itemId, orderId] : [orderId],
    );
    if (rows.length === 0) throw new NotFoundException(itemId ? 'Misa pelayanan tidak ditemukan.' : 'Order tidak ditemukan.');
    const r = rows[0];
    return { status: r.status, acceptedRomoId: r.accepted_romo_id == null ? null : Number(r.accepted_romo_id), rescheduleStatus: r.reschedule_status, handoverStatus: r.handover_status, scheduledDate: r.scheduled_date ?? null };
  }

  /** Tanggal (yyyy-MM-dd) pelayanan atau misa; ubah jam hanya mengubah jam pada tanggal ini. */
  async scheduledDate(orderId: number, itemId?: number | null): Promise<string | null> {
    return (await this.target(orderId, itemId)).scheduledDate;
  }

  async assertExists(orderId: number): Promise<void> {
    await this.target(orderId, null);
  }

  /** Ubah jam hanya untuk pelayanan yang sudah diterima dan belum berlangsung, tanpa ajuan lain yang masih menunggu. */
  async assertRescheduleProposable(orderId: number, itemId?: number | null): Promise<void> {
    const t = await this.target(orderId, itemId);
    if (t.status !== 'CONFIRMED') throw new ConflictException(`Ubah jam hanya dapat diajukan untuk pelayanan yang sudah diterima Romo dan belum berlangsung (status saat ini ${t.status}).`);
    if (t.rescheduleStatus === 'PENDING_UMAT') throw new ConflictException('Masih ada ajuan ubah jam yang menunggu respons umat.');
  }

  async assertReschedulePending(orderId: number, itemId?: number | null): Promise<void> {
    const t = await this.target(orderId, itemId);
    if (t.rescheduleStatus !== 'PENDING_UMAT') throw new ConflictException('Tidak ada ajuan ubah jam yang menunggu respons.');
    if (['DONE', 'CLOSE', 'FAIL'].includes(t.status)) throw new ConflictException('Pelayanan sudah selesai atau ditutup, sehingga ajuan ubah jam tidak berlaku lagi.');
  }

  async assertHandoverPending(orderId: number, itemId?: number | null): Promise<void> {
    const t = await this.target(orderId, itemId);
    if (t.handoverStatus !== 'PENDING') throw new ConflictException('Tidak ada pelimpahan yang menunggu respons.');
  }

  /** Pelimpahan: pelayanan harus berjalan, Romo pengganti harus Romo aktif lain (atau nama Romo eksternal yang wajar). */
  async assertHandoverAllowed(orderId: number, itemId: number | null | undefined, dto: { romoId: number; targetRomoId?: number; externalRomoName?: string; reason?: string }): Promise<void> {
    const external = (dto.externalRomoName ?? '').trim();
    if ((dto.reason ?? '').length > MAX_HANDOVER_REASON) throw new BadRequestException(`Alasan maksimal ${MAX_HANDOVER_REASON} karakter.`);
    if (external) {
      if (external.length < 3 || external.length > MAX_EXTERNAL_ROMO_NAME || /[\u0000-\u001f<>]/.test(external)) throw new BadRequestException(`Nama Romo pengganti harus 3 sampai ${MAX_EXTERNAL_ROMO_NAME} karakter dan tanpa karakter khusus.`);
    } else {
      if (!dto.targetRomoId) throw new BadRequestException('Romo pengganti wajib diisi.');
      if (Number(dto.targetRomoId) === Number(dto.romoId)) throw new BadRequestException('Romo pengganti tidak boleh sama dengan Romo yang bertugas.');
      const romo = await this.dataSource.query(
        `SELECT 1 FROM auth_users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1 AND r.code IN ('ROMO_PAROKI', 'ROMO_ORDO') AND u.account_status = 'APPROVED' AND u.is_active IS NOT FALSE`,
        [dto.targetRomoId],
      );
      if (romo.length === 0) throw new BadRequestException('Romo pengganti tidak valid: harus Romo terdaftar yang aktif.');
    }
    const t = await this.target(orderId, itemId);
    if (!(ONGOING_STATUSES as string[]).includes(t.status)) throw new ConflictException(`Pelimpahan hanya dapat diajukan untuk pelayanan yang sedang berjalan (status saat ini ${t.status}).`);
    if (t.handoverStatus === 'PENDING') throw new ConflictException('Masih ada pelimpahan yang menunggu respons.');
  }

  /** Kategori dan tingkat urgensi harus ada (dan kategori aktif) agar tidak berujung galat server. */
  async assertNewOrderRefs(dto: { serviceCategoryId: number; urgencyLevelId: number }): Promise<void> {
    const [cat, urg] = await Promise.all([
      this.dataSource.query('SELECT 1 FROM service_categories WHERE id = $1 AND is_active IS NOT FALSE', [dto.serviceCategoryId]),
      this.dataSource.query('SELECT 1 FROM urgency_levels WHERE id = $1', [dto.urgencyLevelId]),
    ]);
    if (cat.length === 0) throw new BadRequestException('Kategori pelayanan tidak ditemukan atau tidak aktif.');
    if (urg.length === 0) throw new BadRequestException('Tingkat urgensi tidak ditemukan.');
  }

  /** Status yang boleh ditetapkan Admin lewat endpoint status. */
  isAdminAssignableStatus(status: string): boolean {
    return (SERVICE_STATUSES as string[]).includes(status);
  }
}
