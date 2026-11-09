import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { Request, Response } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CreatePaymentOrderDto } from './dto/create-payment-order.dto';
import { PaymentService } from './payment.service';
import type { ReturnQueryFromVNPay } from 'vnpay';

const escape = (value: unknown): string =>
  String(value ?? '').replace(
    /[&<>"']/g,
    (char) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      })[char] as string,
  );

const money = (value: number): string =>
  new Intl.NumberFormat('vi-VN').format(value);

const page = (body: string): string =>
  `<!doctype html><html lang="vi"><head><meta charset="utf-8">` +
  `<meta name="viewport" content="width=device-width,initial-scale=1">` +
  `<title>VNPAY</title></head>` +
  `<body style="margin:0;background:#f2f5fb;font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#0f172a">` +
  `<div style="max-width:480px;margin:0 auto;padding:24px 16px 48px">` +
  `${body}</div></body></html>`;

const portalHeader = `
<div style="display:flex;align-items:center;gap:10px;padding:12px 0">
  <div style="width:36px;height:36px;border-radius:9px;background:#1a5cff;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700">V</div>
  <div>
    <div style="font-weight:700;font-size:16px">VNPAY</div>
    <div style="font-size:11px;letter-spacing:.08em;color:#64748b">CỔNG THANH TOÁN TRỰC TUYẾN</div>
  </div>
</div>`;

const card = (inner: string): string =>
  `<div style="background:#fff;border-radius:16px;padding:20px;box-shadow:0 1px 3px rgba(15,23,42,.08)">${inner}</div>`;

// The portal has no route into the app's navigation, so the button only hands
// the app back to the foreground; the app re-reads the order when it resumes.
const backToAppLink = (txnRef: string): string =>
  `<a href="intent://payment-return?txnRef=${encodeURIComponent(txnRef)}#Intent;scheme=trotot;package=com.trotot.app;end"` +
  ' style="display:block;margin-top:18px;text-align:center;background:#1a5cff;color:#fff;border-radius:12px;padding:14px;text-decoration:none;font-weight:600">Về ứng dụng</a>' +
  '<div style="margin-top:10px;font-size:12px;color:#94a3b8;text-align:center">Nếu nút không hoạt động, đóng tab bằng dấu X.</div>';

@ApiTags('Payment')
@Controller('payment')
export class PaymentController {
  constructor(private readonly payment: PaymentService) {}

  @Post('orders')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Create a VNPay checkout order' })
  create(
    @CurrentUser() user: User,
    @Body() dto: CreatePaymentOrderDto,
    @Req() request: Request,
  ) {
    return this.payment.create(user, dto, request.ip ?? '127.0.0.1');
  }

  @Get('orders/:txnRef/status')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Check a VNPay payment order status' })
  status(@CurrentUser() user: User, @Param('txnRef') txnRef: string) {
    return this.payment.status(user, txnRef);
  }

  @Post('orders/:txnRef/cancel')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Cancel a deposit order and release the room hold' })
  cancel(@CurrentUser() user: User, @Param('txnRef') txnRef: string) {
    return this.payment.cancel(user, txnRef);
  }

  // VNPay sends the browser here with the signed result query. Public by
  // design: the checksum, not the session, is what authorises this request.
  @Get('vnpay/return')
  @ApiOperation({ summary: 'Receive the VNPay portal result' })
  async return(
    @Query() query: Record<string, string>,
    @Res() res: Response,
  ): Promise<void> {
    const result = await this.payment.handleReturn(
      query as unknown as ReturnQueryFromVNPay,
    );
    res.type('html').send(
      page(
        portalHeader +
          card(
            `<div style="font-size:18px;font-weight:700;color:${result.verified && result.order.status === 'PAID' ? '#16a34a' : '#dc2626'}">${escape(result.order.message)}</div>` +
            `<div style="margin-top:12px;font-size:14px">Mã giao dịch: <b>${escape(result.order.txnRef)}</b></div>` +
            `<div style="margin-top:6px;font-size:14px">Số tiền: <b>${money(result.order.amount)} VND</b></div>` +
            `<div style="margin-top:18px;font-size:13px;color:#64748b">Quay lại ứng dụng Trọ Tốt để xem kết quả đặt cọc.</div>` +
            backToAppLink(result.order.txnRef),
          ),
      ),
    );
  }

  // Stands in for sandbox.vnpayment.vn while merchant credentials are absent.
  @Get('dev/checkout/:txnRef')
  @ApiOperation({ summary: 'Dev-only VNPay portal stand-in' })
  async devCheckout(
    @Param('txnRef') txnRef: string,
    @Res() res: Response,
  ): Promise<void> {
    const order = await this.payment.devPreview(txnRef);
    const settled = order.status !== 'PENDING';
    const action = settled
      ? `<div style="font-size:18px;font-weight:700;color:${order.status === 'PAID' ? '#16a34a' : '#dc2626'}">${escape(order.message)}</div>` +
        backToAppLink(txnRef)
      : `<div style="display:flex;gap:12px;margin-top:24px">` +
        `<a href="/api/payment/dev/return/${encodeURIComponent(txnRef)}?code=00" style="flex:1;text-align:center;background:#1a5cff;color:#fff;border-radius:12px;padding:14px;text-decoration:none;font-weight:600">Xác nhận</a>` +
        `<a href="/api/payment/dev/return/${encodeURIComponent(txnRef)}?code=24" style="flex:1;text-align:center;background:#e2e8f0;color:#0f172a;border-radius:12px;padding:14px;text-decoration:none;font-weight:600">Hủy</a>` +
        `</div>`;
    res.type('html').send(
      page(
        portalHeader +
          card(
            `<div style="font-size:13px;color:#64748b">Nội dung thanh toán</div>` +
            `<div style="font-size:15px;font-weight:600;margin-top:4px">${escape(order.orderInfo)}</div>` +
            `<div style="font-size:13px;color:#64748b;margin-top:16px">Số tiền</div>` +
            `<div style="font-size:26px;font-weight:700;color:#1a5cff;margin-top:2px">${money(order.amount)} <span style="font-size:14px;color:#64748b">VND</span></div>` +
            action,
          ) +
          `<div style="margin-top:14px;font-size:12px;color:#94a3b8">Bản dev: đây không phải cổng VNPAY thật.</div>`,
      ),
    );
  }

  @Get('dev/return/:txnRef')
  @ApiOperation({ summary: 'Dev-only portal result' })
  async devReturn(
    @Param('txnRef') txnRef: string,
    @Query('code') code: string,
    @Res() res: Response,
  ): Promise<void> {
    const order = await this.payment.devReturn(
      txnRef,
      code === '00' ? '00' : '24',
    );
    res.type('html').send(
      page(
        portalHeader +
          card(
            `<div style="font-size:18px;font-weight:700;color:${order.status === 'PAID' ? '#16a34a' : '#dc2626'}">${escape(order.message)}</div>` +
            `<div style="margin-top:18px;font-size:13px;color:#64748b">Quay lại ứng dụng Trọ Tốt để xem kết quả đặt cọc.</div>` +
            backToAppLink(txnRef),
          ),
      ),
    );
  }

  @Post('dev/succeed/:txnRef')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Mark a dev-mock order paid (only without VNPay credentials)',
  })
  devSucceed(@CurrentUser() user: User, @Param('txnRef') txnRef: string) {
    return this.payment.devSucceed(user, txnRef);
  }
}
