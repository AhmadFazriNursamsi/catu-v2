import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AssignmentsService } from '../assignments/assignments.service';
import { OrderEventsService } from '../order-events/order-events.service';
import { AcceptanceClaimService } from '../order-rules/acceptance-claim.service';
import { orderKeuskupanSql } from '../order-rules/lintas-paroki';
import { EscalationSettingsService } from './escalation-settings.service';
import { RegisterRomoInput, RomoRegistrationService } from './romo-registration.service';
import { opensAt } from './escalation-rules';

/** Awalan gelar hanya bila nama belum memuatnya ("Romo Agus" tidak menjadi "Romo Romo Agus"). */
const titled = (title: string, name: string) => (new RegExp(`^${title}\\b`, 'i').test(name.trim()) ? name.trim() : `${title} ${name.trim()}`);

interface Actor {
  sub: number;
  roleCode: string;
}

interface Evaluation {
  order: any;
  pendingItems: any[];
  reason: string | null;
  /** OPEN: siap dicarikan Romo; WAITING: belum lewat batas menit; CLOSED: sudah diterima/ditutup. */
  state: 'OPEN' | 'WAITING' | 'CLOSED';
}

/**
 * Koordinator mencarikan Romo untuk pelayanan yang belum diterima setelah batas menit eskalasi:
 * memilih salah satu Romo terdaftar, lalu pelayanan otomatis tercatat diterima atas nama Romo tersebut.
 */
@Injectable()
export class KoordinatorAssignmentService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly settings: EscalationSettingsService,
    private readonly assignments: AssignmentsService,
    private readonly events: OrderEventsService,
    private readonly registration: RomoRegistrationService,
    private readonly claims: AcceptanceClaimService,
  ) {}

  async get(user: Actor, orderId: number) {
    const ev = await this.evaluate(user, orderId);
    const items = (await this.dataSource.query('SELECT id, item_name, scheduled_date, scheduled_time_start, location_name FROM order_items WHERE order_id = $1 ORDER BY id', [orderId]));
    const order = {
      id: orderId,
      orderNumber: ev.order.order_number,
      categoryName: ev.order.category_name,
      scheduledDate: ev.order.scheduled_date,
      scheduledTime: ev.order.scheduled_time,
      locationName: ev.order.location_name,
      items: items.map((i: any) => ({ id: Number(i.id), itemName: i.item_name, scheduledDate: i.scheduled_date, scheduledTime: i.scheduled_time_start, locationName: i.location_name })),
    };
    return {
      eligible: ev.reason === null,
      state: ev.state,
      reason: ev.reason,
      order,
      pendingItemIds: ev.pendingItems.map((i: any) => Number(i.id)),
      romos: ev.reason === null ? await this.listRomos(ev.order) : [],
    };
  }

  /** Pilihan formulir pendaftaran Romo (hanya saat pelayanan siap dicarikan Romo). */
  async registerOptions(user: Actor, orderId: number) {
    const ev = await this.evaluate(user, orderId);
    if (ev.reason) throw new BadRequestException(ev.reason);
    return this.registration.options(ev.order);
  }

  /**
   * Mendaftarkan Romo yang belum terdaftar: akun langsung aktif dan pelayanan otomatis diterima atas namanya
   * (semua misa yang belum diterima, atau satu misa bila [itemId] diberikan).
   */
  async registerRomo(user: Actor, orderId: number, input: RegisterRomoInput & { itemId?: number }) {
    const ev = await this.evaluate(user, orderId);
    if (ev.reason) throw new BadRequestException(ev.reason);
    const registered = await this.registration.register(ev.order, input);
    try {
      const assigned = await this.assign(user, orderId, { romoId: registered.romo.id, itemId: input.itemId });
      return { ...registered, assigned: true, message: assigned.message };
    } catch (err) {
      // Akun sudah dibuat; kegagalan penetapan dilaporkan agar Koordinator dapat memilihnya manual.
      return { ...registered, assigned: false, assignError: (err as Error).message };
    }
  }

  async assign(user: Actor, orderId: number, dto: { romoId: number; itemId?: number }) {
    const ev = await this.evaluate(user, orderId);
    if (ev.reason) throw new BadRequestException(ev.reason);
    const romo = await this.dataSource.query(
      `SELECT u.id, p.full_name FROM auth_users u JOIN user_profiles p ON p.user_id = u.id JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1 AND r.code IN ('ROMO_PAROKI', 'ROMO_ORDO') AND u.account_status = 'APPROVED'`,
      [dto.romoId],
    );
    if (romo.length === 0) throw new BadRequestException('Romo tidak ditemukan atau belum aktif.');

    const itemIds: Array<number | undefined> = ev.pendingItems.length === 0 ? [undefined] : ev.pendingItems.map((i: any) => Number(i.id));
    const targets = dto.itemId ? itemIds.filter((id) => id === Number(dto.itemId)) : itemIds;
    if (targets.length === 0) throw new BadRequestException('Misa yang dipilih sudah diterima atau tidak ditemukan.');

    const koordinator = await this.dataSource.query('SELECT full_name FROM user_profiles WHERE user_id = $1', [user.sub]);
    const koordinatorName = koordinator[0]?.full_name || 'Koordinator';
    for (const itemId of targets) {
      // Klaim atomik yang sama dengan penerimaan Romo: Koordinator dan Romo tidak dapat menetapkan bersamaan.
      const claim = await this.claims.claim({ orderId, itemId, romoId: dto.romoId, enforceTerritory: false });
      try {
        const res: any = await this.assignments.respondAssignment(String(orderId), { status: 'CONFIRMED', romoId: dto.romoId, itemId } as any);
        if (res?.status !== 'CONFIRMED') throw new BadRequestException(res?.message || 'Gagal menetapkan Romo.');
      } catch (err) {
        await claim.release();
        throw err;
      }
      await this.events.postChat(orderId, itemId, `${titled('Koordinator', koordinatorName)} menunjuk ${titled('Romo', romo[0].full_name)} untuk melayani pelayanan ini.`);
      await this.events.notify([dto.romoId], {
        orderId,
        itemId,
        type: 'ORDER_ASSIGNED_BY_KOORDINATOR',
        title: 'Anda Ditunjuk Melayani',
        body: `${titled('Koordinator', koordinatorName)} menunjuk Anda untuk pelayanan ${ev.order.category_name} (${ev.order.order_number}). Pelayanan sudah tercatat Anda terima.`,
      });
    }
    return { message: `Pelayanan ditetapkan kepada ${titled('Romo', romo[0].full_name)}.`, romoId: Number(romo[0].id), assignedItems: targets.filter(Boolean) };
  }

  /** Eligibility: koordinator sesuai wilayah, pelayanan belum diterima, dan batas menit Koordinator sudah lewat. */
  private async evaluate(user: Actor, orderId: number): Promise<Evaluation> {
    const rows = await this.dataSource.query(
      `SELECT o.id, o.order_number, o.status, o.created_at, o.accepted_romo_id, o.lintas_paroki, o.scheduled_date, o.scheduled_time, o.location_name,
              sc.name AS category_name,
              COALESCE(o.paroki_id, up.paroki_id) AS paroki_id,
              COALESCE(o.kabupaten_kota_id, up.kabupaten_kota_id) AS kabupaten_kota_id,
              COALESCE(o.keuskupan_id, up.keuskupan_id) AS keuskupan_id,
              COALESCE(o.lingkungan_id, up.lingkungan_id) AS lingkungan_id
       FROM orders o JOIN service_categories sc ON sc.id = o.service_category_id
       LEFT JOIN user_profiles up ON up.user_id = o.user_id WHERE o.id = $1`,
      [orderId],
    );
    if (rows.length === 0) throw new NotFoundException('Order tidak ditemukan');
    const order = rows[0];
    if (!['SUPERADMIN', 'ADMIN'].includes(user.roleCode)) {
      const k = (await this.dataSource.query('SELECT keuskupan_id FROM user_profiles WHERE user_id = $1', [user.sub]))[0];
      // Keuskupan pemohon, atau keuskupan tujuan bila pelayanan lintas paroki.
      const allowed = (await this.dataSource.query(orderKeuskupanSql('$1'), [orderId])).map((r: any) => String(r.keuskupan_id));
      const inScope = k && k.keuskupan_id && allowed.includes(String(k.keuskupan_id));
      if (!inScope) throw new ForbiddenException('Akses ditolak: pelayanan ini di luar keuskupan Anda');
    }
    const items = await this.dataSource.query('SELECT id, status, accepted_romo_id FROM order_items WHERE order_id = $1', [orderId]);
    const pendingItems = items.filter((i: any) => i.status === 'PENDING' && !i.accepted_romo_id);
    const open = items.length === 0 ? order.status === 'PENDING' && !order.accepted_romo_id : pendingItems.length > 0;
    if (!open) return { order, pendingItems, state: 'CLOSED', reason: 'Pelayanan ini sudah diterima Romo atau sudah ditutup.' };
    const { koordinatorAfterMinutes } = await this.settings.get();
    const at = opensAt(new Date(order.created_at), koordinatorAfterMinutes);
    if (Date.now() < at.getTime()) {
      const time = at.toLocaleTimeString('id-ID', { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit' }).replace('.', ':');
      return { order, pendingItems, state: 'WAITING', reason: `Baru dapat dicarikan Romo mulai pukul ${time} WIB (${order.lintas_paroki ? 'menunggu Romo Ordo tujuan' : 'menunggu Romo Paroki dan Romo Ordo'}).` };
    }
    return { order, pendingItems, state: 'OPEN', reason: null };
  }

  /** Semua Romo terdaftar dan aktif; Romo paroki dan Romo Ordo setempat diurutkan lebih dulu. */
  private async listRomos(order: any) {
    const rows = await this.dataSource.query(
      `SELECT u.id, p.full_name, r.code AS role_code, p.paroki_id, p.kabupaten_kota_id,
              par.name AS paroki_name, ord.name AS ordo_name
       FROM auth_users u JOIN user_profiles p ON p.user_id = u.id JOIN roles r ON r.id = u.role_id
       LEFT JOIN paroki par ON par.id = p.paroki_id LEFT JOIN ordo ord ON ord.id = p.ordo_id
       WHERE r.code IN ('ROMO_PAROKI', 'ROMO_ORDO') AND u.account_status = 'APPROVED'`,
    );
    const rank = (r: any) =>
      r.role_code === 'ROMO_PAROKI' && order.paroki_id && String(r.paroki_id) === String(order.paroki_id) ? 0
      : r.role_code === 'ROMO_ORDO' && order.kabupaten_kota_id && String(r.kabupaten_kota_id) === String(order.kabupaten_kota_id) ? 1 : 2;
    return rows
      .map((r: any) => ({
        id: Number(r.id),
        fullName: r.full_name,
        roleCode: r.role_code,
        affiliation: r.role_code === 'ROMO_ORDO' ? r.ordo_name || 'Romo Ordo' : r.paroki_name || 'Romo Paroki',
        local: rank(r) < 2,
        rank: rank(r),
      }))
      .sort((a: any, b: any) => a.rank - b.rank || String(a.fullName).localeCompare(String(b.fullName)))
      .map(({ rank: _rank, ...rest }: any) => rest);
  }
}
