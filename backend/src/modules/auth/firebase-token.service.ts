import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

@Injectable()
export class FirebaseTokenService {
  constructor(private configService: ConfigService) {
    if (!getApps().length) {
      initializeApp({
        credential: cert({
          projectId: this.configService.get<string>('FIREBASE_PROJECT_ID')!,
          clientEmail: this.configService.get<string>('FIREBASE_CLIENT_EMAIL')!,
          privateKey: this.configService
            .get<string>('FIREBASE_PRIVATE_KEY')!
            .replace(/\\n/g, '\n'),
        }),
      });
    }
  }

  async createCustomToken(userId: string, role: string): Promise<string> {
    return getAuth().createCustomToken(userId, { role });
  }
}