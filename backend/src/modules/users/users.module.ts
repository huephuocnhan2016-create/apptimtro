import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { RoomsModule } from '../rooms/rooms.module';

@Module({
  imports: [AuthModule, RoomsModule],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
