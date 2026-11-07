import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { RoomStatus, User, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { CreateConversationDto } from './dto/create-conversation.dto';

const participantSelect = { id: true, fullName: true, avatarUrl: true };

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  // Conversation id trả về từ đây là doc id Firestore — client không được tự sinh.
  async openConversation(user: User, dto: CreateConversationDto) {
    if (user.role !== UserRole.STUDENT) {
      throw new ForbiddenException('Only students can start a conversation.');
    }
    const room = await this.prisma.room.findFirst({
      where: { id: dto.roomId, status: { in: [RoomStatus.AVAILABLE, RoomStatus.FULL] } },
    });
    if (!room) throw new NotFoundException('Room not found.');
    if (room.landlordId === user.id) {
      throw new BadRequestException('You cannot chat about your own room.');
    }
    const conversation = await this.prisma.conversation.upsert({
      where: { studentId_roomId: { studentId: user.id, roomId: room.id } },
      create: { studentId: user.id, landlordId: room.landlordId, roomId: room.id },
      update: {},
    });
    return { id: conversation.id };
  }

  async listConversations(user: User) {
    const conversations = await this.prisma.conversation.findMany({
      where: { OR: [{ studentId: user.id }, { landlordId: user.id }] },
      include: {
        room: {
          select: {
            id: true,
            title: true,
            images: { orderBy: { sortOrder: 'asc' }, select: { imageUrl: true }, take: 1 },
          },
        },
        student: { select: participantSelect },
        landlord: { select: participantSelect },
      },
      orderBy: { createdAt: 'desc' },
    });
    return conversations.map((conversation) => {
      const isStudent = conversation.studentId === user.id;
      const participant = isStudent ? conversation.landlord : conversation.student;
      return {
        id: conversation.id,
        createdAt: conversation.createdAt,
        roomId: conversation.room.id,
        roomTitle: conversation.room.title,
        roomImageUrl: conversation.room.images[0]?.imageUrl ?? null,
        participantId: participant.id,
        participantName: participant.fullName,
        participantAvatarUrl: participant.avatarUrl,
      };
    });
  }
}
