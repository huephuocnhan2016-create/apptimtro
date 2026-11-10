import {
  BadGatewayException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  PaymentGateway,
  PaymentStatus,
  RoomStatus,
  User,
  UserRole,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';
import type { ReturnQueryFromVNPay } from 'vnpay';
import { PrismaService } from '../../database/prisma.service';
import { CreatePaymentOrderDto } from './dto/create-payment-order.dto';
import { MomoService } from './momo.service';
import { PaymentOrderEntity } from './payment-order.entity';
import { VnpayService } from './vnpay.service';

type PaymentRow = {
  id: string;
  roomId: string;
  studentId: string;
  txnRef: string;
  amount: unknown;
  status: PaymentStatus;
  gateway?: PaymentGateway;
  gatewayRequestId?: string | null;
  transactionNo: string | null;
  responseCode: string | null;
  payDate: Date | null;
};

@Injectable()
export class PaymentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly vnpay: VnpayService,
    private readonly momo: MomoService,
  ) {}

  private gatewayOf(payment: { gateway?: PaymentGateway }): PaymentGateway {
    return payment.gateway ?? PaymentGateway.VNPAY;
  }

  // Either portal running without credentials makes this a development box.
  private get devModeEnabled(): boolean {
    return this.vnpay.devModeEnabled || this.momo.devModeEnabled;
  }

  private devModeFor(gateway: PaymentGateway): boolean {
    return gateway === PaymentGateway.MOMO
      ? this.momo.devModeEnabled
      : this.vnpay.devModeEnabled;
  }

  private async checkoutUrl(
    payment: {
      txnRef: string;
      createdAt: Date;
      gatewayRequestId?: string | null;
    },
    gateway: PaymentGateway,
    amount: number,
    orderInfo: string,
    ip: string,
  ): Promise<{
    payUrl: string;
    deeplink: string | null;
    qrCodeUrl: string | null;
  }> {
    if (gateway !== PaymentGateway.MOMO) {
      return {
        payUrl: await this.vnpay.buildCheckoutUrl({
          amount,
          txnRef: payment.txnRef,
          ip,
          createdAt: payment.createdAt,
          orderInfo,
        }),
        deeplink: null,
        qrCodeUrl: null,
      };
    }
    return this.momo.createOrder({
      amount,
      orderId: payment.txnRef,
      orderInfo,
      requestId: payment.gatewayRequestId ?? payment.txnRef,
    });
  }

  async create(user: User, dto: CreatePaymentOrderDto, ip: string) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can create payment orders.');
    }
    const gateway = dto.gateway ?? PaymentGateway.VNPAY;
    const room = await this.prisma.room.findUnique({
      where: { id: dto.roomId },
    });
    if (!room) throw new NotFoundException('Room not found.');
    if (room.status !== RoomStatus.AVAILABLE || room.availableRooms <= 0) {
      throw new ConflictException(
        'This room is no longer open for a deposit.',
      );
    }
    const amount = Math.round(Number(room.deposit));
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      throw new BadGatewayException('Room has an invalid payment amount.');
    }

    // A student keeps at most one live order per room. Re-opening the portal
    // they already used resumes that checkout with its own txnRef, switching
    // portal retires it first, and a paid deposit is closed. Without this the
    // app could press "Đặt cọc" as many times as it liked and leave several
    // unpaid checkouts on the same room.
    const live = await this.liveDeposit(user.id, room.id);
    if (live?.status === PaymentStatus.PAID) {
      throw new ConflictException('Bạn đã đặt cọc phòng này rồi.');
    }
    if (live && this.gatewayOf(live) === gateway) {
      return this.checkoutFor(live, gateway, ip);
    }
    if (live) {
      await this.markCancelled(live, PaymentStatus.PENDING);
    }

    // Two requests can pass the read above at the same time; the partial
    // unique index picks the winner and the loser reports the same answer.
    const payment = await this.prisma.payment
      .create({
        data: {
          studentId: user.id,
          roomId: room.id,
          txnRef: randomUUID().replace(/-/g, ''),
          amount,
          gateway,
          // MoMo echoes this back on query, and reusing it keeps a retry of the
          // same order from looking like a new one to their side.
          gatewayRequestId: randomUUID().replace(/-/g, ''),
        },
      })
      .catch((error) => {
        if (this.isUniqueViolation(error)) {
          throw new ConflictException('Bạn đã đặt cọc phòng này rồi.');
        }
        throw error;
      });
    try {
      return await this.checkoutFor(payment, gateway, ip);
    } catch (error) {
      // Keeps failed orders out of the PENDING pool the status poller scans.
      await this.prisma.payment
        .update({
          where: { id: payment.id },
          data: { status: PaymentStatus.FAILED },
        })
        .catch(() => undefined);
      throw error;
    }
  }

  // Builds the portal link for an order. The txnRef and gateway request id
  // come from the row, so a resumed checkout stays one attempt on the portal
  // side instead of looking like a new transaction.
  private async checkoutFor(
    payment: {
      txnRef: string;
      createdAt: Date;
      amount: unknown;
      gatewayRequestId?: string | null;
    },
    gateway: PaymentGateway,
    ip: string,
  ) {
    const amount = Math.round(Number(payment.amount));
    const orderInfo = this.orderInfoFor(payment.txnRef);
    const checkout = await this.checkoutUrl(
      payment,
      gateway,
      amount,
      orderInfo,
      ip,
    );
    return new PaymentOrderEntity(
      payment.txnRef,
      checkout.payUrl,
      amount,
      PaymentStatus.PENDING,
      orderInfo,
      gateway,
      checkout.deeplink,
      checkout.qrCodeUrl,
    );
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    );
  }

  // A student pulling out of a deposit. Money already handed to a portal can
  // only come back through that portal's refund API, so with real credentials a
  // paid deposit stays paid and the landlord settles it offline.
  async cancel(user: User, txnRef: string) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can cancel payment orders.');
    }
    const payment = await this.prisma.payment.findFirst({
      where: { txnRef, studentId: user.id },
    });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (
      payment.status === PaymentStatus.PAID &&
      !this.devModeFor(this.gatewayOf(payment))
    ) {
      throw new ConflictException(
        `Tiền cọc đã vào ${this.gatewayOf(payment)}, hoàn tiền cần cổng refund của ${this.gatewayOf(payment)}.`,
      );
    }
    if (
      payment.status === PaymentStatus.PENDING ||
      payment.status === PaymentStatus.PAID
    ) {
      await this.markCancelled(payment, payment.status);
    }
    return this.reload(txnRef);
  }

  // The deposits a student is currently holding, newest first. Only paid
  // orders count: a pending checkout has not booked a room yet.
  async deposits(user: User) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can list deposit orders.');
    }
    const payments = await this.prisma.payment.findMany({
      where: { studentId: user.id, status: PaymentStatus.PAID },
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
    return payments.map((payment) => ({
      txnRef: payment.txnRef,
      amount: Math.round(Number(payment.amount)),
      payDate: payment.payDate,
      room: {
        id: payment.room.id,
        title: payment.room.title,
        address: payment.room.address,
        price: Number(payment.room.price),
        deposit: Number(payment.room.deposit),
        image: payment.room.images[0]?.imageUrl ?? null,
      },
    }));
  }

  async devSucceed(user: User, txnRef: string) {
    if (!this.devModeEnabled) {
      throw new NotFoundException('Payment order not found.');
    }
    const payment = await this.prisma.payment.findFirst({
      where: { txnRef, studentId: user.id },
    });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (payment.status !== PaymentStatus.PENDING) {
      return this.view(payment);
    }
    await this.markPaid(payment, {
      transactionNo: this.devTransactionNo(txnRef),
      responseCode: '00',
      payDate: new Date(),
    });
    return this.reload(txnRef);
  }

  // The dev checkout page opens in a browser tab that carries no access token,
  // so it closes the order by transaction reference alone. Dev mode only.
  async devReturn(txnRef: string, responseCode: string) {
    if (!this.devModeEnabled) {
      throw new NotFoundException('Payment order not found.');
    }
    const payment = await this.prisma.payment.findFirst({ where: { txnRef } });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (payment.status === PaymentStatus.PENDING) {
      await this.close(payment, responseCode);
    }
    return this.reload(txnRef);
  }

  // The dev checkout page needs something to show before the shopper decides.
  async devPreview(txnRef: string) {
    if (!this.devModeEnabled) {
      throw new NotFoundException('Payment order not found.');
    }
    const payment = await this.prisma.payment.findFirst({ where: { txnRef } });
    if (!payment) throw new NotFoundException('Payment order not found.');
    return {
      ...this.view(payment),
      orderInfo: this.orderInfoFor(txnRef),
    };
  }

  // VNPay lands the shopper back here when the portal finishes. The checksum is
  // the only thing between a forged query string and a booked room.
  async handleReturn(query: ReturnQueryFromVNPay) {
    const verified = this.vnpay.verifyReturn(query);
    const txnRef = String(query.vnp_TxnRef ?? '');
    const payment = await this.prisma.payment.findFirst({ where: { txnRef } });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (!verified.isVerified) {
      return { verified: false, order: this.view(payment) };
    }
    if (payment.status === PaymentStatus.PENDING) {
      const expectedAmount = Math.round(Number(payment.amount) * 100);
      if (Number(verified.vnp_Amount) !== expectedAmount) {
        await this.markClosed(payment, '97');
      } else {
        await this.close(payment, String(verified.vnp_ResponseCode ?? ''));
      }
    }
    return { verified: true, order: this.view(await this.requireRow(txnRef)) };
  }

  private devTransactionNo(txnRef: string): string {
    return `DEV-${txnRef.slice(0, 8)}`;
  }

  // The portal renders this as-is, so it stays without diacritics.
  private orderInfoFor(txnRef: string): string {
    return `Dat coc tro tot ${txnRef}`;
  }

  private async close(
    payment: { id: string; roomId: string; studentId: string; txnRef: string },
    responseCode: string,
  ) {
    if (responseCode !== '00') {
      await this.markClosed(payment, responseCode);
      return;
    }
    await this.markPaid(payment, {
      transactionNo: this.devTransactionNo(payment.txnRef),
      responseCode,
      payDate: new Date(),
    });
  }

  // The order that currently ties a student to a room: an unpaid checkout or
  // a paid deposit. Cancelled and failed orders are history and free the key.
  private async liveDeposit(studentId: string, roomId: string) {
    return this.prisma.payment.findFirst({
      where: {
        studentId,
        roomId,
        status: { in: [PaymentStatus.PENDING, PaymentStatus.PAID] },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async holdsDeposit(options: {
    client: Prisma.TransactionClient;
    studentId: string;
    roomId: string;
    exceptPaymentId?: string;
  }) {
    const { client, studentId, roomId, exceptPaymentId } = options;
    const held = await client.payment.findFirst({
      where: {
        studentId,
        roomId,
        status: PaymentStatus.PAID,
        ...(exceptPaymentId ? { id: { not: exceptPaymentId } } : {}),
      },
      select: { id: true },
    });
    return Boolean(held);
  }

  // A paid deposit books one of the listing's rooms, and a listing emptied by
  // deposits reads as deposited rather than merely full. Two orders for the
  // same room can both reach the gate, so only the first one may book.
  private async markPaid(
    payment: { id: string; roomId: string; studentId: string },
    data: { transactionNo: string; responseCode: string; payDate: Date },
  ) {
    await this.prisma.$transaction(async (tx) => {
      if (
        await this.holdsDeposit({
          client: tx,
          studentId: payment.studentId,
          roomId: payment.roomId,
          exceptPaymentId: payment.id,
        })
      ) {
        await tx.payment.updateMany({
          where: { id: payment.id, status: PaymentStatus.PENDING },
          data: { status: PaymentStatus.FAILED, responseCode: '97' },
        });
        return;
      }
      const flipped = await tx.payment.updateMany({
        where: { id: payment.id, status: PaymentStatus.PENDING },
        data: { status: PaymentStatus.PAID, ...data },
      });
      if (flipped.count === 0) return;
      await tx.room.updateMany({
        where: { id: payment.roomId, availableRooms: { gt: 0 } },
        data: { availableRooms: { decrement: 1 } },
      });
      await tx.room.updateMany({
        where: { id: payment.roomId, availableRooms: 0 },
        data: { status: RoomStatus.DEPOSITED },
      });
    });
  }

  private async markClosed(payment: { id: string }, responseCode: string) {
    await this.prisma.payment.updateMany({
      where: { id: payment.id, status: PaymentStatus.PENDING },
      data: {
        status:
          responseCode === '24'
            ? PaymentStatus.CANCELLED
            : PaymentStatus.FAILED,
        responseCode,
      },
    });
  }

  // Cancelling a paid deposit gives the room back to the listing, and a listing
  // that reads as deposited stops reading that way.
  private async markCancelled(
    payment: { id: string; roomId: string },
    from: PaymentStatus,
  ) {
    await this.prisma.$transaction(async (tx) => {
      const flipped = await tx.payment.updateMany({
        where: { id: payment.id, status: from },
        data: { status: PaymentStatus.CANCELLED, responseCode: '24' },
      });
      if (flipped.count === 0 || from !== PaymentStatus.PAID) return;
      await tx.room.updateMany({
        where: { id: payment.roomId },
        data: { availableRooms: { increment: 1 } },
      });
      await tx.room.updateMany({
        where: {
          id: payment.roomId,
          status: RoomStatus.DEPOSITED,
          availableRooms: { gt: 0 },
        },
        data: { status: RoomStatus.AVAILABLE },
      });
    });
  }

  async status(user: User, txnRef: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { txnRef, studentId: user.id },
    });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (payment.status !== PaymentStatus.PENDING) {
      return this.view(payment);
    }
    return this.gatewayOf(payment) === PaymentGateway.MOMO
      ? this.statusMomo(payment)
      : this.statusVnpay(payment);
  }

  // MoMo keeps the transaction id in its own column and reuses the requestId
  // from the create call, so a gatewayRequestId from the order is required.
  private async statusMomo(payment: PaymentRow) {
    const result = await this.momo.queryOrder({
      orderId: payment.txnRef,
      requestId: payment.gatewayRequestId ?? payment.txnRef,
    });
    if (!result.isVerified) {
      throw new BadGatewayException('Could not verify the MoMo response.');
    }
    if (result.orderId !== payment.txnRef) {
      throw new BadGatewayException('MoMo returned a different transaction.');
    }
    if (result.isSuccess) {
      if (Number(result.amount) !== Math.round(Number(payment.amount))) {
        throw new BadGatewayException('MoMo returned a different amount.');
      }
      if (!result.transactionNo || !result.payDate) {
        throw new BadGatewayException('MoMo response is missing payment data.');
      }
      await this.markPaid(payment, {
        transactionNo: result.transactionNo,
        responseCode: result.responseCode,
        payDate: result.payDate,
      });
      return this.reload(payment.txnRef);
    }
    return this.view(payment);
  }

  private async statusVnpay(payment: PaymentRow & { createdAt: Date }) {
    const result = await this.vnpay.queryStatus({
      txnRef: payment.txnRef,
      createdAt: payment.createdAt,
      amount: Number(payment.amount),
    });
    if (!result.isVerified) {
      throw new BadGatewayException('Could not verify the VNPay response.');
    }
    if (result.vnp_TxnRef !== payment.txnRef) {
      throw new BadGatewayException('VNPay returned a different transaction.');
    }

    const expectedAmount = Math.round(Number(payment.amount) * 100);
    if (Number(result.vnp_Amount) !== expectedAmount) {
      throw new BadGatewayException('VNPay returned a different amount.');
    }
    if (
      result.isSuccess &&
      String(result.vnp_ResponseCode) === '00' &&
      String(result.vnp_TransactionStatus) === '00'
    ) {
      if (result.vnp_TransactionNo == null || result.vnp_PayDate == null) {
        throw new BadGatewayException('VNPay response is missing payment data.');
      }
      await this.markPaid(payment, {
        transactionNo: String(result.vnp_TransactionNo),
        responseCode: String(result.vnp_ResponseCode),
        payDate: this.vnpay.parsePaymentDate(result.vnp_PayDate),
      });
      return this.reload(payment.txnRef);
    }
    return this.view(payment);
  }

  // MoMo sends the same signed payload twice: once to the browser and once
  // server-to-server. Whichever arrives first writes the result; the other one
  // finds the order already settled and only reports it back.
  async handleMomoResult(params: Record<string, string>) {
    const verified = this.momo.parseResult(params);
    const txnRef = String(verified.orderId ?? '');
    const payment = await this.prisma.payment.findFirst({ where: { txnRef } });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (!verified.isVerified) {
      return { verified: false, order: this.view(payment) };
    }
    if (payment.status === PaymentStatus.PENDING) {
      if (
        verified.isSuccess &&
        Number(verified.amount) !== Math.round(Number(payment.amount))
      ) {
        await this.markClosed(payment, '97');
      } else if (verified.isSuccess) {
        await this.markPaid(payment, {
          transactionNo:
            verified.transactionNo ?? this.devTransactionNo(payment.txnRef),
          responseCode: '00',
          payDate: verified.payDate ?? new Date(),
        });
      } else {
        await this.markClosed(payment, verified.responseCode);
      }
    }
    return { verified: true, order: this.view(await this.requireRow(txnRef)) };
  }

  private async requireRow(txnRef: string): Promise<PaymentRow> {
    const payment = await this.prisma.payment.findFirst({ where: { txnRef } });
    if (!payment) throw new NotFoundException('Payment order not found.');
    return payment;
  }

  private async reload(txnRef: string) {
    return this.view(await this.requireRow(txnRef));
  }

  // Everything the result card needs, in the same shape the VNPay portal uses.
  private view(payment: PaymentRow) {
    const gateway = this.gatewayOf(payment);
    const describe =
      gateway === PaymentGateway.MOMO
        ? (code: string) => this.momo.describeResult(code)
        : (code: string) => this.vnpay.describeResponse(code);
    const message =
      payment.status === PaymentStatus.PAID
        ? 'Giao dịch thành công'
        : payment.responseCode
          ? describe(payment.responseCode)
          : 'Giao dịch chưa hoàn tất';
    return {
      status: payment.status,
      txnRef: payment.txnRef,
      amount: Math.round(Number(payment.amount)),
      gateway,
      bankName: gateway === PaymentGateway.MOMO ? 'MOMO' : 'VNPAY',
      transactionNo: payment.transactionNo,
      responseCode: payment.responseCode,
      payDate: payment.payDate
        ? this.vnpay.formatPaymentDate(payment.payDate)
        : null,
      message,
    };
  }
}
