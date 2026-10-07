#!/usr/bin/env python3
"""Uji menyeluruh Misa Kedukaan (tahap 1: paroki penerima SAMA dengan paroki pemohon) lewat API.

Kedukaan = satu permintaan berisi beberapa MISA (item). Tiap misa punya status, Romo, grup chat, ubah jam,
pelimpahan, penyelesaian, dan ulasan sendiri; status order diturunkan dari status misa-misanya.

HANYA untuk runtime pengembangan lokal (catu_backend :3005 + container shared-postgres). Bergantung pada data seed
pengembangan (lihat perminyakan-flow.py). Semua order uji (catatan memuat "uji-ked") dan akun uji dibersihkan.

Pemakaian:  python3 scripts/backend/kedukaan-flow.py
Keluaran: satu baris PASS/FAIL/INFO per skenario; kode keluar 1 bila ada FAIL."""
import json, re, subprocess, sys, threading, time

sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from flowlib import *  # noqa: E402,F401,F403

MARK = 'uji-ked'
created_orders, created_users = [], []


def purge():
    for r_ in psql(f"select id from orders where notes like '%{MARK}%'").split():
        created_orders.append(int(r_))
    for oid in set(created_orders):
        purge_order(oid)
    for ph in created_users + [p for p in psql("select phone_number from auth_users where phone_number like '62813000007%'").split()]:
        uid = psql(f"select id from auth_users where phone_number='{ph}'")
        if uid:
            for stmt in (f"delete from chat_group_members where user_id={uid}", f"delete from notifications where user_id={uid}", f"delete from activity_logs where user_id={uid}",
                         f"delete from user_profiles where user_id={uid}", f"delete from auth_users where id={uid}"):
                psql(stmt)
    created_orders.clear()


purge()
T = {}
for name, sub, role in [('UMAT', 8, 'UMAT'), ('UMAT2', 58, 'UMAT'), ('ROMO', 12, 'ROMO_PAROKI'), ('ROMO2', 13, 'ROMO_PAROKI'), ('ROMO3', 45, 'ROMO_PAROKI'),
                        ('ROMO257', 47, 'ROMO_PAROKI'), ('ORDO', 50, 'ROMO_ORDO'), ('ORDO_OUT', 48, 'ROMO_ORDO'), ('PENG', 9, 'PENGURUS_LINGKUNGAN'),
                        ('PENG2', 49, 'PENGURUS_LINGKUNGAN'), ('KOOR', 53, 'KOORDINATOR_KEUSKUPAN'), ('KOOR_OUT', 54, 'KOORDINATOR_KEUSKUPAN'), ('ADMIN', 52, 'ADMIN'), ('SUPER', 7, 'SUPERADMIN')]:
    T[name] = jwt(sub, role)
_st, _orig = call('GET', '/master/escalation-settings', T['SUPER'])
call('PUT', '/master/escalation-settings', T['SUPER'], {'ordoAfterMinutes': 10, 'koordinatorAfterMinutes': 20})   # nilai baku untuk uji; dipulihkan di akhir


def mk_items(n=3, start=4, names=None):
    names = names or ['Misa Pemberkatan Jenazah', 'Misa Requiem', 'Misa Pemakaman', 'Misa Arwah 7 Hari', 'Misa Arwah 40 Hari']
    return [{'itemName': names[i % len(names)], 'scheduledDate': future(start + i), 'scheduledTimeStart': f'{9 + i:02d}:00', 'scheduledTimeEnd': f'{10 + i:02d}:00', 'locationName': ['Rumah Duka', 'Gereja', 'Pemakaman'][i % 3]} for i in range(n)]


def new_ked(token, items=None, **over):
    items = mk_items() if items is None else items
    p = dict(serviceCategoryId=2, urgencyLevelId=1, scheduledDate=items[0]['scheduledDate'] if items else future(4), scheduledTime=items[0]['scheduledTimeStart'] if items else '09:00',
             locationName='Rumah Duka St. Carolus', addressDetail='Rumah Duka St. Carolus',
             notes=f'Misa: Pemberkatan | Nama Almarhum: Antonius Supardi | Hubungan: Ayah | Tgl Meninggal: 03/10/2026 | Waktu Meninggal: 21:30 | Catatan: {MARK}')
    if items:
        p['items'] = items
    p.update(over)
    p = {k: v for k, v in p.items() if v is not None}
    st, r = call('POST', '/orders', token, p)
    oid = int(r['order']['id']) if st in (200, 201) and isinstance(r, dict) and r.get('order') else None
    if oid:
        created_orders.append(oid)
    return st, r, oid


def item_ids(oid):
    return [int(x) for x in psql(f"select id from order_items where order_id={oid} order by id").split()]


def istat(iid):
    return psql(f"select status::text||'|'||coalesce(accepted_romo_id::text,'-')||'|'||coalesce(scheduled_date::text,'-')||'|'||coalesce(substring(scheduled_time_start::text,1,5),'-')||'|'||coalesce(reschedule_status,'-')||'|'||coalesce(handover_status,'-') from order_items where id={iid}")


def ostat(oid):
    return psql(f"select status::text||'|'||coalesce(accepted_romo_id::text,'-') from orders where id={oid}")


def grp(oid, iid):
    return psql(f"select id from chat_groups where order_id={oid} and order_item_id={iid}")


def gmembers(g):
    rows = psql(f"select user_id||':'||role_in_group from chat_group_members where chat_group_id={g} order by user_id")
    return rows.split('\n') if rows else []


def gtexts(g):
    return psql(f"select coalesce(string_agg(message, ' || ' order by id), '') from chat_messages where chat_group_id={g} and message_type='SYSTEM_EVENT'")


def nrows(user, oid, ntype):
    rows = psql(f"select id||':'||coalesce(chat_group_id::text,'-')||':'||title from notifications where user_id={user} and order_id={oid} and type='{ntype}' order by id")
    return rows.split('\n') if rows else []


def nrows_g(user, oid, ntype):
    rows = psql(f"select coalesce(chat_group_id::text,'-') from notifications where user_id={user} and order_id={oid} and type='{ntype}' order by id")
    return rows.split('\n') if rows else []


def nusers(oid, ntype):
    return sorted(int(x) for x in psql(f"select user_id from notifications where order_id={oid} and type='{ntype}'").split() if x)


def respond(tok, oid, status, romo, item=None):
    body = {'status': status, 'romoId': romo}
    if item:
        body['itemId'] = item
    return call('POST', f'/assignments/{oid}/respond', tok, body)


def sees(tok, query, oid):
    st, r = call('GET', '/orders' + query, tok)
    return any(str(o.get('id')) == str(oid) for o in lst(r))


base_resched = lambda romo: {'romoId': romo, 'newTimeStart': '19:00', 'newTimeEnd': '20:00', 'reason': 'Ada pelayanan mendadak di rumah sakit lain'}

try:
    print('=== A. PEMBUATAN MISA KEDUKAAN (multi-misa) ===')
    st, r, K1 = new_ked(T['UMAT'])
    num = (r or {}).get('order', {}).get('order_number') if K1 else None
    I = item_ids(K1) if K1 else []
    rec('A1', st == 201 and re.match(r'^MD-\d{8}-\d{4,}$', num or '') is not None and len(I) == 3 and ostat(K1).startswith('PENDING') and all(istat(i).startswith('PENDING') for i in I), 'Buat 3 misa -> 201, nomor MD-, order dan 3 misa PENDING', f"HTTP {st}; nomor={num}; misa={len(I)}")
    I1, I2, I3 = (I + [0, 0, 0])[:3]
    G = {i: grp(K1, i) for i in I}
    rec('A2', len(G) == 3 and all(G.values()) and len(set(G.values())) == 3, 'Satu grup chat terpisah per misa (3 grup)', f"grup={G}")
    mem = {i: gmembers(G[i]) for i in I}
    rec('A3', all('8:UMAT' in m and '9:PENGURUS_LINGKUNGAN' in m and '11:PENGURUS_LINGKUNGAN' in m for m in mem.values()) and all(not any(x.startswith(('12:', '13:', '45:')) for x in m) for m in mem.values()), 'Setiap grup misa berisi pemohon dan pengurus; belum ada Romo', f"anggota misa1={mem.get(I1)}")
    rows12 = nrows(12, K1, 'NEW_ORDER_ROMO')
    rec('A4', len(rows12) == 3 and all(nusers(K1, 'NEW_ORDER_ROMO').count(u) == 3 for u in (12, 13, 45)), 'Romo Paroki 256 menerima 1 notifikasi PER MISA (3 x), Romo paroki lain tidak', f"penerima={nusers(K1, 'NEW_ORDER_ROMO')}")
    rec('A5', all(nusers(K1, 'NEW_ORDER_MONITOR').count(u) == 3 for u in (9, 11)) and not nusers(K1, 'NEW_ORDER_KOORDINATOR') and 47 not in nusers(K1, 'NEW_ORDER_ROMO') and 50 not in nusers(K1, 'NEW_ORDER_ROMO'), 'Pengurus lingkungan diberi tahu per misa; Koordinator dan Romo Ordo belum', f"monitor={nusers(K1, 'NEW_ORDER_MONITOR')}")
    linked = [x.split(':')[1] for x in rows12]
    rec('A6', None, 'Notifikasi pembuatan menaut ke grup misa tertentu (chat_group_id) agar ketukan membuka misa yang tepat', f"chat_group_id per notifikasi Romo 12: {linked} (grup misa={list(G.values())})")
    st, r = call('POST', '/orders', T['UMAT'], {'serviceCategoryId': 2, 'urgencyLevelId': 1, 'scheduledDate': future(4), 'scheduledTime': '09:00', 'locationName': 'x', 'addressDetail': 'x', 'notes': MARK, 'items': [{'itemName': 'Misa', 'scheduledDate': '2020-01-01', 'scheduledTimeStart': '09:00', 'scheduledTimeEnd': '10:00', 'locationName': 'x'}]})
    rec('A7-lampau', st == 400, 'Tanggal misa yang sudah lewat ditolak', f"HTTP {st}; {msg(r)[:70]}")
    bad_time = mk_items(1); bad_time[0]['scheduledTimeStart'] = '25:99'
    st, r, oid = new_ked(T['UMAT'], items=bad_time)
    rec('A7-jam', st == 400, 'Jam misa tidak valid (25:99) ditolak', f"HTTP {st}; {msg(r)[:70]}")
    rev = mk_items(1); rev[0]['scheduledTimeStart'] = '11:00'; rev[0]['scheduledTimeEnd'] = '09:00'
    st, r, oid = new_ked(T['UMAT'], items=rev)
    rec('A7-selesai', st == 400, 'Jam selesai misa sebelum jam mulai ditolak', f"HTTP {st}" + (' (DITERIMA)' if oid else ''))
    empty = mk_items(1); empty[0]['itemName'] = ''
    st, r, oid = new_ked(T['UMAT'], items=empty)
    rec('A7-nama', st == 400, 'Nama misa kosong ditolak', f"HTTP {st}")
    longname = mk_items(1); longname[0]['itemName'] = 'M' * 5000
    st, r, oid = new_ked(T['UMAT'], items=longname)
    rec('A7-panjang', st == 400, 'Nama misa 5000 karakter ditolak', f"HTTP {st}" + (' (DITERIMA)' if oid else ''))
    longloc = mk_items(1); longloc[0]['locationName'] = 'L' * 5000
    st, r, oid = new_ked(T['UMAT'], items=longloc)
    rec('A7-lokasi', st == 400, 'Lokasi misa 5000 karakter ditolak', f"HTTP {st}" + (' (DITERIMA)' if oid else ''))
    st, r, oid = new_ked(T['UMAT'], items=mk_items(60))
    rec('A7-jumlah', st == 400, 'Jumlah misa dibatasi (60 misa ditolak)', f"HTTP {st}" + (f' (DITERIMA, {len(item_ids(oid))} misa dan {psql(f"select count(*) from chat_groups where order_id={oid}")} grup)' if oid else ''))
    st, r, oid = new_ked(T['UMAT'], items=[])
    rec('A8', st == 400 and not oid, 'Misa Kedukaan tanpa daftar misa ditolak', f"HTTP {st}; {msg(r)[:70]}")
    for urg, ok in ((1, True), (2, True), (3, True), (99, False)):
        st, r, oid = new_ked(T['UMAT'], items=mk_items(1), urgencyLevelId=urg)
        rec(f'A9-{urg}', (st == 201) == ok, f'Tingkat urgensi {urg} {"diterima" if ok else "ditolak"}', f"HTTP {st}")
    st, r, oid = new_ked(T['UMAT'], items=mk_items(1), notes='x' * 2001)
    rec('A10', st == 400, 'Catatan > 2000 karakter ditolak', f"HTTP {st}")
    special = f'Nama Almarhum: Maria "Ibu" O\'Brien | Catatan: baris1\nbaris2 🕊️ <b>tebal</b> ; DROP TABLE orders; -- {MARK}'
    st, r, oid = new_ked(T['UMAT'], items=mk_items(1, names=['Misa "Requiem" 🕊️ <i>khusus</i>']), notes=special)
    det = call('GET', f'/orders/{oid}', T['UMAT'])[1] if oid else {}
    ok11 = bool(det) and det.get('notes') == special and det['items'][0]['itemName'] == 'Misa "Requiem" 🕊️ <i>khusus</i>'
    rec('A11', st == 201 and ok11, 'Karakter khusus (kutip, emoji, HTML, baris baru, SQL) pada catatan dan nama misa tersimpan apa adanya dan aman', f"HTTP {st}; utuh={ok11}")
    big = 'data:image/png;base64,' + 'A' * 700_000
    st, r, oid = new_ked(T['UMAT'], items=mk_items(1), attachmentUrl=big)
    st2, r2 = call('GET', f'/orders/{oid}', T['UMAT']) if oid else (0, None)
    rec('A12', st == 201 and len((r2 or {}).get('attachmentUrl') or '') == len(big), 'Foto almarhum (data URL ~700 KB) diterima dan dapat dibaca kembali utuh', f"HTTP {st}; panjang kembali={len((r2 or {}).get('attachmentUrl') or '')}")
    huge = 'data:image/png;base64,' + 'A' * 16_000_000
    st, r, oid = new_ked(T['UMAT'], items=mk_items(1), attachmentUrl=huge)
    rec('A13', st in (400, 413), 'Foto lebih besar dari batas body (16 MB > 15 MB) ditolak dengan galat 4xx (bukan 500)', f"HTTP {st}")
    mid = 'data:image/png;base64,' + 'A' * 14_000_000
    st, r, oid = new_ked(T['UMAT'], items=mk_items(1), attachmentUrl=mid)
    rec('A13b', None, 'Foto ~14 MB (di bawah batas body 15 MB) diterima dan disimpan di database apa adanya (tanpa kompresi/batas khusus foto)', f"HTTP {st}")
    nums, lock = [], threading.Lock()
    def mk_once(i):
        s_, r_, o_ = new_ked(T['UMAT'], items=mk_items(2), notes=f'Nama Almarhum: Serentak {i} | Catatan: {MARK}')
        with lock:
            nums.append((s_, (r_ or {}).get('order', {}).get('order_number') if o_ else None))
    ths = [threading.Thread(target=mk_once, args=(i,)) for i in range(12)]
    [t_.start() for t_ in ths]; [t_.join() for t_ in ths]
    got = [n for _, n in nums if n]
    rec('A14', all(s_ == 201 for s_, _ in nums) and len(set(got)) == len(got) == 12 and all(n.startswith('MD-') for n in got), '12 pembuatan serentak: semuanya berhasil, nomor MD- unik', f"HTTP={sorted(set(s_ for s_, _ in nums))}; unik={len(set(got))}/{len(got)}")
    st, r = call('POST', '/orders', None, {})
    rec('A15', st == 401, 'Tanpa login ditolak', f"HTTP {st}")

    print('=== B. VISIBILITAS ===')
    st, r = call('GET', '/orders?romoId=12', T['ROMO'])
    o = next((x for x in lst(r) if str(x.get('id')) == str(K1)), None)
    rec('B1', o is not None and len(o.get('items', [])) == 3 and all(it.get('status') == 'PENDING' for it in o['items']), 'Romo Paroki melihat order beserta 3 misa berstatus PENDING', f"misa di daftar={len((o or {}).get('items', []))}")
    rec('B2', not sees(T['ROMO257'], '?romoId=47', K1) and not sees(T['ORDO'], '?romoId=50', K1), 'Romo paroki lain dan Romo Ordo (sebelum jeda) tidak melihat', '')
    rec('B3', not sees(T['PENG'], '?userId=9', K1) and not sees(T['PENG2'], '?userId=49', K1) and not sees(T['KOOR'], '?userId=53', K1), 'Beranda pengurus (se-lingkungan maupun lain) dan Koordinator tidak memuat pelayanan Umat; mereka cukup lewat notifikasi dan grup chat', '')
    rec('B3b', sees(T['UMAT'], '?userId=8', K1), 'Pemohon tetap melihat pelayanannya sendiri', '')
    st, r = call('GET', f'/orders/{K1}', T['UMAT'])
    st2, r2 = call('GET', f'/orders/{K1}', T['UMAT2'])
    rec('B4', st == 200 and len(r.get('items', [])) == 3 and st2 == 403, 'Pemohon membuka detail dengan 3 misa; umat lain 403', f"HTTP {st}/{st2}")
    st, r = call('GET', '/orders?userId=8', T['UMAT'])
    rec('B5', sees(T['UMAT'], '?userId=8', K1) and not sees(T['UMAT2'], '?userId=8', K1), 'Pemohon melihat di daftarnya; umat lain tidak walau meminta userId=8', '')

    print('=== C. PENERIMAAN PER MISA ===')
    st, r = respond(T['ORDO'], K1, 'CONFIRMED', 50, I1)
    rec('C1', st == 403 and istat(I1).startswith('PENDING'), 'Romo Ordo belum boleh menerima misa sebelum jeda', f"HTTP {st}")
    st, r = respond(T['ROMO257'], K1, 'CONFIRMED', 47, I3)
    rec('C2', st == 403 and istat(I3).startswith('PENDING'), 'Romo paroki lain (257) tidak boleh menerima misa', f"HTTP {st}")
    st, r = respond(T['ROMO'], K1, 'CONFIRMED', 12, I1)
    rec('C3', success(st, r) and istat(I1).startswith('CONFIRMED|12') and istat(I2).startswith('PENDING') and istat(I3).startswith('PENDING'), 'Romo 12 menerima misa 1 saja; misa 2 dan 3 tetap PENDING', f"misa1={istat(I1)}; misa2={istat(I2)}")
    rec('C4', ostat(K1).startswith('CONFIRMED'), 'Status order ikut CONFIRMED begitu ada misa yang diterima', f"order={ostat(K1)}")
    m1, m2, m3 = gmembers(G[I1]), gmembers(G[I2]), gmembers(G[I3])
    rec('C5', '12:ROMO_PAROKI' in m1 and not any(x.startswith('12:') for x in m2 + m3), 'Romo 12 hanya masuk grup misa 1, bukan grup misa 2 dan 3', f"misa1={m1}")
    rec('C6', 'mengkonfirmasi' in gtexts(G[I1]) and 'mengkonfirmasi' not in gtexts(G[I2]), 'Pesan sistem penerimaan hanya di grup misa 1', '')
    un = nrows(8, K1, 'ORDER_CONFIRMED')
    rec('C7', len(un) == 1 and 'Misa Pemberkatan' in un[0], 'Pemohon diberi tahu untuk misa yang diterima (judul memuat nama misa)', f"{un}")
    st, r = respond(T['ROMO2'], K1, 'CONFIRMED', 13, I2)
    rec('C8', success(st, r) and istat(I2).startswith('CONFIRMED|13') and istat(I3).startswith('PENDING'), 'Romo 13 menerima misa 2; misa 3 masih PENDING', f"misa2={istat(I2)}")
    st, r = respond(T['ROMO'], K1, 'CONFIRMED', 12, I1)
    rec('C9', 'sudah menerima' in msg(r).lower() and istat(I1).startswith('CONFIRMED|12'), 'Romo yang sama menerima misa yang sama lagi: tidak diproses ulang', msg(r)[:70])
    st, r = respond(T['ROMO'], K1, 'CONFIRMED', 12, I2)
    rec('C10', st == 409 and istat(I2).startswith('CONFIRMED|13'), 'Romo lain tidak dapat menimpa misa yang sudah diterima', f"HTTP {st}; {msg(r)[:60]}")
    race = []
    for trial in range(8):
        s_, r_, RK = new_ked(T['UMAT'], items=mk_items(2))
        RI = item_ids(RK); out = {}
        def go(n_, tok_, rid_):
            out[n_] = respond(tok_, RK, 'CONFIRMED', rid_, RI[0])
        ths = [threading.Thread(target=go, args=('a', T['ROMO'], 12)), threading.Thread(target=go, args=('b', T['ROMO2'], 13))]
        [t_.start() for t_ in ths]; [t_.join() for t_ in ths]
        codes = sorted(out[k][0] for k in out)
        acc = istat(RI[0]).split('|')[1]
        mm = psql(f"select string_agg(user_id::text, ',') from chat_group_members where chat_group_id={grp(RK, RI[0])} and role_in_group like 'ROMO%'")
        race.append((codes == [201, 409] and mm == acc, codes, acc, mm))
    rec('C11', all(x[0] for x in race), 'Dua Romo menerima MISA YANG SAMA bersamaan (8 percobaan): satu menang, satu 409, hanya pemenang di grup misa', f"bermasalah={[x for x in race if not x[0]]}")
    s_, r_, RK2 = new_ked(T['UMAT'], items=mk_items(2))
    RI2 = item_ids(RK2)
    ths = [threading.Thread(target=lambda: respond(T['ROMO'], RK2, 'CONFIRMED', 12, RI2[0])), threading.Thread(target=lambda: respond(T['ROMO2'], RK2, 'CONFIRMED', 13, RI2[1]))]
    [t_.start() for t_ in ths]; [t_.join() for t_ in ths]
    rec('C12', istat(RI2[0]).startswith('CONFIRMED|12') and istat(RI2[1]).startswith('CONFIRMED|13') and ostat(RK2).startswith('CONFIRMED'), 'Dua Romo menerima MISA BERBEDA bersamaan: keduanya berhasil', f"misa1={istat(RI2[0])}; misa2={istat(RI2[1])}; order={ostat(RK2)}")
    s_, r_, RK3 = new_ked(T['UMAT'], items=mk_items(2))
    RI3 = item_ids(RK3)
    st, r = respond(T['ROMO'], RK3, 'CONFIRMED', 12)
    rec('C13', None, 'Menerima tanpa menyebut misa pada order multi-misa (perilaku saat ini)', f"HTTP {st}; order={ostat(RK3)}; misa={[istat(i).split('|')[:2] for i in RI3]}")
    st, r = respond(T['ROMO'], K1, 'CONFIRMED', 12, I3)
    rec('C14', success(st, r) and istat(I3).startswith('CONFIRMED|12') and ostat(K1).startswith('CONFIRMED'), 'Romo 12 menerima misa 3: semua misa kini CONFIRMED', f"order={ostat(K1)}")

    print('=== D. UBAH JAM PER MISA ===')
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I1})
    rec('D1', success(st, r) and istat(I1).split('|')[4] == 'PENDING_UMAT' and istat(I2).split('|')[4] in ('NONE', '-') and istat(I3).split('|')[4] in ('NONE', '-'), 'Romo 12 mengajukan ubah jam misa 1: hanya misa 1 yang PENDING_UMAT', f"misa1={istat(I1)}; misa2={istat(I2)}")
    rows = nrows(8, K1, 'RESCHEDULE_PROPOSED')
    rec('D2', len(rows) == 1 and rows[0].split(':')[1] == G[I1], 'Notifikasi ajuan menaut ke grup misa 1 (ketukan membuka misa yang tepat)', f"{rows}; grup misa1={G[I1]}")
    rec('D3', 'perubahan jadwal' in gtexts(G[I1]).lower() and 'perubahan jadwal' not in gtexts(G[I2]).lower() and 'Misa Pemberkatan' in gtexts(G[I1]), 'Pesan ajuan (memuat nama misa) hanya di grup misa 1', f"misa1: {gtexts(G[I1])[-110:]}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO2'], base_resched(13) | {'itemId': I3})
    rec('D4', bsc(r) == 403, 'Romo 13 (bukan pemegang misa 3) tidak dapat mengajukan ubah jam misa 3', f"body={bsc(r)}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I2})
    rec('D5', bsc(r) == 403, 'Romo 12 tidak dapat mengajukan ubah jam misa 2 milik Romo 13', f"body={bsc(r)}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I1})
    rec('D6', st in (400, 409), 'Ajuan baru ditolak selagi ajuan misa 1 menunggu respons', f"HTTP {st}; {msg(r)[:70]}")
    st, r = call('POST', f'/orders/{K1}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': I1, 'action': 'REJECT'})
    rec('D7', success(st, r) and r.get('rejectedCount') == 1 and r.get('rescheduleClosed') is False and '1 kali lagi' in gtexts(G[I1]), 'Penolakan ke-1 misa 1: masih ada kesempatan (pesan di grup misa 1)', f"{json.dumps(r)[:110]}")
    call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I1})
    st, r = call('POST', f'/orders/{K1}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': I1, 'action': 'REJECT'})
    rec('D8', success(st, r) and r.get('rescheduleClosed') is True and len(nrows(12, K1, 'RESCHEDULE_CLOSED')) >= 1, 'Penolakan ke-2 misa 1: DITUTUP dan Romo 12 diberi tahu', f"{json.dumps(r)[:110]}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I1})
    rec('D9', st in (400, 403), 'Misa 1: ajuan baru ditolak setelah ditutup', f"HTTP {st}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO2'], base_resched(13) | {'itemId': I2})
    rec('D10', success(st, r), 'Misa 2 tidak terpengaruh penutupan misa 1: Romo 13 masih dapat mengajukan (hitungan penolakan per misa)', f"HTTP {st}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{K1}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': I2, 'action': 'ACCEPT'})
    rec('D11', success(st, r) and f'|{future(5)}|19:00' in istat(I2) and istat(I2).split('|')[4] == 'ACCEPTED' and istat(I1).split('|')[2] == future(4) and istat(I3).split('|')[2] == future(6), 'Ubah jam misa 2 diterima: hanya JAM misa 2 yang berubah (19:00), tanggal tetap; status "Ubah Jam Diterima" hanya di misa 2', f"misa1={istat(I1)}; misa2={istat(I2)}; misa3={istat(I3)}")
    st, r = call('POST', f'/orders/{K1}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': I2, 'action': 'ACCEPT'})
    rec('D12', st == 409, 'Merespons ajuan misa yang sudah selesai ditolak (409)', f"HTTP {st}")
    other = int(psql(f"select id from order_items where order_id <> {K1} limit 1") or 0)
    st, r = call('POST', f'/orders/{K1}/reschedule/respond', T['UMAT'], {'userId': 8, 'itemId': other, 'action': 'ACCEPT'})
    rec('D13', st in (404, 409), 'itemId milik order lain ditolak', f"HTTP {st}; {msg(r)[:50]}")
    ord_date = psql(f"select scheduled_date::text from orders where id={K1}")
    rec('D14', ord_date == future(4), 'Jadwal tingkat order tidak ikut berubah saat jam sebuah misa diubah', f"order.scheduled_date={ord_date} (tanggal misa 1={future(4)})")
    rec('D15', istat(I1).split('|')[4] == 'REJECTED' and istat(I3).split('|')[4] in ('NONE', '-'), 'Status ubah jam per misa: misa 1 "Ditolak", misa 3 belum pernah mengajukan', f"misa1={istat(I1)}; misa3={istat(I3)}")
    st, r = call('POST', f'/orders/{K1}/reschedule/propose', T['ROMO'], base_resched(12) | {'itemId': I1, 'newDate': future(9)})
    rec('D16', st == 400 and 'tidak dapat mengubah tanggal' in msg(r).lower(), 'Ubah jam yang menyertakan tanggal berbeda ditolak (400)', f"HTTP {st}; {msg(r)[:80]}")

    print('=== E. PELIMPAHAN PER MISA ===')
    st, r = call('POST', f'/orders/{K1}/handover', T['ROMO'], {'romoId': 12, 'itemId': I1, 'targetRomoId': 13, 'reason': 'Berhalangan hadir di misa pemberkatan'})
    rec('E1', success(st, r) and istat(I1).split('|')[5] == 'PENDING' and istat(I3).split('|')[5] in ('NONE', '-'), 'Romo 12 melimpahkan misa 1 ke Romo 13: hanya misa 1 PENDING', f"misa1={istat(I1)}; misa3={istat(I3)}")
    rows = nrows(13, K1, 'ROMO_HANDOVER')
    rec('E2', len(rows) >= 1 and rows[0].split(':')[1] == G[I1], 'Notifikasi ke Romo 13 menaut ke grup misa 1', f"{rows}")
    st, r = call('POST', f'/orders/{K1}/handover', T['ROMO'], {'romoId': 12, 'itemId': I1, 'targetRomoId': 45, 'reason': 'ajuan kedua'})
    rec('E3', st == 409, 'Pelimpahan kedua untuk misa yang sama ditolak selagi menunggu', f"HTTP {st}")
    st, r = call('POST', f'/orders/{K1}/handover/respond', T['ROMO3'], {'romoId': 45, 'itemId': I1, 'action': 'ACCEPT'})
    rec('E4', bsc(r) == 403 and istat(I1).startswith('CONFIRMED|12'), 'Romo yang bukan target tidak dapat menerima pelimpahan', f"body={bsc(r)}")
    st, r = call('POST', f'/orders/{K1}/handover/respond', T['ROMO2'], {'romoId': 13, 'itemId': I1, 'action': 'REJECT'})
    rec('E5', success(st, r) and istat(I1).startswith('CONFIRMED|12'), 'Romo 13 menolak: misa 1 tetap pada Romo 12', f"misa1={istat(I1)}")
    call('POST', f'/orders/{K1}/handover', T['ROMO'], {'romoId': 12, 'itemId': I1, 'targetRomoId': 13, 'reason': 'Berhalangan hadir (ajuan ulang)'})
    st, r = call('POST', f'/orders/{K1}/handover/respond', T['ROMO2'], {'romoId': 13, 'itemId': I1, 'action': 'ACCEPT'})
    rec('E6', success(st, r) and istat(I1).startswith('CONFIRMED|13') and istat(I3).startswith('CONFIRMED|12') and istat(I2).startswith('CONFIRMED|13'), 'Romo 13 menerima pelimpahan: misa 1 pindah ke Romo 13; misa 3 tetap Romo 12', f"misa1={istat(I1)}; misa3={istat(I3)}")
    m1 = gmembers(G[I1])
    rec('E7', '13:ROMO_PAROKI' in m1, 'Romo 13 masuk grup misa 1', f"anggota misa1={m1}")
    rec('E8', '12:ROMO_PAROKI' not in m1, 'Romo lama (12) keluar dari grup misa 1 setelah pelimpahan diterima', f"anggota misa1={m1}")
    st, r = call('POST', f'/orders/{K1}/handover', T['ROMO2'], {'romoId': 13, 'itemId': I1, 'targetRomoId': 45, 'reason': 'dilimpahkan lagi'})
    rec('E9', bsc(r) == 400, 'Misa hasil pelimpahan tidak dapat dilimpahkan lagi', f"body={bsc(r)}")
    st, r = call('POST', f'/orders/{K1}/handover', T['ROMO2'], {'romoId': 13, 'itemId': I2, 'targetRomoId': 13, 'reason': 'sendiri'})
    rec('E10', st == 400, 'Melimpahkan ke diri sendiri ditolak', f"HTTP {st}")
    st, r = call('POST', f'/orders/{K1}/handover', T['ROMO2'], {'romoId': 13, 'itemId': I2, 'targetRomoId': 8, 'reason': 'ke umat'})
    rec('E11', st == 400, 'Melimpahkan ke akun yang bukan Romo ditolak', f"HTTP {st}")
    s_, r_, RK4 = new_ked(T['UMAT'], items=mk_items(2))
    RI4 = item_ids(RK4)
    st, r = call('POST', f'/orders/{RK4}/handover', T['ROMO'], {'romoId': 12, 'itemId': RI4[0], 'targetRomoId': 13, 'reason': 'misa belum diterima'})
    rec('E12', st == 409, 'Melimpahkan misa yang belum diterima ditolak', f"HTTP {st}")
    respond(T['ROMO'], RK4, 'CONFIRMED', 12, RI4[0])
    st, r = call('POST', f'/orders/{RK4}/handover', T['ROMO'], {'romoId': 12, 'itemId': RI4[0], 'externalRomoName': 'Romo Eksternal Uji', 'reason': 'Berhalangan hadir'})
    rec('E13', success(st, r), 'Pelimpahan misa ke Romo eksternal (belum terdaftar) berhasil', f"HTTP {st}; misa={istat(RI4[0])}; external={psql(f'select coalesce(external_romo_name,chr(45)) from order_items where id={RI4[0]}')}; misa2={istat(RI4[1]).split('|')[0]}")

    print('=== F. PELAKSANAAN & PENYELESAIAN PER MISA ===')
    st, r = respond(T['ROMO2'], K1, 'IN_PROGRESS', 13, I1)
    rec('F1', success(st, r) and istat(I1).startswith('IN_PROGRESS|13'), 'Romo 13 memulai misa 1', istat(I1))
    st, r = respond(T['ROMO'], K1, 'DONE', 12, I2)
    rec('F2', st == 403 and istat(I2).startswith('CONFIRMED'), 'Romo 12 tidak dapat menyelesaikan misa 2 milik Romo 13', f"HTTP {st}")
    st, r = respond(T['ROMO2'], K1, 'DONE', 13, I1)
    rec('F3', success(st, r) and istat(I1).startswith('DONE|13') and ostat(K1).startswith('CONFIRMED'), 'Misa 1 DONE; order tetap CONFIRMED karena misa lain belum selesai', f"order={ostat(K1)}")
    rec('F4', any('Misa Pemberkatan' in x for x in nrows(8, K1, 'ORDER_DONE')), 'Pemohon diberi tahu misa 1 selesai (judul memuat nama misa)', f"{nrows(8, K1, 'ORDER_DONE')}")
    for to in ('CONFIRMED', 'IN_PROGRESS', 'CLOSE'):
        st, r = respond(T['ROMO2'], K1, to, 13, I1)
        rec(f'F5-{to}', st == 409 and istat(I1).startswith('DONE'), f'Misa 1 yang sudah DONE tidak dapat diubah ke {to}', f"HTTP {st}")
    st, r = respond(T['ROMO2'], K1, 'FAIL', 13, I2)
    rec('F6', st in (403, 409) and istat(I2).startswith('CONFIRMED'), 'FAIL pada misa tidak dapat ditetapkan Romo', f"HTTP {st}")
    respond(T['ROMO2'], K1, 'DONE', 13, I2)
    st, r = respond(T['ROMO'], K1, 'DONE', 12, I3)
    rec('F7', istat(I2).startswith('DONE') and istat(I3).startswith('DONE') and ostat(K1).startswith('DONE'), 'Semua misa DONE -> order otomatis DONE', f"order={ostat(K1)}; misa={[istat(i).split('|')[0] for i in I]}")
    s_, r_, MK = new_ked(T['UMAT'], items=mk_items(2))
    MI = item_ids(MK)
    respond(T['ROMO'], MK, 'CONFIRMED', 12, MI[0]); respond(T['ROMO'], MK, 'CONFIRMED', 12, MI[1])
    respond(T['ROMO'], MK, 'DONE', 12, MI[0]); respond(T['ROMO'], MK, 'CLOSE', 12, MI[1])
    rec('F8', ostat(MK).split('|')[0] in ('DONE', 'CLOSE'), 'Campuran final (misa 1 DONE, misa 2 CLOSE): order menjadi final (DONE/CLOSE), bukan PENDING', f"order={ostat(MK)}; misa={[istat(i).split('|')[0] for i in MI]}")
    s_, r_, MK2 = new_ked(T['UMAT'], items=mk_items(2))
    MI2 = item_ids(MK2)
    respond(T['ROMO'], MK2, 'CONFIRMED', 12, MI2[0]); respond(T['ROMO'], MK2, 'CONFIRMED', 12, MI2[1]); respond(T['ROMO'], MK2, 'DONE', 12, MI2[0])
    rec('F9', ostat(MK2).startswith('CONFIRMED'), 'Misa 1 DONE, misa 2 masih CONFIRMED: order tetap CONFIRMED', f"order={ostat(MK2)}")
    st, r = call('PUT', f'/auth/admin/orders/{MK2}/status', T['ADMIN'], {'status': 'DONE'})
    rec('F10', None, 'Admin menetapkan status order DONE pada order multi-misa (perilaku saat ini)', f"HTTP {st}; order={ostat(MK2)}; misa={[istat(i).split('|')[0] for i in MI2]} (status misa tidak ikut berubah)")

    print('=== G. ULASAN PER MISA ===')
    for i, rating, who in ((I1, 5, 13), (I2, 3, 13), (I3, 4, 12)):
        st, r = call('POST', f'/orders/{K1}/review', T['UMAT'], {'itemId': i, 'rating': rating, 'reviewNotes': f'Ulasan misa {i}'})
        rec(f'G1-{i}', success(st, r) and psql(f"select rating from order_items where id={i}") == str(rating), f'Ulasan misa {i} ({rating} bintang) tersimpan pada misa itu', f"HTTP {st}; {msg(r)[:50]}")
    rec('G2', all(psql(f"select rating from order_items where id={i}") == str(v) for i, v in ((I1, 5), (I2, 3), (I3, 4))), 'Setiap misa menyimpan ulasannya sendiri', '')
    st, r = call('POST', f'/orders/{K1}/review', T['UMAT'], {'itemId': I1, 'rating': 1, 'reviewNotes': 'ulasan ulang'})
    rec('G3', st == 409 and psql(f"select rating from order_items where id={I1}") == '5', 'Ulasan kedua untuk misa yang sama ditolak (409)', f"HTTP {st}")
    st, r = call('POST', f'/orders/{K1}/review', T['UMAT'], {'itemId': other, 'rating': 5, 'reviewNotes': 'misa order lain'})
    rec('G4', st in (404, 409), 'Ulasan untuk misa milik order lain ditolak', f"HTTP {st}")
    st, r = call('POST', f'/orders/{K1}/review', T['UMAT2'], {'itemId': I1, 'rating': 5, 'reviewNotes': 'bukan pemohon'})
    rec('G5', st == 403, 'Umat lain tidak dapat mengulas', f"HTTP {st}")
    s_, r_, GK = new_ked(T['UMAT'], items=mk_items(2))
    GI = item_ids(GK)
    respond(T['ROMO'], GK, 'CONFIRMED', 12, GI[0]); respond(T['ROMO'], GK, 'CONFIRMED', 12, GI[1]); respond(T['ROMO'], GK, 'DONE', 12, GI[0])
    st, r = call('POST', f'/orders/{GK}/review', T['UMAT'], {'itemId': GI[1], 'rating': 5, 'reviewNotes': 'misa belum selesai'})
    rec('G6', st == 400, 'Ulasan untuk misa yang belum selesai ditolak (misa 1 DONE, misa 2 masih CONFIRMED)', f"HTTP {st}; order={ostat(GK)}")
    st, r = call('POST', f'/orders/{MK2}/review', T['UMAT'], {'itemId': MI2[1], 'rating': 5, 'reviewNotes': 'misa belum selesai'})
    rec('G6b', st == 400, 'Ulasan untuk misa yang belum selesai ditolak walau status ORDER sudah DONE (hasil override Admin)', f"HTTP {st}; order={ostat(MK2)}; misa={istat(MI2[1]).split('|')[0]}")
    st, r = call('POST', f'/orders/{K1}/review', T['UMAT'], {'itemId': I2, 'rating': 9, 'reviewNotes': 'x'})
    rec('G7', st == 400, 'Rating di luar 1-5 ditolak', f"HTTP {st}")
    rec('G8', any(x for x in nrows(13, K1, 'ORDER_REVIEW')) and any(x for x in nrows(12, K1, 'ORDER_REVIEW')), 'Romo yang bertugas pada tiap misa diberi tahu ada ulasan (13 untuk misa 1-2, 12 untuk misa 3)', f"13={len(nrows(13, K1, 'ORDER_REVIEW'))}; 12={len(nrows(12, K1, 'ORDER_REVIEW'))}")
    rec('G9', None, 'Rating tingkat order setelah ulasan per misa (perilaku saat ini)', f"orders.rating={psql(f'select coalesce(rating::text,chr(45)) from orders where id={K1}')} (misa: 5, 3, 4)")
    st, r = call('POST', f'/orders/{K1}/review', T['UMAT'], {'rating': 5, 'reviewNotes': 'Ulasan keseluruhan'})
    rec('G10', None, 'Ulasan tingkat order (tanpa misa) setelah semua misa diulas (perilaku saat ini)', f"HTTP {st}; {msg(r)[:70]}")

    print('=== H. CHAT PER MISA ===')
    gid = {i: G[i] for i in I}
    call('POST', f'/chat/groups/{gid[I3]}/messages', T['UMAT'], {'messageType': 'TEXT', 'message': 'Mohon Romo untuk misa pemakaman'})
    cnt = lambda g: psql(f"select count(*) from chat_messages where chat_group_id={g} and message_type='TEXT'")
    rec('H1', cnt(gid[I3]) == '1' and cnt(gid[I1]) == '0' and cnt(gid[I2]) == '0', 'Pesan di grup misa 3 tidak muncul di grup misa 1 dan 2', f"misa1={cnt(gid[I1])} misa2={cnt(gid[I2])} misa3={cnt(gid[I3])}")
    codes = {}
    for who, tok in (('ROMO', T['ROMO']), ('ROMO2', T['ROMO2'])):
        for i in I:
            codes[(who, i)] = call('GET', f'/chat/groups/{gid[i]}/messages', tok)[0]
    rec('H2', codes[('ROMO2', I1)] == 200 and codes[('ROMO2', I2)] == 200 and codes[('ROMO2', I3)] == 403 and codes[('ROMO', I3)] == 200 and codes[('ROMO', I2)] == 403, 'Romo hanya membaca grup misa yang ia pegang (13: misa 1-2; 12: misa 3), bukan misa Romo lain', f"{ {f'{w}/misa{I.index(i) + 1}': c for (w, i), c in codes.items()} }")
    st, r = call('GET', f'/chat/order/{K1}?itemId={I2}', T['UMAT'])
    st2, r2 = call('GET', f'/chat/order/{K1}', T['UMAT'])
    rec('H3', (r or {}).get('groupId') is not None and str(r['groupId']) == gid[I2] and str(r2['groupId']) == gid[I1], 'Mencari grup menurut itemId mengembalikan grup misa itu; tanpa itemId = grup misa pertama', f"itemId={I2} -> {r}; tanpa -> {r2}")
    cmn = nusers(K1, 'CHAT_MESSAGE')
    last = psql(f"select string_agg(distinct user_id::text, ',') from notifications where order_id={K1} and type='CHAT_MESSAGE' and chat_group_id={gid[I3]}")
    rec('H4', '12' in last.split(',') and '13' not in last.split(',') and '9' in last.split(','), 'Notifikasi pesan grup misa 3 hanya ke anggota grup itu (Romo 12 dan pengurus; bukan Romo 13)', f"penerima grup misa3={last}")
    st, r = call('GET', f'/chat/user/12/groups', T['ROMO'])
    rows = r if isinstance(r, list) else (r or {}).get('groups', [])
    mine = sorted(str(x.get('group_id') or x.get('groupId')) for x in rows if str(x.get('order_id') or x.get('orderId')) == str(K1))
    rec('H5', gid[I3] in mine and gid[I2] not in mine, 'Daftar chat Romo 12 memuat grup misa miliknya dan tidak memuat grup misa Romo lain', f"grup Romo 12 di order ini={mine}")
    st, r = call('GET', f'/chat/groups/{gid[I1]}/messages', T['KOOR'])
    st2, r2 = call('GET', f'/chat/groups/{gid[I1]}/messages', T['KOOR_OUT'])
    rec('H6', st == 200 and st2 == 403, 'Koordinator se-keuskupan dapat membaca; keuskupan lain 403', f"{st}/{st2}")

    print('=== I. ESKALASI ROMO ORDO & KOORDINATOR PER MISA ===')
    s_, r_, EK = new_ked(T['UMAT'], items=mk_items(3, names=['Misa A', 'Misa B', 'Misa C']))
    EI = item_ids(EK)
    respond(T['ROMO'], EK, 'CONFIRMED', 12, EI[0])
    s_, r_, EK2 = new_ked(T['UMAT'], items=mk_items(2, names=['Misa D', 'Misa E']))
    EI2 = item_ids(EK2)
    psql(f"update orders set created_at = now() - interval '11 minutes' where id={EK}; update orders set created_at = now() - interval '21 minutes' where id={EK2}")
    time.sleep(22)
    EG = sorted(grp(EK, i) for i in EI[1:])   # misa A sudah diterima Romo 12 sebelum eskalasi: hanya misa B dan C yang dieskalasi
    rec('I1', {50, 60} <= set(nusers(EK, 'NEW_ORDER_ROMO')) and not nusers(EK, 'NEW_ORDER_KOORDINATOR') and sorted(nrows_g(50, EK, 'NEW_ORDER_ROMO')) == EG, 'Lewat 10 menit: Romo Ordo diberi tahu per misa yang belum punya Romo (misa B dan C; misa A sudah diterima) - tiap notifikasi menaut ke grup misanya; Koordinator belum', f"romo={nusers(EK, 'NEW_ORDER_ROMO')}; notif Romo Ordo 50 -> grup {nrows_g(50, EK, 'NEW_ORDER_ROMO')}; grup misa={EG}")
    rec('I2', sees(T['ORDO'], '?romoId=50', EK), 'Romo Ordo kini melihat order di daftarnya', '')
    st, r = respond(T['ORDO'], EK, 'CONFIRMED', 50, EI[0])
    rec('I3', st == 409 and istat(EI[0]).startswith('CONFIRMED|12'), 'Romo Ordo tidak dapat menimpa misa yang sudah diterima Romo Paroki', f"HTTP {st}")
    st, r = respond(T['ORDO_OUT'], EK, 'CONFIRMED', 48, EI[1])
    rec('I4', st == 403 and istat(EI[1]).startswith('PENDING'), 'Romo Ordo kota lain (3173) tidak dapat menerima', f"HTTP {st}")
    st, r = respond(T['ORDO'], EK, 'CONFIRMED', 50, EI[1])
    rec('I5', success(st, r) and istat(EI[1]).startswith('CONFIRMED|50') and istat(EI[2]).startswith('PENDING'), 'Romo Ordo kota pelayanan menerima misa B; misa C tetap PENDING', f"misaB={istat(EI[1])}")
    EG2 = sorted(grp(EK2, i) for i in EI2)
    kk = {k: sorted(nrows_g(k, EK2, 'NEW_ORDER_KOORDINATOR')) for k in (10, 51, 53)}
    rec('I6', all(v == EG2 for v in kk.values()), 'Lewat 20 menit: Koordinator diberi tahu per misa yang belum punya Romo (2 misa -> 2 notifikasi, tiap satu menaut ke grup misanya)', f"{kk}; grup misa={EG2}")
    rec('I7', all(any(x.startswith('53:KOORDINATOR') for x in gmembers(grp(EK2, i))) for i in EI2), 'Koordinator masuk grup chat SEMUA misa pada order itu', f"anggota misa D={gmembers(grp(EK2, EI2[0]))}")
    st, r = call('GET', f'/orders/{EK2}/koordinator-assignment', T['KOOR'])
    rec('I8', st == 200 and r.get('state') == 'OPEN' and sorted(r.get('pendingItemIds', [])) == sorted(EI2), 'Carikan Romo terbuka dan menampilkan kedua misa yang belum diterima', f"state={(r or {}).get('state')}; pending={(r or {}).get('pendingItemIds')}")
    st, r = call('POST', f'/orders/{EK2}/koordinator-assignment', T['KOOR'], {'romoId': 12, 'itemId': EI2[0]})
    rec('I9', st in (200, 201) and istat(EI2[0]).startswith('CONFIRMED|12') and istat(EI2[1]).startswith('PENDING'), 'Koordinator menetapkan Romo 12 hanya untuk misa D; misa E tetap menunggu', f"misaD={istat(EI2[0])}; misaE={istat(EI2[1])}")
    st, r = call('POST', f'/orders/{EK2}/koordinator-assignment', T['KOOR'], {'romoId': 13})
    rec('I10', st in (200, 201) and istat(EI2[1]).startswith('CONFIRMED|13') and ostat(EK2).startswith('CONFIRMED'), 'Penetapan tanpa misa menetapkan sisa misa yang belum diterima; order CONFIRMED', f"misaE={istat(EI2[1])}; order={ostat(EK2)}")
    st, r = call('GET', f'/orders/{EK2}/koordinator-assignment', T['KOOR'])
    rec('I11', (r or {}).get('state') == 'CLOSED', 'Setelah semua misa punya Romo, Carikan Romo tertutup', f"state={(r or {}).get('state')}")
    s_, r_, EK3 = new_ked(T['UMAT'], items=mk_items(2, names=['Misa F', 'Misa G']))
    EI3 = item_ids(EK3)
    psql(f"update orders set created_at = now() - interval '21 minutes' where id={EK3}")
    phone = '62813000007' + str(int(time.time()) % 100).zfill(2)
    created_users.append(phone)
    st, r = call('POST', f'/orders/{EK3}/koordinator-assignment/register-romo', T['KOOR'], {'fullName': 'Romo Baru Kedukaan Uji', 'phoneNumber': phone, 'roleCode': 'ROMO_PAROKI', 'parokiId': 256, 'itemId': EI3[0]})
    rid = (r or {}).get('romo', {}).get('id')
    rec('I12', st in (200, 201) and r.get('assigned') is True and istat(EI3[0]).startswith(f'CONFIRMED|{rid}') and istat(EI3[1]).startswith('PENDING'), 'Koordinator mendaftarkan Romo baru untuk misa F saja: akun aktif dan misa F otomatis diterima; misa G menunggu', f"misaF={istat(EI3[0])}; misaG={istat(EI3[1])}")

    print('=== J. STATUS OTOMATIS LEWAT TANGGAL (per misa) ===')
    s_, r_, J1 = new_ked(T['UMAT'], items=mk_items(2, names=['Misa lampau', 'Misa mendatang']))
    JI1 = item_ids(J1)
    psql(f"update order_items set scheduled_date = current_date - 1 where id={JI1[0]}; update order_items set scheduled_date = current_date + 3 where id={JI1[1]}; update orders set scheduled_date = current_date - 1 where id={J1}")
    s_, r_, J2 = new_ked(T['UMAT'], items=mk_items(2, names=['Misa lama', 'Misa mendatang']))
    JI2 = item_ids(J2)
    respond(T['ROMO'], J2, 'CONFIRMED', 12, JI2[0]); respond(T['ROMO'], J2, 'CONFIRMED', 12, JI2[1])
    psql(f"update order_items set scheduled_date = current_date - 2 where id={JI2[0]}; update order_items set scheduled_date = current_date + 2 where id={JI2[1]}; update orders set scheduled_date = current_date - 2 where id={J2}")
    sh(f"docker compose -f {COMPOSE} restart backend >/dev/null 2>&1"); time.sleep(20)
    for k in ('ROMO', 'UMAT', 'ADMIN'):
        T[k] = jwt({'ROMO': 12, 'UMAT': 8, 'ADMIN': 52}[k], {'ROMO': 'ROMO_PAROKI', 'UMAT': 'UMAT', 'ADMIN': 'ADMIN'}[k])
    call('GET', '/orders?userId=8', T['UMAT'])
    rec('J1', istat(JI1[0]).startswith('FAIL') and istat(JI1[1]).startswith('PENDING'), 'Misa lampau tanpa Romo menjadi FAIL; misa mendatang tetap PENDING', f"lampau={istat(JI1[0]).split('|')[0]}; mendatang={istat(JI1[1]).split('|')[0]}")
    rec('J2', not ostat(J1).startswith('FAIL'), 'Order TIDAK menjadi FAIL selama masih ada misa mendatang yang menunggu Romo', f"order={ostat(J1)}")
    st, r = respond(T['ROMO'], J1, 'CONFIRMED', 12, JI1[1])
    rec('J3', st in (200, 201) and istat(JI1[1]).startswith('CONFIRMED') and not ostat(J1).startswith('FAIL'), 'Misa mendatang masih dapat diterima Romo dan order tidak berstatus FAIL', f"HTTP {st}; misa={istat(JI1[1]).split('|')[0]}; order={ostat(J1)}")
    rec('J4', istat(JI2[0]).startswith('CLOSE') and istat(JI2[1]).startswith('CONFIRMED'), 'Misa lama (diterima, lewat 2 hari) CLOSE; misa mendatang tetap CONFIRMED', f"lama={istat(JI2[0]).split('|')[0]}; mendatang={istat(JI2[1]).split('|')[0]}")
    rec('J5', not ostat(J2).startswith('CLOSE'), 'Order TIDAK menjadi CLOSE selama masih ada misa mendatang yang aktif', f"order={ostat(J2)}")

finally:
    print('=== Pembersihan ===')
    if isinstance(_orig, dict) and 'ordoAfterMinutes' in _orig:
        call('PUT', '/master/escalation-settings', T['SUPER'], _orig)
        print('parameter eskalasi dipulihkan ke', _orig)
    purge()
    print('sisa order uji:', psql(f"select count(*) from orders where notes like '%{MARK}%'"), '| sisa akun uji:', psql("select count(*) from auth_users where phone_number like '62813000007%'"))

sys.exit(summary())
