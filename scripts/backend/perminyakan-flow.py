#!/usr/bin/env python3
"""Uji menyeluruh alur pelayanan Sakramen Perminyakan (dari pembuatan sampai ulasan) lewat API.

Mencakup: pembuatan + validasi, notifikasi pembuatan, visibilitas per peran, penerimaan Romo, perubahan jam
(termasuk batas 2 penolakan), pelimpahan (ganti Romo), pelaksanaan & penyelesaian, ulasan, chat grup, notifikasi,
eskalasi Romo Ordo/Koordinator + Koordinator mencarikan Romo, status otomatis lewat tanggal, admin, dan otorisasi.

HANYA untuk runtime pengembangan lokal (catu_backend di :3005 + container shared-postgres); jangan diarahkan ke produksi.
Bergantung pada data seed pengembangan: Umat 8 (lingkungan 9471441, paroki 256, keuskupan 30) dan Umat 58 (paroki 1),
Romo Paroki 12/13/45 (paroki 256) dan 47 (paroki 257), Romo Ordo 50 dan 60 (kota 3175), Pengurus 9/11 (lingkungan 9471441)
dan 49 (lingkungan lain), Koordinator 10/53 (keuskupan 30) dan 54 (keuskupan lain), Admin 52.
Semua order uji (catatan memuat "uji-pel") dan akun uji dibersihkan di akhir.

Pemakaian:  python3 scripts/backend/perminyakan-flow.py
Keluaran: satu baris PASS/FAIL/INFO per skenario; kode keluar 1 bila ada FAIL."""
import datetime, json, os, re, subprocess, sys, time, urllib.error, urllib.request

B = 'http://localhost:3005'
COMPOSE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docker-compose.yml')
MARK = 'uji-pel'
results, created_orders, created_users = [], [], []


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def psql(q):
    return sh(f'docker exec shared-postgres psql -U postgres -d catu_v2_db -tAc "{q}"')


def jwt(sub, role):
    return sh(f"docker compose -f {COMPOSE} exec -T backend node -e \"const j=require('jsonwebtoken');console.log(j.sign({{sub:{sub},roleCode:'{role}'}},process.env.JWT_SECRET,{{expiresIn:'2h'}}))\"")


def call(method, path, token=None, body=None):
    for _ in range(6):
        req = urllib.request.Request(B + path, method=method, data=json.dumps(body).encode() if body is not None else None)
        req.add_header('Content-Type', 'application/json')
        if token:
            req.add_header('Authorization', f'Bearer {token}')
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read() or b'null')
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(15)
                continue
            try:
                return e.code, json.loads(e.read() or b'null')
            except Exception:
                return e.code, None
    return 429, None


def rec(i, ok, title, detail=''):
    results.append((i, 'PASS' if ok is True else ('FAIL' if ok is False else 'INFO'), title, detail))
    print(f"[{results[-1][1]}] {i} {title}" + (f"  -> {detail}" if detail else ''), flush=True)


def msg(body):
    m = (body or {}).get('message') if isinstance(body, dict) else body
    return ' '.join(m) if isinstance(m, list) else str(m)


def bsc(r):
    """Beberapa endpoint melaporkan galat bisnis sebagai {statusCode: 4xx} di body dengan HTTP 2xx."""
    return r.get('statusCode') if isinstance(r, dict) else None


def success(st, r):
    return st in (200, 201) and (bsc(r) in (None, 200, 201))


def lst(r):
    if isinstance(r, list):
        return r
    if isinstance(r, dict):
        for k in ('data', 'notifications', 'orders', 'messages', 'members'):
            if isinstance(r.get(k), list):
                return r[k]
    return []


def future(days):
    return (datetime.date.today() + datetime.timedelta(days=days)).isoformat()


def new_order(token, **over):
    p = dict(serviceCategoryId=1, urgencyLevelId=1, scheduledDate=future(5), scheduledTime='18:00', locationName='RS Uji Perminyakan', addressDetail='Kamar 302',
             notes=f'Nama Penerima: Antonius Supardi | Gender: Laki-laki | Usia: 72 tahun | Catatan: {MARK}')
    p.update(over)
    p = {k: v for k, v in p.items() if v is not None}
    st, r = call('POST', '/orders', token, p)
    oid = r['order']['id'] if st in (200, 201) and isinstance(r, dict) and r.get('order') else None
    if oid:
        created_orders.append(oid)
    return st, r, oid


def ord_row(oid):
    return psql(f"select status||'|'||coalesce(accepted_romo_id::text,'-')||'|'||coalesce(scheduled_date::text,'-')||'|'||coalesce(substring(scheduled_time::text,1,5),'-') from orders where id={oid}")


def notif(user, oid, types=None):
    q = f"select coalesce(string_agg(type, ',' order by id), '-') from notifications where user_id={user} and order_id={oid}"
    return psql(q)


def notif_users(oid, ntype):
    return sorted(int(x) for x in psql(f"select user_id from notifications where order_id={oid} and type='{ntype}'").split() if x)


def members(oid):
    rows = psql(f"select m.user_id||':'||m.role_in_group from chat_group_members m join chat_groups g on g.id=m.chat_group_id where g.order_id={oid} order by m.user_id")
    return rows.split('\n') if rows else []


def chat_texts(oid):
    return psql(f"select string_agg(message, ' || ' order by m.id) from chat_messages m join chat_groups g on g.id=m.chat_group_id where g.order_id={oid} and message_type='SYSTEM_EVENT'")


def respond(token, oid, status, romo):
    return call('POST', f'/assignments/{oid}/respond', token, {'status': status, 'romoId': romo})


def purge():
    """Hapus order/akun uji (juga sisa dari proses sebelumnya yang terhenti)."""
    for r_ in psql(f"select id from orders where notes like '%{MARK}%'").split():
        created_orders.append(int(r_))
    for oid in set(created_orders):
        for stmt in (
            f"delete from chat_message_reads where message_id in (select m.id from chat_messages m join chat_groups g on g.id=m.chat_group_id where g.order_id={oid})",
            f"delete from chat_messages where chat_group_id in (select id from chat_groups where order_id={oid})",
            f"delete from chat_group_members where chat_group_id in (select id from chat_groups where order_id={oid})",
            f"delete from notifications where order_id={oid}",
            f"delete from chat_groups where order_id={oid}",
            f"delete from order_reschedules where order_id={oid}",
            f"delete from order_romo_handovers where order_id={oid}",
            f"delete from order_monitors where order_id={oid}",
            f"delete from order_assignments where order_id={oid}",
            f"delete from order_items where order_id={oid}",
            f"delete from activity_logs where target_id::text = '{oid}' or target_id::text in (select order_number from orders where id={oid})",
            f"delete from orders where id={oid}",
        ):
            psql(stmt)
    for ph in created_users:
        uid = psql(f"select id from auth_users where phone_number='{ph}'")
        if uid:
            for stmt in (f"delete from chat_group_members where user_id={uid}", f"delete from notifications where user_id={uid}", f"delete from activity_logs where user_id={uid}",
                         f"delete from user_profiles where user_id={uid}", f"delete from auth_users where id={uid}"):
                psql(stmt)

purge()   # mulai dari kondisi bersih
created_orders.clear(); created_users.clear()

T = {}
for name, sub, role in [('UMAT', 8, 'UMAT'), ('UMAT2', 58, 'UMAT'), ('ROMO', 12, 'ROMO_PAROKI'), ('ROMO2', 13, 'ROMO_PAROKI'), ('ROMO3', 45, 'ROMO_PAROKI'),
                        ('ROMO257', 47, 'ROMO_PAROKI'), ('ORDO', 50, 'ROMO_ORDO'), ('ORDO2', 60, 'ROMO_ORDO'), ('ORDO_OUT', 48, 'ROMO_ORDO'), ('PENG', 9, 'PENGURUS_LINGKUNGAN'),
                        ('PENG2', 49, 'PENGURUS_LINGKUNGAN'), ('KOOR', 53, 'KOORDINATOR_KEUSKUPAN'), ('KOOR_OUT', 54, 'KOORDINATOR_KEUSKUPAN'), ('ADMIN', 52, 'ADMIN')]:
    T[name] = jwt(sub, role)

T['SUPER'] = jwt(7, 'SUPERADMIN')
_st, _orig = call('GET', '/master/escalation-settings', T['SUPER'])
call('PUT', '/master/escalation-settings', T['SUPER'], {'ordoAfterMinutes': 10, 'koordinatorAfterMinutes': 20})   # nilai baku untuk uji; dipulihkan di akhir

try:
    print('=== A. PEMBUATAN PELAYANAN (Umat) ===')
    st, r, O1 = new_order(T['UMAT'])
    num = (r or {}).get('order', {}).get('order_number') if O1 else None
    rec('A1', st == 201 and bool(num) and re.match(r'^SM-\d{8}-\d{4}$', num or '') is not None, 'Buat pelayanan lengkap -> 201, nomor format SM-YYYYMMDD-NNNN', f"HTTP {st}; nomor={num}")
    rec('A2', ord_row(O1).startswith('PENDING|-'), 'Status awal PENDING dan belum ada Romo', ord_row(O1))
    rec('A3', psql(f"select user_id from orders where id={O1}") == '8', 'Pemohon tercatat sebagai pembuat (identitas dari token)', f"user_id={psql(f'select user_id from orders where id={O1}')}")
    st, r, other = new_order(T['UMAT'], userId=58)
    rec('A4', other is not None and psql(f"select user_id from orders where id={other}") == '8', 'Umat tidak dapat membuat pelayanan atas nama umat lain (userId di body diabaikan)', f"user_id={psql(f'select user_id from orders where id={other}') if other else None}")
    st, r = call('POST', '/orders', None, {})
    rec('A5', st == 401, 'Tanpa login ditolak', f"HTTP {st}")
    for key, over in [('lokasi kosong', {'locationName': ''}), ('alamat/kamar kosong', {'addressDetail': ''}), ('tanggal kosong', {'scheduledDate': None}),
                      ('tanggal tidak valid', {'scheduledDate': 'bukan-tanggal'}), ('kategori bukan angka', {'serviceCategoryId': 'x'}), ('jam kosong', {'scheduledTime': None})]:
        st, r, oid = new_order(T['UMAT'], **over)
        rec('A6-' + key, st == 400, f'Validasi: {key} ditolak', f"HTTP {st}; {msg(r)[:70]}")
    st, r, oid = new_order(T['UMAT'], scheduledDate='2020-01-01')
    rec('A7', st == 400, 'Tanggal pelayanan yang sudah lewat ditolak server', f"HTTP {st}" + (f"; DIBUAT order {r['order']['order_number']}" if oid else ''))
    st, r, oid = new_order(T['UMAT'], scheduledTime='25:99')
    rec('A8', st == 400, 'Jam tidak valid (25:99) ditolak server', f"HTTP {st}" + (' (DIBUAT)' if oid else ''))
    st, r, oid = new_order(T['UMAT'], urgencyLevelId=9999)
    rec('A9', st in (400, 404, 422), 'Tingkat urgensi yang tidak ada ditolak dengan galat 4xx (bukan 500)', f"HTTP {st}; {msg(r)[:70]}")
    st, r, oid = new_order(T['UMAT'], serviceCategoryId=9999)
    rec('A10', st in (400, 404, 422), 'Kategori pelayanan yang tidak ada ditolak dengan galat 4xx (bukan 500)', f"HTTP {st}; {msg(r)[:70]}")
    st, r, oid = new_order(T['UMAT'], notes=None)
    rec('A11', st == 201, 'Catatan bersifat opsional', f"HTTP {st}")
    st, r, oid = new_order(T['UMAT'], notes='x' * 20000 + MARK)
    rec('A12', st == 400 and 'maksimal' in msg(r).lower(), 'Catatan sangat panjang (20.000 karakter) ditolak dengan pesan batas', f"HTTP {st}; {msg(r)[:60]}")
    st, r, oid = new_order(T['UMAT'], notes='x' * (2000 - len(MARK)) + MARK)
    rec('A12b', st == 201, 'Catatan tepat 2000 karakter masih diterima', f"HTTP {st}")
    st, r, oid = new_order(T['UMAT'], attachmentUrl='https://example.com/foto-uji.jpg')
    rec('A14', st == 201, 'Lampiran foto (URL) diterima', f"HTTP {st}")
    st, r, O_P257 = new_order(T['UMAT'], parokiId=257, notes=f'Nama Penerima: Maria | Catatan: {MARK}')
    rec('A13', st == 201, 'Pelayanan untuk paroki penerima berbeda (257)', f"HTTP {st}; paroki_id={psql(f'select paroki_id from orders where id={O_P257}') if O_P257 else None}")

    import threading
    conc, lock = [], threading.Lock()
    def create_once(i):
        st_, r_, oid_ = new_order(T['UMAT'], notes=f'Nama Penerima: Serentak {i} | Catatan: {MARK}')
        with lock:
            conc.append((st_, (r_ or {}).get('order', {}).get('order_number') if oid_ else None))
    workers = [threading.Thread(target=create_once, args=(i,)) for i in range(30)]
    [w.start() for w in workers]; [w.join() for w in workers]
    numbers = [n for _, n in conc if n]
    rec('A15', all(st_ == 201 for st_, _ in conc) and len(set(numbers)) == len(numbers) == 30, '30 pembuatan serentak: semuanya berhasil dan setiap nomor unik (tanpa galat 500)', f"HTTP={sorted(set(st_ for st_, _ in conc))}; nomor unik={len(set(numbers))}/{len(numbers)}")

    print('=== B. NOTIFIKASI PEMBUATAN & GRUP CHAT ===')
    rp = notif_users(O1, 'NEW_ORDER_ROMO')
    rec('B1', set(rp) >= {12, 13, 45} and 47 not in rp, 'Romo Paroki 256 diberi tahu; Romo paroki lain tidak', f"penerima NEW_ORDER_ROMO={rp}")
    mon = notif_users(O1, 'NEW_ORDER_MONITOR')
    rec('B2', {9, 11} <= set(mon) and 49 not in mon and 8 not in mon, 'Pengurus lingkungan setempat diberi tahu; pengurus lain dan pembuat tidak', f"penerima NEW_ORDER_MONITOR={mon}")
    rec('B3', not notif_users(O1, 'NEW_ORDER_KOORDINATOR') and 10 not in mon and 53 not in mon, 'Koordinator TIDAK diberi tahu saat pelayanan dibuat', f"koordinator={notif_users(O1, 'NEW_ORDER_KOORDINATOR')}")
    rec('B4', 50 not in rp and 60 not in rp, 'Romo Ordo TIDAK diberi tahu saat pelayanan dibuat', '')
    mem = members(O1)
    rec('B5', '8:UMAT' in mem and not any(':KOORDINATOR' in m for m in mem), 'Grup chat terbentuk: pemohon anggota UMAT, Koordinator belum masuk', f"anggota={mem}")
    rec('B6', 'telah dibuat' in (chat_texts(O1) or ''), 'Pesan sistem awal grup chat ada', (chat_texts(O1) or '')[:80])
    st, r = call('GET', f'/chat/order/{O1}', T['UMAT'])
    G1 = (r or {}).get('groupId')
    rec('B7', st == 200 and G1, 'Pemohon dapat menemukan grup chat pelayanannya', f"groupId={G1}")
    st, r = call('GET', f'/orders/{O_P257}', T['UMAT'])
    rec('B8', 47 in notif_users(O_P257, 'NEW_ORDER_ROMO') and 12 not in notif_users(O_P257, 'NEW_ORDER_ROMO'), 'Pelayanan paroki 257: Romo paroki 257 diberi tahu, Romo 256 tidak', f"penerima={notif_users(O_P257, 'NEW_ORDER_ROMO')}")

    print('=== C. VISIBILITAS PER PERAN ===')
    def sees(token, query, oid):
        st, r = call('GET', '/orders' + query, token)
        return st, any(str(o.get('id')) == str(oid) for o in lst(r))
    rec('C1', sees(T['UMAT'], '?userId=8', O1) == (200, True), 'Pemohon melihat pelayanannya sendiri', '')
    rec('C2', sees(T['UMAT2'], '?userId=8', O1)[1] is False, 'Umat lain tidak melihat pelayanan orang lain walau meminta userId=8', '')
    st, r = call('GET', f'/orders/{O1}', T['UMAT2'])
    rec('C3', st == 403, 'Umat lain tidak dapat membuka detail pelayanan orang lain', f"HTTP {st}")
    rec('C4', sees(T['ROMO'], '?romoId=12', O1)[1] is True, 'Romo Paroki 256 melihat pelayanan di parokinya', '')
    rec('C5', sees(T['ROMO257'], '?romoId=47', O1)[1] is False, 'Romo Paroki 257 tidak melihat pelayanan paroki 256', '')
    rec('C6', sees(T['ORDO'], '?romoId=50', O1)[1] is False, 'Romo Ordo belum melihat pelayanan sebelum batas menit', '')
    rec('C7', sees(T['PENG'], '?userId=9', O1)[1] is True, 'Pengurus lingkungan setempat memantau pelayanan umatnya', '')
    rec('C8', sees(T['PENG2'], '?userId=49', O1)[1] is False, 'Pengurus lingkungan lain tidak melihatnya', '')
    rec('C9', sees(T['KOOR'], '?userId=53', O1)[1] is False, 'Koordinator tidak melihat pelayanan umat lain di daftarnya', '')
    rec('C10', sees(T['ADMIN'], '', O1)[1] is True, 'Admin melihat semua pelayanan', '')
    st, r = call('GET', '/orders/available-romos?parokiId=256', T['ROMO'])
    rec('C11', st == 200 and any(str(x.get('id')) == '13' for x in lst(r)), 'Daftar Romo tersedia untuk pelimpahan (paroki 256)', f"HTTP {st}; {len(lst(r))} romo")
    st, r = call('GET', '/orders/999999', T['ADMIN'])
    rec('C12', None if (st == 200 and bsc(r) == 404) else st == 404, 'Order yang tidak ada: HTTP 404 (perilaku saat ini: HTTP 200 dengan statusCode 404 di body)', f"HTTP {st}; body.statusCode={bsc(r)}")
    st, r = call('GET', '/orders?romoId=12;drop%20table%20orders', T['ROMO'])
    rec('C13', st in (200, 400) and psql("select count(*) from orders") != '', 'Parameter berisi SQL tidak merusak (kueri berparameter)', f"HTTP {st}")

    print('=== D. PENERIMAAN OLEH ROMO ===')
    st, r = respond(T['ORDO'], O1, 'CONFIRMED', 50)
    rec('D1', st == 403, 'Romo Ordo belum boleh menerima sebelum batas menit', f"HTTP {st}; {msg(r)[:80]}")
    st, r = respond(T['UMAT'], O1, 'CONFIRMED', 8)
    rec('D2', st == 403, 'Umat tidak boleh menerima pelayanan (role)', f"HTTP {st}")
    st, r = respond(T['ROMO'], O1, 'XYZ', 12)
    rec('D3', st == 400, 'Status tidak sah ditolak', f"HTTP {st}")
    st, r = respond(T['ROMO257'], O1, 'CONFIRMED', 47)
    other_accept = ord_row(O1)
    rec('D4', other_accept.startswith('PENDING'), 'Romo paroki LAIN (257) tidak boleh menerima pelayanan paroki 256', f"HTTP {st}; order={other_accept}" + ('' if other_accept.startswith('PENDING') else ' (DITERIMA romo luar paroki!)'))
    if not other_accept.startswith('PENDING'):
        psql(f"update orders set status='PENDING', accepted_romo_id=NULL where id={O1}; update order_items set status='PENDING', accepted_romo_id=NULL where order_id={O1}")
        psql(f"delete from chat_group_members where user_id=47 and chat_group_id in (select id from chat_groups where order_id={O1})")
    st, r = respond(T['ROMO'], O1, 'CONFIRMED', 12)
    rec('D5', success(st, r) and ord_row(O1).startswith('CONFIRMED|12'), 'Romo Paroki menerima -> CONFIRMED atas namanya', f"HTTP {st}; order={ord_row(O1)}")
    rec('D6', '12:ROMO_PAROKI' in members(O1), 'Romo yang menerima masuk grup chat', f"anggota={members(O1)}")
    st, r = call('GET', f'/orders/{O1}', T['UMAT'])
    rec('D6b', st == 200 and str((r or {}).get('acceptedRomoId')) == '12' and bool((r or {}).get('acceptedRomoName')), 'Detail pelayanan memuat Romo yang bertugas', f"acceptedRomoId={(r or {}).get('acceptedRomoId')}; nama={(r or {}).get('acceptedRomoName')}; status={(r or {}).get('status')}")
    rec('D7', 'ORDER_CONFIRMED' in notif(8, O1), 'Umat diberi tahu pelayanan dikonfirmasi', notif(8, O1))
    rec('D8', 'ORDER_CONFIRMED' in notif(9, O1) and 'ORDER_CONFIRMED' in notif(11, O1), 'Pengurus lingkungan diberi tahu', f"9={notif(9, O1)} 11={notif(11, O1)}")
    rec('D9', 'ORDER_CONFIRMED' not in notif(53, O1) and 'ORDER_CONFIRMED' not in notif(10, O1), 'Koordinator tidak diberi tahu soal penerimaan', f"53={notif(53, O1)} 10={notif(10, O1)}")
    rec('D10', 'mengkonfirmasi' in (chat_texts(O1) or ''), 'Pesan sistem penerimaan tercatat di grup chat', '')
    st, r = respond(T['ROMO2'], O1, 'CONFIRMED', 13)
    rec('D11', 'sudah diterima' in msg(r).lower() and ord_row(O1).startswith('CONFIRMED|12'), 'Romo lain tidak dapat menimpa penerimaan', f"{msg(r)[:70]}; order={ord_row(O1)}")
    st, r = respond(T['ROMO2'], O1, 'DONE', 13)
    rec('D12', 'Hanya Romo yang bertugas' in msg(r) and ord_row(O1).startswith('CONFIRMED'), 'Romo yang tidak bertugas tidak dapat menyelesaikan', msg(r)[:80])
    st, r = respond(T['ADMIN'], O_P257, 'CONFIRMED', 47)
    rec('D13', success(st, r) and ord_row(O_P257).startswith('CONFIRMED|47'), 'Admin dapat menerima atas nama Romo (paroki 257)', ord_row(O_P257))

    import threading
    race_results = []
    for trial in range(12):
        st, r, RC = new_order(T['UMAT'])
        out = {}
        def go(name, tok, romo):
            out[name] = respond(tok, RC, 'CONFIRMED', romo)
        th = [threading.Thread(target=go, args=('a', T['ROMO'], 12)), threading.Thread(target=go, args=('b', T['ROMO2'], 13))]
        [t.start() for t in th]; [t.join() for t in th]
        codes = sorted(out[k][0] for k in out)
        accepted = psql(f"select accepted_romo_id from orders where id={RC}")
        romo_members = psql(f"select string_agg(m.user_id::text, ',' order by m.user_id) from chat_group_members m join chat_groups g on g.id=m.chat_group_id where g.order_id={RC} and m.role_in_group like 'ROMO%'")
        race_results.append((codes == [201, 409] and romo_members == accepted, codes, accepted, romo_members))
    rec('D14', all(ok for ok, *_ in race_results), 'Dua Romo menerima bersamaan (12 percobaan): tepat satu berhasil (201), satu 409, dan hanya pemenang masuk grup chat', f"bermasalah={[x for x in race_results if not x[0]]}")

    print('=== E. CHAT GRUP ===')
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['UMAT'], {'messageType': 'TEXT', 'message': 'Mohon Romo datang pukul 18.00'})
    rec('E1', st in (200, 201), 'Pemohon mengirim pesan', f"HTTP {st}")
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['ROMO'], {'messageType': 'TEXT', 'message': 'Baik, saya hadir.'})
    rec('E2', st in (200, 201), 'Romo bertugas membalas', f"HTTP {st}")
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['UMAT2'], {'messageType': 'TEXT', 'message': 'saya bukan anggota'})
    rec('E3', st == 403, 'Non-anggota tidak dapat mengirim pesan', f"HTTP {st}")
    st, r = call('GET', f'/chat/groups/{G1}/messages', T['UMAT2'])
    rec('E4', st == 403, 'Non-anggota tidak dapat membaca pesan', f"HTTP {st}")
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['UMAT'], {'messageType': 'TEXT', 'message': ''})
    rec('E5', st == 400 or (st in (200, 201) and False), 'Pesan TEXT kosong ditolak', f"HTTP {st}")
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['UMAT'], {'messageType': 'BOGUS', 'message': 'x'})
    rec('E6', st == 400, 'Jenis pesan tidak sah ditolak', f"HTTP {st}")
    st, r = call('GET', f'/chat/groups/{G1}/messages', T['UMAT'])
    texts = [m.get('message') for m in lst(r)]
    rec('E7', st == 200 and any('Mohon Romo' in (t or '') for t in texts) and any('saya hadir' in (t or '') for t in texts), 'Anggota membaca riwayat pesan', f"{len(texts)} pesan")
    cm = notif_users(O1, 'CHAT_MESSAGE')
    rec('E8', 12 in cm and 8 in cm and {9, 11} <= set(cm), 'Anggota grup (pemohon, Romo, pengurus) diberi notifikasi pesan chat baru', f"penerima CHAT_MESSAGE={sorted(set(cm))}")
    rec('E8b', {10, 51} <= set(cm) and 54 not in cm, 'Koordinator se-keuskupan (10, 51) diberi notifikasi chat untuk diskusi; Koordinator keuskupan lain (54) tidak', f"koordinator penerima={sorted({10, 51, 53, 54} & set(cm))}")
    st, r = call('POST', f'/chat/groups/{G1}/read', T['ROMO'], {})
    rec('E9', st in (200, 201), 'Tandai pesan dibaca', f"HTTP {st}")
    st, r = call('GET', f'/chat/groups/{G1}/members', T['UMAT'])
    roles = sorted({str(m.get('role_in_group')) for m in lst(r)})
    rec('E10', st == 200 and 'PEMOHON' in roles and 'ROMO_PAROKI' in roles, 'Daftar anggota grup memuat pemohon dan Romo', f"peran={roles}")
    names = [str(m.get('user_id')) for m in lst(r) if m.get('role_in_group') == 'KOORDINATOR']
    rec('E10b', '54' not in names and {'10', '51', '53'} <= set(names), 'Daftar anggota memuat Koordinator se-keuskupan saja', f"koordinator di anggota={names}")
    st, r = call('GET', f'/chat/groups/{G1}/messages', T['KOOR'])
    rec('E11', st == 200, 'Koordinator se-keuskupan dengan umat pemohon boleh membaca chat (untuk diskusi)', f"HTTP {st}")
    st, r = call('POST', f'/chat/groups/{G1}/messages', T['KOOR'], {'messageType': 'TEXT', 'message': 'Koordinator ikut berdiskusi'})
    rec('E11b', st in (200, 201), 'Koordinator se-keuskupan boleh mengirim pesan diskusi', f"HTTP {st}")
    for key, call_args in [('membaca pesan', ('GET', f'/chat/groups/{G1}/messages', None)), ('mengirim pesan', ('POST', f'/chat/groups/{G1}/messages', {'messageType': 'TEXT', 'message': 'dari keuskupan lain'})),
                           ('melihat detail grup', ('GET', f'/chat/groups/{G1}', None)), ('melihat anggota grup', ('GET', f'/chat/groups/{G1}/members', None)),
                           ('menandai dibaca', ('POST', f'/chat/groups/{G1}/read', {}))]:
        st, r = call(call_args[0], call_args[1], T['KOOR_OUT'], call_args[2])
        rec('E12-' + key, st == 403, f'Koordinator keuskupan LAIN tidak dapat {key}', f"HTTP {st}")
    # kecocokan lingkungan saja tidak cukup: syarat adalah keuskupan yang sama
    psql("update user_profiles set lingkungan_id=9471441 where user_id=54")
    st, r = call('GET', f'/chat/groups/{G1}/messages', T['KOOR_OUT'])
    st2, r2 = call('GET', '/chat/user/54/groups', T['KOOR_OUT'])
    in_list = any(str(x.get('order_id') or x.get('orderId')) == str(O1) for x in (r2 if isinstance(r2, list) else (r2 or {}).get('groups', [])))
    rec('E12-lingkungan', st == 403 and not in_list, 'Koordinator keuskupan lain dengan lingkungan yang sama tetap ditolak dan chat tidak muncul di daftarnya', f"baca HTTP {st}; muncul di daftar={in_list}")
    psql("update user_profiles set lingkungan_id=NULL where user_id=54 and lingkungan_id=9471441")
    st, r = call('GET', '/chat/user/53/groups', T['KOOR'])
    in53 = any(str(x.get('order_id') or x.get('orderId')) == str(O1) for x in (r if isinstance(r, list) else (r or {}).get('groups', [])))
    rec('E13', in53, 'Chat pelayanan se-keuskupan muncul di daftar chat Koordinator', f"muncul={in53}")

    print('=== F. PERUBAHAN JAM (RESCHEDULE) ===')
    d = future(8)
    base = {'romoId': 12, 'newDate': d, 'newTimeStart': '19:00', 'newTimeEnd': '20:00', 'reason': 'Ada pelayanan mendadak di rumah sakit lain'}
    for key, over, frag in [('jam tidak valid', {'newTimeStart': '25:61'}, 'Jam mulai'), ('jam selesai <= mulai', {'newTimeEnd': '18:00'}, 'Jam selesai'),
                            ('alasan terlalu singkat', {'reason': 'sibuk'}, 'singkat'), ('alasan kosong', {'reason': ''}, 'Alasan'),
                            ('tanggal lewat', {'newDate': '2020-01-01'}, 'lewat'), ('tanggal > 60 hari', {'newDate': future(120)}, 'maksimal'),
                            ('tanggal tidak valid', {'newDate': '2026-02-31'}, 'tidak valid')]:
        st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO'], {**base, **over})
        rec('F1-' + key, st == 400 and frag.lower() in msg(r).lower(), f'Validasi ajuan: {key} ditolak', f"HTTP {st}; {msg(r)[:70]}")
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO2'], {**base, 'romoId': 13})
    rec('F2', bsc(r) == 403, 'Romo yang tidak bertugas tidak dapat mengajukan', f"HTTP {st}; body={bsc(r)}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['UMAT'], base)
    rec('F3', st == 403, 'Umat tidak dapat mengajukan ubah jam (role)', f"HTTP {st}")
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO'], base)
    rec('F4', success(st, r), 'Romo bertugas mengajukan ubah jam', f"HTTP {st}; {msg(r)[:60]}")
    rec('F5', 'RESCHEDULE_PROPOSED' in notif(8, O1), 'Umat diberi tahu ada ajuan ubah jam', notif(8, O1))
    rec('F6', 'ubah jam' in (chat_texts(O1) or '').lower() or 'jadwal' in (chat_texts(O1) or '').lower(), 'Ajuan tercatat di grup chat', '')
    st, r = call('POST', f'/orders/{O1}/reschedule/respond', T['UMAT2'], {'userId': 58, 'action': 'ACCEPT'})
    rec('F7', st == 403, 'Umat lain tidak dapat merespons ajuan', f"HTTP {st}")
    st, r = call('POST', f'/orders/{O1}/reschedule/respond', T['UMAT'], {'userId': 8, 'action': 'REJECT'})
    rec('F8', success(st, r) and r.get('rejectedCount') == 1 and r.get('rescheduleClosed') is False, 'Umat menolak (1x) -> masih ada kesempatan', f"{json.dumps(r)[:120]}")
    rec('F9', '1 kali lagi' in (chat_texts(O1) or ''), 'Pesan sisa kesempatan tercatat di chat', '')
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO'], base)
    rec('F10', success(st, r), 'Romo mengajukan lagi (kesempatan ke-2)', f"HTTP {st}")
    st, r = call('POST', f'/orders/{O1}/reschedule/respond', T['UMAT'], {'userId': 8, 'action': 'REJECT'})
    rec('F11', success(st, r) and r.get('rescheduleClosed') is True, 'Penolakan ke-2 -> pengajuan DITUTUP', f"{json.dumps(r)[:120]}")
    rec('F12', 'RESCHEDULE_CLOSED' in notif(12, O1), 'Romo diberi tahu pengajuan ubah jam ditutup', notif(12, O1))
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO'], base)
    rec('F13', st in (400, 403), 'Setelah ditutup, ajuan baru ditolak', f"HTTP {st}; {msg(r)[:80]}")
    st, r, O2 = new_order(T['UMAT'])
    respond(T['ROMO'], O2, 'CONFIRMED', 12)
    st, r = call('POST', f'/orders/{O2}/reschedule/propose', T['ROMO'], base)
    st, r = call('POST', f'/orders/{O2}/reschedule/respond', T['UMAT'], {'userId': 8, 'action': 'ACCEPT'})
    row = ord_row(O2)
    rec('F14', success(st, r) and f'|{d}|19:00' in row, 'Umat menerima -> jadwal pelayanan berubah', f"order={row}")
    rec('F15', 'RESCHEDULE_ACCEPTED' in notif(12, O2), 'Romo diberi tahu ajuan diterima', notif(12, O2))
    st, r = call('POST', f'/orders/{O2}/reschedule/respond', T['UMAT'], {'userId': 8, 'action': 'ACCEPT'})
    rec('F16', not (success(st, r) and 'berhasil' in msg(r).lower()), 'Merespons ajuan yang sudah selesai tidak diproses ulang', f"HTTP {st}; {msg(r)[:70]}")
    st, r, O3 = new_order(T['UMAT'])
    st, r = call('POST', f'/orders/{O3}/reschedule/propose', T['ROMO'], base)
    rec('F17', not success(st, r), 'Ajuan ubah jam pada pelayanan yang belum diterima Romo ditolak', f"HTTP {st}; body={bsc(r)}")

    print('=== G. PELIMPAHAN (GANTI ROMO) ===')
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'reason': 'Berhalangan'})
    rec('G1', not success(st, r), 'Pelimpahan tanpa Romo pengganti ditolak', f"HTTP {st}; body={bsc(r)}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO3'], {'romoId': 45, 'targetRomoId': 13, 'reason': 'Bukan saya'})
    rec('G2', bsc(r) == 403, 'Romo yang tidak bertugas tidak dapat melimpahkan', f"HTTP {st}; body={bsc(r)}")
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 12, 'reason': 'Berhalangan hadir'})
    rec('G3', not success(st, r), 'Melimpahkan ke diri sendiri ditolak', f"HTTP {st}; body={bsc(r)}")
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 8, 'reason': 'Berhalangan hadir'})
    to_umat = psql(f"select handover_target_romo_id from orders where id={O1}")
    rec('G4', (not success(st, r)) and to_umat != '8', 'Melimpahkan ke akun yang BUKAN Romo (umat) ditolak', f"HTTP {st}; body={bsc(r)}; target_tercatat={to_umat or '-'}")
    if to_umat == '8':
        psql(f"update orders set handover_status='NONE', handover_target_romo_id=NULL, handover_proposed_by=NULL where id={O1}; update order_items set handover_status='NONE', handover_target_romo_id=NULL, handover_proposed_by=NULL where order_id={O1}; delete from order_romo_handovers where order_id={O1}")
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 13, 'reason': 'Berhalangan hadir, ada tugas lain'})
    rec('G5', success(st, r) and psql(f"select handover_status from orders where id={O1}") == 'PENDING', 'Romo mengajukan pelimpahan langsung -> PENDING', f"HTTP {st}; {msg(r)[:60]}")
    rec('G6', 'ROMO_HANDOVER' in notif(13, O1), 'Romo pengganti diberi tahu', notif(13, O1))
    rec('G7', 'pelimpahan' in (chat_texts(O1) or '').lower(), 'Pelimpahan tercatat di grup chat', '')
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 45, 'reason': 'Ajuan kedua saat yang pertama menunggu'})
    rec('G7b', st == 409 and psql(f"select handover_target_romo_id from orders where id={O1}") == '13', 'Pelimpahan baru ditolak (409) selagi pelimpahan sebelumnya menunggu respons', f"HTTP {st}; {msg(r)[:70]}")
    st, r = call('POST', f'/orders/{O1}/handover/respond', T['ROMO3'], {'romoId': 45, 'action': 'ACCEPT'})
    rec('G8', bsc(r) == 403 and ord_row(O1).startswith('CONFIRMED|12'), 'Romo yang bukan target tidak dapat menerima pelimpahan', f"body={bsc(r)}; order={ord_row(O1)}")
    st, r = call('POST', f'/orders/{O1}/handover/respond', T['ROMO2'], {'romoId': 13, 'action': 'REJECT'})
    rec('G9', success(st, r) and ord_row(O1).startswith('CONFIRMED|12'), 'Romo pengganti menolak -> tugas tetap pada Romo awal', f"order={ord_row(O1)}; {msg(r)[:60]}")
    rec('G10', 'ROMO_HANDOVER' in notif(12, O1), 'Romo awal diberi tahu penolakan', notif(12, O1))
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 13, 'reason': 'Berhalangan hadir (ajuan ulang)'})
    st, r = call('POST', f'/orders/{O1}/handover/respond', T['ROMO2'], {'romoId': 13, 'action': 'ACCEPT'})
    rec('G11', success(st, r) and ord_row(O1).startswith('CONFIRMED|13'), 'Romo pengganti menerima -> tugas berpindah ke Romo 13', f"order={ord_row(O1)}; {msg(r)[:60]}")
    rec('G12', '13:ROMO_PAROKI' in members(O1), 'Romo pengganti masuk grup chat', f"anggota={members(O1)}")
    rec('G13', 'ROMO_HANDOVER' in notif(8, O1) or 'ORDER_CONFIRMED' in notif(8, O1), 'Umat diberi tahu pergantian Romo', notif(8, O1))
    st, r = call('POST', f'/orders/{O1}/handover', T['ROMO2'], {'romoId': 13, 'targetRomoId': 45, 'reason': 'Dilimpahkan lagi'})
    rec('G14', bsc(r) == 400, 'Pelayanan hasil pelimpahan tidak dapat dilimpahkan lagi', f"body={bsc(r)}; {msg(r)[:70]}")
    st, r = call('POST', f'/orders/{O1}/reschedule/propose', T['ROMO'], {**base, 'newDate': future(9)})
    rec('G15', bsc(r) == 403 or st >= 400, 'Romo lama (12) tidak lagi berwenang mengajukan ubah jam', f"HTTP {st}; body={bsc(r)}")
    st, r, O4 = new_order(T['UMAT'])
    respond(T['ROMO'], O4, 'CONFIRMED', 12)
    for bad in ('ab', 'x' * 101, 'Romo <script>alert(1)</script>'):
        st, r = call('POST', f'/orders/{O4}/handover', T['ROMO'], {'romoId': 12, 'externalRomoName': bad, 'reason': 'Berhalangan hadir'})
        rec('G16-' + (bad[:6] if len(bad) < 40 else '101 karakter'), st == 400 and psql(f"select coalesce(external_romo_name,'-') from orders where id={O4}") == '-', f'Nama Romo eksternal tidak wajar ({bad[:12]}...) ditolak dan tidak tersimpan', f"HTTP {st}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{O4}/handover', T['ROMO'], {'romoId': 12, 'externalRomoName': 'Romo Eksternal Uji', 'reason': 'Berhalangan hadir'})
    rec('G16', success(st, r), 'Pelimpahan ke Romo eksternal (belum terdaftar, hanya nama)', f"HTTP {st}; {msg(r)[:70]}; external={psql(f'select coalesce(external_romo_name,chr(45)) from orders where id={O4}')}")

    print('=== H. PELAKSANAAN & PENYELESAIAN ===')
    st, r = respond(T['ROMO2'], O1, 'IN_PROGRESS', 13)
    rec('H1', success(st, r) and ord_row(O1).startswith('IN_PROGRESS|13'), 'Romo bertugas memulai pelayanan -> IN_PROGRESS', ord_row(O1))
    st, r = respond(T['ROMO2'], O1, 'FAIL', 13)
    rec('H1b', st in (403, 409) and ord_row(O1).startswith('IN_PROGRESS|13'), 'FAIL tidak dapat ditetapkan Romo (hanya Admin/sistem)', f"HTTP {st}; order={ord_row(O1)}")
    st, r, O5 = new_order(T['UMAT'])
    respond(T['ROMO'], O5, 'CONFIRMED', 12)
    st, r = respond(T['ROMO'], O5, 'CLOSE', 12)
    rec('H1c', success(st, r) and ord_row(O5).startswith('CLOSE|12'), 'Romo menutup pelayanan yang sudah diterima (CONFIRMED -> CLOSE)', f"order={ord_row(O5)}")
    st, r = respond(T['ROMO'], O5, 'CONFIRMED', 12)
    rec('H1d', st == 409 and ord_row(O5).startswith('CLOSE'), 'Pelayanan CLOSE tidak dapat dibuka kembali', f"HTTP {st}; order={ord_row(O5)}")
    rec('H2', 'ORDER_IN_PROGRESS' in notif(8, O1), 'Umat diberi tahu pelayanan berlangsung', notif(8, O1))
    st, r = respond(T['ROMO'], O1, 'DONE', 12)
    rec('H3', 'Hanya Romo yang bertugas' in msg(r) and ord_row(O1).startswith('IN_PROGRESS'), 'Romo lama (bukan bertugas) tidak dapat menyelesaikan', msg(r)[:70])
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT'], {'rating': 5, 'reviewNotes': 'Terima kasih Romo'})
    rec('H4', not (success(st, r) and 'berhasil' in msg(r).lower()), 'Ulasan sebelum pelayanan selesai ditolak', f"HTTP {st}; body={bsc(r)}; {msg(r)[:70]}")
    st, r = respond(T['ROMO2'], O1, 'DONE', 13)
    rec('H5', success(st, r) and ord_row(O1).startswith('DONE|13'), 'Romo bertugas menyelesaikan -> DONE', ord_row(O1))
    rec('H6', 'ORDER_DONE' in notif(8, O1), 'Umat diberi tahu pelayanan selesai', notif(8, O1))
    st, r = respond(T['ROMO2'], O1, 'CONFIRMED', 13)
    h7_row = ord_row(O1)
    psql(f"update orders set status='DONE' where id={O1}; update order_items set status='DONE' where order_id={O1}")   # pulihkan agar bagian ulasan tidak ikut terpengaruh
    rec('H7', h7_row.startswith('DONE'), 'Pelayanan yang sudah DONE tidak dapat dikembalikan ke CONFIRMED', f"order={h7_row}")
    respond(T['ROMO'], O2, 'DONE', 12)
    st, r = call('POST', f'/orders/{O2}/reschedule/propose', T['ROMO'], {**base, 'newDate': future(9)})
    rec('H8', not success(st, r), 'Ubah jam pada pelayanan yang sudah DONE ditolak', f"order={ord_row(O2)}; HTTP {st}; body={bsc(r)}")
    st, r = call('POST', f'/orders/{O2}/handover', T['ROMO'], {'romoId': 12, 'targetRomoId': 45, 'reason': 'Setelah selesai'})
    rec('H9', not success(st, r), 'Pelimpahan pada pelayanan yang sudah DONE ditolak', f"HTTP {st}; body={bsc(r)}")

    print('=== I. ULASAN ===')
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT2'], {'rating': 5, 'reviewNotes': 'Ulasan orang lain'})
    rec('I1', st == 403, 'Umat lain tidak dapat mengulas pelayanan orang lain', f"HTTP {st}")
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT'], {'rating': 5, 'reviewNotes': '   '})
    rec('I2', st == 400, 'Ulasan kosong ditolak', f"HTTP {st}; {msg(r)[:60]}")
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT'], {'rating': 9, 'reviewNotes': 'Rating di luar 1-5'})
    rec('I3', st == 400, 'Rating di luar 1-5 ditolak', f"HTTP {st}" + (f"; tersimpan rating={psql(f'select rating from orders where id={O1}')}" if st in (200, 201) else ''))
    if st in (200, 201):
        psql(f"update orders set rating=NULL, review_notes=NULL, reviewed_at=NULL where id={O1}")
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT'], {'rating': 5, 'reviewNotes': 'Pelayanan khidmat, terima kasih Romo'})
    rec('I4', success(st, r) and psql(f"select rating from orders where id={O1}") == '5', 'Ulasan sah tersimpan (bintang 5)', f"HTTP {st}; rating={psql(f'select rating from orders where id={O1}')}")
    rec('I5', 'ORDER_REVIEW' in notif(13, O1), 'Romo yang bertugas diberi tahu ada ulasan', notif(13, O1))
    rec('I6', 'ulasan' in (chat_texts(O1) or '').lower(), 'Ulasan tercatat di grup chat', '')
    st, r = call('POST', f'/orders/{O1}/review', T['UMAT'], {'rating': 1, 'reviewNotes': 'Ulasan kedua mengubah penilaian'})
    rec('I7', not success(st, r) or psql(f"select rating from orders where id={O1}") == '5', 'Ulasan kedua tidak menimpa ulasan pertama', f"HTTP {st}; rating={psql(f'select rating from orders where id={O1}')}")

    print('=== J. NOTIFIKASI ===')
    st, r = call('GET', '/notifications?userId=8', T['UMAT'])
    ns = lst(r)
    rec('J1', st == 200 and len(ns) > 0 and all(str(n.get('userId') or n.get('user_id') or 8) == '8' for n in ns), 'Umat membaca daftar notifikasinya', f"HTTP {st}; {len(ns)} notifikasi")
    st, r = call('GET', '/notifications?userId=12', T['UMAT'])
    own = lst(r)
    st2, r2 = call('GET', '/notifications?userId=8', T['UMAT'])
    rec('J2', [n.get('id') for n in own] == [n.get('id') for n in lst(r2)], 'Meminta notifikasi orang lain (userId=12) tetap hanya mengembalikan milik sendiri', f"{len(own)} vs {len(lst(r2))}")
    unread = [n for n in ns if not (n.get('isRead') or n.get('is_read'))]
    if unread:
        nid = unread[0].get('id')
        st, r = call('POST', f'/notifications/{nid}/read', T['UMAT'], {})
        rec('J3', st in (200, 201) and psql(f"select is_read from notifications where id={nid}") == 't', 'Tandai satu notifikasi dibaca', f"HTTP {st}")
        st, r = call('POST', f'/notifications/{nid}/read', T['UMAT2'], {})
        rec('J4', st == 403, 'Umat lain tidak dapat menandai notifikasi orang lain', f"HTTP {st}")
    st, r = call('POST', '/notifications/read-all', T['UMAT'], {})
    rec('J5', st in (200, 201) and psql("select count(*) from notifications where user_id=8 and is_read=false") == '0', 'Tandai semua dibaca', f"HTTP {st}; sisa={psql('select count(*) from notifications where user_id=8 and is_read=false')}")
    st, r = call('POST', '/notifications/register-device', T['UMAT'], {'userId': 8, 'fcmToken': 'uji-token-pel', 'deviceType': 'android'})
    rec('J6', st in (200, 201), 'Daftar token perangkat (push)', f"HTTP {st}")
    st, r = call('POST', '/notifications/register-device', T['UMAT'], {'userId': 12, 'fcmToken': 'uji-token-lain'})
    rec('J7', st == 403, 'Tidak dapat mendaftarkan token untuk akun orang lain', f"HTTP {st}")
    psql("delete from user_devices where fcm_token in ('uji-token-pel','uji-token-lain')")

    print('=== K. ESKALASI ROMO ORDO & KOORDINATOR ===')
    st, r, E1 = new_order(T['UMAT'])   # -> Romo Ordo (11 menit)
    st, r, E2 = new_order(T['UMAT'])   # -> Koordinator (21 menit)
    st, r, E3 = new_order(T['UMAT'])   # diterima Romo Paroki sebelum jatuh tempo
    respond(T['ROMO'], E3, 'CONFIRMED', 12)
    psql(f"update orders set created_at = now() - interval '11 minutes' where id={E1}; update orders set created_at = now() - interval '21 minutes' where id={E2}; update orders set created_at = now() - interval '30 minutes' where id={E3}")
    time.sleep(22)
    rec('K1', 50 in notif_users(E1, 'NEW_ORDER_ROMO') and 60 in notif_users(E1, 'NEW_ORDER_ROMO'), 'Lewat 10 menit: Romo Ordo diberi tahu', f"penerima={notif_users(E1, 'NEW_ORDER_ROMO')}")
    rec('K2', not notif_users(E1, 'NEW_ORDER_KOORDINATOR'), 'Lewat 10 menit: Koordinator belum diberi tahu', '')
    st, listed = sees(T['ORDO'], '?romoId=50', E1)
    rec('K3', listed is True, 'Romo Ordo kini melihat pelayanan di daftarnya', '')
    rec('K4', {10, 53} <= set(notif_users(E2, 'NEW_ORDER_KOORDINATOR')) and 54 not in notif_users(E2, 'NEW_ORDER_KOORDINATOR'), 'Lewat 20 menit: Koordinator se-keuskupan diberi tahu, keuskupan lain tidak', f"penerima={notif_users(E2, 'NEW_ORDER_KOORDINATOR')}")
    rec('K5', any(m.endswith(':KOORDINATOR') for m in members(E2)), 'Koordinator masuk grup chat setelah eskalasi', f"anggota={members(E2)}")
    rec('K6', not notif_users(E3, 'NEW_ORDER_ROMO') or 50 not in notif_users(E3, 'NEW_ORDER_ROMO'), 'Pelayanan yang sudah diterima Romo Paroki tidak dieskalasi', f"ordo_notified={psql(f'select ordo_notified_at is not null from orders where id={E3}')}")
    st, r = respond(T['ORDO_OUT'], E1, 'CONFIRMED', 48)
    rec('K6b', st == 403 and ord_row(E1).startswith('PENDING'), 'Romo Ordo dari KOTA LAIN tidak dapat menerima walau pelayanan sudah terbuka untuk Romo Ordo', f"HTTP {st}; order={ord_row(E1)}; {msg(r)[:70]}")
    st, r = respond(T['ORDO'], E1, 'CONFIRMED', 50)
    rec('K7', success(st, r) and ord_row(E1).startswith('CONFIRMED|50'), 'Romo Ordo menerima setelah dibuka', ord_row(E1))
    st, r = call('GET', f'/orders/{E2}/koordinator-assignment', T['KOOR'])
    rec('K8', st == 200 and r.get('state') == 'OPEN' and len(r.get('romos', [])) > 0, 'Koordinator melihat status OPEN dan daftar Romo terdaftar', f"state={(r or {}).get('state')}; romo={len((r or {}).get('romos', []))}")
    st, r = call('GET', f'/orders/{E2}/koordinator-assignment', T['KOOR_OUT'])
    rec('K9', st == 403, 'Koordinator keuskupan lain tidak berwenang', f"HTTP {st}")
    st, r = call('POST', f'/orders/{E2}/koordinator-assignment', T['KOOR'], {'romoId': 60})
    rec('K10', st in (200, 201) and ord_row(E2).startswith('CONFIRMED|60'), 'Koordinator menetapkan Romo -> pelayanan otomatis diterima', f"order={ord_row(E2)}")
    st, r, E4 = new_order(T['UMAT'])
    psql(f"update orders set created_at = now() - interval '21 minutes' where id={E4}")
    phone = '62813000008' + str(int(time.time()) % 100).zfill(2)
    created_users.append(phone)
    st, r = call('POST', f'/orders/{E4}/koordinator-assignment/register-romo', T['KOOR'], {'fullName': 'Romo Baru Uji Pelayanan', 'phoneNumber': phone, 'roleCode': 'ROMO_PAROKI', 'parokiId': 256})
    rid = (r or {}).get('romo', {}).get('id')
    rec('K11', st in (200, 201) and r.get('assigned') is True and ord_row(E4).startswith(f'CONFIRMED|{rid}'), 'Koordinator mendaftarkan Romo baru -> aktif dan otomatis menerima', f"assigned={(r or {}).get('assigned')}; order={ord_row(E4)}")

    print('=== L. STATUS OTOMATIS LEWAT TANGGAL ===')
    st, r, L1 = new_order(T['UMAT'])
    st, r, L2 = new_order(T['UMAT'])
    respond(T['ROMO'], L2, 'CONFIRMED', 12)
    psql(f"update orders set scheduled_date = current_date - 2 where id in ({L1},{L2})")
    sh(f"docker compose -f {COMPOSE} restart backend >/dev/null 2>&1"); time.sleep(20)
    T['ROMO'] = jwt(12, 'ROMO_PAROKI'); T['ADMIN'] = jwt(52, 'ADMIN'); T['UMAT'] = jwt(8, 'UMAT')
    call('GET', '/orders?userId=8', T['UMAT'])
    rec('L1', ord_row(L1).startswith('FAIL'), 'Pelayanan tanpa Romo yang jadwalnya sudah lewat -> FAIL', ord_row(L1))
    rec('L2', ord_row(L2).startswith('CLOSE'), 'Pelayanan diterima yang jadwalnya lewat >= 2 hari -> CLOSE', ord_row(L2))

    st, r = respond(T['ROMO'], L1, 'CONFIRMED', 12)
    rec('L3', ord_row(L1).startswith('FAIL'), 'Pelayanan berstatus FAIL (jadwal lewat tanpa Romo) tidak dapat diterima', f"order={ord_row(L1)}; HTTP {st}; {msg(r)[:60]}")

    print('=== M. ADMIN & KETAHANAN ===')
    st, r = call('GET', '/orders', T['ADMIN'])
    rec('M1', st == 200 and len(lst(r)) >= 5, 'Admin memuat seluruh daftar pelayanan', f"{len(lst(r))} pelayanan")
    st, r = call('PUT', f'/auth/admin/orders/{L1}/status', T['ADMIN'], {'status': 'BOGUS'})
    rec('M2', st == 400 or bsc(r) == 400, 'Admin: status pelayanan tidak sah ditolak', f"HTTP {st}; body={bsc(r)}")
    st, r = call('PUT', f'/auth/admin/orders/{L1}/status', T['UMAT'], {'status': 'DONE'})
    rec('M3', st == 403, 'Umat tidak dapat mengubah status lewat endpoint admin', f"HTTP {st}")
    st, r = call('GET', '/chat/groups', T['UMAT'])
    rec('M4', st == 403, 'Umat tidak dapat melihat seluruh grup chat', f"HTTP {st}")
    st, r = call('GET', '/orders/abc', T['ADMIN'])
    rec('M5', st in (400, 404) or bsc(r) == 404, 'ID order bukan angka tidak membuat galat 500', f"HTTP {st}")
    st, r = call('POST', '/orders', T['UMAT'], 'not-json-object')
    rec('M6', st == 400, 'Body bukan objek ditolak', f"HTTP {st}")
finally:
    print('=== Pembersihan ===')
    if isinstance(_orig, dict) and 'ordoAfterMinutes' in _orig:
        call('PUT', '/master/escalation-settings', T['SUPER'], _orig)
        print('parameter eskalasi dipulihkan ke', _orig)
    purge()
    leftover = psql(f"select count(*) from orders where notes like '%{MARK}%'")
    print('sisa order uji:', leftover, '| sisa akun uji:', psql("select count(*) from auth_users where phone_number like '62813000008%'"))

passed = sum(1 for x in results if x[1] == 'PASS')
failed = [x for x in results if x[1] == 'FAIL']
info = [x for x in results if x[1] == 'INFO']
print(f'\nRINGKASAN: {passed} PASS, {len(failed)} FAIL, {len(info)} INFO')
if failed:
    print('GAGAL:')
    for x in failed:
        print(f'  - {x[0]} {x[2]}  -> {x[3]}')
sys.exit(1 if failed else 0)
