import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { DeviceTokenDto } from './dto/device-token.dto';
import { NotificationService } from './notification.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationService) {}

  @Post('device-token')
  register(@CurrentUser() user: User, @Body() dto: DeviceTokenDto) {
    return this.notifications.register(user.id, dto.token, dto.platform);
  }

  @Delete('device-token')
  unregister(@CurrentUser() user: User, @Body() dto: DeviceTokenDto) {
    return this.notifications.unregister(user.id, dto.token);
  }
}
