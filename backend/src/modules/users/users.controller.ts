import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { UsersService } from './users.service';
import { RoomsService } from '../rooms/rooms.service';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly rooms: RoomsService,
  ) {}

  @Get('me')
  @ApiOperation({ summary: 'Get the current user profile' })
  getMe(@CurrentUser() user: User) {
    return this.users.getMe(user.id);
  }

  @Get('me/favorites')
  @ApiOperation({ summary: 'List favorite rooms for the authenticated user' })
  favorites(@CurrentUser() user: User) {
    return this.rooms.favorites(user);
  }
}
