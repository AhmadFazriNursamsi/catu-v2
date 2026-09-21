import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { ActivityLogsService } from './activity-logs.service';

@Injectable()
export class ActivityLogInterceptor implements NestInterceptor {
  constructor(private readonly activityLogsService: ActivityLogsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const http = context.switchToHttp();
    const req = http.getRequest();
    const method = req.method?.toUpperCase();

    if (method === 'GET' || method === 'OPTIONS') {
      return next.handle();
    }

    const ip = String(req.ip || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '');
    const userAgent = String(req.get('user-agent') || 'Unknown');

    return next.handle().pipe(
      tap({
        next: (resData: any) => {
          this.handleAuthAndSession(req, resData, ip, userAgent);
          this.handleMasterData(req, resData, ip, userAgent);
          this.handleUserManagement(req, resData, ip, userAgent);
          this.handleOrders(req, resData, ip, userAgent);
        },
      }),
    );
  }

  private extractAdminActor(req: any) {
    try {
      const authHeader = req.headers?.authorization || req.headers?.Authorization;
      if (authHeader && typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
        const token = authHeader.split(' ')[1];
        const payloadBase64 = token.split('.')[1];
        if (payloadBase64) {
          const decoded = JSON.parse(Buffer.from(payloadBase64, 'base64').toString('utf-8'));
          return {
            userId: decoded.sub ? Number(decoded.sub) : 7,
            userName: decoded.fullName || decoded.name || 'Super Admin CATU',
            userRole: decoded.roleCode || decoded.role || 'ADMIN',
          };
        }
      }
    } catch (_) {}
    return {
      userId: 7,
      userName: 'Administrator CATU',
      userRole: 'ADMIN',
    };
  }

  private handleAuthAndSession(req: any, resData: any, ip: string, userAgent: string) {
    const url: string = req.originalUrl || req.url || '';
    const body = req.body || {};

    if (url.includes('/auth/admin/logout')) {
      const admin = this.extractAdminActor(req);
      const name = body.fullName || admin.userName || 'Administrator';
      this.activityLogsService.log({
        ...admin,
        userName: name,
        action: 'LOGOUT_ADMIN',
        targetEntity: 'AUTH',
        targetId: admin.userId ? String(admin.userId) : null,
        description: `Admin ${name} keluar dari Web Portal`,
        ipAddress: ip,
        userAgent,
      });
      return;
    }

    if (url.includes('/auth/admin/login')) {
      const user = resData?.user || {};
      this.activityLogsService.log({
        userId: user.id || null,
        userName: user.fullName || 'Administrator',
        userRole: 'ADMIN',
        action: 'LOGIN_ADMIN',
        targetEntity: 'AUTH',
        targetId: user.id ? String(user.id) : null,
        description: `Admin ${user.fullName || 'Administrator'} berhasil login ke Web Portal`,
        ipAddress: ip,
        userAgent,
      });
      return;
    }

    if (url.includes('/auth/login')) {
      const user = resData?.user || {};
      this.activityLogsService.log({
        userId: user.id || null,
        userName: user.fullName || body.phoneNumber,
        userRole: user.roleCode || 'USER',
        action: 'LOGIN_MOBILE',
        targetEntity: 'AUTH',
        targetId: user.id ? String(user.id) : null,
        description: `${user.roleCode || 'User'} ${user.fullName || ''} berhasil login via Mobile App`,
        ipAddress: ip,
        userAgent,
      });
      return;
    }
  }

  private handleMasterData(req: any, resData: any, ip: string, userAgent: string) {
    const url: string = req.originalUrl || req.url || '';
    if (!url.includes('/master/')) return;

    const method = req.method?.toUpperCase();
    const body = req.body || {};
    const admin = this.extractAdminActor(req);
    const parts = url.split('?')[0].split('/');
    const lastPart = parts[parts.length - 1];
    const targetId = !isNaN(Number(lastPart)) ? lastPart : (resData?.id ? String(resData.id) : null);

    if (url.includes('/master/paroki')) {
      const desc = method === 'POST'
        ? `Admin menambahkan Paroki baru "${body.name || ''}"`
        : method === 'PUT'
          ? `Admin memperbarui data Paroki "${body.name || ''}" (#${targetId})`
          : `Admin menghapus Paroki (#${targetId})`;
      const action = method === 'POST' ? 'MASTER_PAROKI_CREATED' : method === 'PUT' ? 'MASTER_PAROKI_UPDATED' : 'MASTER_PAROKI_DELETED';
      this.activityLogsService.log({ ...admin, action, targetEntity: 'PAROKI', targetId, description: desc, ipAddress: ip, userAgent, metadata: body });
      return;
    }

    if (url.includes('/master/wilayah')) {
      const desc = method === 'POST'
        ? `Admin menambahkan Wilayah baru "${body.name || ''}"`
        : method === 'PUT'
          ? `Admin memperbarui data Wilayah "${body.name || ''}" (#${targetId})`
          : `Admin menghapus Wilayah (#${targetId})`;
      const action = method === 'POST' ? 'MASTER_WILAYAH_CREATED' : method === 'PUT' ? 'MASTER_WILAYAH_UPDATED' : 'MASTER_WILAYAH_DELETED';
      this.activityLogsService.log({ ...admin, action, targetEntity: 'WILAYAH', targetId, description: desc, ipAddress: ip, userAgent, metadata: body });
      return;
    }

    if (url.includes('/master/lingkungan')) {
      const desc = method === 'POST'
        ? `Admin menambahkan Lingkungan baru "${body.name || ''}"`
        : method === 'PUT'
          ? `Admin memperbarui data Lingkungan "${body.name || ''}" (#${targetId})`
          : `Admin menghapus Lingkungan (#${targetId})`;
      const action = method === 'POST' ? 'MASTER_LINGKUNGAN_CREATED' : method === 'PUT' ? 'MASTER_LINGKUNGAN_UPDATED' : 'MASTER_LINGKUNGAN_DELETED';
      this.activityLogsService.log({ ...admin, action, targetEntity: 'LINGKUNGAN', targetId, description: desc, ipAddress: ip, userAgent, metadata: body });
      return;
    }

    if (url.includes('/master/service-categories')) {
      const desc = method === 'POST'
        ? `Admin menambahkan Kategori/Layanan Sakramen baru "${body.name || ''}"`
        : method === 'PUT'
          ? `Admin memperbarui data Kategori/Layanan Sakramen "${body.name || ''}" (#${targetId})`
          : `Admin menghapus Kategori/Layanan Sakramen (#${targetId})`;
      const action = method === 'POST' ? 'MASTER_SERVICE_CREATED' : method === 'PUT' ? 'MASTER_SERVICE_UPDATED' : 'MASTER_SERVICE_DELETED';
      this.activityLogsService.log({ ...admin, action, targetEntity: 'SERVICE_CATEGORIES', targetId, description: desc, ipAddress: ip, userAgent, metadata: body });
      return;
    }
  }

  private handleUserManagement(req: any, _resData: any, ip: string, userAgent: string) {
    const url: string = req.originalUrl || req.url || '';
    const body = req.body || {};
    const admin = this.extractAdminActor(req);

    if (url.includes('/auth/approvals') || url.includes('/auth/approve-registration')) {
      const isApproved = body.action === 'APPROVED';
      const targetUserId = body.targetUserId || req.params?.userId;
      this.activityLogsService.log({
        ...admin,
        action: isApproved ? 'USER_APPROVED' : 'USER_REJECTED',
        targetEntity: 'AUTH_USERS',
        targetId: targetUserId ? String(targetUserId) : null,
        description: `Admin telah ${isApproved ? 'menyetujui' : 'menolak'} pendaftaran akun user ID: ${targetUserId}`,
        ipAddress: ip,
        userAgent,
        metadata: { action: body.action, reason: body.rejectionReason },
      });
      return;
    }

    if (url.includes('/auth/admin/users/') && url.includes('/status')) {
      const parts = url.split('?')[0].split('/');
      const userId = parts[parts.indexOf('users') + 1] || req.params?.userId;
      const isDeactivated = body.status === 'INACTIVE' || body.status === 'SUSPENDED' || body.status === 'REJECTED';
      this.activityLogsService.log({
        ...admin,
        action: isDeactivated ? 'USER_DEACTIVATED' : 'USER_STATUS_UPDATED',
        targetEntity: 'AUTH_USERS',
        targetId: userId ? String(userId) : null,
        description: isDeactivated
          ? `Admin menonaktifkan akun pengguna #${userId} (${body.status})`
          : `Admin memperbarui status akun pengguna #${userId} menjadi ${body.status}`,
        ipAddress: ip,
        userAgent,
        metadata: body,
      });
      return;
    }

    if (url.includes('/auth/admin/users/') && url.includes('/role')) {
      const parts = url.split('?')[0].split('/');
      const userId = parts[parts.indexOf('users') + 1] || req.params?.userId;
      this.activityLogsService.log({
        ...admin,
        action: 'USER_ROLE_CHANGED',
        targetEntity: 'AUTH_USERS',
        targetId: userId ? String(userId) : null,
        description: `Admin mengubah role akun pengguna #${userId} menjadi ${body.roleCode}`,
        ipAddress: ip,
        userAgent,
        metadata: { roleCode: body.roleCode },
      });
      return;
    }

    if (url.includes('/auth/profile/')) {
      const parts = url.split('?')[0].split('/');
      const userId = parts[parts.indexOf('profile') + 1] || req.params?.userId;
      const isDeactivated = body.accountStatus === 'INACTIVE' || body.accountStatus === 'SUSPENDED';
      const action = isDeactivated ? 'USER_DEACTIVATED' : 'USER_PROFILE_UPDATED';
      const description = isDeactivated
        ? `Admin menonaktifkan akun jemaat #${userId} (${body.fullName || ''})`
        : `Admin memperbarui data profil jemaat #${userId} (${body.fullName || ''}) [Role: ${body.roleCode || '-'}]`;

      this.activityLogsService.log({
        ...admin,
        action,
        targetEntity: 'AUTH_USERS',
        targetId: userId ? String(userId) : null,
        description,
        ipAddress: ip,
        userAgent,
        metadata: { fullName: body.fullName, roleCode: body.roleCode, accountStatus: body.accountStatus },
      });
      return;
    }
  }

  private handleOrders(req: any, resData: any, ip: string, userAgent: string) {
    const url: string = req.originalUrl || req.url || '';
    const body = req.body || {};

    if (url.endsWith('/orders') && req.method === 'POST') {
      const order = resData?.order || {};
      this.activityLogsService.log({
        userId: order.user_id || body.userId || null,
        userRole: 'UMAT',
        action: 'ORDER_CREATED',
        targetEntity: 'ORDERS',
        targetId: order.order_number || order.id,
        description: `Permohonan pelayanan baru dibuat #${order.order_number || order.id || ''}`,
        ipAddress: ip,
        userAgent,
        metadata: { orderId: order.id, orderNumber: order.order_number },
      });
      return;
    }

    if (url.includes('/orders') && url.includes('/status')) {
      const parts = url.split('?')[0].split('/');
      const orderId = parts[parts.indexOf('orders') + 1] || req.params?.id;
      const admin = this.extractAdminActor(req);
      this.activityLogsService.log({
        ...admin,
        action: 'ORDER_STATUS_UPDATE',
        targetEntity: 'ORDERS',
        targetId: orderId,
        description: `Admin mengubah status pesanan #${orderId} menjadi ${body.status}`,
        ipAddress: ip,
        userAgent,
        metadata: { orderId, status: body.status },
      });
      return;
    }
  }
}
