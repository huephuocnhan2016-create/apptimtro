import {
  BadGatewayException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus, User, UserRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../database/prisma.service';
import { CreatePaymentOrderDto } from './dto/create-payment-order.dto';
import { PaymentOrderEntity } from './payment-order.entity';
import { VnpayService } from './vnpay.service';

@Injectable()
export class PaymentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly vnpay: VnpayService,
  ) {}

  async create(user: User, dto: CreatePaymentOrderDto, ip: string) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can create payment orders.');
    }
    const room = await this.prisma.room.findUnique({
      where: { id: dto.roomId },
    });
    if (!room) throw new NotFoundException('Room not found.');

    const amount = Math.round(Number(room.price));
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      throw new BadGatewayException('Room has an invalid payment amount.');
    }
    const payment = await this.prisma.payment.create({
      data: {
        studentId: user.id,
        roomId: room.id,
        txnRef: randomUUID().replace(/-/g, ''),
        amount,
      },
    });
    const qr = await this.vnpay.createQr({
      amount,
      txnRef: payment.txnRef,
      ip,
      createdAt: payment.createdAt,
    });
    return new PaymentOrderEntity(
      payment.txnRef,
      qr.qrcontent,
      amount,
      payment.status,
    );
  }

  async status(user: User, txnRef: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { txnRef, studentId: user.id },
    });
    if (!payment) throw new NotFoundException('Payment order not found.');
    if (payment.status !== PaymentStatus.PENDING) {
      return { status: payment.status };
    }

    const result = await this.vnpay.queryStatus({
      txnRef: payment.txnRef,
      createdAt: payment.createdAt,
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
      const payDate = this.vnpay.parsePaymentDate(result.vnp_PayDate);
      if (Number.isNaN(payDate.getTime())) {
        throw new BadGatewayException('VNPay returned an invalid payment date.');
      }
      await this.prisma.payment.updateMany({
        where: { id: payment.id, status: PaymentStatus.PENDING },
        data: {
          status: PaymentStatus.PAID,
          transactionNo: String(result.vnp_TransactionNo),
          responseCode: String(result.vnp_ResponseCode),
          payDate,
        },
      });
      return { status: PaymentStatus.PAID };
    }
    return { status: PaymentStatus.PENDING };
  }
}
