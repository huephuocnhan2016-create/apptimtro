import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);
  private firebaseApp?: App;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async register(userId: string, token: string, platform?: string) {
    await this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform },
      update: { userId, platform },
    });
    return { registered: true };
  }

  async unregister(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({ where: { userId, token } });
    return { registered: false };
  }

  async sendToUser(
    userId: string,
    notification: { title: string; body: string },
    data: Record<string, string>,
  ): Promise<void> {
    const firebase = this.messaging();
    if (!firebase) return;
    const records = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { id: true, token: true },
    });
    if (!records.length) return;
    const response = await firebase.sendEachForMulticast({
      tokens: records.map(({ token }) => token),
      notification,
      data,
      android: {
        priority: 'high',
        notification: { channelId: 'calls', sound: 'default' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const invalidTokens = response.responses.flatMap((result, index) =>
      !result.success &&
      (result.error?.code === 'messaging/registration-token-not-registered' ||
        result.error?.code === 'messaging/invalid-registration-token')
        ? [records[index].id]
        : [],
    );
    if (invalidTokens.length) {
      await this.prisma.deviceToken.deleteMany({ where: { id: { in: invalidTokens } } });
    }
    if (response.failureCount > invalidTokens.length) {
      this.logger.warn(`FCM delivery failed for ${response.failureCount} device(s).`);
    }
  }

  private messaging() {
    const serviceAccount = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccount) {
      this.logger.warn('FCM is not configured; push delivery is disabled.');
      return null;
    }
    if (!this.firebaseApp) {
      const existing = getApps().find(({ name }) => name === 'trotot');
      if (existing) {
        this.firebaseApp = existing;
      } else {
        const credentials = JSON.parse(serviceAccount) as {
          project_id: string;
          client_email: string;
          private_key: string;
        };
        this.firebaseApp = initializeApp(
          {
            credential: cert({
              projectId: credentials.project_id,
              clientEmail: credentials.client_email,
              privateKey: credentials.private_key.replace(/\\n/g, '\n'),
            }),
          },
          'trotot',
        );
      }
    }
    return getMessaging(this.firebaseApp);
  }
}
