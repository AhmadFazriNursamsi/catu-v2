import { ConflictException } from '@nestjs/common';
import { AssignmentWorkflowService } from './assignment-workflow.service';

/** Romo tidak boleh menyelesaikan pelayanan sebelum tanggal pelaksanaannya; Admin boleh mengoreksi. */
function build(scheduledDate: string) {
  const respondAssignment = jest.fn(async () => ({ message: 'ok', status: 'DONE' }));
  const svc = new AssignmentWorkflowService(
    { query: jest.fn() } as any,
    { respondAssignment } as any,
    {} as any,
    { target: jest.fn(async () => ({ status: 'CONFIRMED', acceptedRomoId: 6, scheduledDate })) } as any,
  );
  return { svc, respondAssignment };
}
const future = new Date(Date.now() + 20 * 86_400_000).toISOString().slice(0, 10);
const past = new Date(Date.now() - 2 * 86_400_000).toISOString().slice(0, 10);

describe('respond DONE dan tanggal pelaksanaan', () => {
  it('Romo: DONE sebelum tanggal ditolak (409) dan tidak diteruskan', async () => {
    const { svc, respondAssignment } = build(future);
    await expect(svc.respond(1, { status: 'DONE' } as any, { romoId: 6, isAdmin: false })).rejects.toThrow(ConflictException);
    expect(respondAssignment).not.toHaveBeenCalled();
  });

  it('Romo: DONE pada atau sesudah tanggal diteruskan', async () => {
    const { svc, respondAssignment } = build(past);
    await svc.respond(1, { status: 'DONE' } as any, { romoId: 6, isAdmin: false });
    expect(respondAssignment).toHaveBeenCalledTimes(1);
  });

  it('Admin boleh mengoreksi walau tanggal belum tiba', async () => {
    const { svc, respondAssignment } = build(future);
    await svc.respond(1, { status: 'DONE' } as any, { romoId: 6, isAdmin: true });
    expect(respondAssignment).toHaveBeenCalledTimes(1);
  });

  it('IN_PROGRESS sebelum tanggal tidak dibatasi (hanya DONE)', async () => {
    const { svc, respondAssignment } = build(future);
    await svc.respond(1, { status: 'IN_PROGRESS' } as any, { romoId: 6, isAdmin: false });
    expect(respondAssignment).toHaveBeenCalledTimes(1);
  });
});
