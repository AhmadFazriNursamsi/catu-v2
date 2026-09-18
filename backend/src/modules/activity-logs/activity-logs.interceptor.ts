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
          this.handleSuccess(req, resData, ip, userAgent);
        },
      }),
    );
  }

  private handleSuccess(req: any, resData: any, ip: string, userAgent: string) {
    const url: string = req.originalUrl || req.url || '';
    const body = req.body || {};

    if (url.includes('/auth/admin/login')) {
      const user = resData?.user || {};
      this.activityLogsService.log({
        userId: user.id || null,
        userName: user.fullName || 'Administrator',
        userRole: 'ADMIN',
        action: 'LOGIN_ADMIN',
        targetEntity: 'AUTH',
        targetId: user.id,
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
        targetId: user.id,
        description: `${user.roleCode || 'User'} ${user.fullName || ''} berhasil login via Mobile App`,
        ipAddress: ip,
        userAgent,
      });
      return;
    }

    if (url.includes('/auth/approvals')) {
      this.activityLogsService.log({
        userId: 7,
        userName: 'Administrator CATU',
        userRole: 'ADMIN',
        action: body.action === 'APPROVED' ? 'USER_APPROVED' : 'USER_REJECTED',
        targetEntity: 'AUTH_USERS',
        targetId: body.targetUserId,
        description: `Admin telah ${body.action === 'APPROVED' ? 'menyetujui' : 'menolak'} akun user ID: ${body.targetUserId}`,
        ipAddress: ip,
        userAgent,
        metadata: { action: body.action, reason: body.rejectionReason },
      });
      return;
    }

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
      this.activityLogsService.log({
        userId: 7,
        userName: 'Administrator CATU',
        userRole: 'ADMIN',
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
