import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus, RoomStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';

const reviewIncludes = {
  student: { select: { fullName: true } },
};

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(roomId: string) {
    await this.visibleRoom(roomId);
    const reviews = await this.prisma.roomReview.findMany({
      where: { roomId },
      include: reviewIncludes,
      orderBy: { createdAt: 'desc' },
    });
    return reviews.map((review) => this.serialize(review));
  }

  async upsert(user: User, roomId: string, dto: CreateReviewDto) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can review a room.');
    }
    const room = await this.visibleRoom(roomId);
    // Only a settled deposit counts: a PENDING order is a checkout session
    // that may never have been paid, and reviews have to outlive that doubt.
    const deposit = await this.prisma.payment.findFirst({
      where: {
        studentId: user.id,
        roomId: room.id,
        status: PaymentStatus.PAID,
      },
      select: { id: true },
    });
    if (!deposit) {
      throw new ForbiddenException(
        'Bạn cần đặt cọc phòng này trước khi đánh giá.',
      );
    }
    const comment = dto.comment?.trim() || null;
    const review = await this.prisma.roomReview.upsert({
      where: {
        studentId_roomId: { studentId: user.id, roomId: room.id },
      },
      create: { studentId: user.id, roomId: room.id, rating: dto.rating, comment },
      update: { rating: dto.rating, comment },
      include: reviewIncludes,
    });
    return this.serialize(review);
  }

  private async visibleRoom(roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: {
        id: roomId,
        status: {
          in: [RoomStatus.AVAILABLE, RoomStatus.FULL, RoomStatus.DEPOSITED],
        },
      },
    });
    if (!room) throw new NotFoundException('Room not found.');
    return room;
  }

  private serialize(review: any) {
    const { student, ...rest } = review;
    return { ...rest, author: student?.fullName?.trim() || 'Sinh viên' };
  }
}
