import 'reflect-metadata';

// @nestjs/config hanya ESM; tes ini membaca metadata dekorator saja, jadi cukup stub impornya.
jest.mock('@nestjs/config', () => ({ ConfigService: class {}, ConfigModule: class {} }));

import { APP_GUARD } from '@nestjs/core';
import { PATH_METADATA, METHOD_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';
import { GLOBAL_GUARD_PROVIDERS } from './global-guards';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { AuthController } from '../../modules/auth/auth.controller';
import { MasterDataController } from '../../modules/master-data/master-data.controller';
import { GeoMasterDataController } from '../../modules/master-data/geo-master-data.controller';
import { ApkController } from '../../modules/apk/apk.controller';
import { NewsController } from '../../news.controller';
import { HealthController } from '../../health.controller';
import { OrdersController } from '../../modules/orders/orders.controller';
import { ChatController } from '../../modules/chat/chat.controller';
import { NotificationsController } from '../../modules/notifications/notifications.controller';
import { AssignmentsController } from '../../modules/assignments/assignments.controller';
import { ActivityLogsController } from '../../modules/activity-logs/activity-logs.controller';
import { ApprovalsController } from '../../modules/auth/approvals.controller';
import { ALLOW_INACTIVE_KEY } from '../decorators/allow-inactive.decorator';

const CONTROLLERS = [
  AuthController,
  MasterDataController,
  GeoMasterDataController,
  ApkController,
  NewsController,
  HealthController,
  OrdersController,
  ChatController,
  NotificationsController,
  AssignmentsController,
  ActivityLogsController,
  ApprovalsController,
];

function routesWith(metadataKey: string): string[] {
  const routes: string[] = [];
  for (const controller of CONTROLLERS) {
    const base = Reflect.getMetadata(PATH_METADATA, controller) as string;
    const classPublic = Reflect.getMetadata(metadataKey, controller) === true;
    for (const name of Object.getOwnPropertyNames(controller.prototype)) {
      const handler = controller.prototype[name];
      if (name === 'constructor' || typeof handler !== 'function') continue;
      const method = Reflect.getMetadata(METHOD_METADATA, handler);
      if (method === undefined) continue;
      if (!classPublic && Reflect.getMetadata(metadataKey, handler) !== true) continue;
      const sub = ((Reflect.getMetadata(PATH_METADATA, handler) as string) || '').replace(/^\/+$/, '');
      routes.push(`${RequestMethod[method]} /${base}${sub ? '/' + sub : ''}`);
    }
  }
  return routes.sort();
}

const publicRoutes = () => routesWith(IS_PUBLIC_KEY);
const inactiveAccountRoutes = () => routesWith(ALLOW_INACTIVE_KEY);

describe('akses publik API (kontrak keamanan)', () => {
  it('JwtAuthGuard dan RolesGuard terpasang global', () => {
    const globalGuards = GLOBAL_GUARD_PROVIDERS.filter((p) => p.provide === APP_GUARD).map((p) => p.useClass);
    expect(globalGuards).toEqual(expect.arrayContaining([JwtAuthGuard, RolesGuard]));
  });

  it('hanya endpoint ini yang boleh diakses tanpa login', () => {
    // Menambah endpoint publik baru wajib disengaja: perbarui daftar ini beserta alasannya di PR.
    expect(publicRoutes()).toEqual([
      'GET /auth/kabupaten-kota',
      'GET /auth/keuskupan',
      'GET /auth/lingkungan',
      'GET /auth/ordo',
      'GET /auth/paroki',
      'GET /auth/provinsi',
      'GET /auth/roles',
      'GET /auth/wilayah',
      'GET /health',
      'GET /master/keuskupan',
      'GET /master/kabupaten-kota',
      'GET /master/lingkungan',
      'GET /master/ordo',
      'GET /master/paroki',
      'GET /master/positions',
      'GET /master/provinsi',
      'GET /master/roles',
      'GET /master/service-categories',
      'GET /master/wilayah',
      'GET /news',
      'GET /news/:idOrSlug',
      'GET /news/categories',
      'GET /news/search-live',
      'GET /news/sources',
      'GET /public/apk',
      'POST /auth/admin/login',
      'POST /auth/forgot-password/request-otp',
      'POST /auth/forgot-password/reset',
      'POST /auth/forgot-password/verify-otp',
      'POST /auth/login',
      'POST /auth/register',
    ].sort());
  });

  it('hanya endpoint ini yang boleh dipakai akun belum disetujui / ditolak', () => {
    // Akun non-APPROVED ditolak di semua endpoint lain oleh JwtAuthGuard. Menambah daftar ini wajib disengaja.
    expect(inactiveAccountRoutes()).toEqual([
      'GET /auth/check-status',
      'GET /auth/profile/:userId',
      'GET /notifications',
      'POST /notifications/:id/read',
      'POST /notifications/read-all',
      'POST /notifications/register-device',
      'POST /notifications/unregister-device',
    ].sort());
  });
});
