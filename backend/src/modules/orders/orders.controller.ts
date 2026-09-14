import {
  Controller,
  Post,
  Put,
  Delete,
  Body,
  Get,
  Param,
  Query,
  OnModuleInit,
  BadRequestException,
  NotFoundException,
  HttpCode,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import {
  RegisterUserDto,
  LoginDto,
  ApproveUserDto,
  RegisterResponseDto,
  LoginResponseDto,
  ApproveUserResponseDto,
  RoleCodeEnum,
  RequestResetOtpDto,
  VerifyResetOtpDto,
  ResetPasswordDto,
} from '../../auth.dto';
import {
  CreateOrderDto,
  RespondOrderAssignmentDto,
  SendChatMessageDto,
  UpdateUserProfileDto,
  CreateKeuskupanDto,
  UpdateKeuskupanDto,
  CreateParokiDto,
  UpdateParokiDto,
  CreateWilayahDto,
  UpdateWilayahDto,
  CreateLingkunganDto,
  UpdateLingkunganDto,
  CreateOrdoDto,
  UpdateOrdoDto,
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  CreateRoleDto,
  UpdateRoleDto,
  CreatePositionDto,
  UpdatePositionDto,
} from '../../orders.dto';
import { FcmService } from '../../fcm.service';

@ApiTags('Orders & Pelayanan')
@Controller('orders')
export class OrdersController {
  constructor(
    @InjectDataSource() private dataSource: DataSource,
    private fcmService: FcmService,
  ) {}

  private async getPengurusForOrder(orderId: number, excludeUserId?: number): Promise<any[]> {
    const orderHierarchy = await this.dataSource.query(
      `SELECT o.lingkungan_id, o.paroki_id, COALESCE(o.keuskupan_id, p.keuskupan_id) as keuskupan_id
       FROM orders o
       JOIN user_profiles p ON o.user_id = p.user_id
       WHERE o.id = $1`,
      [orderId],
    );
    if (orderHierarchy.length === 0) return [];
    const oh = orderHierarchy[0];
    const keuskupanId = oh.keuskupan_id;
    let pengurus: any[] = [];
    if (oh.lingkungan_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.lingkungan_id = $1`,
        [oh.lingkungan_id],
      );
    }
    if (pengurus.length === 0 && oh.paroki_id) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.paroki_id = $1`,
        [oh.paroki_id],
      );
    }

    // Also include Koordinator in the same Keuskupan
    if (keuskupanId) {
      const koordinator = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'KOORDINATOR' OR LOWER(p.pengurus_position) LIKE '%koordinator%') AND p.keuskupan_id = $1`,
        [keuskupanId],
      );
      for (const k of koordinator) {
        if (!pengurus.some((p: any) => p.id === k.id)) {
          pengurus.push(k);
        }
      }
    }

    if (excludeUserId) {
      pengurus = pengurus.filter((p: any) => p.id !== excludeUserId);
    }

    return pengurus;
  }

  @Post()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Membuat Pesanan Pelayanan Baru (Perminyakan / Misa Kedukaan Multi-Item)',
  })
  async createOrder(@Body() dto: CreateOrderDto) {
    const orderNum = `ORD-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${Math.floor(1000 + Math.random() * 9000)}`;
    let userId = dto.userId && dto.userId > 0 ? dto.userId : null;
    if (userId) {
      const uCheck = await this.dataSource.query('SELECT id FROM auth_users WHERE id = $1', [userId]);
      if (uCheck.length === 0) userId = null;
    }
    if (!userId) {
      const uFirst = await this.dataSource.query('SELECT id FROM auth_users ORDER BY id ASC LIMIT 1');
      userId = uFirst.length > 0 ? uFirst[0].id : null;
    }

    // Fetch user profile default hierarchy if DTO doesn't specify custom location hierarchy
    let kId = dto.keuskupanId;
    let pId = dto.parokiId;
    let wId = dto.wilayahId;
    let lId = dto.lingkunganId;
    let kabId = dto.kabupatenKotaId;

    if (!kId || !pId || !kabId) {
      const prof = await this.dataSource.query(
        `SELECT keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id FROM user_profiles WHERE user_id = $1`,
        [userId],
      );
      if (prof.length > 0) {
        kId = kId || prof[0].keuskupan_id || 1;
        pId = pId || prof[0].paroki_id || 10;
        wId = wId || prof[0].wilayah_id || 101;
        lId = lId || prof[0].lingkungan_id || 1001;
        kabId = kabId || prof[0].kabupaten_kota_id || 3175;
      } else {
        kId = kId || 1;
        pId = pId || 10;
        wId = wId || 101;
        lId = lId || 1001;
        kabId = kabId || 3175;
      }
    }

    const orderResult = await this.dataSource.query(
      `INSERT INTO orders (order_number, user_id, service_category_id, urgency_level_id, keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id, status, scheduled_date, scheduled_time, location_name, address_detail, notes, attachment_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'PENDING', $10, $11, $12, $13, $14, $15) RETURNING id, order_number, status, created_at`,
      [
        orderNum,
        userId,
        dto.serviceCategoryId,
        dto.urgencyLevelId,
        kId,
        pId,
        wId || null,
        lId || null,
        kabId || null,
        dto.scheduledDate,
        dto.scheduledTime,
        dto.locationName,
        dto.addressDetail,
        dto.notes || '',
        dto.attachmentUrl || null,
      ],
    );

    const order = orderResult[0];

    // 1. Find actual Pengurus Lingkungan for this lingkungan / paroki
    let pengurus: any[] = [];
    if (lId) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.lingkungan_id = $1`,
        [lId],
      );
    }
    if (pengurus.length === 0 && pId) {
      pengurus = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) AND p.paroki_id = $1`,
        [pId],
      );
    }

    // 1b. Find Koordinator for this Keuskupan
    let koordinator: any[] = [];
    if (kId) {
      koordinator = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE (r.code = 'KOORDINATOR' OR LOWER(p.pengurus_position) LIKE '%koordinator%') AND p.keuskupan_id = $1`,
        [kId],
      );
    }

    // 2. Find Romo Paroki
    let romoParoki: any[] = [];
    if (pId) {
      romoParoki = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE r.code = 'ROMO_PAROKI' AND p.paroki_id = $1`,
        [pId],
      );
    }

    // 3. Find Romo Ordo
    let romoOrdo: any[] = [];
    if (kabId) {
      romoOrdo = await this.dataSource.query(
        `SELECT u.id FROM auth_users u
         JOIN user_profiles p ON u.id = p.user_id
         JOIN roles r ON u.role_id = r.id
         WHERE r.code = 'ROMO_ORDO' AND p.kabupaten_kota_id = $1`,
        [kabId],
      );
    }

    // Strictly filter out creator from observer / monitoring lists
    if (userId) {
      const numUserId = Number(userId);
      pengurus = pengurus.filter((p: any) => Number(p.id) !== numUserId);
      koordinator = koordinator.filter((k: any) => Number(k.id) !== numUserId);
      romoParoki = romoParoki.filter((r: any) => Number(r.id) !== numUserId);
      romoOrdo = romoOrdo.filter((ro: any) => Number(ro.id) !== numUserId);
    }

    let firstGroupId: number | null = null;

    if (dto.items && dto.items.length > 0) {
      for (const item of dto.items) {
        const itemResult = await this.dataSource.query(
          `INSERT INTO order_items (order_id, item_name, scheduled_date, scheduled_time_start, scheduled_time_end, location_name)
           VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
          [order.id, item.itemName, item.scheduledDate, item.scheduledTimeStart, item.scheduledTimeEnd, item.locationName],
        );
        const itemId = itemResult[0].id;

        const groupResult = await this.dataSource.query(
          `INSERT INTO chat_groups (order_id, order_item_id, title, last_message_text) VALUES ($1, $2, $3, $4) RETURNING id`,
          [order.id, itemId, `Grup Pelayanan - ${item.itemName} (${order.order_number})`, 'Grup Pelayanan telah dibentuk'],
        );
        const gId = groupResult[0].id;
        if (!firstGroupId) firstGroupId = gId;

        // 1. Add order creator (Umat)
        if (userId) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'UMAT') ON CONFLICT DO NOTHING`,
            [gId, userId],
          );
        }

        // 2. Add Pengurus Lingkungan
        for (const p of pengurus) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'PENGURUS_LINGKUNGAN') ON CONFLICT DO NOTHING`,
            [gId, p.id],
          );
        }

        // 2b. Add Koordinator Keuskupan
        for (const k of koordinator) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'KOORDINATOR') ON CONFLICT DO NOTHING`,
            [gId, k.id],
          );
        }

        // 3. Welcome message
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [gId, `Grup Pelayanan untuk ${item.itemName} (${order.order_number}) telah dibuat. Menunggu konfirmasi kehadiran Romo.`],
        );

        // 🔔 4. Notify Pengurus Lingkungan per-misa (exclude creator)
        for (const p of pengurus) {
          if (p.id && p.id !== userId) {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
               VALUES ($1, $2, $3, $4, 'NEW_ORDER_MONITOR', false)`,
              [
                p.id,
                order.id,
                `Pemantauan ${item.itemName}`,
                `Ada permintaan ${item.itemName} (${order.order_number}) dari warga lingkungan Anda. Ketuk untuk memantau status dan koordinasi via chat.`
              ],
            );
          }
        }

        // 🔔 4b. Notify Koordinator Keuskupan per-misa (exclude creator)
        for (const k of koordinator) {
          if (k.id && k.id !== userId) {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
               VALUES ($1, $2, $3, $4, 'NEW_ORDER_KOORDINATOR', false)`,
              [
                k.id,
                order.id,
                `Pemantauan Keuskupan: ${item.itemName}`,
                `Ada permintaan ${item.itemName} (${order.order_number}) di keuskupan Anda. Ketuk untuk memantau status dan koordinasi via chat.`
              ],
            );
          }
        }

        // 🔔 5. Notify Romo Paroki per-misa (exclude creator)
        for (const rp of romoParoki) {
          if (rp.id && rp.id !== userId) {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
               VALUES ($1, $2, $3, $4, 'NEW_ORDER_ROMO', false)`,
              [
                rp.id,
                order.id,
                `Permintaan Pelayanan ${item.itemName}`,
                `Umat yang berada di paroki anda telah membuat permintaan pelayanan ${item.itemName} (${order.order_number}).`
              ],
            );
          }
        }

        // 🔔 6. Notify Romo Ordo per-misa (exclude creator)
        let targetRomoOrdo = romoOrdo;
        const itemKabId = item.kabupatenKotaId || kabId;
        if (itemKabId && itemKabId !== kabId) {
          targetRomoOrdo = await this.dataSource.query(
            `SELECT u.id FROM auth_users u
             JOIN user_profiles p ON u.id = p.user_id
             JOIN roles r ON u.role_id = r.id
             WHERE r.code = 'ROMO_ORDO' AND p.kabupaten_kota_id = $1`,
            [itemKabId],
          );
        }

        for (const ro of targetRomoOrdo) {
          if (ro.id && ro.id !== userId) {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
               VALUES ($1, $2, $3, $4, 'NEW_ORDER_ROMO', false)`,
              [
                ro.id,
                order.id,
                `Permintaan Pelayanan ${item.itemName}`,
                `Umat yang berada di kota anda telah membuat permintaan pelayanan ${item.itemName} (${order.order_number}).`
              ],
            );
          }
        }
      }
    } else {
      const groupResult = await this.dataSource.query(
        `INSERT INTO chat_groups (order_id, order_item_id, title, last_message_text) VALUES ($1, NULL, $2, $3) RETURNING id`,
        [order.id, `Grup Pelayanan - ${order.order_number}`, 'Grup Pelayanan telah dibentuk'],
      );
      firstGroupId = groupResult[0].id;

      if (userId) {
        await this.dataSource.query(
          `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'UMAT') ON CONFLICT DO NOTHING`,
          [firstGroupId, userId],
        );
      }

      for (const p of pengurus) {
        if (p.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'PENGURUS_LINGKUNGAN') ON CONFLICT DO NOTHING`,
            [firstGroupId, p.id],
          );
        }
      }

      for (const k of koordinator) {
        if (k.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group) VALUES ($1, $2, 'KOORDINATOR') ON CONFLICT DO NOTHING`,
            [firstGroupId, k.id],
          );
        }
      }

      await this.dataSource.query(
        `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
        [firstGroupId, `Grup Pelayanan ${order.order_number} telah dibuat. Menunggu konfirmasi kehadiran Romo.`],
      );

      // 🔔 Notify Pengurus Lingkungan (exclude creator)
      for (const p of pengurus) {
        if (p.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
             VALUES ($1, $2, 'Pemantauan Pelayanan Sakramen Perminyakan', $3, 'NEW_ORDER_MONITOR', false)`,
            [p.id, order.id, `Ada permintaan pelayanan Sakramen Perminyakan (${order.order_number}) dari warga lingkungan Anda. Ketuk untuk memantau status dan koordinasi via chat.`],
          );
        }
      }

      // 🔔 Notify Koordinator Keuskupan (exclude creator)
      for (const k of koordinator) {
        if (k.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
             VALUES ($1, $2, 'Pemantauan Keuskupan: Sakramen Perminyakan', $3, 'NEW_ORDER_KOORDINATOR', false)`,
            [k.id, order.id, `Ada permintaan pelayanan Sakramen Perminyakan (${order.order_number}) di keuskupan Anda. Ketuk untuk memantau status dan koordinasi via chat.`],
          );
        }
      }

      // 🔔 Notify Romo Paroki (exclude creator)
      for (const rp of romoParoki) {
        if (rp.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
             VALUES ($1, $2, 'Permintaan Pelayanan Sakramen Perminyakan', $3, 'NEW_ORDER_ROMO', false)`,
            [rp.id, order.id, `Umat yang berada di paroki anda telah membuat permintaan pelayanan Sakramen Perminyakan (${order.order_number}).`],
          );
        }
      }

      // 🔔 Notify Romo Ordo (exclude creator)
      for (const ro of romoOrdo) {
        if (ro.id !== userId) {
          await this.dataSource.query(
            `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
             VALUES ($1, $2, 'Permintaan Pelayanan Sakramen Perminyakan', $3, 'NEW_ORDER_ROMO', false)`,
            [ro.id, order.id, `Umat yang berada di kota anda telah membuat permintaan pelayanan Sakramen Perminyakan (${order.order_number}).`],
          );
        }
      }
    }

    // 🔔 7. Send Real-Time FCM Push Notifications to Romo, Pengurus, and Koordinator
    try {
      const catRow = await this.dataSource.query('SELECT name FROM service_categories WHERE id = $1', [dto.serviceCategoryId]);
      const catName = catRow[0]?.name || 'Pelayanan';
      const isKedukaan = catName.toLowerCase().includes('kedukaan');

      // Unique Romo Paroki & Romo Ordo IDs (exclude creator)
      const allRomoIds = Array.from(new Set([
        ...romoParoki.map((r: any) => r.id),
        ...romoOrdo.map((ro: any) => ro.id),
      ])).filter((id: number) => id && id !== userId);

      if (allRomoIds.length > 0) {
        await this.fcmService.sendPushToUsers(allRomoIds, {
          title: isKedukaan ? `Permintaan Pelayanan Misa Kedukaan` : `Permintaan Sakramen Perminyakan`,
          body: `Umat telah membuat permohonan ${catName} (${order.order_number}). Ketuk untuk melihat detail dan konfirmasi.`,
          data: {
            type: 'NEW_ORDER_ROMO',
            orderId: order.id.toString(),
            orderNumber: order.order_number,
            categoryName: catName,
          },
        });
      }

      // Unique Pengurus IDs (exclude creator)
      const allPengurusIds = Array.from(new Set(pengurus.map((p: any) => p.id))).filter((id: number) => id && id !== userId);
      if (allPengurusIds.length > 0) {
        await this.fcmService.sendPushToUsers(allPengurusIds, {
          title: `Pemantauan Pelayanan: ${catName}`,
          body: `Ada permohonan ${catName} (${order.order_number}) dari warga lingkungan Anda.`,
          data: {
            type: 'NEW_ORDER_MONITOR',
            orderId: order.id.toString(),
            orderNumber: order.order_number,
            categoryName: catName,
          },
        });
      }

      // Unique Koordinator IDs (exclude creator)
      const allKoordinatorIds = Array.from(new Set(koordinator.map((k: any) => k.id))).filter((id: number) => id && id !== userId);
      if (allKoordinatorIds.length > 0) {
        await this.fcmService.sendPushToUsers(allKoordinatorIds, {
          title: `Pemantauan Keuskupan: ${catName}`,
          body: `Ada permohonan ${catName} (${order.order_number}) baru di keuskupan Anda.`,
          data: {
            type: 'NEW_ORDER_KOORDINATOR',
            orderId: order.id.toString(),
            orderNumber: order.order_number,
            categoryName: catName,
          },
        });
      }
    } catch (fcmErr) {
      console.error('Error dispatching FCM in createOrder:', fcmErr);
    }

    return {
      message: 'Order pelayanan berhasil dibuat di PostgreSQL! Group Chat WhatsApp telah otomatis dibentuk.',
      order: order,
      chatGroupId: firstGroupId,
    };
  }

  @Get()
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Daftar Pelayanan / Monitoring Orders dari Database PostgreSQL' })
  async getOrders(
    @Query('userId') userId?: string,
    @Query('parokiId') parokiId?: string,
    @Query('romoId') romoId?: string,
    @Query('kabupatenKotaId') kabupatenKotaId?: string,
    @Query('keuskupanId') keuskupanId?: string,
    @Query('lingkunganId') lingkunganId?: string,
    @Query('isKoordinator') isKoordinator?: string,
  ) {
    const selectQuery = `
      SELECT o.id, o.order_number, sc.name as category_name, ul.name as urgency_name, o.status,
             o.scheduled_date, o.scheduled_time, o.location_name, o.address_detail, o.notes,
             o.attachment_url as "attachmentUrl",
             o.user_id,
             p.full_name as pemohon_name,
             k.name as keuskupan_name, par.name as paroki_name, l.name as lingkungan_name,
             COALESCE(o.paroki_id, p.paroki_id) as paroki_id,
             COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) as kabupaten_kota_id,
             o.accepted_romo_id as "acceptedRomoId",
             (SELECT rp.full_name FROM user_profiles rp WHERE rp.user_id = o.accepted_romo_id) as "acceptedRomoName",
             COALESCE(o.reschedule_status, 'NONE') as "rescheduleStatus",
             o.reschedule_proposed_by as "rescheduleProposedBy",
             o.reschedule_new_date as "rescheduleNewDate",
             o.reschedule_new_time as "rescheduleNewTime",
             o.reschedule_new_time_end as "rescheduleNewTimeEnd",
             o.reschedule_reason as "rescheduleReason",
             COALESCE(o.handover_status, 'NONE') as "handoverStatus",
             o.handover_proposed_by as "handoverProposedBy",
             (SELECT full_name FROM user_profiles WHERE user_id = o.handover_proposed_by) as "handoverProposerName",
             o.handover_target_romo_id as "handoverTargetRomoId",
             (SELECT full_name FROM user_profiles WHERE user_id = o.handover_target_romo_id) as "handoverTargetRomoName",
             o.handover_reason as "handoverReason"
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN urgency_levels ul ON o.urgency_level_id = ul.id
      JOIN user_profiles p ON o.user_id = p.user_id
      LEFT JOIN keuskupan k ON COALESCE(o.keuskupan_id, p.keuskupan_id) = k.id
      LEFT JOIN paroki par ON COALESCE(o.paroki_id, p.paroki_id) = par.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
    `;

    let orders: any[];
    const whereClauses: string[] = [];
    const queryParams: any[] = [];
    let paramIdx = 1;

    if (keuskupanId && !isNaN(parseInt(keuskupanId))) {
      whereClauses.push(`COALESCE(o.keuskupan_id, p.keuskupan_id) = $${paramIdx++}`);
      queryParams.push(parseInt(keuskupanId));
    } else if (lingkunganId && !isNaN(parseInt(lingkunganId))) {
      whereClauses.push(`COALESCE(o.lingkungan_id, p.lingkungan_id) = $${paramIdx++}`);
      queryParams.push(parseInt(lingkunganId));
    } else if (romoId && !isNaN(parseInt(romoId))) {
      const parsedRId = parseInt(romoId);
      const romoRes = await this.dataSource.query(
        `SELECT r.code as role_code, p.kabupaten_kota_id, p.paroki_id
         FROM auth_users u
         JOIN user_profiles p ON p.user_id = u.id
         JOIN roles r ON u.role_id = r.id
         WHERE u.id = $1`,
        [parsedRId],
      );
      if (romoRes.length > 0) {
        const romo = romoRes[0];
        const assignedOrHandoverClause = `(o.accepted_romo_id = $${paramIdx} OR (o.handover_target_romo_id = $${paramIdx} AND o.handover_status = 'PENDING') OR EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id AND (oi.accepted_romo_id = $${paramIdx} OR (oi.handover_target_romo_id = $${paramIdx} AND oi.handover_status = 'PENDING'))))`;
        paramIdx++;
        queryParams.push(parsedRId);

        if (romo.role_code === 'ROMO_ORDO' && romo.kabupaten_kota_id) {
          whereClauses.push(`(COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++} OR ${assignedOrHandoverClause})`);
          queryParams.push(romo.kabupaten_kota_id);
        } else if (romo.paroki_id) {
          whereClauses.push(`(COALESCE(o.paroki_id, p.paroki_id) = $${paramIdx++} OR ${assignedOrHandoverClause})`);
          queryParams.push(romo.paroki_id);
        } else if (romo.kabupaten_kota_id) {
          whereClauses.push(`(COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++} OR ${assignedOrHandoverClause})`);
          queryParams.push(romo.kabupaten_kota_id);
        } else {
          whereClauses.push(assignedOrHandoverClause);
        }
      } else {
        whereClauses.push(`(o.accepted_romo_id = $${paramIdx++} OR (o.handover_target_romo_id = $${paramIdx++} AND o.handover_status = 'PENDING'))`);
        queryParams.push(parsedRId, parsedRId);
      }
    } else if (userId && !isNaN(parseInt(userId))) {
      whereClauses.push(`o.user_id = $${paramIdx++}`);
      queryParams.push(parseInt(userId));
    } else if (kabupatenKotaId && !isNaN(parseInt(kabupatenKotaId))) {
      whereClauses.push(`COALESCE(o.kabupaten_kota_id, p.kabupaten_kota_id) = $${paramIdx++}`);
      queryParams.push(parseInt(kabupatenKotaId));
    } else if (parokiId && !isNaN(parseInt(parokiId))) {
      whereClauses.push(`COALESCE(o.paroki_id, p.paroki_id) = $${paramIdx++}`);
      queryParams.push(parseInt(parokiId));
    }

    const whereStr = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
    orders = await this.dataSource.query(
      `${selectQuery} ${whereStr} ORDER BY o.id DESC`,
      queryParams,
    );

    for (const order of orders) {
      const items = await this.dataSource.query(
        `SELECT id, item_name as "itemName", scheduled_date as "scheduledDate",
                scheduled_time_start as "scheduledTimeStart", scheduled_time_end as "scheduledTimeEnd",
                location_name as "locationName", COALESCE(status, 'PENDING') as status, accepted_romo_id as "acceptedRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = accepted_romo_id) as "acceptedRomoName",
                COALESCE(reschedule_status, 'NONE') as "rescheduleStatus",
                reschedule_proposed_by as "rescheduleProposedBy",
                reschedule_new_date as "rescheduleNewDate",
                reschedule_new_time_start as "rescheduleNewTimeStart",
                reschedule_new_time_end as "rescheduleNewTimeEnd",
                reschedule_reason as "rescheduleReason",
                COALESCE(handover_status, 'NONE') as "handoverStatus",
                handover_proposed_by as "handoverProposedBy",
                (SELECT full_name FROM user_profiles WHERE user_id = handover_proposed_by) as "handoverProposerName",
                handover_target_romo_id as "handoverTargetRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = handover_target_romo_id) as "handoverTargetRomoName",
                handover_reason as "handoverReason"
         FROM order_items
         WHERE order_id = $1
         ORDER BY id ASC`,
        [order.id],
      );
      order.items = items;

      const reschedules = await this.dataSource.query(
        `SELECT r.id, r.order_id as "orderId", r.item_id as "itemId",
                r.proposed_by as "proposedBy", p_prop.full_name as "proposerName",
                r.previous_date as "previousDate", r.previous_time_start as "previousTimeStart", r.previous_time_end as "previousTimeEnd",
                r.proposed_date as "proposedDate", r.proposed_time_start as "proposedTimeStart", r.proposed_time_end as "proposedTimeEnd",
                r.reason, r.status,
                r.responded_by as "respondedBy", p_resp.full_name as "responderName",
                r.responded_at as "respondedAt", r.created_at as "createdAt"
         FROM order_reschedules r
         LEFT JOIN user_profiles p_prop ON r.proposed_by = p_prop.user_id
         LEFT JOIN user_profiles p_resp ON r.responded_by = p_resp.user_id
         WHERE r.order_id = $1
         ORDER BY r.id DESC`,
        [order.id],
      );
      order.rescheduleHistory = reschedules;

      const handovers = await this.dataSource.query(
        `SELECT h.id, h.order_id as "orderId", h.item_id as "itemId",
                h.previous_romo_id as "previousRomoId", p_prev.full_name as "previousRomoName",
                h.new_romo_id as "newRomoId", p_new.full_name as "newRomoName",
                h.handover_type as "handoverType", h.reason, h.status, h.created_at as "createdAt"
         FROM order_romo_handovers h
         LEFT JOIN user_profiles p_prev ON h.previous_romo_id = p_prev.user_id
         LEFT JOIN user_profiles p_new ON h.new_romo_id = p_new.user_id
         WHERE h.order_id = $1
         ORDER BY h.id DESC`,
        [order.id],
      );
      order.handoverHistory = handovers;
    }

    return orders;
  }

  @Get('available-romos')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan daftar Romo yang aktif untuk pelimpahan/ganti romo' })
  async getAvailableRomos(@Query('parokiId') parokiId?: string) {
    const query = `
      SELECT u.id, u.phone_number as "phoneNumber", p.full_name as "fullName", r.code as "roleCode",
             p.paroki_id as "parokiId", par.name as "parokiName",
             p.ordo_id as "ordoId", ord.name as "ordoName", ord.code as "ordoCode"
      FROM auth_users u
      JOIN user_profiles p ON u.id = p.user_id
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN paroki par ON p.paroki_id = par.id
      LEFT JOIN ordo ord ON p.ordo_id = ord.id
      WHERE (r.code LIKE '%ROMO%' OR r.code = 'ROMO_PAROKI' OR r.code = 'ROMO_ORDO')
        AND u.is_active = true
      ORDER BY p.full_name ASC
    `;
    return await this.dataSource.query(query);
  }

  @Get(':id')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Mendapatkan Detail Transaksi Order Pelayanan berdasarkan ID' })
  async getOrderById(@Param('id') idParam: string) {
    const orderId = parseInt(idParam, 10) || 0;
    const selectQuery = `
      SELECT o.id, o.order_number, sc.name as category_name, ul.name as urgency_name, o.status,
             o.scheduled_date, o.scheduled_time, o.location_name, o.address_detail, o.notes,
             o.attachment_url as "attachmentUrl",
             p.full_name as pemohon_name,
             k.name as keuskupan_name, par.name as paroki_name, l.name as lingkungan_name,
             o.user_id,
             o.accepted_romo_id as "acceptedRomoId",
             (SELECT rp.full_name FROM user_profiles rp WHERE rp.user_id = o.accepted_romo_id) as "acceptedRomoName",
             COALESCE(o.reschedule_status, 'NONE') as "rescheduleStatus",
             o.reschedule_proposed_by as "rescheduleProposedBy",
             o.reschedule_new_date as "rescheduleNewDate",
             o.reschedule_new_time as "rescheduleNewTime",
             o.reschedule_new_time_end as "rescheduleNewTimeEnd",
             o.reschedule_reason as "rescheduleReason",
             COALESCE(o.handover_status, 'NONE') as "handoverStatus",
             o.handover_proposed_by as "handoverProposedBy",
             (SELECT full_name FROM user_profiles WHERE user_id = o.handover_proposed_by) as "handoverProposerName",
             o.handover_target_romo_id as "handoverTargetRomoId",
             (SELECT full_name FROM user_profiles WHERE user_id = o.handover_target_romo_id) as "handoverTargetRomoName",
             o.handover_reason as "handoverReason"
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN urgency_levels ul ON o.urgency_level_id = ul.id
      JOIN user_profiles p ON o.user_id = p.user_id
      LEFT JOIN keuskupan k ON COALESCE(o.keuskupan_id, p.keuskupan_id) = k.id
      LEFT JOIN paroki par ON COALESCE(o.paroki_id, p.paroki_id) = par.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
      WHERE o.id = $1
    `;
    const orders = await this.dataSource.query(selectQuery, [orderId]);
    if (orders.length > 0) {
      const order = orders[0];
      const items = await this.dataSource.query(
        `SELECT id, item_name as "itemName", scheduled_date as "scheduledDate",
                scheduled_time_start as "scheduledTimeStart", scheduled_time_end as "scheduledTimeEnd",
                location_name as "locationName", COALESCE(status, 'PENDING') as status, accepted_romo_id as "acceptedRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = accepted_romo_id) as "acceptedRomoName",
                COALESCE(reschedule_status, 'NONE') as "rescheduleStatus",
                reschedule_proposed_by as "rescheduleProposedBy",
                reschedule_new_date as "rescheduleNewDate",
                reschedule_new_time_start as "rescheduleNewTimeStart",
                reschedule_new_time_end as "rescheduleNewTimeEnd",
                reschedule_reason as "rescheduleReason",
                COALESCE(handover_status, 'NONE') as "handoverStatus",
                handover_proposed_by as "handoverProposedBy",
                (SELECT full_name FROM user_profiles WHERE user_id = handover_proposed_by) as "handoverProposerName",
                handover_target_romo_id as "handoverTargetRomoId",
                (SELECT full_name FROM user_profiles WHERE user_id = handover_target_romo_id) as "handoverTargetRomoName",
                handover_reason as "handoverReason"
         FROM order_items
         WHERE order_id = $1
         ORDER BY id ASC`,
        [order.id],
      );
      order.items = items;

      const reschedules = await this.dataSource.query(
        `SELECT r.id, r.order_id as "orderId", r.item_id as "itemId",
                r.proposed_by as "proposedBy", p_prop.full_name as "proposerName",
                r.previous_date as "previousDate", r.previous_time_start as "previousTimeStart", r.previous_time_end as "previousTimeEnd",
                r.proposed_date as "proposedDate", r.proposed_time_start as "proposedTimeStart", r.proposed_time_end as "proposedTimeEnd",
                r.reason, r.status,
                r.responded_by as "respondedBy", p_resp.full_name as "responderName",
                r.responded_at as "respondedAt", r.created_at as "createdAt"
         FROM order_reschedules r
         LEFT JOIN user_profiles p_prop ON r.proposed_by = p_prop.user_id
         LEFT JOIN user_profiles p_resp ON r.responded_by = p_resp.user_id
         WHERE r.order_id = $1
         ORDER BY r.id DESC`,
        [order.id],
      );
      order.rescheduleHistory = reschedules;

      const handovers = await this.dataSource.query(
        `SELECT h.id, h.order_id as "orderId", h.item_id as "itemId",
                h.previous_romo_id as "previousRomoId", p_prev.full_name as "previousRomoName",
                h.new_romo_id as "newRomoId", p_new.full_name as "newRomoName",
                h.handover_type as "handoverType", h.reason, h.status, h.created_at as "createdAt"
         FROM order_romo_handovers h
         LEFT JOIN user_profiles p_prev ON h.previous_romo_id = p_prev.user_id
         LEFT JOIN user_profiles p_new ON h.new_romo_id = p_new.user_id
         WHERE h.order_id = $1
         ORDER BY h.id DESC`,
        [order.id],
      );
      order.handoverHistory = handovers;

      return order;
    }
    return { statusCode: 404, message: 'Order tidak ditemukan' };
  }

  @Post(':id/reschedule/propose')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan perubahan jadwal (reschedule) ke Umat' })
  async proposeReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      newDate?: string;
      newTimeStart: string;
      newTimeEnd?: string;
      reason: string;
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { romoId, itemId, newDate, newTimeStart, newTimeEnd, reason } = dto;

    if (!romoId || !newTimeStart) {
      return { statusCode: 400, message: 'Data pengajuan perubahan jadwal tidak lengkap.' };
    }

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, scheduled_time, accepted_romo_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    // Check Romo authorization & record previous schedule
    let isAuthorized = false;
    let targetItemName = '';
    let prevDate = order.scheduled_date;
    let prevTimeStart = order.scheduled_time;
    let prevTimeEnd: string | null = null;

    if (itemId) {
      const itemRes = await this.dataSource.query(
        `SELECT id, item_name, scheduled_date, scheduled_time_start, scheduled_time_end, accepted_romo_id, status FROM order_items WHERE id = $1 AND order_id = $2`,
        [itemId, orderId],
      );
      if (itemRes.length > 0) {
        const it = itemRes[0];
        targetItemName = it.item_name;
        prevDate = it.scheduled_date;
        prevTimeStart = it.scheduled_time_start;
        prevTimeEnd = it.scheduled_time_end;
        isAuthorized = Number(it.accepted_romo_id ?? order.accepted_romo_id) === Number(romoId);
      }
    } else {
      isAuthorized = Number(order.accepted_romo_id) === Number(romoId);
    }

    if (!isAuthorized) {
      return { statusCode: 403, message: 'Hanya Romo yang bertugas yang dapat mengajukan perubahan jadwal pelayanan ini.' };
    }

    const romoProf = await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [romoId],
    );
    const romoName = romoProf.length > 0 ? romoProf[0].full_name : 'Romo';

    const proposedDate = newDate || order.scheduled_date;

    if (itemId) {
      await this.dataSource.query(
        `UPDATE order_items
         SET reschedule_status = 'PENDING_UMAT',
             reschedule_proposed_by = $1,
             reschedule_new_date = $2,
             reschedule_new_time_start = $3,
             reschedule_new_time_end = $4,
             reschedule_reason = $5
         WHERE id = $6 AND order_id = $7`,
        [romoId, proposedDate, newTimeStart, newTimeEnd || null, reason || '', itemId, orderId],
      );
    }

    await this.dataSource.query(
      `UPDATE orders
       SET reschedule_status = 'PENDING_UMAT',
           reschedule_proposed_by = $1,
           reschedule_new_date = $2,
           reschedule_new_time = $3,
           reschedule_new_time_end = $4,
           reschedule_reason = $5
       WHERE id = $6`,
      [romoId, proposedDate, newTimeStart, newTimeEnd || null, reason || '', orderId],
    );

    // Record to order_reschedules audit log table
    await this.dataSource.query(
      `INSERT INTO order_reschedules (order_id, item_id, proposed_by, previous_date, previous_time_start, previous_time_end, proposed_date, proposed_time_start, proposed_time_end, reason, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'PENDING_UMAT')`,
      [orderId, itemId || null, romoId, prevDate, prevTimeStart, prevTimeEnd, proposedDate, newTimeStart, newTimeEnd || null, reason || 'Penyesuaian agenda'],
    );

    // Format display string
    const timeDisplay = newTimeEnd ? `${newTimeStart} - ${newTimeEnd} WIB` : `${newTimeStart} WIB`;
    const itemPrefix = targetItemName ? `[${targetItemName}] ` : '';

    // Insert Chat System Event
    const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
    if (groups.length > 0) {
      const groupId = groups[0].id;
      await this.dataSource.query(
        `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
        [groupId, `Romo ${romoName} mengajukan perubahan jadwal ${itemPrefix}menjadi ${timeDisplay}. Alasan: "${reason || 'Penyesuaian agenda'}". Menunggu persetujuan Umat pemohon.`],
      );
    }

    // Send Notification to Umat
    await this.dataSource.query(
      `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
       VALUES ($1, $2, $3, $4, 'RESCHEDULE_PROPOSED', false)`,
      [
        order.user_id,
        orderId,
        `Usulan Perubahan Jadwal: ${targetItemName || 'Pelayanan'}`,
        `Romo ${romoName} mengajukan perubahan jam pelayanan ${itemPrefix}menjadi ${timeDisplay}. Alasan: "${reason || '-'}". Ketuk untuk menanggapi.`,
      ],
    );

    // Send Notification to Pengurus Lingkungan
    const pengurusResched = await this.getPengurusForOrder(orderId);
    for (const p of pengurusResched) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'RESCHEDULE_PROPOSED', false)`,
        [
          p.id,
          orderId,
          `Usulan Perubahan Jadwal: ${targetItemName || 'Pelayanan'}`,
          `Romo ${romoName} mengajukan perubahan jam pelayanan ${itemPrefix}menjadi ${timeDisplay} (${order.order_number}).`,
        ],
      );
    }

    // 🔔 Dispatch FCM Push to Umat & Pengurus
    try {
      const targetReschedUsers = Array.from(new Set([
        order.user_id,
        ...pengurusResched.map((p: any) => p.id),
      ])).filter((id: number) => id && id !== romoId);

      if (targetReschedUsers.length > 0) {
        await this.fcmService.sendPushToUsers(targetReschedUsers, {
          title: `Usulan Perubahan Jadwal: ${targetItemName || 'Pelayanan'}`,
          body: `Romo ${romoName} mengajukan perubahan jam pelayanan ${itemPrefix}menjadi ${timeDisplay}. Alasan: "${reason || '-'}".`,
          data: {
            type: 'RESCHEDULE_PROPOSED',
            orderId: orderId.toString(),
            orderNumber: order.order_number,
          },
        });
      }
    } catch (fcmErr) {
      console.error('Error dispatching FCM in proposeReschedule:', fcmErr);
    }

    return {
      statusCode: 200,
      success: true,
      message: 'Pengajuan perubahan jadwal berhasil dikirimkan ke Umat pemohon.',
    };
  }

  @Post(':id/reschedule/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Umat merespon (terima / tolak) pengajuan reschedule dari Romo' })
  async respondReschedule(
    @Param('id') idParam: string,
    @Body() dto: {
      userId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT' | 'ACCEPTED' | 'REJECTED';
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { userId, itemId, action } = dto;
    const isAccept = action.toUpperCase().startsWith('ACCEPT');

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, scheduled_time,
              reschedule_status, reschedule_proposed_by, reschedule_new_date, reschedule_new_time, reschedule_new_time_end, reschedule_reason, accepted_romo_id
       FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    if (userId && Number(order.user_id) !== Number(userId)) {
      return { statusCode: 403, message: 'Hanya pemohon (Umat) yang dapat menyetujui atau menolak perubahan jadwal ini.' };
    }

    let targetItemName = '';
    if (itemId) {
      const iRes = await this.dataSource.query('SELECT item_name FROM order_items WHERE id = $1', [itemId]);
      if (iRes.length > 0) targetItemName = iRes[0].item_name;
    }
    const serviceTitle = targetItemName || 'Pelayanan';
    const romoId = order.reschedule_proposed_by || order.accepted_romo_id;
    const pengurusRespond = await this.getPengurusForOrder(orderId);

    if (isAccept) {
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items
           SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
               scheduled_time_start = COALESCE(reschedule_new_time_start, scheduled_time_start),
               scheduled_time_end = COALESCE(reschedule_new_time_end, scheduled_time_end),
               reschedule_status = 'ACCEPTED'
           WHERE id = $1 AND order_id = $2`,
          [itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items
           SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
               scheduled_time_start = COALESCE(reschedule_new_time_start, scheduled_time_start),
               scheduled_time_end = COALESCE(reschedule_new_time_end, scheduled_time_end),
               reschedule_status = 'ACCEPTED'
           WHERE order_id = $1`,
          [orderId],
        );
      }
      await this.dataSource.query(
        `UPDATE orders
         SET scheduled_date = COALESCE(reschedule_new_date, scheduled_date),
             scheduled_time = COALESCE(reschedule_new_time, scheduled_time),
             reschedule_status = 'ACCEPTED'
         WHERE id = $1`,
        [orderId],
      );

      // Update order_reschedules log
      await this.dataSource.query(
        `UPDATE order_reschedules
         SET status = 'ACCEPTED', responded_by = $1, responded_at = CURRENT_TIMESTAMP
         WHERE order_id = $2 AND status = 'PENDING_UMAT'`,
        [userId || order.user_id, orderId],
      );

      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [groups[0].id, `Umat pemohon telah MENYETUJUI pengajuan perubahan jadwal. Jadwal pelayanan resmi diperbarui.`],
        );
      }

      // 🔔 Notify Romo Bertugas
      if (romoId) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'RESCHEDULE_ACCEPTED', false)`,
          [
            romoId,
            orderId,
            `Perubahan Jadwal Disetujui: ${serviceTitle}`,
            `Umat telah menyetujui jadwal baru untuk pelayanan ${serviceTitle} (${order.order_number}).`,
          ],
        );
      }

      // 🔔 Notify Pengurus Lingkungan
      for (const p of pengurusRespond) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'RESCHEDULE_ACCEPTED', false)`,
          [
            p.id,
            orderId,
            `Perubahan Jadwal Disetujui: ${serviceTitle}`,
            `Jadwal pelayanan ${serviceTitle} (${order.order_number}) telah disesuaikan mengikuti persetujuan Umat.`,
          ],
        );
      }

      // 🔔 Dispatch FCM Push to Romo & Pengurus
      try {
        const targetReschedRespUsers = Array.from(new Set([
          romoId,
          ...pengurusRespond.map((p: any) => p.id),
        ])).filter((id: number) => id && id !== userId);

        if (targetReschedRespUsers.length > 0) {
          await this.fcmService.sendPushToUsers(targetReschedRespUsers, {
            title: `Perubahan Jadwal Disetujui: ${serviceTitle}`,
            body: `Umat telah menyetujui jadwal baru untuk pelayanan ${serviceTitle} (${order.order_number}).`,
            data: {
              type: 'RESCHEDULE_ACCEPTED',
              orderId: orderId.toString(),
              orderNumber: order.order_number,
            },
          });
        }
      } catch (fcmErr) {
        console.error('Error dispatching FCM in respondReschedule (Accept):', fcmErr);
      }

      return {
        statusCode: 200,
        success: true,
        message: 'Perubahan jadwal berhasil disetujui dan diperbarui.',
      };
    } else {
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items SET reschedule_status = 'REJECTED' WHERE id = $1 AND order_id = $2`,
          [itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items SET reschedule_status = 'REJECTED' WHERE order_id = $1`,
          [orderId],
        );
      }
      await this.dataSource.query(
        `UPDATE orders SET reschedule_status = 'REJECTED' WHERE id = $1`,
        [orderId],
      );

      // Update order_reschedules log
      await this.dataSource.query(
        `UPDATE order_reschedules
         SET status = 'REJECTED', responded_by = $1, responded_at = CURRENT_TIMESTAMP
         WHERE order_id = $2 AND status = 'PENDING_UMAT'`,
        [userId || order.user_id, orderId],
      );

      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [groups[0].id, `Umat pemohon MENOLAK pengajuan perubahan jadwal. Pelayanan tetap dilaksanakan sesuai jadwal awal.`],
        );
      }

      // 🔔 Notify Romo Bertugas
      if (romoId) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'RESCHEDULE_REJECTED', false)`,
          [
            romoId,
            orderId,
            `Perubahan Jadwal Ditolak: ${serviceTitle}`,
            `Umat tidak menyetujui perubahan jadwal (${order.order_number}). Pelayanan tetap pada jadwal semula.`,
          ],
        );
      }

      // 🔔 Notify Pengurus Lingkungan
      for (const p of pengurusRespond) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'RESCHEDULE_REJECTED', false)`,
          [
            p.id,
            orderId,
            `Perubahan Jadwal Ditolak: ${serviceTitle}`,
            `Umat menolak perubahan jadwal pelayanan ${serviceTitle} (${order.order_number}). Pelayanan tetap sesuai jadwal awal.`,
          ],
        );
      }

      // 🔔 Dispatch FCM Push to Romo & Pengurus
      try {
        const targetReschedRespUsers = Array.from(new Set([
          romoId,
          ...pengurusRespond.map((p: any) => p.id),
        ])).filter((id: number) => id && id !== userId);

        if (targetReschedRespUsers.length > 0) {
          await this.fcmService.sendPushToUsers(targetReschedRespUsers, {
            title: `Perubahan Jadwal Ditolak: ${serviceTitle}`,
            body: `Umat menolak perubahan jadwal (${order.order_number}). Pelayanan tetap pada jadwal awal.`,
            data: {
              type: 'RESCHEDULE_REJECTED',
              orderId: orderId.toString(),
              orderNumber: order.order_number,
            },
          });
        }
      } catch (fcmErr) {
        console.error('Error dispatching FCM in respondReschedule (Reject):', fcmErr);
      }

      return {
        statusCode: 200,
        success: true,
        message: 'Pengajuan perubahan jadwal telah ditolak.',
      };
    }
  }

  @Post(':id/handover')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo mengajukan pelimpahan tugas pelayanan (Ganti Romo / Berhalangan)' })
  async handoverOrder(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      targetRomoId: number;
      reason: string;
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { romoId, itemId, targetRomoId, reason } = dto;

    if (!romoId || !reason || !targetRomoId) {
      return { statusCode: 400, message: 'Alasan berhalangan, Romo asal, dan Romo pengganti wajib diisi.' };
    }

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, scheduled_date, scheduled_time, accepted_romo_id, paroki_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    let isAuthorized = false;
    let targetItemName = '';
    if (itemId) {
      const itemRes = await this.dataSource.query(
        `SELECT id, item_name, accepted_romo_id, status FROM order_items WHERE id = $1 AND order_id = $2`,
        [itemId, orderId],
      );
      if (itemRes.length > 0) {
        const it = itemRes[0];
        targetItemName = it.item_name;
        isAuthorized = Number(it.accepted_romo_id ?? order.accepted_romo_id) === Number(romoId);
      }
    } else {
      isAuthorized = Number(order.accepted_romo_id) === Number(romoId);
    }

    if (!isAuthorized) {
      return { statusCode: 403, message: 'Hanya Romo yang bertugas yang dapat mengajukan pelimpahan pelayanan ini.' };
    }

    const prevRomoProf = await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [romoId],
    );
    const prevRomoName = prevRomoProf.length > 0 ? prevRomoProf[0].full_name : 'Romo';

    const newRomoProf = await this.dataSource.query(
      `SELECT full_name FROM user_profiles WHERE user_id = $1`,
      [targetRomoId],
    );
    const newRomoName = newRomoProf.length > 0 ? newRomoProf[0].full_name : 'Romo Pengganti';
    const itemPrefix = targetItemName ? `[${targetItemName}] ` : '';

    if (itemId) {
      await this.dataSource.query(
        `UPDATE order_items
         SET handover_status = 'PENDING', handover_proposed_by = $1, handover_target_romo_id = $2, handover_reason = $3
         WHERE id = $4 AND order_id = $5`,
        [romoId, targetRomoId, reason, itemId, orderId],
      );
    } else {
      await this.dataSource.query(
        `UPDATE order_items
         SET handover_status = 'PENDING', handover_proposed_by = $1, handover_target_romo_id = $2, handover_reason = $3
         WHERE order_id = $4`,
        [romoId, targetRomoId, reason, orderId],
      );
    }

    await this.dataSource.query(
      `UPDATE orders
       SET handover_status = 'PENDING', handover_proposed_by = $1, handover_target_romo_id = $2, handover_reason = $3
       WHERE id = $4`,
      [romoId, targetRomoId, reason, orderId],
    );

    // Record handover audit
    await this.dataSource.query(
      `INSERT INTO order_romo_handovers (order_id, item_id, previous_romo_id, new_romo_id, handover_type, reason, status)
       VALUES ($1, $2, $3, $4, 'DIRECT_ASSIGN', $5, 'PENDING')`,
      [orderId, itemId || null, romoId, targetRomoId, reason],
    );

    // Post chat system event to existing group members (Romo Baru has not accepted yet so does not join chat yet)
    const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
    if (groups.length > 0) {
      const groupId = groups[0].id;
      await this.dataSource.query(
        `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
        [groupId, `Pemberitahuan: Romo ${prevRomoName} mengajukan pelimpahan tugas pelayanan ${itemPrefix}kepada Romo ${newRomoName} ("${reason}"). Menunggu konfirmasi dari Romo ${newRomoName}.`],
      );
    }

    const serviceTitle = targetItemName || 'Pelayanan';
    const pengurusHandover = await this.getPengurusForOrder(orderId);

    // Notify Umat
    await this.dataSource.query(
      `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
       VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
      [
        order.user_id,
        orderId,
        `Pengajuan Ganti Romo: ${serviceTitle}`,
        `Romo ${prevRomoName} berhalangan ("${reason}"). Pengalihan tugas pelayanan ${serviceTitle} (${order.order_number}) ke Romo ${newRomoName} sedang menunggu konfirmasi.`,
      ],
    );

    // Notify New Romo
    await this.dataSource.query(
      `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
       VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
      [
        targetRomoId,
        orderId,
        `Permintaan Pelimpahan Pelayanan: ${serviceTitle}`,
        `Romo ${prevRomoName} melimpahkan tugas pelayanan ${serviceTitle} (${order.order_number}) kepada Anda. Alasan: "${reason}". Buka aplikasi untuk menerima atau menolak.`,
      ],
    );

    // Notify Pengurus Lingkungan
    for (const p of pengurusHandover) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
        [
          p.id,
          orderId,
          `Pengajuan Ganti Romo: ${serviceTitle}`,
          `Romo ${prevRomoName} mengajukan pengalihan pelayanan ${serviceTitle} (${order.order_number}) kepada Romo ${newRomoName} ("${reason}").`,
        ],
      );
    }

    // 🔔 Dispatch FCM Push to Target Romo, Umat, and Pengurus
    try {
      // 1. Push to Target Romo
      await this.fcmService.sendPushToUsers(targetRomoId, {
        title: `Permintaan Pelimpahan Pelayanan: ${serviceTitle}`,
        body: `Romo ${prevRomoName} melimpahkan tugas pelayanan ${serviceTitle} (${order.order_number}) kepada Anda. Alasan: "${reason}".`,
        data: {
          type: 'ROMO_HANDOVER',
          orderId: orderId.toString(),
          orderNumber: order.order_number,
        },
      });

      // 2. Push to Umat & Pengurus
      const targetHandoverInfoUsers = Array.from(new Set([
        order.user_id,
        ...pengurusHandover.map((p: any) => p.id),
      ])).filter((id: number) => id && id !== romoId && id !== targetRomoId);

      if (targetHandoverInfoUsers.length > 0) {
        await this.fcmService.sendPushToUsers(targetHandoverInfoUsers, {
          title: `Pengajuan Ganti Romo: ${serviceTitle}`,
          body: `Romo ${prevRomoName} mengajukan pengalihan pelayanan ${serviceTitle} (${order.order_number}) kepada Romo ${newRomoName}.`,
          data: {
            type: 'ROMO_HANDOVER',
            orderId: orderId.toString(),
            orderNumber: order.order_number,
          },
        });
      }
    } catch (fcmErr) {
      console.error('Error dispatching FCM in handoverOrder:', fcmErr);
    }

    return {
      statusCode: 200,
      success: true,
      message: `Pengajuan pelimpahan tugas kepada Romo ${newRomoName} berhasil dikirim.`,
    };
  }

  @Post(':id/handover/respond')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Romo Baru menerima atau menolak pelimpahan tugas pelayanan' })
  async respondHandover(
    @Param('id') idParam: string,
    @Body() dto: {
      romoId: number;
      itemId?: number;
      action: 'ACCEPT' | 'REJECT';
    },
  ) {
    const orderId = parseInt(idParam, 10) || 0;
    const { romoId, itemId, action } = dto;
    const isAccept = action === 'ACCEPT';

    const orderRes = await this.dataSource.query(
      `SELECT id, order_number, user_id, status, accepted_romo_id,
              handover_status, handover_proposed_by, handover_target_romo_id, handover_reason
       FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderRes.length === 0) {
      return { statusCode: 404, message: 'Order tidak ditemukan.' };
    }
    const order = orderRes[0];

    if (Number(order.handover_target_romo_id) !== Number(romoId)) {
      return { statusCode: 403, message: 'Hanya Romo pengganti yang dituju yang dapat menerima atau menolak pelimpahan tugas ini.' };
    }

    let targetItemName = '';
    if (itemId) {
      const iRes = await this.dataSource.query('SELECT item_name FROM order_items WHERE id = $1', [itemId]);
      if (iRes.length > 0) targetItemName = iRes[0].item_name;
    }
    const serviceTitle = targetItemName || 'Pelayanan';

    const prevRomoId = order.handover_proposed_by;
    const prevProf = await this.dataSource.query('SELECT full_name FROM user_profiles WHERE user_id = $1', [prevRomoId]);
    const prevRomoName = prevProf.length > 0 ? prevProf[0].full_name : 'Romo';

    const targetProf = await this.dataSource.query('SELECT full_name FROM user_profiles WHERE user_id = $1', [romoId]);
    const targetRomoName = targetProf.length > 0 ? targetProf[0].full_name : 'Romo Pengganti';
    const pengurusRespondHandover = await this.getPengurusForOrder(orderId);

    if (isAccept) {
      // Romo Baru accepts: transfer responsibility
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items
           SET accepted_romo_id = $1, handover_status = 'ACCEPTED', status = 'CONFIRMED'
           WHERE id = $2 AND order_id = $3`,
          [romoId, itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items
           SET accepted_romo_id = $1, handover_status = 'ACCEPTED', status = 'CONFIRMED'
           WHERE order_id = $2`,
          [romoId, orderId],
        );
      }

      await this.dataSource.query(
        `UPDATE orders
         SET accepted_romo_id = $1, handover_status = 'ACCEPTED', status = 'CONFIRMED'
         WHERE id = $2`,
        [romoId, orderId],
      );

      // Update audit log
      await this.dataSource.query(
        `UPDATE order_romo_handovers
         SET status = 'ACCEPTED', responded_at = CURRENT_TIMESTAMP
         WHERE order_id = $1 AND new_romo_id = $2 AND status = 'PENDING'`,
        [orderId, romoId],
      );

      // Add Romo Baru to chat group & Kick Romo Lama from chat group
      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        let romoRole = 'ROMO_PAROKI';
        const rCheck = await this.dataSource.query(
          `SELECT r.code FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE u.id = $1`,
          [romoId],
        );
        if (rCheck.length > 0 && rCheck[0].code === 'ROMO_ORDO') {
          romoRole = 'ROMO_ORDO';
        }

        for (const grp of groups) {
          // 1. Add Romo Baru to chat group
          await this.dataSource.query(
            `INSERT INTO chat_group_members (chat_group_id, user_id, role_in_group)
             VALUES ($1, $2, $3)
             ON CONFLICT (chat_group_id, user_id) DO UPDATE SET role_in_group = $3`,
            [grp.id, romoId, romoRole],
          );

          // 2. Automatically kick Romo Lama from chat group
          if (prevRomoId) {
            await this.dataSource.query(
              `DELETE FROM chat_group_members WHERE chat_group_id = $1 AND user_id = $2`,
              [grp.id, prevRomoId],
            );
          }

          // 3. Post system event message to group
          await this.dataSource.query(
            `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
            [grp.id, `Romo ${targetRomoName} telah MENERIMA pelimpahan tugas dan bergabung ke grup pelayanan. Romo ${prevRomoName} resmi keluar dari grup ini.`],
          );
        }
      }

      // 🔔 Notify Romo Lama
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
        [
          prevRomoId,
          orderId,
          `Pelimpahan Disetujui: ${serviceTitle}`,
          `Romo ${targetRomoName} telah MENYETUJUI pelimpahan tugas ${serviceTitle} (${order.order_number}). Anda resmi tidak lagi bertugas untuk pelayanan ini.`,
        ],
      );

      // 🔔 Notify Umat
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
        [
          order.user_id,
          orderId,
          `Romo Pelayanan Diperbarui: ${serviceTitle}`,
          `Pelayanan ${serviceTitle} (${order.order_number}) resmi dialihkan ke Romo ${targetRomoName} menggantikan Romo ${prevRomoName}.`,
        ],
      );

      // 🔔 Notify Pengurus Lingkungan
      for (const p of pengurusRespondHandover) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
          [
            p.id,
            orderId,
            `Romo Pelayanan Diperbarui: ${serviceTitle}`,
            `Pelayanan ${serviceTitle} (${order.order_number}) resmi dialihkan ke Romo ${targetRomoName} menggantikan Romo ${prevRomoName}.`,
          ],
        );
      }

      // 🔔 Dispatch FCM Push to Romo Lama, Umat, and Pengurus (Accept)
      try {
        const targetHandoverAcceptUsers = Array.from(new Set([
          prevRomoId,
          order.user_id,
          ...pengurusRespondHandover.map((p: any) => p.id),
        ])).filter((id: number) => id && id !== romoId);

        if (targetHandoverAcceptUsers.length > 0) {
          await this.fcmService.sendPushToUsers(targetHandoverAcceptUsers, {
            title: `Romo Pelayanan Diperbarui: ${serviceTitle}`,
            body: `Pelayanan ${serviceTitle} (${order.order_number}) resmi dialihkan ke Romo ${targetRomoName} menggantikan Romo ${prevRomoName}.`,
            data: {
              type: 'ROMO_HANDOVER',
              orderId: orderId.toString(),
              orderNumber: order.order_number,
            },
          });
        }
      } catch (fcmErr) {
        console.error('Error dispatching FCM in respondHandover (Accept):', fcmErr);
      }

      return {
        statusCode: 200,
        success: true,
        message: `Pelimpahan tugas berhasil diterima. Pelayanan (${order.order_number}) kini menjadi tanggung jawab Anda.`,
      };
    } else {
      // Romo Baru rejects: stays with Romo Lama
      if (itemId) {
        await this.dataSource.query(
          `UPDATE order_items SET handover_status = 'REJECTED' WHERE id = $1 AND order_id = $2`,
          [itemId, orderId],
        );
      } else {
        await this.dataSource.query(
          `UPDATE order_items SET handover_status = 'REJECTED' WHERE order_id = $1`,
          [orderId],
        );
      }

      await this.dataSource.query(
        `UPDATE orders SET handover_status = 'REJECTED' WHERE id = $1`,
        [orderId],
      );

      // Update audit log
      await this.dataSource.query(
        `UPDATE order_romo_handovers
         SET status = 'REJECTED', responded_at = CURRENT_TIMESTAMP
         WHERE order_id = $1 AND new_romo_id = $2 AND status = 'PENDING'`,
        [orderId, romoId],
      );

      // System chat message
      const groups = await this.dataSource.query(`SELECT id FROM chat_groups WHERE order_id = $1`, [orderId]);
      if (groups.length > 0) {
        await this.dataSource.query(
          `INSERT INTO chat_messages (chat_group_id, sender_id, message_type, message) VALUES ($1, NULL, 'SYSTEM_EVENT', $2)`,
          [groups[0].id, `Romo ${targetRomoName} MENOLAK pelimpahan tugas pelayanan. Pelayanan tetap ditugaskan kepada Romo ${prevRomoName}.`],
        );
      }

      // 🔔 Notify Romo Lama
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
        [
          prevRomoId,
          orderId,
          `Pelimpahan Ditolak: ${serviceTitle}`,
          `Romo ${targetRomoName} MENOLAK pelimpahan tugas ${serviceTitle} (${order.order_number}). Anda tetap bertugas melayani atau silakan limpahkan ke Romo lain.`,
        ],
      );

      // 🔔 Notify Umat
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
         VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
        [
          order.user_id,
          orderId,
          `Status Pelimpahan Pelayanan: ${serviceTitle}`,
          `Pelimpahan ke Romo ${targetRomoName} belum disetujui. Romo ${prevRomoName} tetap bertugas melayani ${serviceTitle}.`,
        ],
      );

      // 🔔 Notify Pengurus Lingkungan
      for (const p of pengurusRespondHandover) {
        await this.dataSource.query(
          `INSERT INTO notifications (user_id, order_id, title, body, type, is_read)
           VALUES ($1, $2, $3, $4, 'ROMO_HANDOVER', false)`,
          [
            p.id,
            orderId,
            `Status Pelimpahan Pelayanan: ${serviceTitle}`,
            `Pelimpahan tugas ${serviceTitle} (${order.order_number}) kepada Romo ${targetRomoName} ditolak. Pelayanan tetap bersama Romo ${prevRomoName}.`,
          ],
        );
      }

      // 🔔 Dispatch FCM Push to Romo Lama, Umat, and Pengurus (Reject)
      try {
        const targetHandoverRejectUsers = Array.from(new Set([
          prevRomoId,
          order.user_id,
          ...pengurusRespondHandover.map((p: any) => p.id),
        ])).filter((id: number) => id && id !== romoId);

        if (targetHandoverRejectUsers.length > 0) {
          await this.fcmService.sendPushToUsers(targetHandoverRejectUsers, {
            title: `Pelimpahan Tugas Ditolak: ${serviceTitle}`,
            body: `Romo ${targetRomoName} menolak pelimpahan tugas (${order.order_number}). Pelayanan tetap bersama Romo ${prevRomoName}.`,
            data: {
              type: 'ROMO_HANDOVER',
              orderId: orderId.toString(),
              orderNumber: order.order_number,
            },
          });
        }
      } catch (fcmErr) {
        console.error('Error dispatching FCM in respondHandover (Reject):', fcmErr);
      }

      return {
        statusCode: 200,
        success: true,
        message: `Pelimpahan tugas telah ditolak. Pelayanan (${order.order_number}) tetap menjadi tugas Romo ${prevRomoName}.`,
      };
    }
  }
}
