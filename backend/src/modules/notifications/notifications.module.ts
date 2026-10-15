import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationService } from './notification.service';
import { NotificationsController } from './notifications.controller';

@Module({
  imports: [AuthModule],
  controllers: [NotificationsController],
  providers: [NotificationService],
  exports: [NotificationService],
})
export class NotificationsModule {}
