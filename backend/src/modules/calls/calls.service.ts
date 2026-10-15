import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CallStatus, Prisma, RoomStatus, User, UserRole } from '@prisma/client';
import { randomUUID } from 'crypto';
import { RtcTokenBuilder, RtcRole } from 'agora-token';
import { PrismaService } from '../../database/prisma.service';
import { NotificationService } from '../notifications/notification.service';
import { CreateCallDto } from './dto/create-call.dto';

const callInclude = {
  caller: { select: { id: true, fullName: true, avatarUrl: true } },
  receiver: { select: { id: true, fullName: true, avatarUrl: true } },
  room: { select: { id: true, title: true, address: true } },
};

@Injectable()
export class CallsService {
  private readonly logger = new Logger(CallsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly notifications: NotificationService,
  ) {}

  async create(user: User, dto: CreateCallDto) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can initiate a room video call.');
    }
    this.agoraConfig();
    const room = await this.prisma.room.findFirst({
      where: { id: dto.roomId, status: RoomStatus.AVAILABLE, availableRooms: { gt: 0 } },
      include: { landlord: true },
    });
    if (!room) throw new NotFoundException('Available room not found.');
    if (room.landlordId === user.id) {
      throw new ForbiddenException('You cannot call yourself.');
    }
    await this.prisma.call.updateMany({
      where: {
        receiverId: room.landlordId,
        status: CallStatus.RINGING,
        createdAt: { lte: new Date(Date.now() - 60_000) },
      },
      data: { status: CallStatus.MISSED, endedAt: new Date() },
    });
    const active = await this.prisma.call.findFirst({
      where: {
        receiverId: room.landlordId,
        status: CallStatus.RINGING,
        createdAt: { gt: new Date(Date.now() - 60_000) },
      },
    });
    if (active) throw new ConflictException('The landlord is already receiving a call.');

    const call = await this.prisma.call.create({
        data: {
          callerId: user.id,
          receiverId: room.landlordId,
          roomId: room.id,
          channelName: `call_${randomUUID().replace(/-/g, '')}`,
        },
        include: callInclude,
      }).catch((error: unknown) => {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('The landlord is already receiving a call.');
      }
      throw error;
    });
    await this.notify(room.landlordId, {
      title: 'Cuộc gọi video đến',
      body: `${user.fullName ?? 'Một sinh viên'} đang gọi video cho bạn`,
    }, { type: 'incoming_call', callId: call.id, roomId: room.id });
    return this.serialize(call);
  }

  async get(user: User, id: string) {
    const call = await this.callForParticipant(user, id);
    if (call.status === CallStatus.RINGING &&
        call.createdAt.getTime() < Date.now() - 60_000) {
      await this.prisma.call.updateMany({
        where: { id, status: CallStatus.RINGING },
        data: { status: CallStatus.MISSED, endedAt: new Date() },
      });
      call.status = CallStatus.MISSED;
      call.endedAt = new Date();
    }
    return {
      ...this.serialize(call),
      ...(call.status === CallStatus.ACCEPTED ? this.issueAgoraToken(call, user) : {}),
    };
  }

  async accept(user: User, id: string) {
    const call = await this.callForParticipant(user, id);
    if (call.receiverId !== user.id) {
      throw new ForbiddenException('Only the receiver can accept this call.');
    }
    if (call.status !== CallStatus.RINGING ||
        call.createdAt.getTime() < Date.now() - 60_000) {
      throw new ConflictException('This call is no longer available.');
    }
    this.agoraConfig();
    const updated = await this.prisma.call.updateMany({
      where: { id, status: CallStatus.RINGING },
      data: { status: CallStatus.ACCEPTED, startedAt: new Date() },
    });
    if (updated.count !== 1) throw new ConflictException('This call has already ended.');
    const accepted = await this.prisma.call.findUniqueOrThrow({
      where: { id },
      include: callInclude,
    });
    await this.notify(
      accepted.callerId,
      { title: 'Cuộc gọi được chấp nhận', body: 'Chủ trọ đã nhận cuộc gọi video.' },
      { type: 'call_accepted', callId: id },
    );
    return {
      ...this.serialize(accepted),
      ...this.issueAgoraToken(accepted, user),
    };
  }

  async reject(user: User, id: string) {
    const call = await this.callForParticipant(user, id);
    if (call.receiverId !== user.id) {
      throw new ForbiddenException('Only the receiver can reject this call.');
    }
    if (call.status !== CallStatus.RINGING) {
      throw new ConflictException('This call is no longer ringing.');
    }
    const updated = await this.prisma.call.updateMany({
      where: { id, status: CallStatus.RINGING },
      data: { status: CallStatus.REJECTED, endedAt: new Date() },
    });
    if (updated.count !== 1) throw new ConflictException('This call has already ended.');
    await this.notify(
      call.callerId,
      { title: 'Cuộc gọi bị từ chối', body: 'Chủ trọ không thể nhận cuộc gọi lúc này.' },
      { type: 'call_rejected', callId: id },
    );
    return { id, status: CallStatus.REJECTED };
  }

  async end(user: User, id: string) {
    const call = await this.callForParticipant(user, id);
    if (call.status !== CallStatus.RINGING && call.status !== CallStatus.ACCEPTED) {
      throw new ConflictException('This call has already ended.');
    }
    const updated = await this.prisma.call.updateMany({
      where: { id, status: call.status },
      data: { status: CallStatus.ENDED, endedAt: new Date() },
    });
    if (updated.count !== 1) throw new ConflictException('This call has already ended.');
    await this.notify(
      user.id === call.callerId ? call.receiverId : call.callerId,
      { title: 'Cuộc gọi đã kết thúc', body: 'Cuộc gọi video đã kết thúc.' },
      { type: 'call_ended', callId: id },
    );
    return { id, status: CallStatus.ENDED };
  }

  async history(user: User) {
    const calls = await this.prisma.call.findMany({
      where: { OR: [{ callerId: user.id }, { receiverId: user.id }] },
      include: callInclude,
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return calls.map((call) => this.serialize(call));
  }

  private async callForParticipant(user: User, id: string) {
    const call = await this.prisma.call.findUnique({ where: { id }, include: callInclude });
    if (!call) throw new NotFoundException('Call not found.');
    if (call.callerId !== user.id && call.receiverId !== user.id) {
      throw new ForbiddenException('You are not a participant in this call.');
    }
    return call;
  }

  private issueAgoraToken(call: { channelName: string }, user: User) {
    const { appId, certificate } = this.agoraConfig();
    const uid = Number.parseInt(user.id.replace(/-/g, '').slice(0, 8), 16) || 1;
    const expiration = 3600;
    return {
      appId,
      channelName: call.channelName,
      uid,
      token: RtcTokenBuilder.buildTokenWithUid(
        appId,
        certificate,
        call.channelName,
        uid,
        RtcRole.PUBLISHER,
        expiration,
        expiration,
      ),
      expiresInSeconds: expiration,
    };
  }

  private agoraConfig() {
    const appId = this.config.get<string>('AGORA_APP_ID');
    const certificate = this.config.get<string>('AGORA_APP_CERTIFICATE');
    if (!appId || !certificate) {
      throw new ServiceUnavailableException('Video calls are not configured on this server.');
    }
    return { appId, certificate };
  }

  private async notify(
    userId: string,
    notification: { title: string; body: string },
    data: Record<string, string>,
  ) {
    try {
      await this.notifications.sendToUser(userId, notification, data);
    } catch (error) {
      if (error instanceof Error) {
        this.logger.error(`Call notification delivery failed: ${error.message}`);
      } else {
        this.logger.error('Call notification delivery failed with an unknown error.');
      }
    }
  }

  private serialize(call: {
    id: string; callerId: string; receiverId: string; roomId: string;
    channelName: string; status: CallStatus; startedAt: Date | null;
    endedAt: Date | null; createdAt: Date; caller: unknown; receiver: unknown;
    room: unknown;
  }) {
    return {
      id: call.id,
      callerId: call.callerId,
      receiverId: call.receiverId,
      roomId: call.roomId,
      channelName: call.channelName,
      status: call.status,
      startedAt: call.startedAt,
      endedAt: call.endedAt,
      createdAt: call.createdAt,
      caller: call.caller,
      receiver: call.receiver,
      room: call.room,
    };
  }
}
