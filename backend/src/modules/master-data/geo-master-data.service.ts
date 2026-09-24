import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  CreateProvinsiDto,
  UpdateProvinsiDto,
  CreateKabupatenKotaDto,
  UpdateKabupatenKotaDto,
} from './geo-master-data.dto';

@Injectable()
export class GeoMasterDataService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  // ── PROVINSI CRUD ──
  async getAllProvinsi() {
    return await this.dataSource.query(`
      SELECT p.id, p.name,
        COUNT(DISTINCT kk.id)::int as total_kabupaten_kota
      FROM provinsi p
      LEFT JOIN kabupaten_kota kk ON kk.provinsi_id = p.id
      GROUP BY p.id
      ORDER BY p.name ASC
    `);
  }

  async createProvinsi(dto: CreateProvinsiDto) {
    const trimmedName = dto.name?.trim().toUpperCase();
    if (!trimmedName) throw new BadRequestException('Nama Provinsi tidak boleh kosong');

    const existing = await this.dataSource.query(
      'SELECT id FROM provinsi WHERE UPPER(name) = $1',
      [trimmedName],
    );
    if (existing.length > 0) {
      throw new BadRequestException(`Provinsi "${trimmedName}" sudah terdaftar.`);
    }

    const res = await this.dataSource.query(
      'INSERT INTO provinsi (name) VALUES ($1) RETURNING *',
      [trimmedName],
    );
    return { success: true, message: 'Provinsi berhasil ditambahkan', data: res[0] };
  }

  async updateProvinsi(id: number, dto: UpdateProvinsiDto) {
    const existing = await this.dataSource.query('SELECT * FROM provinsi WHERE id = $1', [id]);
    if (!existing.length) throw new NotFoundException('Provinsi tidak ditemukan');

    const name = dto.name !== undefined ? dto.name.trim().toUpperCase() : existing[0].name;
    if (!name) throw new BadRequestException('Nama Provinsi tidak boleh kosong');

    const res = await this.dataSource.query(
      'UPDATE provinsi SET name = $1 WHERE id = $2 RETURNING *',
      [name, id],
    );
    return { success: true, message: 'Provinsi berhasil diperbarui', data: res[0] };
  }

  async deleteProvinsi(id: number) {
    const countRes = await this.dataSource.query(
      'SELECT COUNT(*)::int as count FROM kabupaten_kota WHERE provinsi_id = $1',
      [id],
    );
    if (countRes[0]?.count > 0) {
      throw new BadRequestException(
        `Tidak dapat menghapus Provinsi ini karena masih memiliki ${countRes[0].count} Kabupaten/Kota terkait.`,
      );
    }
    await this.dataSource.query('DELETE FROM provinsi WHERE id = $1', [id]);
    return { success: true, message: 'Provinsi berhasil dihapus' };
  }

  // ── KABUPATEN / KOTA CRUD ──
  async getAllKabupatenKota(provinsiId?: number) {
    let query = `
      SELECT kk.id, kk.provinsi_id, kk.name, kk.type,
        p.name as provinsi_name,
        COUNT(DISTINCT u.id)::int as total_umat
      FROM kabupaten_kota kk
      LEFT JOIN provinsi p ON p.id = kk.provinsi_id
      LEFT JOIN user_profiles u ON u.kabupaten_kota_id = kk.id
    `;
    const params: unknown[] = [];
    if (provinsiId) {
      query += ' WHERE kk.provinsi_id = $1';
      params.push(provinsiId);
    }
    query += ' GROUP BY kk.id, p.name ORDER BY p.name ASC, kk.name ASC';
    return await this.dataSource.query(query, params);
  }

  async createKabupatenKota(dto: CreateKabupatenKotaDto) {
    const trimmedName = dto.name?.trim().toUpperCase();
    if (!trimmedName) throw new BadRequestException('Nama Kabupaten/Kota tidak boleh kosong');
    if (!dto.provinsiId) throw new BadRequestException('Provinsi wajib dipilih');

    const prov = await this.dataSource.query('SELECT id FROM provinsi WHERE id = $1', [dto.provinsiId]);
    if (!prov.length) throw new BadRequestException('Provinsi tidak valid atau tidak ditemukan');

    const type = dto.type ? dto.type.toUpperCase() : 'KOTA';

    const res = await this.dataSource.query(
      'INSERT INTO kabupaten_kota (provinsi_id, name, type) VALUES ($1, $2, $3) RETURNING *',
      [dto.provinsiId, trimmedName, type],
    );
    return { success: true, message: 'Kabupaten/Kota berhasil ditambahkan', data: res[0] };
  }

  async updateKabupatenKota(id: number, dto: UpdateKabupatenKotaDto) {
    const existing = await this.dataSource.query('SELECT * FROM kabupaten_kota WHERE id = $1', [id]);
    if (!existing.length) throw new NotFoundException('Kabupaten/Kota tidak ditemukan');

    const provinsiId = dto.provinsiId !== undefined ? dto.provinsiId : existing[0].provinsi_id;
    const name = dto.name !== undefined ? dto.name.trim().toUpperCase() : existing[0].name;
    const type = dto.type !== undefined ? dto.type.toUpperCase() : existing[0].type;

    if (dto.provinsiId) {
      const prov = await this.dataSource.query('SELECT id FROM provinsi WHERE id = $1', [dto.provinsiId]);
      if (!prov.length) throw new BadRequestException('Provinsi tidak valid atau tidak ditemukan');
    }

    const res = await this.dataSource.query(
      'UPDATE kabupaten_kota SET provinsi_id = $1, name = $2, type = $3 WHERE id = $4 RETURNING *',
      [provinsiId, name, type, id],
    );
    return { success: true, message: 'Kabupaten/Kota berhasil diperbarui', data: res[0] };
  }

  async deleteKabupatenKota(id: number) {
    const userCount = await this.dataSource.query(
      'SELECT COUNT(*)::int as count FROM user_profiles WHERE kabupaten_kota_id = $1',
      [id],
    );
    const orderCount = await this.dataSource.query(
      'SELECT COUNT(*)::int as count FROM orders WHERE kabupaten_kota_id = $1',
      [id],
    );
    const total = (userCount[0]?.count || 0) + (orderCount[0]?.count || 0);
    if (total > 0) {
      throw new BadRequestException(
        `Tidak dapat menghapus Kabupaten/Kota ini karena masih digunakan oleh ${total} data Umat/Pelayanan.`,
      );
    }
    await this.dataSource.query('DELETE FROM kabupaten_kota WHERE id = $1', [id]);
    return { success: true, message: 'Kabupaten/Kota berhasil dihapus' };
  }
}
