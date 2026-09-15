import {
  Injectable,
  BadRequestException,
  NotFoundException,
  HttpCode,
} from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";
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
} from "../../auth.dto";
import {
  UpdateUserProfileDto,
} from "../../orders.dto";
import { FcmService } from "../../fcm.service";

@Injectable()
export class AuthService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly jwtService: JwtService,
    private readonly fcmService: FcmService,
  ) {}
async getRoles() {
    const roles = await this.dataSource.query(
      `SELECT id, code, name FROM roles WHERE code IN ('UMAT', 'ROMO_PAROKI', 'ROMO_ORDO') ORDER BY id ASC`,
    );
    return roles.map((r) => {
      let displayName = r.name;
      if (r.code === 'UMAT') {
        displayName = 'Umat';
      } else if (r.code === 'ROMO_PAROKI') {
        displayName = 'Romo Paroki';
      } else if (r.code === 'ROMO_ORDO') {
        displayName = 'Romo Ordo';
      }
      return { id: r.id, code: r.code, name: displayName, label: displayName };
    });
  }
  async getKeuskupan() {
    return await this.dataSource.query('SELECT id, name FROM keuskupan ORDER BY id ASC');
  }
  async getParoki(keuskupanId?: number) {
    if (keuskupanId) {
      return await this.dataSource.query('SELECT id, keuskupan_id, name FROM paroki WHERE keuskupan_id = $1 ORDER BY id ASC', [keuskupanId]);
    }
    return await this.dataSource.query('SELECT id, keuskupan_id, name FROM paroki ORDER BY id ASC');
  }
  async getWilayah(parokiId?: number) {
    if (parokiId) {
      return await this.dataSource.query('SELECT id, paroki_id, name FROM wilayah WHERE paroki_id = $1 ORDER BY id ASC', [parokiId]);
    }
    return await this.dataSource.query('SELECT id, paroki_id, name FROM wilayah ORDER BY id ASC');
  }
  async getLingkungan(wilayahId?: number) {
    if (wilayahId) {
      return await this.dataSource.query('SELECT id, wilayah_id, name FROM lingkungan WHERE wilayah_id = $1 ORDER BY id ASC', [wilayahId]);
    }
    return await this.dataSource.query('SELECT id, wilayah_id, name FROM lingkungan ORDER BY id ASC');
  }
  async getProvinsi() {
    return await this.dataSource.query('SELECT id, name FROM provinsi ORDER BY id ASC');
  }
  async getKabupatenKota(provinsiId?: number) {
    if (provinsiId) {
      return await this.dataSource.query(
        'SELECT id, provinsi_id, name, type FROM kabupaten_kota WHERE provinsi_id = $1 ORDER BY id ASC',
        [provinsiId],
      );
    }
    return await this.dataSource.query('SELECT id, provinsi_id, name, type FROM kabupaten_kota ORDER BY id ASC');
  }
  async getOrdo() {
    return await this.dataSource.query('SELECT id, code, name FROM ordo ORDER BY id ASC');
  }
  async checkAccountStatus(phone: string) {
    if (!phone) return { statusCode: 400, message: 'Nomor HP wajib disertakan' };
    let cleanPhone = phone.trim();
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (cleanPhone.startsWith('+62')) cleanPhone = cleanPhone.substring(3);
    if (cleanPhone.startsWith('62')) cleanPhone = cleanPhone.substring(2);
    const fullPhone = `62${cleanPhone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.ordo_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, ord.name as ordo_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1`,
      [fullPhone],
    );

    if (!users.length) {
      return { statusCode: 404, message: 'Akun tidak ditemukan' };
    }

    const user = users[0];
    return {
      statusCode: 200,
      accountStatus: user.account_status,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        birthDate: user.birth_date,
        address: user.address,
        avatarUrl: user.avatar_url,
        roleCode: user.role_code,
        accountStatus: user.account_status,
        keuskupanId: user.keuskupan_id,
        parokiId: user.paroki_id,
        wilayahId: user.wilayah_id,
        lingkunganId: user.lingkungan_id,
        ordoId: user.ordo_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
        ordoName: user.ordo_name,
        kabupatenKotaName: user.kota_name,
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }
  async getPengurusPendingUmat(
    lingkunganId?: string,
    keuskupanId?: string,
    pengurusUserId?: string,
  ) {
    let resolvedLingkunganId = lingkunganId ? parseInt(lingkunganId, 10) : null;
    let resolvedKeuskupanId = keuskupanId ? parseInt(keuskupanId, 10) : null;
    let isKoordinator = false;

    if (pengurusUserId) {
      const p = await this.dataSource.query(
        'SELECT lingkungan_id, keuskupan_id, pengurus_position FROM user_profiles WHERE user_id = $1',
        [parseInt(pengurusUserId, 10)],
      );
      if (p.length > 0) {
        const pos = (p[0].pengurus_position || '').toString().toLowerCase();
        if (pos.includes('koordinator')) {
          isKoordinator = true;
          if (!resolvedKeuskupanId && p[0].keuskupan_id) resolvedKeuskupanId = p[0].keuskupan_id;
        } else {
          if (!resolvedLingkunganId && p[0].lingkungan_id) resolvedLingkunganId = p[0].lingkungan_id;
        }
      }
    }

    if (resolvedKeuskupanId || isKoordinator) {
      const targetKeuskupan = resolvedKeuskupanId || 1;
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON p.user_id = u.id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN wilayah w ON p.wilayah_id = w.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'UMAT'
           AND u.account_status = 'PENDING_APPROVAL'
           AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
           AND p.keuskupan_id = $1
         ORDER BY u.created_at DESC`,
        [targetKeuskupan],
      );
      return rows;
    }

    if (!resolvedLingkunganId) {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN wilayah w ON p.wilayah_id = w.id
         LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'UMAT'
           AND u.account_status = 'PENDING_APPROVAL'
           AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
         ORDER BY u.created_at DESC`,
      );
      return rows;
    }

    const rows = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE r.code = 'UMAT'
         AND u.account_status = 'PENDING_APPROVAL'
         AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')
         AND p.lingkungan_id = $1
       ORDER BY u.created_at DESC`,
      [resolvedLingkunganId],
    );
    return rows;
  }
  async processPengurusApproval(
    body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    const { targetUserId, approverUserId, action, rejectionReason } = body;
    if (!targetUserId || !approverUserId || !action) {
      throw new BadRequestException('Parameter targetUserId, approverUserId, dan action wajib diisi.');
    }

    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
    await this.dataSource.query(
      'UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newStatus, targetUserId],
    );

    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason)
       VALUES ($1, $2, $3, $4)`,
      [targetUserId, approverUserId, action, rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: action === 'APPROVE' ? 'Umat berhasil disetujui!' : 'Pendaftaran umat berhasil ditolak.',
      accountStatus: newStatus,
    };
  }
  async getRomoPendingRomo(
    romoUserId?: string,
    parokiId?: string,
    ordoId?: string,
  ) {
    let resolvedParokiId = parokiId ? parseInt(parokiId, 10) : null;
    let resolvedOrdoId = ordoId ? parseInt(ordoId, 10) : null;
    let isOrdo = false;

    if (romoUserId) {
      const p = await this.dataSource.query(
        `SELECT p.paroki_id, p.ordo_id, r.code as role_code, p.romo_position
         FROM user_profiles p
         JOIN auth_users u ON p.user_id = u.id
         JOIN roles r ON u.role_id = r.id
         WHERE p.user_id = $1`,
        [parseInt(romoUserId, 10)],
      );
      if (p.length > 0) {
        if (p[0].role_code === 'ROMO_ORDO') isOrdo = true;
        if (p[0].paroki_id) resolvedParokiId = p[0].paroki_id;
        if (p[0].ordo_id) resolvedOrdoId = p[0].ordo_id;
      }
    }

    if (isOrdo || resolvedOrdoId) {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                p.romo_position, o.name as ordo_name, o.code as ordo_code,
                k.name as keuskupan_name, par.name as paroki_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN ordo o ON (p.ordo_id = o.id OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = o.id))
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'ROMO_ORDO'
           AND u.account_status = 'PENDING_APPROVAL'
           AND ($1::int IS NULL OR p.ordo_id = $1::int OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1::int))
         ORDER BY u.created_at DESC`,
        [resolvedOrdoId],
      );
      return rows;
    } else {
      const rows = await this.dataSource.query(
        `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.created_at,
                p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
                p.romo_position,
                k.name as keuskupan_name, par.name as paroki_name,
                kk.name as kota_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         JOIN user_profiles p ON u.id = p.user_id
         LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
         LEFT JOIN paroki par ON p.paroki_id = par.id
         LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
         WHERE r.code = 'ROMO_PAROKI'
           AND u.account_status = 'PENDING_APPROVAL'
           AND ($1::int IS NULL OR p.paroki_id = $1::int)
         ORDER BY u.created_at DESC`,
        [resolvedParokiId],
      );
      return rows;
    }
  }
  async processRomoApproval(
    body: { targetUserId: number; approverUserId: number; action: 'APPROVE' | 'REJECT'; rejectionReason?: string },
  ) {
    const { targetUserId, approverUserId, action, rejectionReason } = body;
    if (!targetUserId || !approverUserId || !action) {
      throw new BadRequestException('Parameter targetUserId, approverUserId, dan action wajib diisi.');
    }

    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
    await this.dataSource.query(
      'UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newStatus, targetUserId],
    );

    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason)
       VALUES ($1, $2, $3, $4)`,
      [targetUserId, approverUserId, action, rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: action === 'APPROVE' ? 'Romo berhasil disetujui!' : 'Pendaftaran Romo berhasil ditolak.',
      accountStatus: newStatus,
    };
  }
  async register(dto: RegisterUserDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const role = await queryRunner.query('SELECT id FROM roles WHERE code = $1', [dto.roleCode]);
      const roleId = role[0]?.id || 1;

      // Romo Position only applies to Romo roles (ROMO_PAROKI / ROMO_ORDO)
      const isRomo = dto.roleCode === RoleCodeEnum.ROMO_PAROKI || dto.roleCode === RoleCodeEnum.ROMO_ORDO || (dto.roleCode as string).startsWith('ROMO');
      const pengurusPositionVal = (dto.pengurusPosition && dto.pengurusPosition.trim() !== '') ? dto.pengurusPosition : null;
      const romoPositionVal = isRomo ? ((dto.romoPosition && dto.romoPosition.trim() !== '') ? dto.romoPosition : 'ROMO_BIASA') : null;

      let approverName = 'Admin Aplikasi CATU';
      let assignedApproverId: number | null = null;
      const isKoordinatorRegistration = (pengurusPositionVal && pengurusPositionVal.toLowerCase().includes('koordinator')) || (dto.roleCode as string) === 'KOORDINATOR';

      if (dto.roleCode === RoleCodeEnum.UMAT && dto.lingkunganId && !isKoordinatorRegistration) {
        const pengurus = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE p.lingkungan_id = $1
             AND (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL)
             AND u.account_status = 'APPROVED'
           ORDER BY CASE WHEN LOWER(p.pengurus_position) LIKE '%ketua%' THEN 1 ELSE 2 END
           LIMIT 1`,
          [dto.lingkunganId],
        );
        if (pengurus.length > 0) {
          assignedApproverId = pengurus[0].id;
          approverName = `${pengurus[0].full_name} (${pengurus[0].phone_number})`;
        }
      } else if (dto.roleCode === 'ROMO_PAROKI' && romoPositionVal !== 'KETUA_ROMO' && dto.parokiId) {
        const ketuaRomo = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE p.paroki_id = $1
             AND r.code = 'ROMO_PAROKI'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'
           LIMIT 1`,
          [dto.parokiId],
        );
        if (ketuaRomo.length > 0) {
          assignedApproverId = ketuaRomo[0].id;
          approverName = `Kepala Romo Paroki: ${ketuaRomo[0].full_name} (${ketuaRomo[0].phone_number})`;
        }
      } else if (dto.roleCode === 'ROMO_ORDO' && romoPositionVal !== 'KETUA_ROMO' && dto.ordoId) {
        const ketuaOrdo = await queryRunner.query(
          `SELECT u.id, p.full_name, u.phone_number
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           JOIN roles r ON u.role_id = r.id
           WHERE (p.ordo_id = $1 OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1))
             AND r.code = 'ROMO_ORDO'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'
           LIMIT 1`,
          [dto.ordoId],
        );
        if (ketuaOrdo.length > 0) {
          assignedApproverId = ketuaOrdo[0].id;
          approverName = `Ketua Romo Ordo: ${ketuaOrdo[0].full_name} (${ketuaOrdo[0].phone_number})`;
        }
      }

      // Hash password dengan Bcrypt salt 10
      const hashedPassword = await bcrypt.hash(dto.password, 10);

      // Check if position already taken for that Lingkungan
      if ((dto.roleCode === 'PENGURUS_LINGKUNGAN' || pengurusPositionVal) && dto.lingkunganId && pengurusPositionVal) {
        const existingPengurus = await queryRunner.query(
          `SELECT u.id, p.full_name, p.pengurus_position, u.account_status
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           WHERE p.lingkungan_id = $1
             AND u.account_status IN ('APPROVED', 'PENDING_APPROVAL')
             AND (
               LOWER(p.pengurus_position) = LOWER($2)
               OR (LOWER($2) LIKE '%ketua%' AND LOWER($2) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
               OR (LOWER($2) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
               OR (LOWER($2) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
               OR (LOWER($2) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
             )`,
          [dto.lingkunganId, pengurusPositionVal],
        );
        if (existingPengurus.length > 0) {
          const existingName = existingPengurus[0].full_name;
          const existingPos = existingPengurus[0].pengurus_position;
          throw new BadRequestException(
            `Jabatan ${pengurusPositionVal} untuk lingkungan ini sudah terisi / diajukan oleh ${existingName} (${existingPos}). Pengurus dengan jabatan yang sama tidak boleh ganda dalam satu lingkungan.`,
          );
        }
      }

      // Flag Jabatan applies ONLY to leadership positions. Ordinary Umat & ordinary Romo have NO leadership position (null).
      const isLeadershipPos = Boolean(pengurusPositionVal || (isRomo && romoPositionVal === 'KETUA_ROMO'));
      const initialActiveFlag = isLeadershipPos ? false : null;

      // Extract years from dates if missing
      let startYear = dto.jabatanStartYear;
      let endYear = dto.jabatanEndYear;
      if (!startYear && dto.jabatanStartDate && dto.jabatanStartDate.includes('/')) {
        const parts = dto.jabatanStartDate.split('/');
        if (parts.length === 3) startYear = parseInt(parts[2], 10);
      }
      if (!endYear && dto.jabatanEndDate && dto.jabatanEndDate.includes('/')) {
        const parts = dto.jabatanEndDate.split('/');
        if (parts.length === 3) endYear = parseInt(parts[2], 10);
      }

      // 1. Insert ke auth_users
      const authResult = await queryRunner.query(
        `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status, approval_assigned_to_user_id)
         VALUES ($1, $2, $3, 'PENDING_APPROVAL', $4) RETURNING id, uuid, phone_number, account_status`,
        [dto.phoneNumber, hashedPassword, roleId, assignedApproverId],
      );
      const authUser = authResult[0];

      // 2. Insert ke user_profiles
      await queryRunner.query(
        `INSERT INTO user_profiles (user_id, full_name, email, birth_date, address, keuskupan_id, paroki_id, wilayah_id, lingkungan_id, kabupaten_kota_id, pengurus_position, romo_position, jabatan_start_year, jabatan_end_year, jabatan_start_date, jabatan_end_date, is_jabatan_active, ordo_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)`,
        [
          authUser.id,
          dto.fullName,
          dto.email || null,
          dto.birthDate || null,
          dto.address || null,
          dto.keuskupanId || null,
          dto.parokiId || null,
          dto.wilayahId || null,
          dto.lingkunganId || null,
          dto.kabupatenKotaId || 3175,
          pengurusPositionVal,
          romoPositionVal,
          startYear || null,
          endYear || null,
          dto.jabatanStartDate || null,
          dto.jabatanEndDate || null,
          initialActiveFlag,
          dto.ordoId || null,
        ],
      );

      await queryRunner.commitTransaction();

      // Detailed location names for response DTO
      let keuskupanName = '';
      let parokiName = '';
      let wilayahName = '';
      let lingkunganName = '';
      let ordoName = '';
      let kabupatenKotaName = 'JAKARTA TIMUR';

      if (dto.keuskupanId) {
        const kRes = await this.dataSource.query('SELECT name FROM keuskupan WHERE id = $1', [dto.keuskupanId]);
        if (kRes.length > 0) keuskupanName = kRes[0].name;
      }
      if (dto.parokiId) {
        const pRes = await this.dataSource.query('SELECT name FROM paroki WHERE id = $1', [dto.parokiId]);
        if (pRes.length > 0) parokiName = pRes[0].name;
      }
      if (dto.wilayahId) {
        const wRes = await this.dataSource.query('SELECT name FROM wilayah WHERE id = $1', [dto.wilayahId]);
        if (wRes.length > 0) wilayahName = wRes[0].name;
      }
      if (dto.lingkunganId) {
        const lRes = await this.dataSource.query('SELECT name FROM lingkungan WHERE id = $1', [dto.lingkunganId]);
        if (lRes.length > 0) lingkunganName = lRes[0].name;
      }
      if (dto.ordoId) {
        const oRes = await this.dataSource.query('SELECT name FROM ordo WHERE id = $1', [dto.ordoId]);
        if (oRes.length > 0) ordoName = oRes[0].name;
      }

      if (dto.roleCode === 'UMAT' && dto.lingkunganId) {
        const pengurusUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE p.lingkungan_id = $1
             AND (r.code = 'PENGURUS_LINGKUNGAN' OR p.pengurus_position IS NOT NULL)
             AND u.account_status = 'APPROVED'`,
          [dto.lingkunganId],
        );

        for (const pg of pengurusUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                pg.id,
                `Pendaftaran Umat Baru: ${dto.fullName}`,
                `Umat baru ${dto.fullName} (${dto.phoneNumber}) telah mendaftar di ${lingkunganName || 'Lingkungan Anda'} dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      } else if (dto.roleCode === 'ROMO_PAROKI' && romoPositionVal !== 'KETUA_ROMO' && dto.parokiId) {
        const ketuaRomoUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE p.paroki_id = $1
             AND r.code = 'ROMO_PAROKI'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'`,
          [dto.parokiId],
        );

        for (const kr of ketuaRomoUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                kr.id,
                `Pendaftaran Romo Paroki Baru: ${dto.fullName}`,
                `Romo ${dto.fullName} (${dto.phoneNumber}) mendaftar di paroki Anda (${parokiName || 'Paroki'}) dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      } else if (dto.roleCode === 'ROMO_ORDO' && romoPositionVal !== 'KETUA_ROMO' && dto.ordoId) {
        let ordoName = '';
        const ordoRes = await this.dataSource.query('SELECT name FROM ordo WHERE id = $1', [dto.ordoId]);
        if (ordoRes.length > 0) ordoName = ordoRes[0].name;

        const ketuaOrdoUsers = await this.dataSource.query(
          `SELECT u.id FROM auth_users u
           JOIN user_profiles p ON u.id = p.user_id
           JOIN roles r ON u.role_id = r.id
           WHERE (p.ordo_id = $1 OR p.user_id IN (SELECT rp.user_id FROM romo_profiles rp WHERE rp.ordo_id = $1))
             AND r.code = 'ROMO_ORDO'
             AND p.romo_position = 'KETUA_ROMO'
             AND u.account_status = 'APPROVED'`,
          [dto.ordoId],
        );

        for (const ko of ketuaOrdoUsers) {
          try {
            await this.dataSource.query(
              `INSERT INTO notifications (user_id, title, body, type)
               VALUES ($1, $2, $3, 'NEW_ORDER_MONITOR')`,
              [
                ko.id,
                `Pendaftaran Romo Ordo Baru: ${dto.fullName}`,
                `Romo ${dto.fullName} (${dto.phoneNumber}) mendaftar di ordo Anda (${ordoName || 'Ordo'}) dan menunggu persetujuan (approval).`,
              ],
            );
          } catch (_) {}
        }
      }

      let approvalTargetMsg = 'Admin Aplikasi CATU';
      if (dto.roleCode === 'UMAT') {
        approvalTargetMsg = 'Pengurus Lingkungan';
      } else if (dto.roleCode === 'ROMO_PAROKI') {
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Kepala Romo Paroki / Admin Aplikasi CATU';
      } else if (dto.roleCode === 'ROMO_ORDO') {
        approvalTargetMsg = romoPositionVal === 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Ketua Romo Ordo / Admin Aplikasi CATU';
      } else if (dto.roleCode === 'PENGURUS_LINGKUNGAN') {
        approvalTargetMsg = 'Admin Aplikasi CATU';
      }

      return {
        statusCode: 201,
        message: `Registrasi berhasil! Akun Anda sedang menunggu persetujuan dari ${approvalTargetMsg}.`,
        user: {
          id: authUser.id,
          uuid: authUser.uuid,
          fullName: dto.fullName,
          phoneNumber: authUser.phone_number,
          email: dto.email || '',
          roleCode: dto.roleCode,
          accountStatus: authUser.account_status,
          keuskupanId: dto.keuskupanId || null,
          parokiId: dto.parokiId || null,
          wilayahId: dto.wilayahId || null,
          lingkunganId: dto.lingkunganId || null,
          ordoId: dto.ordoId || null,
          keuskupanName: keuskupanName || null,
          parokiName: parokiName || null,
          wilayahName: wilayahName || null,
          lingkunganName: lingkunganName || null,
          ordoName: ordoName || null,
          kabupatenKotaName: 'JAKARTA TIMUR',
          pengurusPosition: dto.pengurusPosition,
          romoPosition: romoPositionVal,
          jabatanStartYear: startYear,
          jabatanEndYear: endYear,
          jabatanStartDate: dto.jabatanStartDate,
          jabatanEndDate: dto.jabatanEndDate,
          isJabatanActive: initialActiveFlag,
        },
        approvalAssignedTo: approverName,
      };
    } catch (err: any) {
      if (queryRunner.isTransactionActive) {
        await queryRunner.rollbackTransaction();
      }
      if (err instanceof BadRequestException || err.status === 400) {
        throw err;
      }
      const errMessage = err.message || '';
      if (err.code === '23505' || errMessage.includes('auth_users_phone_number_key') || errMessage.includes('unique constraint') || errMessage.includes('phone_number')) {
        throw new BadRequestException('Nomor WhatsApp / HP ini sudah terdaftar. Silakan gunakan nomor lain atau login.');
      }
      throw new BadRequestException(errMessage || 'Registrasi gagal. Silakan periksa kembali data Anda.');
    } finally {
      await queryRunner.release();
    }
  }
  async login(dto: LoginDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;
    const localPhone = `0${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.password_hash, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.ordo_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, ord.name as ordo_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1 OR u.phone_number = $2`,
      [fullPhone, localPhone],
    );

    if (!users.length) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const dbPasswordHash = users[0].password_hash;
    const isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor HP atau Password salah' };
    }

    const user = users[0];

    // Admin tidak boleh login di aplikasi mobile
    if (user.role_code === 'ADMIN') {
      return {
        statusCode: 403,
        message: 'Akun Administrator tidak dapat login melalui aplikasi mobile. Silakan gunakan Web Portal Admin di browser komputer (http://localhost:8000).',
      };
    }

    const accessToken = this.jwtService.sign({
      sub: user.id,
      uuid: user.uuid,
      phoneNumber: user.phone_number,
      roleCode: user.role_code,
      fullName: user.full_name,
    });

    return {
      statusCode: 200,
      message: 'Login Berhasil',
      accessToken,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        birthDate: user.birth_date,
        address: user.address,
        avatarUrl: user.avatar_url,
        roleCode: user.role_code,
        accountStatus: user.account_status,
        keuskupanId: user.keuskupan_id,
        parokiId: user.paroki_id,
        wilayahId: user.wilayah_id,
        lingkunganId: user.lingkungan_id,
        ordoId: user.ordo_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.keuskupan_name,
        parokiName: user.paroki_name,
        wilayahName: user.wilayah_name,
        lingkunganName: user.lingkungan_name,
        ordoName: user.ordo_name,
        kabupatenKotaName: user.kota_name,
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }
  async adminLogin(dto: LoginDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.password_hash, u.account_status, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id, kk.provinsi_id,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name, kk.name as kota_name,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
       FROM auth_users u
       JOIN roles r ON u.role_id = r.id
       JOIN user_profiles p ON p.user_id = u.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       WHERE u.phone_number = $1 OR u.phone_number = $2 OR u.phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return { statusCode: 401, message: 'Nomor WhatsApp / HP atau kata sandi salah' };
    }

    const user = users[0];

    // Check Role: MUST BE ADMIN
    if (user.role_code !== 'ADMIN') {
      return {
        statusCode: 403,
        message: `Akses Ditolak: Portal Web ini khusus untuk Administrator Sistem. Pengguna peran "${user.role_code}" silakan masuk melalui Aplikasi Mobile CATU.`,
      };
    }

    const dbPasswordHash = user.password_hash;
    const isPasswordValid = await bcrypt.compare(dto.password, dbPasswordHash);

    if (!isPasswordValid) {
      return { statusCode: 401, message: 'Nomor WhatsApp / HP atau kata sandi salah' };
    }

    const accessToken = this.jwtService.sign({
      sub: user.id,
      uuid: user.uuid,
      phoneNumber: user.phone_number,
      roleCode: user.role_code,
      fullName: user.full_name,
      isAdmin: true,
    });

    return {
      statusCode: 200,
      message: 'Login Administrator Berhasil',
      accessToken,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        roleCode: user.role_code,
        accountStatus: user.account_status,
      },
    };
  }

  // ── Forgot Password Endpoints ──
  async requestResetOtp(dto: RequestResetOtpDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    const users = await this.dataSource.query(
      `SELECT u.id, u.phone_number, p.full_name
       FROM auth_users u
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE u.phone_number = $1 OR u.phone_number = $2 OR u.phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return {
        statusCode: 404,
        message: 'Nomor WhatsApp tidak terdaftar di sistem CATU.',
      };
    }

    const user = users[0];
    const demoOtp = '123456';
    const maskedPhone = fullPhone.replace(/(\d{4})\d+(\d{3})/, '$1-****-$2');

    return {
      statusCode: 200,
      message: 'Kode OTP verifikasi berhasil dikirimkan ke WhatsApp Anda.',
      phoneNumber: user.phone_number,
      fullName: user.full_name || 'Pengguna',
      maskedPhone,
      demoOtp,
    };
  }
  async verifyResetOtp(dto: VerifyResetOtpDto) {
    const otp = dto.otpCode.trim();
    if (!otp || otp.length < 4) {
      return {
        statusCode: 400,
        message: 'Kode OTP tidak valid.',
      };
    }

    if (otp !== '123456' && otp.length !== 6) {
      return {
        statusCode: 400,
        message: 'Kode OTP salah atau telah kadaluarsa.',
      };
    }

    return {
      statusCode: 200,
      message: 'Verifikasi kode OTP berhasil.',
      verified: true,
    };
  }
  async resetPassword(dto: ResetPasswordDto) {
    let phone = dto.phoneNumber.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    const fullPhone = `62${phone}`;

    if (!dto.newPassword || dto.newPassword.length < 6) {
      return {
        statusCode: 400,
        message: 'Kata sandi baru minimal 6 karakter.',
      };
    }

    const users = await this.dataSource.query(
      `SELECT id, phone_number FROM auth_users
       WHERE phone_number = $1 OR phone_number = $2 OR phone_number = $3`,
      [fullPhone, `0${phone}`, dto.phoneNumber.trim()],
    );

    if (!users.length) {
      return {
        statusCode: 404,
        message: 'Pengguna tidak ditemukan.',
      };
    }

    const newHash = await bcrypt.hash(dto.newPassword, 10);

    await this.dataSource.query(
      `UPDATE auth_users
       SET password_hash = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [newHash, users[0].id],
    );

    return {
      statusCode: 200,
      message: 'Kata sandi berhasil diperbarui! Silakan masuk dengan kata sandi baru Anda.',
    };
  }
  async getProfile(userId: string) {
    const uid = parseInt(userId);
    if (isNaN(uid)) throw new BadRequestException('User ID tidak valid');

    const users = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.role_id, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.ordo_id, ord.name as ordo_name,
              p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year,
              p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name, prov.name as provinsi_name, prov.id as provinsi_id
       FROM auth_users u
       JOIN user_profiles p ON p.user_id = u.id
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
       WHERE u.id = $1`,
      [uid],
    );

    if (!users.length) {
      throw new BadRequestException('User tidak ditemukan');
    }

    const user = users[0];
    return {
      statusCode: 200,
      user: {
        id: user.id,
        uuid: user.uuid,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email || '',
        birthDate: user.birth_date || '',
        address: user.address || '',
        avatarUrl: user.avatar_url || '',
        roleCode: user.role_code,
        accountStatus: user.account_status,
        ordoId: user.ordo_id,
        ordoName: user.ordo_name || '',
        keuskupanId: user.role_code === 'ROMO_ORDO' ? null : user.keuskupan_id,
        parokiId: user.role_code === 'ROMO_ORDO' ? null : user.paroki_id,
        wilayahId: user.role_code === 'ROMO_ORDO' ? null : user.wilayah_id,
        lingkunganId: user.role_code === 'ROMO_ORDO' ? null : user.lingkungan_id,
        kabupatenKotaId: user.kabupaten_kota_id,
        provinsiId: user.provinsi_id,
        keuskupanName: user.role_code === 'ROMO_ORDO' ? '' : (user.keuskupan_name || ''),
        parokiName: user.role_code === 'ROMO_ORDO' ? '' : (user.paroki_name || ''),
        wilayahName: user.role_code === 'ROMO_ORDO' ? '' : (user.wilayah_name || ''),
        lingkunganName: user.role_code === 'ROMO_ORDO' ? '' : (user.lingkungan_name || ''),
        kabupatenKotaName: user.kota_name || '',
        provinsiName: user.provinsi_name || '',
        pengurusPosition: user.pengurus_position,
        romoPosition: user.romo_position,
        jabatanStartYear: user.jabatan_start_year,
        jabatanEndYear: user.jabatan_end_year,
        jabatanStartDate: user.jabatan_start_date,
        jabatanEndDate: user.jabatan_end_date,
        isJabatanActive: user.is_jabatan_active !== null ? user.is_jabatan_active : false,
      },
    };
  }
  async updateProfile(
    userId: string,
    dto: UpdateUserProfileDto,
  ) {
    const uid = parseInt(userId);
    if (isNaN(uid)) throw new BadRequestException('User ID tidak valid');

    if (dto.phoneNumber) {
      let cleanPhone = dto.phoneNumber.trim().replace(/\D/g, '');
      if (!cleanPhone.startsWith('62')) {
        if (cleanPhone.startsWith('0')) cleanPhone = '62' + cleanPhone.substring(1);
        else cleanPhone = '62' + cleanPhone;
      }

      // Check if phone number is already used by another user
      const existingPhone = await this.dataSource.query(
        `SELECT id, phone_number FROM auth_users WHERE (phone_number = $1 OR phone_number = $2 OR phone_number = $3) AND id != $4`,
        [cleanPhone, cleanPhone.replace(/^62/, '0'), cleanPhone.replace(/^62/, ''), uid],
      );
      if (existingPhone.length > 0) {
        throw new BadRequestException('Nomor WhatsApp ini sudah terdaftar dan digunakan oleh pengguna lain!');
      }

      await this.dataSource.query(
        `UPDATE auth_users SET phone_number = $1 WHERE id = $2`,
        [cleanPhone, uid],
      );
    }

    if (dto.roleCode || (dto as any).role_code) {
      const targetRole = dto.roleCode || (dto as any).role_code;
      const roleRes = await this.dataSource.query(`SELECT id FROM roles WHERE code = $1`, [targetRole]);
      if (roleRes.length > 0) {
        await this.dataSource.query(`UPDATE auth_users SET role_id = $1 WHERE id = $2`, [roleRes[0].id, uid]);
      }
    }

    const userRoleRes = await this.dataSource.query(
      `SELECT r.code FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE u.id = $1`,
      [uid],
    );
    const activeRoleCode = dto.roleCode || (userRoleRes[0] ? userRoleRes[0].code : '');

    const targetLingkunganId = (dto.lingkunganId !== undefined || (dto as any).lingkungan_id !== undefined)
      ? (dto.lingkunganId ?? (dto as any).lingkungan_id)
      : null;
    const targetPengurusPos = (dto as any).pengurusPosition ?? (dto as any).pengurus_position;

    if (activeRoleCode === 'PENGURUS_LINGKUNGAN' || targetPengurusPos) {
      let checkLingkunganId = targetLingkunganId;
      if (!checkLingkunganId) {
        const curProf = await this.dataSource.query(`SELECT lingkungan_id FROM user_profiles WHERE user_id = $1`, [uid]);
        checkLingkunganId = curProf[0]?.lingkungan_id;
      }
      let checkPos = targetPengurusPos;
      if (!checkPos) {
        const curProf = await this.dataSource.query(`SELECT pengurus_position FROM user_profiles WHERE user_id = $1`, [uid]);
        checkPos = curProf[0]?.pengurus_position;
      }

      if (checkLingkunganId && checkPos) {
        const existingPengurus = await this.dataSource.query(
          `SELECT u.id, p.full_name, p.pengurus_position
           FROM user_profiles p
           JOIN auth_users u ON p.user_id = u.id
           WHERE p.lingkungan_id = $1
             AND u.id != $2
             AND u.account_status IN ('APPROVED', 'PENDING_APPROVAL')
             AND (
               LOWER(p.pengurus_position) = LOWER($3)
               OR (LOWER($3) LIKE '%ketua%' AND LOWER($3) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
               OR (LOWER($3) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
               OR (LOWER($3) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
               OR (LOWER($3) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
             )`,
          [checkLingkunganId, uid, checkPos],
        );
        if (existingPengurus.length > 0) {
          const existingName = existingPengurus[0].full_name;
          const existingPos = existingPengurus[0].pengurus_position;
          throw new BadRequestException(
            `Jabatan ${checkPos} untuk lingkungan ini sudah terisi oleh ${existingName} (${existingPos}). Pengurus dengan jabatan yang sama tidak boleh ganda dalam satu lingkungan.`,
          );
        }
      }
    }

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (dto.fullName !== undefined) {
      fields.push(`full_name = $${idx++}`);
      values.push(dto.fullName);
    }
    if (dto.email !== undefined) {
      fields.push(`email = $${idx++}`);
      values.push(dto.email);
    }
    if (dto.birthDate !== undefined) {
      const bDate = dto.birthDate && String(dto.birthDate).trim() ? String(dto.birthDate).trim() : null;
      fields.push(`birth_date = $${idx++}`);
      values.push(bDate);
    }
    if (dto.address !== undefined) {
      fields.push(`address = $${idx++}`);
      values.push(dto.address);
    }
    if (dto.avatarUrl !== undefined) {
      fields.push(`avatar_url = $${idx++}`);
      values.push(dto.avatarUrl);
    }
    if (activeRoleCode === 'ROMO_ORDO') {
      fields.push(`keuskupan_id = NULL`, `paroki_id = NULL`, `wilayah_id = NULL`, `lingkungan_id = NULL`);
    } else {
      if (dto.keuskupanId !== undefined || (dto as any).keuskupan_id !== undefined) {
        const kId = (dto.keuskupanId ?? (dto as any).keuskupan_id) ? parseInt(dto.keuskupanId ?? (dto as any).keuskupan_id) : null;
        fields.push(`keuskupan_id = $${idx++}`);
        values.push(kId && !isNaN(kId) && kId > 0 ? kId : null);
      }
      if (dto.parokiId !== undefined || (dto as any).paroki_id !== undefined) {
        const pId = (dto.parokiId ?? (dto as any).paroki_id) ? parseInt(dto.parokiId ?? (dto as any).paroki_id) : null;
        fields.push(`paroki_id = $${idx++}`);
        values.push(pId && !isNaN(pId) && pId > 0 ? pId : null);
      }
      if (dto.wilayahId !== undefined || (dto as any).wilayah_id !== undefined) {
        const wId = (dto.wilayahId ?? (dto as any).wilayah_id) ? parseInt(dto.wilayahId ?? (dto as any).wilayah_id) : null;
        fields.push(`wilayah_id = $${idx++}`);
        values.push(wId && !isNaN(wId) && wId > 0 ? wId : null);
      }
      if (dto.lingkunganId !== undefined || (dto as any).lingkungan_id !== undefined) {
        const lId = (dto.lingkunganId ?? (dto as any).lingkungan_id) ? parseInt(dto.lingkunganId ?? (dto as any).lingkungan_id) : null;
        fields.push(`lingkungan_id = $${idx++}`);
        values.push(lId && !isNaN(lId) && lId > 0 ? lId : null);
      }
    }
    if (dto.kabupatenKotaId !== undefined || (dto as any).kabupaten_kota_id !== undefined) {
      const kkId = (dto.kabupatenKotaId ?? (dto as any).kabupaten_kota_id) ? parseInt(dto.kabupatenKotaId ?? (dto as any).kabupaten_kota_id) : null;
      fields.push(`kabupaten_kota_id = $${idx++}`);
      values.push(kkId && !isNaN(kkId) && kkId > 0 ? kkId : null);
    }
    if (dto.ordoId !== undefined || (dto as any).ordo_id !== undefined) {
      const oId = (dto.ordoId ?? (dto as any).ordo_id) ? parseInt(dto.ordoId ?? (dto as any).ordo_id) : null;
      fields.push(`ordo_id = $${idx++}`);
      values.push(oId && !isNaN(oId) && oId > 0 ? oId : null);
    }
    if ((dto as any).pengurusPosition !== undefined || (dto as any).pengurus_position !== undefined) {
      fields.push(`pengurus_position = $${idx++}`);
      values.push((dto as any).pengurusPosition ?? (dto as any).pengurus_position);
    }
    if ((dto as any).romoPosition !== undefined || (dto as any).romo_position !== undefined) {
      fields.push(`romo_position = $${idx++}`);
      values.push((dto as any).romoPosition ?? (dto as any).romo_position);
    }
    if ((dto as any).jabatanStartYear !== undefined || (dto as any).jabatan_start_year !== undefined) {
      fields.push(`jabatan_start_year = $${idx++}`);
      values.push((dto as any).jabatanStartYear ?? (dto as any).jabatan_start_year);
    }
    if ((dto as any).jabatanEndYear !== undefined || (dto as any).jabatan_end_year !== undefined) {
      fields.push(`jabatan_end_year = $${idx++}`);
      values.push((dto as any).jabatanEndYear ?? (dto as any).jabatan_end_year);
    }
    if ((dto as any).isJabatanActive !== undefined || (dto as any).is_jabatan_active !== undefined) {
      fields.push(`is_jabatan_active = $${idx++}`);
      values.push((dto as any).isJabatanActive ?? (dto as any).is_jabatan_active);
    }

    if ((dto as any).accountStatus !== undefined || (dto as any).account_status !== undefined) {
      const targetStatus = (dto as any).accountStatus ?? (dto as any).account_status;
      await this.dataSource.query(`UPDATE auth_users SET account_status = $1 WHERE id = $2`, [targetStatus, uid]);
    }

    if (fields.length > 0) {
      fields.push(`updated_at = NOW()`);
      values.push(uid);
      await this.dataSource.query(
        `UPDATE user_profiles SET ${fields.join(', ')} WHERE user_id = $${idx}`,
        values,
      );
    }

    const updated = await this.dataSource.query(
      `SELECT u.id, u.uuid, u.phone_number, u.account_status, u.role_id, r.code as role_code,
              p.full_name, p.email, p.birth_date, p.address, p.avatar_url, p.ordo_id, ord.name as ordo_name,
              p.keuskupan_id, p.paroki_id, p.wilayah_id, p.lingkungan_id, p.kabupaten_kota_id,
              p.pengurus_position, p.romo_position, p.jabatan_start_year, p.jabatan_end_year,
              p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active,
              k.name as keuskupan_name, par.name as paroki_name, w.name as wilayah_name, l.name as lingkungan_name,
              kk.name as kota_name, prov.name as provinsi_name, prov.id as provinsi_id
       FROM auth_users u
       JOIN user_profiles p ON p.user_id = u.id
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN ordo ord ON p.ordo_id = ord.id
       LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
       LEFT JOIN paroki par ON p.paroki_id = par.id
       LEFT JOIN wilayah w ON p.wilayah_id = w.id
       LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
       LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
       LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
       WHERE u.id = $1`,
      [uid],
    );

    const uObj = updated[0] ? {
      id: updated[0].id,
      uuid: updated[0].uuid,
      fullName: updated[0].full_name,
      phoneNumber: updated[0].phone_number,
      email: updated[0].email || '',
      birthDate: updated[0].birth_date || '',
      address: updated[0].address || '',
      avatarUrl: updated[0].avatar_url || '',
      roleCode: updated[0].role_code,
      accountStatus: updated[0].account_status,
      ordoId: updated[0].ordo_id,
      ordoName: updated[0].ordo_name || '',
      keuskupanId: updated[0].keuskupan_id,
      parokiId: updated[0].paroki_id,
      wilayahId: updated[0].wilayah_id,
      lingkunganId: updated[0].lingkungan_id,
      kabupatenKotaId: updated[0].kabupaten_kota_id,
      provinsiId: updated[0].provinsi_id,
      keuskupanName: updated[0].keuskupan_name || '',
      parokiName: updated[0].paroki_name || '',
      wilayahName: updated[0].wilayah_name || '',
      lingkunganName: updated[0].lingkungan_name || '',
      kabupatenKotaName: updated[0].kota_name || '',
      provinsiName: updated[0].provinsi_name || '',
    } : {};

    return {
      statusCode: 200,
      message: 'Profil pengguna berhasil diperbarui!',
      user: uObj,
    };
  }
  async approveRegistration(dto: ApproveUserDto) {
    if (dto.action === 'APPROVED') {
      const targetProf = await this.dataSource.query(
        `SELECT u.role_id, r.code as role_code, p.lingkungan_id, p.keuskupan_id, p.pengurus_position, p.full_name
         FROM auth_users u
         JOIN roles r ON u.role_id = r.id
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE u.id = $1`,
        [dto.targetUserId],
      );

      if (targetProf.length > 0) {
        const roleCode = targetProf[0].role_code;
        const pengurusPos = (targetProf[0].pengurus_position || '').toString().toLowerCase();
        const isKoordinator = pengurusPos.includes('koordinator') || roleCode === 'KOORDINATOR';

        // Check if Koordinator in that Keuskupan already exists
        if (isKoordinator && targetProf[0].keuskupan_id) {
          const existingKoordinator = await this.dataSource.query(
            `SELECT u.id, p.full_name, p.pengurus_position
             FROM user_profiles p
             JOIN auth_users u ON p.user_id = u.id
             WHERE p.keuskupan_id = $1
               AND u.id != $2
               AND u.account_status = 'APPROVED'
               AND LOWER(p.pengurus_position) LIKE '%koordinator%'`,
            [targetProf[0].keuskupan_id, dto.targetUserId],
          );
          if (existingKoordinator.length > 0) {
            throw new BadRequestException(
              `Gagal menyetujui akun: Jabatan Koordinator untuk keuskupan ini sudah aktif oleh ${existingKoordinator[0].full_name}.`,
            );
          }
        }

        // Pengurus Lingkungan duplicate position check
        if (roleCode === 'PENGURUS_LINGKUNGAN' && targetProf[0].lingkungan_id && targetProf[0].pengurus_position) {
          const existingApproved = await this.dataSource.query(
            `SELECT u.id, p.full_name, p.pengurus_position
             FROM user_profiles p
             JOIN auth_users u ON p.user_id = u.id
             WHERE p.lingkungan_id = $1
               AND u.id != $2
               AND u.account_status = 'APPROVED'
               AND (
                 LOWER(p.pengurus_position) = LOWER($3)
                 OR (LOWER($3) LIKE '%ketua%' AND LOWER($3) NOT LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%ketua%' AND LOWER(p.pengurus_position) NOT LIKE '%wakil%')
                 OR (LOWER($3) LIKE '%wakil%' AND LOWER(p.pengurus_position) LIKE '%wakil%')
                 OR (LOWER($3) LIKE '%sekretaris%' AND LOWER(p.pengurus_position) LIKE '%sekretaris%')
                 OR (LOWER($3) LIKE '%bendahara%' AND LOWER(p.pengurus_position) LIKE '%bendahara%')
               )`,
            [targetProf[0].lingkungan_id, dto.targetUserId, targetProf[0].pengurus_position],
          );
          if (existingApproved.length > 0) {
            throw new BadRequestException(
              `Gagal menyetujui akun: Jabatan ${targetProf[0].pengurus_position} pada lingkungan ini sudah terisi dan aktif oleh ${existingApproved[0].full_name}. Tidak boleh ada jabatan pengurus yang ganda dalam satu lingkungan.`,
            );
          }
        }
      }

      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = TRUE WHERE user_id = $1`,
        [dto.targetUserId],
      );
    }

    const updated = await this.dataSource.query(
      `UPDATE auth_users SET account_status = $1 WHERE id = $2 RETURNING id, account_status`,
      [dto.action, dto.targetUserId],
    );

    const userProfile = await this.dataSource.query(`SELECT full_name FROM user_profiles WHERE user_id = $1`, [dto.targetUserId]);

    // Audit Log Approval
    await this.dataSource.query(
      `INSERT INTO user_approvals (target_user_id, approver_user_id, action, rejection_reason) VALUES ($1, 7, $2, $3)`,
      [dto.targetUserId, dto.action, dto.rejectionReason || null],
    );

    return {
      statusCode: 200,
      message: `Akun user ${userProfile[0]?.full_name || ''} (ID: ${dto.targetUserId}) telah berhasil di-${dto.action}`,
      targetUserId: dto.targetUserId,
      status: dto.action,
      approvedBy: 'Super Admin CATU / Ketua Lingkungan',
      approvedAt: new Date().toISOString(),
    };
  }

  // ── Admin Dashboard Endpoints ──
  async getAdminAnalytics() {
    const totalOrdersRes = await this.dataSource.query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status::text = 'PENDING') as pending,
        COUNT(*) FILTER (WHERE status::text = 'CONFIRMED' OR status::text = 'ACCEPTED' OR status::text = 'IN_PROGRESS') as confirmed,
        COUNT(*) FILTER (WHERE status::text = 'DONE' OR status::text = 'SELESAI' OR status::text = 'COMPLETED') as done,
        COUNT(*) FILTER (WHERE status::text = 'FAIL' OR status::text = 'REJECTED' OR status::text = 'CANCELLED') as fail
      FROM orders
    `);

    const categoriesRes = await this.dataSource.query(`
      SELECT sc.name, COUNT(o.id) as count
      FROM service_categories sc
      LEFT JOIN orders o ON o.service_category_id = sc.id
      GROUP BY sc.name
    `);

    const usersRes = await this.dataSource.query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE u.account_status = 'PENDING_APPROVAL') as pending_approvals,
        COUNT(*) FILTER (WHERE u.account_status = 'PENDING_APPROVAL' AND (LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR')) as pending_koordinator,
        COUNT(*) FILTER (WHERE r.code = 'UMAT' AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) as total_umat,
        COUNT(*) FILTER (WHERE LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR') as total_koordinator,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_PAROKI') as total_romo_paroki,
        COUNT(*) FILTER (WHERE r.code = 'ROMO_ORDO') as total_romo_ordo,
        COUNT(*) FILTER (WHERE r.code = 'PENGURUS_LINGKUNGAN' OR (p.pengurus_position IS NOT NULL AND LOWER(p.pengurus_position) NOT LIKE '%koordinator%')) as total_pengurus,
        COUNT(*) FILTER (WHERE r.code = 'ADMIN') as total_admin
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
    `);

    const recentOrders = await this.dataSource.query(`
      SELECT o.id, o.order_number, sc.name as category_name, o.status, p.full_name as pemohon_name, o.created_at
      FROM orders o
      JOIN service_categories sc ON o.service_category_id = sc.id
      JOIN user_profiles p ON o.user_id = p.user_id
      ORDER BY o.id DESC LIMIT 5
    `);

    const recentUsers = await this.dataSource.query(`
      SELECT u.id, u.phone_number, r.code as role_code, r.name as role_name, p.full_name, u.account_status, u.created_at, p.pengurus_position
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
      ORDER BY u.id DESC LIMIT 5
    `);

    return {
      statusCode: 200,
      orders: totalOrdersRes[0] || {},
      users: usersRes[0] || {},
      categories: categoriesRes || [],
      recentOrders: recentOrders || [],
      recentUsers: recentUsers || [],
    };
  }
  async getAdminUsers(
    role?: string,
    status?: string,
    search?: string,
  ) {
    let query = `
      SELECT u.id, u.uuid, u.phone_number, u.account_status, u.is_active, u.created_at,
             r.id as role_id, r.code as role_code, r.name as role_name,
             p.full_name, p.email, p.birth_date, p.address, p.avatar_url,
             p.keuskupan_id, k.name as keuskupan_name,
             p.paroki_id, par.name as paroki_name,
             p.wilayah_id, w.name as wilayah_name,
             p.lingkungan_id, l.name as lingkungan_name,
             p.kabupaten_kota_id, kk.name as kota_name, kk.provinsi_id, prov.name as provinsi_name,
             p.ordo_id, ord.name as ordo_name,
             p.pengurus_position, p.romo_position,
             p.jabatan_start_year, p.jabatan_end_year, p.jabatan_start_date, p.jabatan_end_date, p.is_jabatan_active
      FROM auth_users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_profiles p ON p.user_id = u.id
      LEFT JOIN keuskupan k ON p.keuskupan_id = k.id
      LEFT JOIN paroki par ON p.paroki_id = par.id
      LEFT JOIN wilayah w ON p.wilayah_id = w.id
      LEFT JOIN lingkungan l ON p.lingkungan_id = l.id
      LEFT JOIN kabupaten_kota kk ON p.kabupaten_kota_id = kk.id
      LEFT JOIN provinsi prov ON kk.provinsi_id = prov.id
      LEFT JOIN ordo ord ON p.ordo_id = ord.id
    `;

    const whereClauses: string[] = [];
    const params: any[] = [];
    let pIdx = 1;

    if (role && role !== 'ALL') {
      if (role === 'KOORDINATOR') {
        whereClauses.push(`(LOWER(p.pengurus_position) LIKE '%koordinator%' OR r.code = 'KOORDINATOR')`);
      } else if (role === 'UMAT') {
        whereClauses.push(`(r.code = 'UMAT' AND (p.pengurus_position IS NULL OR LOWER(p.pengurus_position) NOT LIKE '%koordinator%'))`);
      } else {
        whereClauses.push(`r.code = $${pIdx++}`);
        params.push(role);
      }
    }
    if (status && status !== 'ALL') {
      whereClauses.push(`u.account_status = $${pIdx++}`);
      params.push(status);
    }
    if (search && search.trim().length > 0) {
      whereClauses.push(`(p.full_name ILIKE $${pIdx} OR u.phone_number ILIKE $${pIdx} OR par.name ILIKE $${pIdx} OR k.name ILIKE $${pIdx})`);
      params.push(`%${search.trim()}%`);
      pIdx++;
    }

    if (whereClauses.length > 0) {
      query += ` WHERE ${whereClauses.join(' AND ')}`;
    }
    query += ` ORDER BY u.id DESC`;

    const users = await this.dataSource.query(query, params);
    return {
      statusCode: 200,
      total: users.length,
      users,
    };
  }
  async updateAdminUserStatus(
    userId: string,
    body: { status: string; isJabatanActive?: boolean },
  ) {
    const uid = parseInt(userId);
    await this.dataSource.query(
      `UPDATE auth_users SET account_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [body.status, uid],
    );
    if (body.isJabatanActive !== undefined) {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = $1 WHERE user_id = $2`,
        [body.isJabatanActive, uid],
      );
    } else if (body.status === 'APPROVED') {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = true WHERE user_id = $1 AND (pengurus_position IS NOT NULL OR romo_position = 'KETUA_ROMO')`,
        [uid],
      );
    } else if (body.status === 'REJECTED') {
      await this.dataSource.query(
        `UPDATE user_profiles SET is_jabatan_active = false WHERE user_id = $1 AND (pengurus_position IS NOT NULL OR romo_position = 'KETUA_ROMO')`,
        [uid],
      );
    }
    return { statusCode: 200, message: `Status akun user ID ${uid} berhasil diubah menjadi ${body.status}` };
  }
  async updateAdminUserRole(
    userId: string,
    body: { roleCode: string },
  ) {
    const uid = parseInt(userId);
    const roleRes = await this.dataSource.query(`SELECT id FROM roles WHERE code = $1`, [body.roleCode]);
    if (!roleRes.length) throw new BadRequestException('Role tidak valid');
    await this.dataSource.query(
      `UPDATE auth_users SET role_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [roleRes[0].id, uid],
    );
    return { statusCode: 200, message: `Role user ID ${uid} berhasil diubah menjadi ${body.roleCode}` };
  }
  async updateAdminOrderStatus(
    orderId: string,
    body: { status: string },
  ) {
    const oid = parseInt(orderId);
    await this.dataSource.query(
      `UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [body.status, oid],
    );
    return { statusCode: 200, message: `Status order #${oid} berhasil diubah menjadi ${body.status}` };
  }
}
