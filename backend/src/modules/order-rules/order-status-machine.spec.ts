import { decideTransition, isServiceStatus } from './order-status-machine';

describe('decideTransition', () => {
  it('alur normal diizinkan', () => {
    expect(decideTransition('PENDING', 'CONFIRMED')).toEqual({ kind: 'ALLOWED' });
    expect(decideTransition('CONFIRMED', 'IN_PROGRESS')).toEqual({ kind: 'ALLOWED' });
    expect(decideTransition('CONFIRMED', 'DONE')).toEqual({ kind: 'ALLOWED' });
    expect(decideTransition('IN_PROGRESS', 'DONE')).toEqual({ kind: 'ALLOWED' });
    expect(decideTransition('IN_PROGRESS', 'CLOSE')).toEqual({ kind: 'ALLOWED' });
  });

  it('status final tidak dapat diubah lagi (tidak mundur ke CONFIRMED)', () => {
    for (const final of ['DONE', 'CLOSE', 'FAIL']) {
      for (const to of ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'CLOSE']) {
        if (to === final) continue;
        expect(decideTransition(final, to).kind).toBe('DENIED');
      }
    }
  });

  it('tidak boleh mundur atau melompat dari PENDING', () => {
    expect(decideTransition('IN_PROGRESS', 'CONFIRMED').kind).toBe('DENIED');
    expect(decideTransition('CONFIRMED', 'PENDING').kind).toBe('DENIED');
    expect(decideTransition('PENDING', 'DONE').kind).toBe('DENIED');
    expect(decideTransition('PENDING', 'IN_PROGRESS').kind).toBe('DENIED');
  });

  it('mengulang status yang sama tidak mengubah apa pun', () => {
    expect(decideTransition('CONFIRMED', 'CONFIRMED')).toEqual({ kind: 'NOOP' });
    expect(decideTransition('DONE', 'DONE')).toEqual({ kind: 'NOOP' });
  });

  it('FAIL hanya oleh Admin dan hanya dari PENDING', () => {
    expect(decideTransition('PENDING', 'FAIL').kind).toBe('DENIED');
    expect(decideTransition('PENDING', 'FAIL', true)).toEqual({ kind: 'ALLOWED' });
    expect(decideTransition('CONFIRMED', 'FAIL', true).kind).toBe('DENIED');
  });

  it('status tidak dikenal ditolak; huruf kecil dinormalkan', () => {
    expect(decideTransition('PENDING', 'BOGUS').kind).toBe('DENIED');
    expect(decideTransition('confirmed', 'done')).toEqual({ kind: 'ALLOWED' });
    expect(isServiceStatus('BOGUS')).toBe(false);
  });
});
