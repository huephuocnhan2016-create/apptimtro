import {
  BadGatewayException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  PaymentGateway,
  PaymentStatus,
  Prisma,
  User,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { MomoService } from './momo.service';
import { PaymentService } from './payment.service';
import { VnpayService } from './vnpay.service';

const student = {
  id: '3150027c-71b7-4c07-8e54-3d1b61e8cb98',
  role: UserRole.STUDENT,
} as User;

const room = {
  id: 'ab8f513e-b394-42e3-98bc-b29e0f9ffbbd',
  price: { toString: () => '1500000.00' },
  deposit: { toString: () => '3000000.00' },
  availableRooms: 2,
  status: 'AVAILABLE',
};

describe('PaymentService', () => {
  const tx = {
    payment: { findFirst: jest.fn(), updateMany: jest.fn() },
    room: { updateMany: jest.fn() },
  };
  const prisma = {
    $transaction: jest.fn((work: (client: typeof tx) => Promise<unknown>) =>
      work(tx),
    ),
    room: { findUnique: jest.fn() },
    payment: {
      create: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
  };
  const vnpay = {
    buildCheckoutUrl: jest.fn(),
    queryStatus: jest.fn(),
    parsePaymentDate: jest.fn(),
    formatPaymentDate: (value: Date) =>
      value.toISOString().replace(/\D/g, '').slice(0, 14),
    describeResponse: (code: string) => `Mã ${code}`,
    devModeEnabled: true,
  };
  const momo = {
    createOrder: jest.fn(),
    queryOrder: jest.fn(),
    parseResult: jest.fn(),
    describeResult: (code: string) => `MoMo mã ${code}`,
    devModeEnabled: false,
  };
  const service = new PaymentService(
    prisma as unknown as PrismaService,
    vnpay as unknown as VnpayService,
    momo as unknown as MomoService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.payment.findFirst.mockResolvedValue(null);
    tx.payment.findFirst.mockResolvedValue(null);
    tx.payment.updateMany.mockResolvedValue({ count: 1 });
    tx.room.updateMany.mockResolvedValue({ count: 1 });
  });

  it('rejects orders for rooms that do not exist', async () => {
    prisma.room.findUnique.mockResolvedValue(null);

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('uses the room deposit from the database for the payment order', async () => {
    const createdAt = new Date('2026-11-08T10:00:00.000Z');
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.create.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'transaction-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      createdAt,
    });
    vnpay.buildCheckoutUrl.mockReturnValue(
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_TxnRef=transaction-ref',
    );

    const result = await service.create(
      student,
      { roomId: room.id },
      '127.0.0.1',
    );

    expect(prisma.payment.create.mock.calls[0][0].data).toMatchObject({
      studentId: student.id,
      roomId: room.id,
      amount: 3000000,
    });
    expect(vnpay.buildCheckoutUrl).toHaveBeenCalledWith(
      expect.objectContaining({ amount: 3000000, createdAt }),
    );
    expect(result.amount).toBe(3000000);
    expect(result.payUrl).toContain('vpcpay.html');
  });

  it('refuses a deposit on a listing that is already deposited', async () => {
    prisma.room.findUnique.mockResolvedValue({
      ...room,
      status: 'DEPOSITED',
      availableRooms: 0,
    });

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('refuses a second deposit on a room the student already holds', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.findFirst.mockResolvedValue({
      id: 'already-paid',
      status: PaymentStatus.PAID,
      gateway: PaymentGateway.VNPAY,
    });

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.payment.findFirst).toHaveBeenCalledWith({
      where: {
        studentId: student.id,
        roomId: room.id,
        status: { in: [PaymentStatus.PENDING, PaymentStatus.PAID] },
      },
      orderBy: { createdAt: 'desc' },
    });
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('resumes the unpaid checkout instead of opening a second one', async () => {
    const createdAt = new Date('2026-11-08T10:00:00.000Z');
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.findFirst.mockResolvedValue({
      id: 'pending-order',
      txnRef: 'pending-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.VNPAY,
      gatewayRequestId: 'pending-request',
      createdAt,
    });
    vnpay.buildCheckoutUrl.mockReturnValue(
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_TxnRef=pending-ref',
    );

    const result = await service.create(
      student,
      { roomId: room.id },
      '127.0.0.1',
    );

    expect(prisma.payment.create).not.toHaveBeenCalled();
    expect(vnpay.buildCheckoutUrl).toHaveBeenCalledWith(
      expect.objectContaining({ txnRef: 'pending-ref', createdAt }),
    );
    expect(result.txnRef).toBe('pending-ref');
  });

  it('retires the unpaid checkout when the student switches portal', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.findFirst.mockResolvedValue({
      id: 'pending-order',
      txnRef: 'pending-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.VNPAY,
      roomId: room.id,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    prisma.payment.create.mockResolvedValue({
      id: 'momo-order',
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.MOMO,
      createdAt: new Date('2026-11-08T10:05:00.000Z'),
    });
    momo.createOrder.mockResolvedValue({
      payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?orderId=momo-ref',
      deeplink: null,
    });

    const result = await service.create(
      student,
      { roomId: room.id, gateway: PaymentGateway.MOMO },
      '127.0.0.1',
    );

    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'pending-order', status: PaymentStatus.PENDING },
      data: { status: PaymentStatus.CANCELLED, responseCode: '24' },
    });
    expect(result.txnRef).toBe('momo-ref');
  });

  it('reports the same conflict when a parallel request wins the unique index', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('duplicate key', {
        code: 'P2002',
        clientVersion: '6.19.3',
      }),
    );

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('marks the order failed when no checkout URL can be built', async () => {
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.create.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'transaction-ref',
      amount: 1500000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.buildCheckoutUrl.mockImplementation(() => {
      throw new ServiceUnavailableException(
        'VNPay merchant credentials are not configured.',
      );
    });
    prisma.payment.update.mockResolvedValue({
      id: 'payment-id',
      status: PaymentStatus.FAILED,
    });

    await expect(
      service.create(student, { roomId: room.id }, '127.0.0.1'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(prisma.payment.update).toHaveBeenCalledWith({
      where: { id: 'payment-id' },
      data: { status: PaymentStatus.FAILED },
    });
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
    expect(tx.payment.updateMany).not.toHaveBeenCalled();
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
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        txnRef: 'transaction-ref',
        studentId: student.id,
        amount: 1500000,
        status: PaymentStatus.PENDING,
        transactionNo: null,
        responseCode: null,
        payDate: null,
        createdAt: new Date('2026-11-08T10:00:00.000Z'),
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        txnRef: 'transaction-ref',
        studentId: student.id,
        amount: 1500000,
        status: PaymentStatus.PAID,
        transactionNo: '12345',
        responseCode: '00',
        payDate,
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

    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.PAID,
        transactionNo: '12345',
        responseCode: '00',
        payDate,
      },
    });
    expect(result.status).toBe(PaymentStatus.PAID);
    expect(result.transactionNo).toBe('12345');
    expect(result.message).toBe('Giao dịch thành công');
  });

  it('books one of the listing rooms once the deposit is paid', async () => {
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      txnRef: 'transaction-ref',
      studentId: student.id,
      amount: 3000000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.queryStatus.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      vnp_TxnRef: 'transaction-ref',
      vnp_Amount: 300000000,
      vnp_ResponseCode: '00',
      vnp_TransactionStatus: '00',
      vnp_TransactionNo: 12345,
      vnp_PayDate: 20261108171500,
    });
    vnpay.parsePaymentDate.mockReturnValue(new Date('2026-11-08T10:15:00.000Z'));

    await service.status(student, 'transaction-ref');

    expect(tx.room.updateMany).toHaveBeenNthCalledWith(1, {
      where: { id: room.id, availableRooms: { gt: 0 } },
      data: { availableRooms: { decrement: 1 } },
    });
    expect(tx.room.updateMany).toHaveBeenNthCalledWith(2, {
      where: { id: room.id, availableRooms: 0 },
      data: { status: 'DEPOSITED' },
    });
  });

  it('fails a second paid order for the same room instead of booking twice', async () => {
    tx.payment.findFirst.mockResolvedValue({ id: 'other-paid' });
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      txnRef: 'transaction-ref',
      studentId: student.id,
      amount: 3000000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.queryStatus.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      vnp_TxnRef: 'transaction-ref',
      vnp_Amount: 300000000,
      vnp_ResponseCode: '00',
      vnp_TransactionStatus: '00',
      vnp_TransactionNo: 12345,
      vnp_PayDate: 20261108171500,
    });
    vnpay.parsePaymentDate.mockReturnValue(new Date('2026-11-08T10:15:00.000Z'));

    await service.status(student, 'transaction-ref');

    expect(tx.payment.findFirst).toHaveBeenCalledWith({
      where: {
        studentId: student.id,
        roomId: room.id,
        status: PaymentStatus.PAID,
        id: { not: 'payment-id' },
      },
      select: { id: true },
    });
    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: { status: PaymentStatus.FAILED, responseCode: '97' },
    });
    expect(tx.room.updateMany).not.toHaveBeenCalled();
  });

  it('leaves the listing alone when another request already paid the order', async () => {
    tx.payment.updateMany.mockResolvedValue({ count: 0 });
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      txnRef: 'transaction-ref',
      studentId: student.id,
      amount: 3000000,
      status: PaymentStatus.PENDING,
      createdAt: new Date('2026-11-08T10:00:00.000Z'),
    });
    vnpay.queryStatus.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      vnp_TxnRef: 'transaction-ref',
      vnp_Amount: 300000000,
      vnp_ResponseCode: '00',
      vnp_TransactionStatus: '00',
      vnp_TransactionNo: 12345,
      vnp_PayDate: 20261108171500,
    });
    vnpay.parsePaymentDate.mockReturnValue(new Date('2026-11-08T10:15:00.000Z'));

    await service.status(student, 'transaction-ref');

    expect(tx.room.updateMany).not.toHaveBeenCalled();
  });

  it('marks a pending order paid through the dev endpoint', async () => {
    vnpay.devModeEnabled = true;
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'dev-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.PENDING,
        transactionNo: null,
        responseCode: null,
        payDate: null,
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'dev-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.PAID,
        transactionNo: 'DEV-dev-ref',
        responseCode: '00',
        payDate: new Date('2026-11-08T10:15:00.000Z'),
      });

    const result = await service.devSucceed(student, 'dev-ref');

    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.PAID,
        transactionNo: 'DEV-dev-ref',
        responseCode: '00',
        payDate: expect.any(Date),
      },
    });
    expect(tx.room.updateMany).toHaveBeenCalledTimes(2);
    expect(result.status).toBe(PaymentStatus.PAID);
  });

  it('cancels a pending order when the dev portal reports code 24', async () => {
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'dev-ref',
        amount: 3000000,
        status: PaymentStatus.PENDING,
        transactionNo: null,
        responseCode: null,
        payDate: null,
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'dev-ref',
        amount: 3000000,
        status: PaymentStatus.CANCELLED,
        transactionNo: null,
        responseCode: '24',
        payDate: null,
      });

    const result = await service.devReturn('dev-ref', '24');

    expect(prisma.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: { status: PaymentStatus.CANCELLED, responseCode: '24' },
    });
    expect(tx.room.updateMany).not.toHaveBeenCalled();
    expect(result.status).toBe(PaymentStatus.CANCELLED);
    expect(result.message).toBe('Mã 24');
  });

  it('cancels a pending order on the student request without touching the room', async () => {
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'cancel-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.PENDING,
        transactionNo: null,
        responseCode: null,
        payDate: null,
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'cancel-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.CANCELLED,
        transactionNo: null,
        responseCode: '24',
        payDate: null,
      });

    const result = await service.cancel(student, 'cancel-ref');

    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: { status: PaymentStatus.CANCELLED, responseCode: '24' },
    });
    expect(tx.room.updateMany).not.toHaveBeenCalled();
    expect(result.status).toBe(PaymentStatus.CANCELLED);
  });

  it('gives the room back when a paid deposit is cancelled in dev mode', async () => {
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'cancel-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.PAID,
        transactionNo: 'DEV-cancel',
        responseCode: '00',
        payDate: new Date('2026-11-09T10:00:00.000Z'),
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        txnRef: 'cancel-ref',
        studentId: student.id,
        amount: 3000000,
        status: PaymentStatus.CANCELLED,
        transactionNo: 'DEV-cancel',
        responseCode: '24',
        payDate: new Date('2026-11-09T10:00:00.000Z'),
      });

    await service.cancel(student, 'cancel-ref');

    expect(tx.room.updateMany).toHaveBeenCalledWith({
      where: { id: room.id },
      data: { availableRooms: { increment: 1 } },
    });
    expect(tx.room.updateMany).toHaveBeenCalledWith({
      where: {
        id: room.id,
        status: 'DEPOSITED',
        availableRooms: { gt: 0 },
      },
      data: { status: 'AVAILABLE' },
    });
  });

  it('refuses to cancel a paid deposit once real VNPay credentials exist', async () => {
    vnpay.devModeEnabled = false;
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      txnRef: 'cancel-ref',
      studentId: student.id,
      amount: 3000000,
      status: PaymentStatus.PAID,
      transactionNo: '999',
      responseCode: '00',
      payDate: new Date('2026-11-09T10:00:00.000Z'),
    });

    await expect(
      service.cancel(student, 'cancel-ref'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.payment.updateMany).not.toHaveBeenCalled();
    vnpay.devModeEnabled = true;
  });

  it('keeps landlords out of the cancel endpoint', async () => {
    await expect(
      service.cancel(
        { id: 'landlord-id', role: UserRole.LANDLORD } as User,
        'cancel-ref',
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.payment.findFirst).not.toHaveBeenCalled();
  });

  it('hides the dev endpoint as soon as real credentials exist', async () => {
    vnpay.devModeEnabled = false;

    await expect(
      service.devSucceed(student, 'dev-ref'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.payment.findFirst).not.toHaveBeenCalled();
    expect(tx.payment.updateMany).not.toHaveBeenCalled();
  });

  it('lists only the paid deposits with their room summary', async () => {
    prisma.payment.findMany.mockResolvedValue([
      {
        txnRef: 'paid-ref',
        amount: { toString: () => '3000000.00' },
        payDate: new Date('2026-11-09T06:00:00.000Z'),
        room: {
          id: room.id,
          title: 'Phong tro Xuyen Moc',
          address: 'Xa Xuyen Moc',
          price: { toString: () => '2000000.00' },
          deposit: { toString: () => '4000000.00' },
          images: [{ imageUrl: 'https://cdn/room.jpg' }],
        },
      },
    ]);

    const result = await service.deposits(student);

    expect(prisma.payment.findMany).toHaveBeenCalledWith({
      where: { studentId: student.id, status: PaymentStatus.PAID },
      orderBy: { payDate: 'desc' },
      include: {
        room: {
          select: {
            id: true,
            title: true,
            address: true,
            price: true,
            deposit: true,
            images: { select: { imageUrl: true }, take: 1 },
          },
        },
      },
    });
    expect(result).toEqual([
      {
        txnRef: 'paid-ref',
        amount: 3000000,
        payDate: new Date('2026-11-09T06:00:00.000Z'),
        room: {
          id: room.id,
          title: 'Phong tro Xuyen Moc',
          address: 'Xa Xuyen Moc',
          price: 2000000,
          deposit: 4000000,
          image: 'https://cdn/room.jpg',
        },
      },
    ]);
  });

  it('keeps landlords out of the deposit list', async () => {
    await expect(
      service.deposits({ id: 'landlord-id', role: UserRole.LANDLORD } as User),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.payment.findMany).not.toHaveBeenCalled();
  });

  it('opens a MoMo order through the MoMo adapter', async () => {
    const createdAt = new Date('2026-11-09T10:00:00.000Z');
    prisma.room.findUnique.mockResolvedValue(room);
    prisma.payment.create.mockResolvedValue({
      id: 'payment-id',
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.MOMO,
      gatewayRequestId: 'momo-request-id',
      createdAt,
    });
    momo.createOrder.mockResolvedValue({
      payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?orderId=momo-ref',
      deeplink: null,
    });

    const result = await service.create(
      student,
      { roomId: room.id, gateway: PaymentGateway.MOMO },
      '127.0.0.1',
    );

    expect(vnpay.buildCheckoutUrl).not.toHaveBeenCalled();
    expect(momo.createOrder).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 3000000,
        orderId: 'momo-ref',
        requestId: 'momo-request-id',
      }),
    );
    expect(result.gateway).toBe(PaymentGateway.MOMO);
    expect(result.payUrl).toContain('test-payment.momo.vn');
  });

  it('marks a MoMo order paid from its gateway query', async () => {
    const payDate = new Date('2026-11-09T10:15:00.000Z');
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        studentId: student.id,
        txnRef: 'momo-ref',
        amount: 3000000,
        status: PaymentStatus.PENDING,
        gateway: PaymentGateway.MOMO,
        gatewayRequestId: 'momo-request-id',
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        studentId: student.id,
        txnRef: 'momo-ref',
        amount: 3000000,
        status: PaymentStatus.PAID,
        gateway: PaymentGateway.MOMO,
        gatewayRequestId: 'momo-request-id',
        transactionNo: '9042738472',
        responseCode: '00',
        payDate,
      });
    momo.queryOrder.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      orderId: 'momo-ref',
      amount: 3000000,
      responseCode: '00',
      transactionNo: '9042738472',
      payDate,
      message: 'Thanh toán thành công',
    });

    const result = await service.status(student, 'momo-ref');

    expect(momo.queryOrder).toHaveBeenCalledWith({
      orderId: 'momo-ref',
      requestId: 'momo-request-id',
    });
    expect(vnpay.queryStatus).not.toHaveBeenCalled();
    expect(tx.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: {
        status: PaymentStatus.PAID,
        transactionNo: '9042738472',
        responseCode: '00',
        payDate,
      },
    });
    expect(result.bankName).toBe('MOMO');
    expect(result.status).toBe(PaymentStatus.PAID);
  });

  it('refuses to book a MoMo deposit the portal priced differently', async () => {
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      studentId: student.id,
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.MOMO,
      gatewayRequestId: 'momo-request-id',
    });
    momo.queryOrder.mockResolvedValue({
      isVerified: true,
      isSuccess: true,
      orderId: 'momo-ref',
      amount: 1000,
      responseCode: '00',
      transactionNo: '9042738472',
      payDate: new Date('2026-11-09T10:15:00.000Z'),
      message: 'Thanh toán thành công',
    });

    await expect(service.status(student, 'momo-ref')).rejects.toBeInstanceOf(
      BadGatewayException,
    );
    expect(tx.payment.updateMany).not.toHaveBeenCalled();
  });

  it('settles a pending order from a verified MoMo result', async () => {
    prisma.payment.findFirst
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        studentId: student.id,
        txnRef: 'momo-ref',
        amount: 3000000,
        status: PaymentStatus.PENDING,
        gateway: PaymentGateway.MOMO,
        gatewayRequestId: 'momo-request-id',
        transactionNo: null,
        responseCode: null,
        payDate: null,
      })
      .mockResolvedValueOnce({
        id: 'payment-id',
        roomId: room.id,
        studentId: student.id,
        txnRef: 'momo-ref',
        amount: 3000000,
        status: PaymentStatus.CANCELLED,
        gateway: PaymentGateway.MOMO,
        gatewayRequestId: 'momo-request-id',
        transactionNo: null,
        responseCode: '24',
        payDate: null,
      });
    momo.parseResult.mockReturnValue({
      isVerified: true,
      isSuccess: false,
      orderId: 'momo-ref',
      amount: 3000000,
      responseCode: '24',
      transactionNo: null,
      payDate: null,
      message: 'Bạn đã hủy giao dịch',
    });

    const result = await service.handleMomoResult({ orderId: 'momo-ref' });

    expect(prisma.payment.updateMany).toHaveBeenCalledWith({
      where: { id: 'payment-id', status: PaymentStatus.PENDING },
      data: { status: PaymentStatus.CANCELLED, responseCode: '24' },
    });
    expect(result.verified).toBe(true);
    expect(result.order.message).toBe('MoMo mã 24');
    expect(result.order.gateway).toBe(PaymentGateway.MOMO);
  });

  it('books the room once when MoMo reports the same success twice', async () => {
    const payDate = new Date('2026-11-09T10:15:00.000Z');
    const pendingRow = {
      id: 'payment-id',
      roomId: room.id,
      studentId: student.id,
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.MOMO,
      gatewayRequestId: 'momo-request-id',
      transactionNo: null,
      responseCode: null,
      payDate: null,
    };
    prisma.payment.findFirst
      .mockResolvedValueOnce(pendingRow)
      .mockResolvedValue({ ...pendingRow, status: PaymentStatus.PAID, payDate });
    momo.parseResult.mockReturnValue({
      isVerified: true,
      isSuccess: true,
      orderId: 'momo-ref',
      amount: 3000000,
      responseCode: '00',
      transactionNo: '9042738472',
      payDate,
      message: 'Thành công.',
    });

    await service.handleMomoResult({ orderId: 'momo-ref' });
    await service.handleMomoResult({ orderId: 'momo-ref' });

    // The browser return and the server IPN carry the same signed result, so
    // only the first one may move the order out of PENDING.
    expect(tx.payment.updateMany).toHaveBeenCalledTimes(1);
  });

  it('writes nothing for a MoMo result whose signature does not match', async () => {
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      studentId: student.id,
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PENDING,
      gateway: PaymentGateway.MOMO,
      gatewayRequestId: 'momo-request-id',
      transactionNo: null,
      responseCode: null,
      payDate: null,
    });
    momo.parseResult.mockReturnValue({
      isVerified: false,
      isSuccess: false,
      orderId: 'momo-ref',
      amount: 3000000,
      responseCode: '0',
      transactionNo: null,
      payDate: null,
      message: '',
    });

    const result = await service.handleMomoResult({ orderId: 'momo-ref' });

    expect(result.verified).toBe(false);
    expect(prisma.payment.updateMany).not.toHaveBeenCalled();
  });

  it('refunds only through the portal the deposit was paid into', async () => {
    // MoMo has real credentials here while VNPay is still a dev mock.
    vnpay.devModeEnabled = true;
    prisma.payment.findFirst.mockResolvedValue({
      id: 'payment-id',
      roomId: room.id,
      studentId: student.id,
      txnRef: 'momo-ref',
      amount: 3000000,
      status: PaymentStatus.PAID,
      gateway: PaymentGateway.MOMO,
      gatewayRequestId: 'momo-request-id',
      transactionNo: '9042738472',
      responseCode: '00',
      payDate: new Date('2026-11-09T10:00:00.000Z'),
    });

    // VNPay may still be in dev mode here; the MoMo order is not.
    await expect(service.cancel(student, 'momo-ref')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.payment.updateMany).not.toHaveBeenCalled();
  });
});
