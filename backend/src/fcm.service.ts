import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

export interface PushNotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private isFirebaseInitialized = false;

  constructor(@InjectDataSource() private dataSource: DataSource) {}

  onModuleInit() {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      if (admin.apps.length > 0) {
        this.isFirebaseInitialized = true;
        this.logger.log('Firebase Admin SDK already initialized.');
        return;
      }

      // Check for serviceAccountKey file paths
      const possiblePaths = [
        process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
        path.join(process.cwd(), 'firebase-service-account.json'),
        path.join(process.cwd(), 'config', 'firebase-service-account.json'),
        '/etc/catu/firebase-service-account.json',
      ].filter(Boolean) as string[];

      let serviceAccount: any = null;

      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          try {
            const raw = fs.readFileSync(p, 'utf8');
            serviceAccount = JSON.parse(raw);
            this.logger.log(`Found Firebase service account file at: ${p}`);
            break;
          } catch (e) {
            this.logger.warn(`Failed reading Firebase JSON at ${p}: ${e.message}`);
          }
        }
      }

      // Or parse from env JSON string
      if (!serviceAccount && process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        try {
          serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
          this.logger.log('Parsed Firebase service account from environment variable.');
        } catch (e) {
          this.logger.warn(`Failed parsing FIREBASE_SERVICE_ACCOUNT_JSON: ${e.message}`);
        }
      }

      if (serviceAccount) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
        this.isFirebaseInitialized = true;
        this.logger.log('🔥 Firebase Cloud Messaging (FCM) Admin SDK successfully initialized!');
      } else {
        this.logger.warn(
          '⚠️ Firebase service account not found. FCM push notifications will run in simulation mode. ' +
          'Place firebase-service-account.json in backend root to enable live cloud delivery.',
        );
      }
    } catch (error) {
      this.logger.error(`Error initializing Firebase: ${error.message}`);
    }
  }

  /**
   * Register or update user device FCM token
   */
  async registerDeviceToken(
    userId: number,
    fcmToken: string,
    deviceType: string = 'ANDROID',
    deviceModel?: string,
  ): Promise<any> {
    try {
      let normalizedType = deviceType.toUpperCase();
      if (!['ANDROID', 'IOS', 'WEB'].includes(normalizedType)) {
        normalizedType = 'ANDROID';
      }

      await this.dataSource.query(
        `INSERT INTO user_devices (user_id, fcm_token, device_type, device_model, last_active_at)
         VALUES ($1, $2, $3::device_type_enum, $4, CURRENT_TIMESTAMP)
         ON CONFLICT (user_id, fcm_token)
         DO UPDATE SET device_type = $3::device_type_enum, device_model = $4, last_active_at = CURRENT_TIMESTAMP`,
        [userId, fcmToken, normalizedType, deviceModel || null],
      );

      this.logger.log(`Registered device token for user ${userId} [${normalizedType}]`);
      return { success: true, message: 'Device token registered successfully' };
    } catch (error) {
      this.logger.error(`Failed to register device token for user ${userId}: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * Unregister / remove device FCM token (e.g. on logout)
   */
  async unregisterDeviceToken(userId: number, fcmToken: string): Promise<any> {
    try {
      await this.dataSource.query(
        `DELETE FROM user_devices WHERE user_id = $1 AND fcm_token = $2`,
        [userId, fcmToken],
      );
      this.logger.log(`Unregistered device token for user ${userId}`);
      return { success: true, message: 'Device token unregistered' };
    } catch (error) {
      this.logger.error(`Failed to unregister device token: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * Send Push Notification to one or multiple users
   */
  async sendPushToUsers(
    userIds: number | number[],
    payload: PushNotificationPayload,
  ): Promise<{ sent: number; failed: number }> {
    const targetUserIds = Array.isArray(userIds) ? userIds : [userIds];
    if (targetUserIds.length === 0) return { sent: 0, failed: 0 };

    try {
      // 1. Fetch active FCM tokens for the given users
      const rows = await this.dataSource.query(
        `SELECT id, user_id, fcm_token, device_type 
         FROM user_devices 
         WHERE user_id = ANY($1::int[]) AND fcm_token IS NOT NULL AND fcm_token != ''`,
        [targetUserIds],
      );

      if (!rows || rows.length === 0) {
        this.logger.debug(`No device tokens registered for users: ${targetUserIds.join(', ')}`);
        return { sent: 0, failed: 0 };
      }

      const tokens: string[] = rows.map((r: any) => r.fcm_token);
      this.logger.log(`Sending FCM Push to ${tokens.length} devices for users: ${targetUserIds.join(', ')}`);

      // 2. If Firebase live is not configured, log simulation
      if (!this.isFirebaseInitialized) {
        this.logger.log(`[FCM SIMULATION] Title: "${payload.title}" | Body: "${payload.body}" | Tokens: ${tokens.length}`);
        return { sent: tokens.length, failed: 0 };
      }

      // 3. Send using Firebase Admin SDK
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
        android: {
          priority: 'high',
          notification: {
            icon: 'ic_stat_catu',
            color: '#1E5399',
            sound: 'notif_catu',
            channelId: 'catu_custom_sound_channel_v1',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            defaultSound: false,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notif_catu.caf',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      let sentCount = response.successCount;
      let failCount = response.failureCount;

      // 4. Prune invalid tokens if any failed
      if (response.failureCount > 0) {
        const tokensToDelete: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === 'messaging/registration-token-not-registered' ||
              errCode === 'messaging/invalid-registration-token'
            ) {
              tokensToDelete.push(tokens[idx]);
            }
          }
        });

        if (tokensToDelete.length > 0) {
          await this.dataSource.query(
            `DELETE FROM user_devices WHERE fcm_token = ANY($1::text[])`,
            [tokensToDelete],
          );
          this.logger.log(`Pruned ${tokensToDelete.length} stale FCM tokens.`);
        }
      }

      return { sent: sentCount, failed: failCount };
    } catch (error) {
      this.logger.error(`Error sending push notifications: ${error.message}`);
      return { sent: 0, failed: targetUserIds.length };
    }
  }
}
