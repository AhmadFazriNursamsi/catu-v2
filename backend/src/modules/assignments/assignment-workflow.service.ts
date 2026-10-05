import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { RespondOrderAssignmentDto } from '../../orders.dto';
import { AcceptanceClaimService } from '../order-rules/acceptance-claim.service';
import { OrderGuardsService } from '../order-rules/order-guards.service';
import { decideTransition } from '../order-rules/order-status-machine';
import { AssignmentsService } from './assignments.service';

export interface RespondContext {
  /** Romo yang bertindak (dari token; Admin boleh menentukan sendiri). */
  romoId?: number | null;
  isAdmin: boolean;
}

/**
 * Penetapan status pelayanan oleh Romo: penerimaan atomik (satu pemenang), pembatasan paroki/kota Romo, dan urutan
 * status yang sah (DONE/CLOSE/FAIL final, tidak mundur). AssignmentsService tetap melakukan pembaruan dan notifikasi.
 */
@Injectable()
export class AssignmentWorkflowService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly assignments: AssignmentsService,
    private readonly claims: AcceptanceClaimService,
    private readonly guards: OrderGuardsService,
  ) {}

  async respond(orderId: number, dto: RespondOrderAssignmentDto, ctx: RespondContext) {
    const status = dto.status === 'ACCEPTED' ? 'CONFIRMED' : dto.status;
    const itemId = (dto as any).itemId || (dto as any).item_id || null;
    const call = () => this.assignments.respondAssignment(String(orderId), { ...dto, romoId: ctx.romoId ?? undefined });

    if (status === 'DECLINED') return call();

    if (status === 'CONFIRMED') {
      if (!ctx.romoId) throw new BadRequestException('Romo yang menerima wajib ditentukan.');
      await this.assertActiveRomo(ctx.romoId);
      const claim = await this.claims.claim({ orderId, itemId, romoId: ctx.romoId, enforceTerritory: !ctx.isAdmin });
      if (!claim.claimed) return { message: 'Anda sudah menerima pelayanan ini sebelumnya.', status: 'CONFIRMED' };
      try {
        const result: any = await call();
        if (result?.status !== 'CONFIRMED') await claim.release();
        return result;
      } catch (err) {
        await claim.release();
        throw err;
      }
    }

    const target = await this.guards.target(orderId, itemId);
    if (!ctx.isAdmin && target.acceptedRomoId !== Number(ctx.romoId)) {
      throw new ForbiddenException('Hanya Romo yang bertugas yang dapat mengubah status pelayanan ini.');
    }
    const decision = decideTransition(target.status, status, ctx.isAdmin);
    if (decision.kind === 'DENIED') throw new ConflictException(decision.message);
    if (decision.kind === 'NOOP') return { message: `Pelayanan sudah berstatus ${status}.`, status };
    return call();
  }

  private async assertActiveRomo(romoId: number): Promise<void> {
    const rows = await this.dataSource.query(
      `SELECT 1 FROM auth_users u JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1 AND r.code IN ('ROMO_PAROKI', 'ROMO_ORDO') AND u.account_status = 'APPROVED' AND u.is_active IS NOT FALSE`,
      [romoId],
    );
    if (rows.length === 0) throw new BadRequestException('Romo tidak ditemukan atau belum aktif.');
  }
}
