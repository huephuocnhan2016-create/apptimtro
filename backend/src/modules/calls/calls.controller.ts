import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CreateCallDto } from './dto/create-call.dto';
import { CallsService } from './calls.service';

@ApiTags('Calls')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('calls')
export class CallsController {
  constructor(private readonly calls: CallsService) {}

  @Post()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  create(@CurrentUser() user: User, @Body() dto: CreateCallDto) {
    return this.calls.create(user, dto);
  }

  @Get()
  history(@CurrentUser() user: User) {
    return this.calls.history(user);
  }

  @Get(':id')
  get(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.get(user, id);
  }

  @Post(':id/accept')
  accept(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.accept(user, id);
  }

  @Post(':id/reject')
  reject(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.reject(user, id);
  }

  @Post(':id/end')
  end(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.end(user, id);
  }
}
