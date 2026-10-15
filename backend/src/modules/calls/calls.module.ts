import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CallsController } from './calls.controller';
import { CallsService } from './calls.service';

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [CallsController],
  providers: [CallsService],
})
export class CallsModule {}
