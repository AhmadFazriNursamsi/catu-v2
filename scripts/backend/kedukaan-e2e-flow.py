#!/usr/bin/env python3
"""Satu alur lengkap Misa Kedukaan (3 misa) dari pembuatan sampai ulasan, dijalankan dua kali:
  A. paroki penerima SAMA dengan paroki pemohon (Umat 8, paroki 256)
  B. paroki penerima BERBEDA (lintas paroki: Umat 8 meminta di paroki 257, kota 3173), ditambah B-X: tujuan di keuskupan lain.

Harapan (aturan bisnis) ditetapkan SEBELUM dijalankan dan tidak disesuaikan dengan hasil. Tiap baris PASS/FAIL memuat bukti.
HANYA untuk runtime pengembangan lokal (catu_backend :3005 + shared-postgres). Order uji bercatatan "uji-e2e" dan akun uji dibersihkan.

Pemakaian:  python3 scripts/backend/kedukaan-e2e-flow.py"""
import re, sys, time

sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from flowlib import *  # noqa: E402,F401,F403

MARK = 'uji-e2e'
created = []


def purge():
    for r_ in psql(f"select id from orders where notes like '%{MARK}%'").split():
        created.append(int(r_))
    for oid in set(created):
        purge_order(oid)
    created.clear()


purge()
T = {}
for name, sub, role in [('UMAT', 8, 'UMAT'), ('UMAT2', 58, 'UMAT'), ('ROMO', 12, 'ROMO_PAROKI'), ('ROMO2', 13, 'ROMO_PAROKI'), ('ROMO3', 45, 'ROMO_PAROKI'),
                        ('ROMO257', 47, 'ROMO_PAROKI'), ('ORDO', 50, 'ROMO_ORDO'), ('ORDO_T', 48, 'ROMO_ORDO'), ('PENG', 9, 'PENGURUS_LINGKUNGAN'),
                        ('PENG2', 49, 'PENGURUS_LINGKUNGAN'), ('KOOR', 53, 'KOORDINATOR_KEUSKUPAN'), ('KOOR_OUT', 54, 'KOORDINATOR_KEUSKUPAN'), ('SUPER', 7, 'SUPERADMIN')]:
    T[name] = jwt(sub, role)
_st, _orig = call('GET', '/master/escalation-settings', T['SUPER'])
call('PUT', '/master/escalation-settings', T['SUPER'], {'ordoAfterMinutes': 10, 'koordinatorAfterMinutes': 20})

NAMES = ['Misa Pemberkatan Jenazah', 'Misa Requiem', 'Misa Pemakaman']


def items():
    return [{'itemName': NAMES[i], 'scheduledDate': future(4 + i), 'scheduledTimeStart': f'{9 + i:02d}:00', 'scheduledTimeEnd': f'{10 + i:02d}:00', 'locationName': ['Rumah Duka', 'Gereja', 'Pemakaman'][i]} for i in range(3)]


def create(over=None, its=None):
    its = items() if its is None else its
    p = dict(serviceCategoryId=2, urgencyLevelId=2, scheduledDate=its[0]['scheduledDate'] if its else future(4), scheduledTime='09:00', locationName='Rumah Duka St. Carolus', addressDetail='Jl. Salemba Raya',
             notes=f'Misa: Pemberkatan | Nama Almarhum: Antonius Supardi | Hubungan: Ayah | Catatan: {MARK}', items=its)
    p.update(over or {})
    st, r = call('POST', '/orders', T['UMAT'], p)
    oid = int(r['order']['id']) if st in (200, 201) and isinstance(r, dict) and r.get('order') else None
    if oid:
        created.append(oid)
    return st, r, oid


def ids(oid):
    return [int(x) for x in psql(f"select id from order_items where order_id={oid} order by id").split()]


def ist(i):
    """status|romo|tanggal|jam-mulai"""
    return psql(f"select status::text||'|'||coalesce(accepted_romo_id::text,'-')||'|'||scheduled_date::text||'|'||substring(scheduled_time_start::text,1,5) from order_items where id={i}")


def ost(oid):
    return psql(f"select status::text||'|'||coalesce(accepted_romo_id::text,'-')||'|'||lintas_paroki::text||'|'||coalesce(paroki_id::text,'-')||'|'||coalesce(keuskupan_id::text,'-') from orders where id={oid}")


def grp(oid, i):
    return psql(f"select id from chat_groups where order_id={oid} and order_item_id={i}")


def mem(g):
    rows = psql(f"select user_id||':'||role_in_group from chat_group_members where chat_group_id={g} order by user_id")
    return rows.split('\n') if rows else []


def nlist(user, oid, ntype):
    rows = psql(f"select coalesce(chat_group_id::text,'-') from notifications where user_id={user} and order_id={oid} and type='{ntype}' order by id")
    return rows.split('\n') if rows else []


def nwho(oid, ntype):
    return sorted(set(int(x) for x in psql(f"select user_id from notifications where order_id={oid} and type='{ntype}'").split() if x))


def respond(tok, oid, status, romo, item=None):
    b = {'status': status, 'romoId': romo}
    if item:
        b['itemId'] = item
    return call('POST', f'/assignments/{oid}/respond', tok, b)


def sees(tok, q, oid):
    st, r = call('GET', '/orders' + q, tok)
    return any(str(o.get('id')) == str(oid) for o in lst(r))


def lifecycle(tag, oid, I, G, acceptor, acceptor_tok, handover_to, handover_tok, third_romo):
    """Tahap sesudah penerimaan: ubah jam, chat, pelimpahan, pelaksanaan, selesai, ulasan. Dipakai kedua skenario."""
    I1, I2, I3 = I
    # ubah jam misa 1 (hanya misa itu)
    st, r = call('POST', f'/orders/{oid}/reschedule/propose', acceptor_tok, {'romoId': acceptor, 'itemId': I1, 'newTimeStart': '19:00', 'newTimeEnd': '20:00', 'reason': 'Menyesuaikan dengan keluarga duka'})
    st2, r2 = call('POST', f'/orders/{oid}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': I1, 'action': 'ACCEPT'})
    rs = lambda i: psql(f"select coalesce(reschedule_status,'NONE') from order_items where id={i}")
    rec(f'{tag}-ubah-jam', success(st, r) and success(st2, r2) and ist(I1).endswith(f'|{future(4)}|19:00') and ist(I2).split('|')[2] == future(5) and ist(I3).split('|')[2] == future(6),
        'Ubah jam misa 1 disetujui Umat: hanya JAM misa 1 berubah (tanggal tetap); misa 2 dan 3 tetap', f"m1={ist(I1)} m2={ist(I2)} m3={ist(I3)}")
    rec(f'{tag}-ubah-jam-status', [rs(I1), rs(I2), rs(I3)] == ['ACCEPTED', 'NONE', 'NONE'], 'Status ubah jam: misa 1 "Diterima"; misa 2 dan 3 tanpa status', f"{[rs(I1), rs(I2), rs(I3)]}")
    st, r = call('POST', f'/orders/{oid}/reschedule/propose', acceptor_tok, {'romoId': acceptor, 'itemId': I1, 'newDate': future(9), 'newTimeStart': '20:00', 'reason': 'Mencoba mengubah tanggal juga'})
    rec(f'{tag}-ubah-jam-tanggal', st == 400 and 'tidak dapat mengubah tanggal' in msg(r).lower(), 'Ubah jam yang menyertakan tanggal berbeda ditolak (400)', f"HTTP {st}; {msg(r)[:70]}")
    # chat per misa
    st, r = call('POST', f'/chat/groups/{G[I1]}/messages', T['UMAT'], {'messageType': 'TEXT', 'message': 'Terima kasih Romo, kami menunggu.'})
    n1 = psql(f"select count(*) from chat_messages where chat_group_id={G[I1]} and message_type='TEXT'")
    n2 = psql(f"select count(*) from chat_messages where chat_group_id={G[I2]} and message_type='TEXT'")
    rec(f'{tag}-chat', st in (200, 201) and n1 == '1' and n2 == '0', 'Pesan Umat di grup misa 1 hanya masuk grup misa 1', f"HTTP {st}; grup1={n1} grup2={n2}")
    got = psql(f"select string_agg(distinct user_id::text, ',' order by user_id::text) from notifications where order_id={oid} and type='CHAT_MESSAGE' and chat_group_id={G[I1]}")
    members1 = [m.split(':')[0] for m in mem(G[I1]) if not m.startswith('8:')]
    recv = set((got or '').split(','))
    rec(f'{tag}-chat-notif', set(members1) <= recv and not ({'13', '45', '46', '47'} & (recv - set(members1))), 'Notifikasi pesan chat sampai ke seluruh anggota grup misa 1 (selain pengirim) dan tidak ke Romo yang bukan anggota', f"penerima={got}; anggota={members1}")
    extra = sorted(recv - set(members1))
    rec(f'{tag}-chat-notif-koordinator', None, 'Penerima notifikasi chat di luar anggota grup (Koordinator keuskupan dianggap pembaca grup) - perlu keputusan', f"tambahan={extra}")
    # pelimpahan misa 2
    st, r = call('POST', f'/orders/{oid}/handover', handover_tok['from'], {'romoId': handover_to['from'], 'itemId': I2, 'targetRomoId': handover_to['to'], 'reason': 'Berhalangan hadir (sudah dikabari keluarga)'})
    stn = nlist(handover_to['to'], oid, 'ROMO_HANDOVER')
    rec(f'{tag}-limpah-ajukan', success(st, r) and G[I2] in stn and G[I1] not in stn, 'Pengajuan pelimpahan misa 2: Romo tujuan diberi tahu dan notifikasinya menaut ke grup MISA 2', f"HTTP {st}; notif Romo {handover_to['to']} -> grup {stn}")
    st, r = call('POST', f'/orders/{oid}/handover/respond', handover_tok['to'], {'romoId': handover_to['to'], 'itemId': I2, 'action': 'ACCEPT'})
    m2 = mem(G[I2])
    rec(f'{tag}-limpah-terima', success(st, r) and ist(I2).split('|')[1] == str(handover_to['to']) and f"{handover_to['to']}:" in ' '.join(m2) and not any(x.startswith(f"{handover_to['from']}:") for x in m2),
        'Pelimpahan diterima: misa 2 kini milik Romo baru; Romo lama keluar dari grup misa 2, Romo baru masuk', f"misa2={ist(I2)}; anggota={m2}")
    rec(f'{tag}-limpah-tidak-bocor', ist(I1).split('|')[1] == str(acceptor), 'Pelimpahan misa 2 tidak mengubah Romo misa 1', f"misa1={ist(I1)}")
    # pelaksanaan
    st, r = respond(handover_tok['from'], oid, 'DONE', handover_to['from'], I2)
    rec(f'{tag}-bukan-petugas', st == 403 and not ist(I2).startswith('DONE'), 'Romo lama (sudah dilimpahkan) tidak dapat menyelesaikan misa 2', f"HTTP {st}")
    st, r = respond(acceptor_tok, oid, 'IN_PROGRESS', acceptor, I1)
    rec(f'{tag}-mulai', success(st, r) and ist(I1).startswith('IN_PROGRESS'), 'Romo memulai misa 1', ist(I1))
    respond(acceptor_tok, oid, 'DONE', acceptor, I1)
    o = ost(oid).split('|')[0]
    rec(f'{tag}-order-belum-selesai', ist(I1).startswith('DONE') and o in ('CONFIRMED', 'IN_PROGRESS'), 'Misa 1 selesai tetapi order belum DONE (misa lain masih berjalan)', f"misa1={ist(I1)}; order={o}")
    st, r = respond(handover_tok['to'], oid, 'DONE', handover_to['to'], I2)
    st3, r3 = respond(third_romo['tok'], oid, 'DONE', third_romo['id'], I3)
    o = ost(oid).split('|')[0]
    rec(f'{tag}-order-selesai', success(st, r) and success(st3, r3) and o == 'DONE' and all(ist(i).startswith('DONE') for i in I), 'Semua misa selesai -> order otomatis DONE', f"order={o}; misa={[ist(i).split('|')[0] for i in I]}")
    st, r = respond(acceptor_tok, oid, 'CONFIRMED', acceptor, I1)
    done_links = sorted(nlist(8, oid, 'ORDER_DONE'))
    rec(f'{tag}-selesai-notif', done_links == sorted(G.values()), 'Pemohon diberi tahu "selesai" untuk TIAP misa, masing-masing menaut ke grup misanya', f"{done_links}; grup={sorted(G.values())}")
    rec(f'{tag}-final', st == 409 and ist(I1).startswith('DONE'), 'Misa yang sudah DONE tidak dapat dimundurkan', f"HTTP {st}")
    # ulasan per misa
    codes = []
    for n, i in enumerate(I):
        st, r = call('POST', f'/orders/{oid}/review', T['UMAT'], {'itemId': i, 'rating': 5 - n, 'reviewNotes': f'Ulasan misa {n + 1}'})
        codes.append(st)
    ratings = [psql(f"select coalesce(rating::text,'-') from order_items where id={i}") for i in I]
    rec(f'{tag}-ulasan', codes == [201, 201, 201] and ratings == ['5', '4', '3'], 'Ulasan tersimpan per misa (5, 4, 3 bintang)', f"HTTP {codes}; rating={ratings}")
    st, r = call('POST', f'/orders/{oid}/review', T['UMAT'], {'itemId': I1, 'rating': 1, 'reviewNotes': 'ulang'})
    st2, r2 = call('POST', f'/orders/{oid}/review', T['UMAT2'], {'itemId': I1, 'rating': 5, 'reviewNotes': 'bukan pemohon'})
    rec(f'{tag}-ulasan-jaga', st == 409 and st2 in (400, 403), 'Ulasan ganda ditolak (409); bukan pemohon ditolak', f"ganda HTTP {st}; bukan pemohon HTTP {st2}")
    want = {acceptor: 1, handover_to['to']: 1, third_romo['id']: 1}
    if third_romo['id'] == acceptor:
        want = {acceptor: 2, handover_to['to']: 1}
    got = {u: len(nlist(u, oid, 'ORDER_REVIEW')) for u in want}
    lama = handover_to['from']
    rec(f'{tag}-ulasan-notif', got == want and (lama in want or not nlist(lama, oid, 'ORDER_REVIEW')),
        'Tiap Romo yang bertugas diberi tahu ulasan misanya (Romo lama tidak)', f"diterima={got}; diharapkan={want}")
    # integritas akhir
    orphan = psql(f"select count(*) from notifications n where n.order_id={oid} and n.chat_group_id is not null and not exists (select 1 from chat_groups g where g.id=n.chat_group_id and g.order_id={oid})")
    leak = psql(f"select count(*) from notifications where order_id={oid} and user_id=8 and type like 'NEW_ORDER%'")
    rec(f'{tag}-integritas', orphan == '0' and leak == '0', 'Tidak ada notifikasi menaut ke grup order lain; pemohon tidak diberi notifikasi "pesanan baru" untuk ordernya sendiri', f"menaut-salah={orphan}; notif-pesanan-baru-ke-pemohon={leak}")


try:
    print('=================== SKENARIO A: PAROKI SAMA (Umat 8, paroki 256) ===================')
    st, r, A = create()
    num = (r or {}).get('order', {}).get('order_number', '')
    I = ids(A) if A else []
    rec('A1', st == 201 and re.match(r'^MD-\d{8}-\d{4,}$', num) and len(I) == 3 and ost(A).startswith('PENDING|-|false|256|30') and all(ist(i).startswith('PENDING') for i in I),
        'Buat 3 misa: 201, nomor MD-, order PENDING bukan lintas paroki (paroki 256, keuskupan 30), 3 misa PENDING', f"HTTP {st}; {num}; {ost(A)}; misa={[ist(i) for i in I]}")
    I1, I2, I3 = (I + [0, 0, 0])[:3]
    G = {i: grp(A, i) for i in I}
    rec('A2', len(set(G.values())) == 3 and all(G.values()) and all(set(mem(G[i])) == {'8:UMAT', '9:PENGURUS_LINGKUNGAN', '11:PENGURUS_LINGKUNGAN'} for i in I), '3 grup chat terpisah per misa; anggota awal: pemohon dan pengurus lingkungan saja', f"anggota={[mem(G[i]) for i in I]}")
    rp = {u: nlist(u, A, 'NEW_ORDER_ROMO') for u in (12, 13, 45)}
    rec('A3', all(sorted(v) == sorted(G.values()) for v in rp.values()), 'Tiap Romo Paroki (12, 13, 45) menerima 3 notifikasi, satu per misa, masing-masing menaut ke grup misanya', f"{rp}")
    pm = {u: nlist(u, A, 'NEW_ORDER_MONITOR') for u in (9, 11)}
    rec('A4', all(sorted(v) == sorted(G.values()) for v in pm.values()), 'Pengurus lingkungan (9, 11) menerima 3 notifikasi pemantauan, satu per misa', f"{pm}")
    rec('A5', not nwho(A, 'NEW_ORDER_KOORDINATOR') and not ({48, 50} & set(nwho(A, 'NEW_ORDER_ROMO'))), 'Saat dibuat: Romo Ordo dan Koordinator belum diberi tahu (menunggu parameter eskalasi)', f"romo={nwho(A, 'NEW_ORDER_ROMO')}; koordinator={nwho(A, 'NEW_ORDER_KOORDINATOR')}")
    rec('A6', sees(T['UMAT'], '?userId=8', A) and sees(T['ROMO'], '?romoId=12', A) and sees(T['ROMO2'], '?romoId=13', A)
        and not sees(T['ROMO257'], '?romoId=47', A) and not sees(T['ORDO'], '?romoId=50', A) and not sees(T['ORDO_T'], '?romoId=48', A)
        and not sees(T['PENG'], '?userId=9', A) and not sees(T['KOOR'], '?userId=53', A),
        'Daftar/beranda: pemohon dan Romo Paroki 256 melihat; Romo paroki lain, Romo Ordo (belum jeda), pengurus dan Koordinator tidak', '')
    # penerimaan
    st, r = respond(T['ROMO'], A, 'CONFIRMED', 12, I1)
    st2, r2 = respond(T['ROMO2'], A, 'CONFIRMED', 13, I2)
    rec('A7', success(st, r) and success(st2, r2) and ist(I1).startswith('CONFIRMED|12') and ist(I2).startswith('CONFIRMED|13') and ist(I3).startswith('PENDING') and ost(A).startswith('CONFIRMED'),
        'Romo 12 menerima misa 1, Romo 13 misa 2; misa 3 tetap PENDING; order CONFIRMED', f"m1={ist(I1)} m2={ist(I2)} m3={ist(I3)}; order={ost(A)}")
    m = {i: mem(G[i]) for i in I}
    rec('A8', '12:ROMO_PAROKI' in m[I1] and '13:ROMO_PAROKI' in m[I2] and not any(x.startswith(('12:', '13:')) for x in m[I3]) and not any(x.startswith('13:') for x in m[I1]) and not any(x.startswith('12:') for x in m[I2]),
        'Romo hanya masuk grup misa yang ia terima', f"{m}")
    st, r = respond(T['ROMO3'], A, 'CONFIRMED', 45, I1)
    st2, r2 = respond(T['ROMO257'], A, 'CONFIRMED', 47, I3)
    rec('A9', st == 409 and st2 == 403 and ist(I1).startswith('CONFIRMED|12') and ist(I3).startswith('PENDING'), 'Misa yang sudah diterima tidak dapat direbut Romo lain (409); Romo paroki lain ditolak (403)', f"HTTP {st} / {st2}")
    st, r = respond(T['ROMO'], A, 'CONFIRMED', 12, I3)
    rec('A10', success(st, r) and ist(I3).startswith('CONFIRMED|12'), 'Romo 12 juga menerima misa 3', ist(I3))
    cn = {u: nlist(8, A, 'ORDER_CONFIRMED') for u in (8,)}
    rec('A11', len(cn[8]) >= 3 and set(cn[8]) >= set(G.values()), 'Pemohon diberi tahu untuk TIAP misa yang diterima, menaut ke grup misa itu', f"{cn}")
    lifecycle('A', A, I, G, 12, T['ROMO'], {'from': 13, 'to': 45}, {'from': T['ROMO2'], 'to': T['ROMO3']}, {'id': 12, 'tok': T['ROMO']})

    print('=================== SKENARIO B: LINTAS PAROKI (Umat 8 paroki 256 -> pelayanan di paroki 257, kota 3173) ===================')
    st, r, B = create({'parokiId': 257, 'keuskupanId': 30, 'kabupatenKotaId': 3173})
    num = (r or {}).get('order', {}).get('order_number', '')
    I = ids(B) if B else []
    rec('B1', st == 201 and re.match(r'^MD-\d{8}-\d{4,}$', num) and len(I) == 3 and ost(B).startswith('PENDING|-|true|257|30') and all(ist(i).startswith('PENDING') for i in I),
        'Buat 3 misa lintas paroki: tercatat lintas (paroki 257, keuskupan pemohon 30), 3 misa PENDING', f"HTTP {st}; {ost(B)}")
    I1, I2, I3 = (I + [0, 0, 0])[:3]
    G = {i: grp(B, i) for i in I}
    rec('B2', len(set(G.values())) == 3 and all(all(f'{k}:KOORDINATOR' in mem(G[i]) for k in (10, 51, 53)) and '8:UMAT' in mem(G[i]) and '9:PENGURUS_LINGKUNGAN' in mem(G[i]) for i in I)
        and not any(x.startswith(('12:', '13:', '45:', '46:', '47:')) for i in I for x in mem(G[i])),
        '3 grup chat; anggota: pemohon, pengurus lingkungan PEMOHON, dan Koordinator keuskupan; tidak ada Romo Paroki', f"{[mem(G[i]) for i in I]}")
    ro = nwho(B, 'NEW_ORDER_ROMO')
    rec('B3', ro == [48], 'Seketika (tanpa jeda): hanya Romo Ordo kota tujuan (48) diberi tahu; tidak satu pun Romo Paroki (256 maupun 257) dan bukan Romo Ordo kota lain', f"penerima={ro}")
    n48 = nlist(48, B, 'NEW_ORDER_ROMO')
    rec('B4', sorted(n48) == sorted(G.values()), 'Romo Ordo tujuan menerima 3 notifikasi, satu per misa, tiap notifikasi menaut ke grup misanya (sama seperti paroki sama)', f"{n48}; grup={list(G.values())}")
    pm = {u: nlist(u, B, 'NEW_ORDER_MONITOR') for u in (9, 11)}
    ko = nwho(B, 'NEW_ORDER_KOORDINATOR')
    kn = {k: nlist(k, B, 'NEW_ORDER_KOORDINATOR') for k in (10, 51, 53)}
    rec('B5', all(sorted(v) == sorted(G.values()) for v in pm.values()) and all(sorted(v) == sorted(G.values()) for v in kn.values()) and 54 not in ko,
        'Pengurus pemohon (9, 11) dan Koordinator keuskupan 30 (10, 51, 53): masing-masing 3 notifikasi, satu per misa, menaut ke grup misanya; keuskupan lain (54) tidak', f"pengurus={pm}; koordinator={kn}")
    rec('B6', sees(T['UMAT'], '?userId=8', B) and sees(T['ORDO_T'], '?romoId=48', B) and not sees(T['ROMO257'], '?romoId=47', B) and not sees(T['ROMO'], '?romoId=12', B)
        and not sees(T['ORDO'], '?romoId=50', B) and not sees(T['PENG'], '?userId=9', B) and not sees(T['KOOR'], '?userId=53', B),
        'Daftar/beranda: pemohon dan Romo Ordo tujuan melihat; Romo Paroki tujuan (47) dan asal (12), Romo Ordo kota lain (50), pengurus dan Koordinator tidak', '')
    for who, tok, rid in (('Romo Paroki tujuan 47', T['ROMO257'], 47), ('Romo Paroki asal 12', T['ROMO'], 12), ('Romo Ordo kota lain 50', T['ORDO'], 50)):
        st, r = respond(tok, B, 'CONFIRMED', rid, I1)
        rec(f'B7-{rid}', st == 403 and ist(I1).startswith('PENDING'), f'{who} tidak berwenang menerima', f"HTTP {st}; {msg(r)[:70]}")
    st, r = respond(T['ORDO_T'], B, 'CONFIRMED', 48, I1)
    st2, r2 = respond(T['ORDO_T'], B, 'CONFIRMED', 48, I2)
    rec('B8', success(st, r) and success(st2, r2) and ist(I1).startswith('CONFIRMED|48') and ist(I2).startswith('CONFIRMED|48') and ist(I3).startswith('PENDING'),
        'Romo Ordo tujuan langsung menerima misa 1 dan 2; misa 3 tetap PENDING', f"m1={ist(I1)} m2={ist(I2)} m3={ist(I3)}")
    cb = nlist(8, B, 'ORDER_CONFIRMED')
    rec('B8b', G[I1] in cb and G[I2] in cb and G[I3] not in cb, 'Pemohon diberi tahu misa 1 dan 2 dikonfirmasi, notifikasi menaut ke grup misa masing-masing', f"{cb}")
    rec('B9', all('48:ROMO_ORDO' in mem(G[i]) for i in (I1, I2)) and not any(x.startswith('48:') for x in mem(G[I3])), 'Romo Ordo masuk grup misa 1 dan 2 saja', f"{[mem(G[i]) for i in I]}")
    st, r = call('GET', f'/chat/groups/{G[I1]}/messages', T['KOOR'])
    st2, r2 = call('GET', f'/chat/groups/{G[I1]}/messages', T['ROMO257'])
    st3, r3 = call('GET', f'/chat/groups/{G[I1]}/messages', T['KOOR_OUT'])
    rec('B10', st == 200 and st2 == 403 and st3 == 403, 'Koordinator keuskupan pemohon dapat membaca chat; Romo Paroki tujuan dan Koordinator keuskupan lain (tidak terlibat) tidak', f"koordinator HTTP {st}; romo47 HTTP {st2}; koordinator54 HTTP {st3}")
    # Carikan Romo untuk misa 3
    st, r = call('GET', f'/orders/{B}/koordinator-assignment', T['KOOR'])
    rec('B11', st == 200 and (r or {}).get('state') == 'WAITING' and 'Romo Ordo' in str((r or {}).get('reason')), 'Koordinator belum boleh mencarikan Romo sebelum parameter Koordinator (pesan menyebut Romo Ordo tujuan)', f"state={(r or {}).get('state')}; {(r or {}).get('reason')}")
    psql(f"update orders set created_at = now() - interval '21 minutes' where id={B}")
    time.sleep(22)
    ko2 = psql(f"select count(*) from notifications where user_id=53 and order_id={B} and type='NEW_ORDER_KOORDINATOR'")
    ko2_new = nlist(53, B, 'NEW_ORDER_KOORDINATOR')[3:]
    st, r = call('GET', f'/orders/{B}/koordinator-assignment', T['KOOR'])
    pend = [int(x) for x in ((r or {}).get('pendingItems') or [])] if isinstance((r or {}).get('pendingItems'), list) else []
    rec('B12', st == 200 and (r or {}).get('state') == 'OPEN' and ko2 == '4' and ko2_new == [G[I3]], 'Lewat parameter Koordinator: Carikan Romo terbuka; Koordinator diberi tahu "perlu Romo" HANYA untuk misa yang belum punya Romo (misa 3), menaut ke grup misa 3', f"state={(r or {}).get('state')}; total notif Koordinator 53={ko2} (3 awal + 1 eskalasi); eskalasi menaut ke {ko2_new}; grup misa 3={G[I3]}")
    st, r = call('POST', f'/orders/{B}/koordinator-assignment', T['KOOR'], {'romoId': 12, 'itemId': I3})
    rec('B13', st in (200, 201) and ist(I3).startswith('CONFIRMED|12') and ist(I1).startswith('CONFIRMED|48') and '12:ROMO_PAROKI' in mem(G[I3]), 'Koordinator menetapkan Romo 12 hanya untuk misa 3; misa lain tidak berubah; Romo 12 masuk grup misa 3', f"HTTP {st}; m3={ist(I3)}; anggota={mem(G[I3])}")
    lifecycle('B', B, I, G, 48, T['ORDO_T'], {'from': 48, 'to': 50}, {'from': T['ORDO_T'], 'to': T['ORDO']}, {'id': 12, 'tok': T['ROMO']})

    print('=================== SKENARIO B-X: LINTAS PAROKI KE KEUSKUPAN LAIN (paroki tujuan di keuskupan 3) ===================')
    other = psql("select id from paroki where keuskupan_id=3 order by id limit 1")
    one = [items()[0]]
    st, r, X = create({'parokiId': int(other), 'keuskupanId': 3, 'kabupatenKotaId': 3273}, its=one)
    IX = ids(X) if X else []
    GX = grp(X, IX[0]) if IX else ''
    rec('BX1', st == 201 and ost(X).split('|')[0] == 'PENDING' and ost(X).split('|')[2] == 'true', 'Tercatat lintas paroki (paroki tujuan di keuskupan lain)', f"HTTP {st}; {ost(X)}")
    mx = mem(GX)
    rec('BX2', all(f'{k}:KOORDINATOR' in mx for k in (10, 51, 53, 54)) and not any(x.startswith(('12:', '13:', '45:', '46:', '47:', '59:')) for x in mx), 'Koordinator keuskupan pemohon (30) DAN keuskupan tujuan (54) sama-sama masuk grup; tidak ada Romo Paroki', f"{mx}")
    ko = nwho(X, 'NEW_ORDER_KOORDINATOR')
    st, r = call('GET', f'/chat/groups/{GX}/messages', T['KOOR_OUT'])
    st2, r2 = call('GET', f'/orders/{X}/koordinator-assignment', T['KOOR_OUT'])
    rec('BX3', {10, 51, 53, 54} <= set(ko) and st == 200 and st2 == 200, 'Keduanya diberi tahu; Koordinator tujuan dapat membaca chat dan membuka Carikan Romo', f"koordinator={ko}; chat HTTP {st}; carikan HTTP {st2}")
    rec('BX4', not ({12, 13, 45, 46, 47, 59} & set(nwho(X, 'NEW_ORDER_ROMO'))), 'Tidak ada Romo Paroki yang diberi tahu', f"penerima={nwho(X, 'NEW_ORDER_ROMO')}")

    print('=================== KETAHANAN ===================')
    st, r, Z = create(its=[{**items()[0], 'scheduledTimeEnd': '08:00'}])
    rec('Z1', st == 400 and not Z, 'Jam selesai sebelum jam mulai ditolak', f"HTTP {st}")
    st, r, Z = create(its=[])
    rec('Z2', st == 400 and not Z, 'Misa Kedukaan tanpa misa ditolak', f"HTTP {st}")
    st, r, Z = create(its=[{**items()[0], 'itemName': 'x' * 5000}])
    rec('Z3', st == 400 and not Z, 'Nama misa 5000 karakter ditolak (bukan 500)', f"HTTP {st}")
finally:
    print('=== Pembersihan ===')
    if isinstance(_orig, dict) and 'ordoAfterMinutes' in _orig:
        call('PUT', '/master/escalation-settings', T['SUPER'], _orig)
        print('parameter eskalasi dipulihkan ke', _orig)
    purge()
    print('sisa order uji:', psql(f"select count(*) from orders where notes like '%{MARK}%'"))

sys.exit(summary())
