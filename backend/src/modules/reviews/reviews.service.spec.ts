import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PaymentStatus, RoomStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { ReviewsService } from './reviews.service';

const uuid = '11111111-1111-4111-8111-111111111111';
const student = { id: uuid, role: UserRole.STUDENT } as User;
const landlord = { id: '22222222-2222-4222-8222-222222222222', role: UserRole.LANDLORD } as User;
const room = { id: uuid, landlordId: landlord.id, status: RoomStatus.DEPOSITED };

describe('ReviewsService', () => {
  const prisma = {
    room: { findFirst: jest.fn() },
    payment: { findFirst: jest.fn() },
    roomReview: { findMany: jest.fn(), upsert: jest.fn() },
  };
  const service = new ReviewsService(prisma as unknown as PrismaService);

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.room.findFirst.mockResolvedValue(room);
  });

  it('refuses a review from an account that is not a student', async () => {
    await expect(
      service.upsert(landlord, room.id, { rating: 5 }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.roomReview.upsert).not.toHaveBeenCalled();
  });

  it('refuses a review until the deposit is actually paid', async () => {
    prisma.payment.findFirst.mockResolvedValue(null);

    await expect(
      service.upsert(student, room.id, { rating: 4, comment: ' ổn ' }),
    ).rejects.toThrow('Bạn cần đặt cọc phòng này trước khi đánh giá.');

    expect(prisma.payment.findFirst).toHaveBeenCalledWith({
      where: { studentId: student.id, roomId: room.id, status: PaymentStatus.PAID },
      select: { id: true },
    });
    expect(prisma.roomReview.upsert).not.toHaveBeenCalled();
  });

  it('writes one review per student and edits it on the next post', async () => {
    prisma.payment.findFirst.mockResolvedValue({ id: 'paid-order' });
    prisma.roomReview.upsert.mockResolvedValue({
      id: 'review-id',
      roomId: room.id,
      studentId: student.id,
      rating: 4,
      comment: 'yên tĩnh',
      createdAt: new Date(0),
      updatedAt: new Date(0),
      student: { fullName: 'Nguyen Van A' },
    });

    await service.upsert(student, room.id, { rating: 4, comment: 'yên tĩnh' });

    expect(prisma.roomReview.upsert.mock.calls[0][0]).toEqual({
      where: { studentId_roomId: { studentId: student.id, roomId: room.id } },
      create: {
        studentId: student.id,
        roomId: room.id,
        rating: 4,
        comment: 'yên tĩnh',
      },
      update: { rating: 4, comment: 'yên tĩnh' },
      include: { student: { select: { fullName: true } } },
    });
  });

  it('keeps a blank comment out of the database', async () => {
    prisma.payment.findFirst.mockResolvedValue({ id: 'paid-order' });
    prisma.roomReview.upsert.mockResolvedValue({ id: 'review-id', rating: 3, student: null });

    await service.upsert(student, room.id, { rating: 3, comment: '   ' });

    expect(prisma.roomReview.upsert.mock.calls[0][0].create.comment).toBeNull();
    expect(prisma.roomReview.upsert.mock.calls[0][0].update.comment).toBeNull();
  });

  it('names the author without leaking the phone number', async () => {
    prisma.roomReview.findMany.mockResolvedValue([
      { id: 'r1', rating: 5, comment: 'sạch sẽ', createdAt: new Date(0), student: { fullName: '  Tran B  ' } },
      { id: 'r2', rating: 2, comment: null, createdAt: new Date(0), student: { fullName: null } },
    ]);

    const result = await service.list(room.id);

    expect(prisma.roomReview.findMany).toHaveBeenCalledWith({
      where: { roomId: room.id },
      include: { student: { select: { fullName: true } } },
      orderBy: { createdAt: 'desc' },
    });
    expect(result.map((review) => review.author)).toEqual(['Tran B', 'Sinh viên']);
  });

  it('hides reviews of a room that is not on the market', async () => {
    prisma.room.findFirst.mockResolvedValue(null);

    await expect(service.list(room.id)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.roomReview.findMany).not.toHaveBeenCalled();
  });
});
