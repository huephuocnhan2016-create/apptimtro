import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { User } from '@prisma/client';
import { Request } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CreatePaymentOrderDto } from './dto/create-payment-order.dto';
import { PaymentService } from './payment.service';

@ApiTags('Payment')
@Controller('payment')
export class PaymentController {
  constructor(private readonly payment: PaymentService) {}

  @Post('orders')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Create a VNPay QR payment order' })
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
  status(
    @CurrentUser() user: User,
    @Param('txnRef') txnRef: string,
  ) {
    return this.payment.status(user, txnRef);
  }
}
