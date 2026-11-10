import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CreateReviewDto } from './dto/create-review.dto';
import { ReviewsService } from './reviews.service';

@ApiTags('Reviews')
@Controller('rooms/:roomId/reviews')
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get()
  @ApiOperation({ summary: 'Đánh giá của sinh viên đã cọc cho một phòng' })
  list(@Param('roomId', ParseUUIDPipe) roomId: string) {
    return this.reviews.list(roomId);
  }

  @Post()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Gửi hoặc sửa đánh giá của chính mình cho phòng' })
  upsert(
    @CurrentUser() user: User,
    @Param('roomId', ParseUUIDPipe) roomId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reviews.upsert(user, roomId, dto);
  }
}
