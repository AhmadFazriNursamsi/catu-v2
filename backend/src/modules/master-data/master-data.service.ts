import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import {
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
} from "../../orders.dto";

@Injectable()
export class MasterDataService {
  constructor(@InjectDataSource() private dataSource: DataSource) {}


  // 1. KEUSKUPAN
  async getAllKeuskupan() {
    return await this.dataSource.query(`
      SELECT k.id, k.name, k.code, k.created_at,
        COUNT(DISTINCT p.id)::int as total_paroki
      FROM keuskupan k
      LEFT JOIN paroki p ON p.keuskupan_id = k.id
      GROUP BY k.id
      ORDER BY k.id ASC
    `);
  }
  async createKeuskupan(dto: CreateKeuskupanDto) {
    if (!dto.name || !dto.name.trim()) {
      throw new BadRequestException('Nama Keuskupan tidak boleh kosong');
    }
    const res = await this.dataSource.query(
      `INSERT INTO keuskupan (name, code) VALUES ($1, $2) RETURNING *`,
      [dto.name.trim(), dto.code?.trim() || null]
    );
    return { success: true, message: 'Keuskupan berhasil ditambahkan', data: res[0] };
  }
  async updateKeuskupan(id: number, dto: UpdateKeuskupanDto) {
    const existing = await this.dataSource.query('SELECT * FROM keuskupan WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Keuskupan tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const code = dto.code !== undefined ? dto.code.trim() : existing[0].code;
    const res = await this.dataSource.query(
      `UPDATE keuskupan SET name = $1, code = $2 WHERE id = $3 RETURNING *`,
      [name, code, id]
    );
    return { success: true, message: 'Keuskupan berhasil diperbarui', data: res[0] };
  }
  async deleteKeuskupan(id: number) {
    const parokiCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM paroki WHERE keuskupan_id = $1', [id]);
    if (parokiCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Keuskupan ini karena masih terhubung dengan ${parokiCount[0].count} Paroki.`);
    }
    await this.dataSource.query('DELETE FROM keuskupan WHERE id = $1', [id]);
    return { success: true, message: 'Keuskupan berhasil dihapus' };
  }

  // 2. PAROKI
  async getAllParoki(keuskupanId?: number) {
    let query = `
      SELECT p.id, p.keuskupan_id, p.name, p.address, p.created_at,
        k.name as keuskupan_name,
        COUNT(DISTINCT w.id)::int as total_wilayah
      FROM paroki p
      LEFT JOIN keuskupan k ON k.id = p.keuskupan_id
      LEFT JOIN wilayah w ON w.paroki_id = p.id
    `;
    const params: any[] = [];
    if (keuskupanId) {
      query += ` WHERE p.keuskupan_id = $1`;
      params.push(keuskupanId);
    }
    query += ` GROUP BY p.id, k.name ORDER BY p.id ASC`;
    return await this.dataSource.query(query, params);
  }
  async createParoki(dto: CreateParokiDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Paroki tidak boleh kosong');
    if (!dto.keuskupanId) throw new BadRequestException('Keuskupan wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO paroki (keuskupan_id, name, address) VALUES ($1, $2, $3) RETURNING *`,
      [dto.keuskupanId, dto.name.trim(), dto.address?.trim() || null]
    );
    return { success: true, message: 'Paroki berhasil ditambahkan', data: res[0] };
  }
  async updateParoki(id: number, dto: UpdateParokiDto) {
    const existing = await this.dataSource.query('SELECT * FROM paroki WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Paroki tidak ditemukan');
    const keuskupanId = dto.keuskupanId !== undefined ? dto.keuskupanId : existing[0].keuskupan_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const address = dto.address !== undefined ? dto.address.trim() : existing[0].address;
    const res = await this.dataSource.query(
      `UPDATE paroki SET keuskupan_id = $1, name = $2, address = $3 WHERE id = $4 RETURNING *`,
      [keuskupanId, name, address, id]
    );
    return { success: true, message: 'Paroki berhasil diperbarui', data: res[0] };
  }
  async deleteParoki(id: number) {
    const wilayahCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM wilayah WHERE paroki_id = $1', [id]);
    if (wilayahCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Paroki ini karena masih terhubung dengan ${wilayahCount[0].count} Wilayah aktif.`);
    }
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM user_profiles WHERE paroki_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Paroki ini karena digunakan oleh ${userCount[0].count} profil pengguna.`);
    }
    await this.dataSource.query('DELETE FROM paroki WHERE id = $1', [id]);
    return { success: true, message: 'Paroki berhasil dihapus' };
  }

  // 3. WILAYAH
  async getAllWilayah(parokiId?: number) {
    let query = `
      SELECT w.id, w.paroki_id, w.name, w.created_at,
        p.name as paroki_name,
        k.name as keuskupan_name,
        COUNT(DISTINCT l.id)::int as total_lingkungan
      FROM wilayah w
      LEFT JOIN paroki p ON p.id = w.paroki_id
      LEFT JOIN keuskupan k ON k.id = p.keuskupan_id
      LEFT JOIN lingkungan l ON l.wilayah_id = w.id
    `;
    const params: any[] = [];
    if (parokiId) {
      query += ` WHERE w.paroki_id = $1`;
      params.push(parokiId);
    }
    query += ` GROUP BY w.id, p.name, k.name ORDER BY w.id ASC`;
    return await this.dataSource.query(query, params);
  }
  async createWilayah(dto: CreateWilayahDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Wilayah tidak boleh kosong');
    if (!dto.parokiId) throw new BadRequestException('Paroki wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO wilayah (paroki_id, name) VALUES ($1, $2) RETURNING *`,
      [dto.parokiId, dto.name.trim()]
    );
    return { success: true, message: 'Wilayah berhasil ditambahkan', data: res[0] };
  }
  async updateWilayah(id: number, dto: UpdateWilayahDto) {
    const existing = await this.dataSource.query('SELECT * FROM wilayah WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Wilayah tidak ditemukan');
    const parokiId = dto.parokiId !== undefined ? dto.parokiId : existing[0].paroki_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const res = await this.dataSource.query(
      `UPDATE wilayah SET paroki_id = $1, name = $2 WHERE id = $3 RETURNING *`,
      [parokiId, name, id]
    );
    return { success: true, message: 'Wilayah berhasil diperbarui', data: res[0] };
  }
  async deleteWilayah(id: number) {
    const lingCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM lingkungan WHERE wilayah_id = $1', [id]);
    if (lingCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Wilayah ini karena masih terhubung dengan ${lingCount[0].count} Lingkungan.`);
    }
    await this.dataSource.query('DELETE FROM wilayah WHERE id = $1', [id]);
    return { success: true, message: 'Wilayah berhasil dihapus' };
  }

  // 4. LINGKUNGAN
  async getAllLingkungan(wilayahId?: number) {
    let query = `
      SELECT l.id, l.wilayah_id, l.name, l.created_at,
        w.name as wilayah_name,
        p.name as paroki_name,
        COUNT(DISTINCT u.id)::int as total_umat
      FROM lingkungan l
      LEFT JOIN wilayah w ON w.id = l.wilayah_id
      LEFT JOIN paroki p ON p.id = w.paroki_id
      LEFT JOIN user_profiles u ON u.lingkungan_id = l.id
    `;
    const params: any[] = [];
    if (wilayahId) {
      query += ` WHERE l.wilayah_id = $1`;
      params.push(wilayahId);
    }
    query += ` GROUP BY l.id, w.name, p.name ORDER BY l.id ASC`;
    return await this.dataSource.query(query, params);
  }
  async createLingkungan(dto: CreateLingkunganDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Lingkungan tidak boleh kosong');
    if (!dto.wilayahId) throw new BadRequestException('Wilayah wajib dipilih');
    const res = await this.dataSource.query(
      `INSERT INTO lingkungan (wilayah_id, name) VALUES ($1, $2) RETURNING *`,
      [dto.wilayahId, dto.name.trim()]
    );
    return { success: true, message: 'Lingkungan berhasil ditambahkan', data: res[0] };
  }
  async updateLingkungan(id: number, dto: UpdateLingkunganDto) {
    const existing = await this.dataSource.query('SELECT * FROM lingkungan WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Lingkungan tidak ditemukan');
    const wilayahId = dto.wilayahId !== undefined ? dto.wilayahId : existing[0].wilayah_id;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const res = await this.dataSource.query(
      `UPDATE lingkungan SET wilayah_id = $1, name = $2 WHERE id = $3 RETURNING *`,
      [wilayahId, name, id]
    );
    return { success: true, message: 'Lingkungan berhasil diperbarui', data: res[0] };
  }
  async deleteLingkungan(id: number) {
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM user_profiles WHERE lingkungan_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Lingkungan ini karena masih digunakan oleh ${userCount[0].count} profil pengguna.`);
    }
    await this.dataSource.query('DELETE FROM lingkungan WHERE id = $1', [id]);
    return { success: true, message: 'Lingkungan berhasil dihapus' };
  }

  // 5. ORDO / KONGREGASI
  async getAllOrdo() {
    return await this.dataSource.query(`
      SELECT o.id, o.name, o.code, o.address, o.created_at,
        COUNT(DISTINCT r.id)::int as total_romo
      FROM ordo o
      LEFT JOIN romo_profiles r ON r.ordo_id = o.id
      GROUP BY o.id
      ORDER BY o.id ASC
    `);
  }
  async createOrdo(dto: CreateOrdoDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Ordo tidak boleh kosong');
    const res = await this.dataSource.query(
      `INSERT INTO ordo (name, code, address) VALUES ($1, $2, $3) RETURNING *`,
      [dto.name.trim(), dto.code?.trim() || null, dto.address?.trim() || null]
    );
    return { success: true, message: 'Ordo berhasil ditambahkan', data: res[0] };
  }
  async updateOrdo(id: number, dto: UpdateOrdoDto) {
    const existing = await this.dataSource.query('SELECT * FROM ordo WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Ordo tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const code = dto.code !== undefined ? dto.code.trim() : existing[0].code;
    const address = dto.address !== undefined ? dto.address.trim() : existing[0].address;
    const res = await this.dataSource.query(
      `UPDATE ordo SET name = $1, code = $2, address = $3 WHERE id = $4 RETURNING *`,
      [name, code, address, id]
    );
    return { success: true, message: 'Ordo berhasil diperbarui', data: res[0] };
  }
  async deleteOrdo(id: number) {
    const romoCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM romo_profiles WHERE ordo_id = $1', [id]);
    if (romoCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Ordo ini karena masih terhubung dengan ${romoCount[0].count} profil Romo.`);
    }
    await this.dataSource.query('DELETE FROM ordo WHERE id = $1', [id]);
    return { success: true, message: 'Ordo berhasil dihapus' };
  }

  // 6. SERVICE CATEGORIES (KATEGORI PELAYANAN / SAKRAMEN)
  async getAllServiceCategories() {
    return await this.dataSource.query(`
      SELECT sc.id, sc.name, sc.description, sc.is_urgent_by_default, sc.is_active,
        COUNT(DISTINCT o.id)::int as total_orders
      FROM service_categories sc
      LEFT JOIN orders o ON o.service_category_id = sc.id
      GROUP BY sc.id
      ORDER BY sc.id ASC
    `);
  }
  async createServiceCategory(dto: CreateServiceCategoryDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Kategori Pelayanan tidak boleh kosong');
    const res = await this.dataSource.query(
      `INSERT INTO service_categories (name, description, is_urgent_by_default, is_active)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [dto.name.trim(), dto.description?.trim() || null, dto.isUrgentByDefault ?? false, dto.isActive ?? true]
    );
    return { success: true, message: 'Kategori Pelayanan berhasil ditambahkan', data: res[0] };
  }
  async updateServiceCategory(id: number, dto: UpdateServiceCategoryDto) {
    const existing = await this.dataSource.query('SELECT * FROM service_categories WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Kategori Pelayanan tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    const description = dto.description !== undefined ? dto.description.trim() : existing[0].description;
    const isUrgent = dto.isUrgentByDefault !== undefined ? dto.isUrgentByDefault : existing[0].is_urgent_by_default;
    const isActive = dto.isActive !== undefined ? dto.isActive : existing[0].is_active;
    const res = await this.dataSource.query(
      `UPDATE service_categories SET name = $1, description = $2, is_urgent_by_default = $3, is_active = $4 WHERE id = $5 RETURNING *`,
      [name, description, isUrgent, isActive, id]
    );
    return { success: true, message: 'Kategori Pelayanan berhasil diperbarui', data: res[0] };
  }
  async deleteServiceCategory(id: number) {
    const orderCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM orders WHERE service_category_id = $1', [id]);
    if (orderCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Kategori Pelayanan ini karena terdapat ${orderCount[0].count} riwayat pelayanan aktif.`);
    }
    await this.dataSource.query('DELETE FROM service_categories WHERE id = $1', [id]);
    return { success: true, message: 'Kategori Pelayanan berhasil dihapus' };
  }

  // 7. ROLES (JENIS PENGGUNA / PERAN USER)
  async getAllRoles() {
    return await this.dataSource.query(`
      SELECT r.id, r.code, r.name,
        COUNT(DISTINCT u.id)::int as total_users
      FROM roles r
      LEFT JOIN auth_users u ON u.role_id = r.id
      GROUP BY r.id
      ORDER BY r.id ASC
    `);
  }
  async createRole(dto: CreateRoleDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Jenis Role tidak boleh kosong');
    if (!dto.code || !dto.code.trim()) throw new BadRequestException('Kode Role tidak boleh kosong');
    const code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
    const existing = await this.dataSource.query('SELECT id FROM roles WHERE code = $1', [code]);
    if (existing.length > 0) throw new BadRequestException(`Kode Role "${code}" sudah terdaftar`);
    const res = await this.dataSource.query(
      `INSERT INTO roles (code, name) VALUES ($1, $2) RETURNING *`,
      [code, dto.name.trim()]
    );
    return { success: true, message: 'Jenis Role berhasil ditambahkan', data: res[0] };
  }
  async updateRole(id: number, dto: UpdateRoleDto) {
    const existing = await this.dataSource.query('SELECT * FROM roles WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jenis Role tidak ditemukan');
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    let code = existing[0].code;
    if (dto.code !== undefined && dto.code.trim()) {
      code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
      const duplicate = await this.dataSource.query('SELECT id FROM roles WHERE code = $1 AND id != $2', [code, id]);
      if (duplicate.length > 0) throw new BadRequestException(`Kode Role "${code}" sudah digunakan oleh role lain`);
    }
    const res = await this.dataSource.query(
      `UPDATE roles SET name = $1, code = $2 WHERE id = $3 RETURNING *`,
      [name, code, id]
    );
    return { success: true, message: 'Jenis Role berhasil diperbarui', data: res[0] };
  }
  async deleteRole(id: number) {
    const userCount = await this.dataSource.query('SELECT COUNT(*)::int as count FROM auth_users WHERE role_id = $1', [id]);
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Jenis Role ini karena masih digunakan oleh ${userCount[0].count} pengguna.`);
    }
    await this.dataSource.query('DELETE FROM roles WHERE id = $1', [id]);
    return { success: true, message: 'Jenis Role berhasil dihapus' };
  }

  // 8. POSITIONS (JABATAN & STRUKTUR PENGURUS / ROMO)
  async getAllPositions(category?: string) {
    let query = `
      SELECT mp.id, mp.category, mp.code, mp.name, mp.is_lead, mp.created_at,
        COUNT(DISTINCT p.id)::int as total_pejabat
      FROM master_positions mp
      LEFT JOIN user_profiles p ON (p.pengurus_position = mp.name OR p.romo_position = mp.name)
    `;
    const params: any[] = [];
    if (category) {
      query += ` WHERE mp.category = $1`;
      params.push(category);
    }
    query += ` GROUP BY mp.id ORDER BY mp.id ASC`;
    return await this.dataSource.query(query, params);
  }
  async createPosition(dto: CreatePositionDto) {
    if (!dto.name || !dto.name.trim()) throw new BadRequestException('Nama Jabatan tidak boleh kosong');
    if (!dto.code || !dto.code.trim()) throw new BadRequestException('Kode Jabatan tidak boleh kosong');
    if (!dto.category) throw new BadRequestException('Kategori Jabatan wajib dipilih');
    const code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
    const existing = await this.dataSource.query('SELECT id FROM master_positions WHERE code = $1', [code]);
    if (existing.length > 0) throw new BadRequestException(`Kode Jabatan "${code}" sudah terdaftar`);
    const res = await this.dataSource.query(
      `INSERT INTO master_positions (category, code, name, is_lead) VALUES ($1, $2, $3, $4) RETURNING *`,
      [dto.category, code, dto.name.trim(), dto.isLead ?? false]
    );
    return { success: true, message: 'Jabatan berhasil ditambahkan', data: res[0] };
  }
  async updatePosition(id: number, dto: UpdatePositionDto) {
    const existing = await this.dataSource.query('SELECT * FROM master_positions WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jabatan tidak ditemukan');
    const category = dto.category !== undefined ? dto.category : existing[0].category;
    const name = dto.name !== undefined ? dto.name.trim() : existing[0].name;
    let code = existing[0].code;
    if (dto.code !== undefined && dto.code.trim()) {
      code = dto.code.trim().toUpperCase().replace(/\s+/g, '_');
      const duplicate = await this.dataSource.query('SELECT id FROM master_positions WHERE code = $1 AND id != $2', [code, id]);
      if (duplicate.length > 0) throw new BadRequestException(`Kode Jabatan "${code}" sudah digunakan`);
    }
    const isLead = dto.isLead !== undefined ? dto.isLead : existing[0].is_lead;
    const res = await this.dataSource.query(
      `UPDATE master_positions SET category = $1, code = $2, name = $3, is_lead = $4 WHERE id = $5 RETURNING *`,
      [category, code, name, isLead, id]
    );
    return { success: true, message: 'Jabatan berhasil diperbarui', data: res[0] };
  }
  async deletePosition(id: number) {
    const existing = await this.dataSource.query('SELECT * FROM master_positions WHERE id = $1', [id]);
    if (!existing.length) throw new BadRequestException('Jabatan tidak ditemukan');
    const posName = existing[0].name;
    const userCount = await this.dataSource.query(
      'SELECT COUNT(*)::int as count FROM user_profiles WHERE pengurus_position = $1 OR romo_position = $1',
      [posName]
    );
    if (userCount[0]?.count > 0) {
      throw new BadRequestException(`Tidak dapat menghapus Jabatan "${posName}" karena masih digunakan oleh ${userCount[0].count} pengguna.`);
    }
    await this.dataSource.query('DELETE FROM master_positions WHERE id = $1', [id]);
    return { success: true, message: 'Jabatan berhasil dihapus' };
  }
}
