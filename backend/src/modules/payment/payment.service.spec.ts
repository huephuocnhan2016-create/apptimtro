import { NotFoundException } from '@nestjs/common';
import { PaymentStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { PaymentService } from './payment.service';
import { VnpayService } from './vnpay.service';

const student = {
  id: '3150027c-71b7-4c07-8e54-3d1b61e8cb98',
  role: UserRole.STUDENT,
} as User;

const room = {
  id: 'ab8f513e-b394-42e3-98bc-b29e0f9ffbbd',
  price: { toString: () => '1500000.00' },
};

describe('PaymentService', () => {
  const prisma = {
    room: { findUnique: jest.fn() },
    payment: {
      create: jest.fn(),
      findFirst: jest.fn(),
      updateMany: jest.fn(),
    },
  };
  const vnpay = {
    createQr: jest.fn(),
    queryStatus: jest.fn(),
    parsePaymentDate: jest.fn(),
  };
  const service = new PaymentService(
    prisma as unknown as PrismaService,
    vnpay as unknown as VnpayService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects orders for rooms that do not exist', async () => {
    prisma.room.findUnique.mockResolvedValue(null);

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('uses the room price from the database for the payment order', async () => {
    const createdAt = new Date('2026-11-08T10:00:00.000Z');
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.create.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'transaction-ref',
      amount: 1500000,
      status: PaymentStatus.PENDING,
      createdAt,
    });
    vnpay.createQr.mockResolvedValue({
      code: '00',
      qrcontent: 'qr-content',
      message: 'Success',
    });

    const result = await service.create(
      student,
      { roomId: room.id },
      '127.0.0.1',
    );

    expect(prisma.payment.create.mock.calls[0][0].data).toMatchObject({
      studentId: student.id,
      roomId: room.id,
      amount: 1500000,
    });
    expect(vnpay.createQr).toHaveBeenCalledWith(
      expect.objectContaining({ amount: 1500000, createdAt }),
    );
    expect(result.amount).toBe(1500000);
    expect(result.qrcontent).toBe('qr-content');
  });

  it('keeps the order pending when VNPay reports a non-success status', async () => {
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'transaction-ref',
      studentId: student.id,
      amount: 1500000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.queryStatus.mockResolvedValue({
      isVerified: true,
      isSuccess: false,
      vnp_TxnRef: 'transaction-ref',
      vnp_Amount: 150000000,
      vnp_ResponseCode: '00',
      vnp_TransactionStatus: '01',
    });

    const result = await service.status(student, 'transaction-ref');

    expect(result.status).toBe(PaymentStatus.PENDING);
    expect(prisma.payment.updateMany).not.toHaveBeenCalled();
  });

  it('does not expose payment orders belonging to another student', async () => {
    prisma.payment.findFirst.mockResolvedValue(null);

    await expect(
      service.status(student, 'another-students-order'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.payment.findFirst).toHaveBeenCalledWith({
      where: {
        txnRef: 'another-students-order',
        studentId: student.id,
      },
    });
    expect(vnpay.queryStatus).not.toHaveBeenCalled();
  });

  it('marks an order paid only after a verified successful response', async () => {
    const payDate = new Date('2026-11-08T10:15:00.000Z');
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'transaction-ref',
      studentId: student.id,
      amount: 1500000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.queryStatus.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      vnp_TxnRef: 'transaction-ref',
      vnp_Amount: 150000000,
      vnp_ResponseCode: '00',
      vnp_TransactionStatus: '00',
      vnp_TransactionNo: 12345,
      vnp_PayDate: 20261108171500,
    });
    vnpay.parsePaymentDate.mockReturnValue(payDate);

    const result = await service.status(student, 'transaction-ref');

    expect(prisma.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.PAID,
        transactionNo: '12345',
        responseCode: '00',
        payDate,
      },
    });
    expect(result.status).toBe(PaymentStatus.PAID);
  });
});
