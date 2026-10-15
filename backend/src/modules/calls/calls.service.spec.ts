import { ForbiddenException } from '@nestjs/common';
import { CallStatus, RoomStatus, User, UserRole } from '@prisma/client';
import { CallsService } from './calls.service';
import { PrismaService } from '../../database/prisma.service';
import { NotificationService } from '../notifications/notification.service';
import { ConfigService } from '@nestjs/config';

const student = {
  id: '3150027c-71b7-4c07-8e54-3d1b61e8cb98',
  role: UserRole.STUDENT,
  fullName: 'Nguyen Van A',
} as User;
const landlord = {
  id: '1fc7a30e-8023-4d9b-a48f-6c19c5590c1d',
  role: UserRole.LANDLORD,
} as User;
const room = {
  id: 'ab8f513e-b394-42e3-98bc-b29e0f9ffbbd',
  landlordId: landlord.id,
  status: RoomStatus.AVAILABLE,
  availableRooms: 2,
  landlord,
};
const call = {
  id: 'a4e43561-5908-4dfa-a0b8-35eeae5003db',
  callerId: student.id,
  receiverId: landlord.id,
  roomId: room.id,
  channelName: 'call_abc123',
  status: CallStatus.RINGING,
  startedAt: null,
  endedAt: null,
  createdAt: new Date(),
  caller: { id: student.id, fullName: student.fullName, avatarUrl: null },
  receiver: { id: landlord.id, fullName: null, avatarUrl: null },
  room: { id: room.id, title: 'Room', address: 'District 1' },
};

describe('CallsService', () => {
  const prisma = {
    room: { findFirst: jest.fn() },
    call: {
      updateMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn(),
      findUniqueOrThrow: jest.fn(),
      findMany: jest.fn(),
    },
  };
  const config = {
    get: jest.fn((key: string) =>
      key === 'AGORA_APP_ID' ? 'a'.repeat(32) : 'b'.repeat(32),
    ),
  };
  const notifications = { sendToUser: jest.fn().mockResolvedValue(undefined) };
  const service = new CallsService(
    prisma as unknown as PrismaService,
    config as unknown as ConfigService,
    notifications as unknown as NotificationService,
  );

  beforeEach(() => jest.clearAllMocks());

  it('creates a call with the landlord derived from the room, not the request', async () => {
    prisma.room.findFirst.mockResolvedValue(room);
    prisma.call.updateMany.mockResolvedValue({ count: 0 });
    prisma.call.findFirst.mockResolvedValue(null);
    prisma.call.create.mockResolvedValue(call);

    const result = await service.create(student, { roomId: room.id });

    expect(prisma.call.create.mock.calls[0][0].data.receiverId).toBe(landlord.id);
    expect(prisma.call.create.mock.calls[0][0].data.channelName).toMatch(/^call_[a-f0-9]{32}$/);
    expect(result.status).toBe(CallStatus.RINGING);
    expect(notifications.sendToUser).toHaveBeenCalledWith(
      landlord.id,
      expect.objectContaining({ body: expect.stringContaining('Nguyen Van A') }),
      expect.objectContaining({ callId: call.id }),
    );
  });

  it('rejects a landlord attempting to initiate a call', async () => {
    await expect(service.create(landlord, { roomId: room.id }))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.room.findFirst).not.toHaveBeenCalled();
  });

  it('only returns call data to a participant', async () => {
    prisma.call.findUnique.mockResolvedValue(call);
    const stranger = { ...student, id: 'e9746763-e762-4d31-9b1b-8522bd52d988' } as User;
    await expect(service.get(stranger, call.id)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('accepts a call only for the server-selected receiver and creates a backend token', async () => {
    prisma.call.findUnique.mockResolvedValue(call);
    prisma.call.updateMany.mockResolvedValue({ count: 1 });
    prisma.call.findUniqueOrThrow.mockResolvedValue({
      ...call,
      status: CallStatus.ACCEPTED,
      startedAt: new Date(),
    });

    const result = await service.accept(landlord, call.id);

    expect(result.status).toBe(CallStatus.ACCEPTED);
    expect(result.token).toEqual(expect.any(String));
    expect(result.appId).toBe('a'.repeat(32));
    expect(result.uid).toBe(Number.parseInt(landlord.id.replace(/-/g, '').slice(0, 8), 16));
  });

  it('does not let the caller accept the call', async () => {
    prisma.call.findUnique.mockResolvedValue(call);
    await expect(service.accept(student, call.id)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
