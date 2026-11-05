import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RolesGuard } from '../../common/guards/roles.guard';
import { RoomViewThrottleGuard } from '../../common/guards/room-view-throttle.guard';
import { RoomsController } from './rooms.controller';
import { GeocodingService } from './geocoding.service';
import { RoomsService } from './rooms.service';
import { LocalStorageService, STORAGE_SERVICE } from './storage.service';

@Module({
  imports: [AuthModule],
  controllers: [RoomsController],
  providers: [
    RoomsService,
    GeocodingService,
    RolesGuard,
    RoomViewThrottleGuard,
    LocalStorageService,
    { provide: STORAGE_SERVICE, useExisting: LocalStorageService },
  ],
  exports: [RoomsService],
})
export class RoomsModule {}
