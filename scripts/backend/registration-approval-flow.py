#!/usr/bin/env python3
"""Uji alur pendaftaran akun dan persetujuan (Pengurus Lingkungan, Umat pemohon, Romo, Ketua Romo)
beserta batas otorisasi persetujuan dan pembatasan akun yang belum aktif.

HANYA untuk runtime pengembangan lokal (catu_backend di :3005 + container shared-postgres); jangan diarahkan ke produksi.
Bergantung pada data seed pengembangan: Kepala Romo paroki 256 (user 12), Kepala Romo paroki 257 (user 47), Ketua Romo Ordo SJ
(user 60), Admin (user 52), Koordinator keuskupan 30 (user 53), Umat (user 8), lingkungan 9471441 (Ketua Lingkungan user 9),
paroki 258 dan ordo 11 tanpa kepala. Semua akun/order uji (nomor 62813000009xx) dibersihkan di akhir.

Pemakaian:  python3 scripts/backend/registration-approval-flow.py
Keluaran: satu baris PASS/FAIL/INFO per skenario; kode keluar 1 bila ada FAIL."""
import json, subprocess, sys, time, urllib.request, urllib.error

B = 'http://localhost:3005'
import os
COMPOSE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docker-compose.yml')
PW = 'Rahasia123'
results = []          # (id, status, judul, detail)
created_users = []    # nomor HP uji
created_orders = []


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def psql(q):
    return sh(f'docker exec shared-postgres psql -U postgres -d catu_v2_db -tAc "{q}"')


def jwt(sub, role):
    return sh(f"docker compose -f {COMPOSE} exec -T backend node -e \"const j=require('jsonwebtoken');console.log(j.sign({{sub:{sub},roleCode:'{role}'}},process.env.JWT_SECRET,{{expiresIn:'1h'}}))\"")


def call(method, path, token=None, body=None):
    for attempt in range(6):
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
    m = (body or {}).get('message')
    return ' '.join(m) if isinstance(m, list) else str(m)


def register(phone, name, role, **kw):
    created_users.append(phone)
    payload = dict(fullName=name, phoneNumber=phone, password=PW, roleCode=role, keuskupanId=30, parokiId=256, wilayahId=9822, lingkunganId=9471441, kabupatenKotaId=3175, gender='L')
    payload.update(kw)
    payload = {k: v for k, v in payload.items() if v is not None}
    return call('POST', '/auth/register', None, payload)


def login(phone):
    return call('POST', '/auth/login', None, {'phoneNumber': phone, 'password': PW})


def uid(phone):
    return psql(f"select id from auth_users where phone_number='{phone}'")


def status(phone):
    return psql(f"select account_status from auth_users where phone_number='{phone}'")


def notif_types(user_id, like=''):
    return psql(f"select coalesce(string_agg(type, ','), '-') from notifications where user_id={user_id} {like}")


ADMIN = jwt(52, 'ADMIN')
KETUA_ROMO_256 = jwt(12, 'ROMO_PAROKI')      # Kepala Romo Paroki 256 (data seed)
KETUA_ORDO_SJ = jwt(60, 'ROMO_ORDO')         # Ketua Romo Ordo SJ (data seed)
OTHER_KETUA_257 = jwt(47, 'ROMO_PAROKI')     # Kepala Romo paroki lain (257)
UMAT_8 = jwt(8, 'UMAT')
PH = lambda n: f'62813000009{n:02d}'

def purge():
    """Hapus akun/order uji (juga sisa dari proses sebelumnya yang terhenti)."""
    ids = [i for i in (psql(f"select id from auth_users where phone_number like '62813000009%'")).split('\n') if i]
    for oid in psql("select id from orders where notes like 'uji-flow%'").split('\n'):
        if oid:
            created_orders.append(int(oid))
    for oid in set(created_orders):
        for stmt in (
            f"delete from chat_message_reads where message_id in (select m.id from chat_messages m join chat_groups g on g.id=m.chat_group_id where g.order_id={oid})",
            f"delete from chat_messages where chat_group_id in (select id from chat_groups where order_id={oid})",
            f"delete from chat_group_members where chat_group_id in (select id from chat_groups where order_id={oid})",
            f"delete from notifications where order_id={oid}",
            f"delete from chat_groups where order_id={oid}",
            f"delete from order_items where order_id={oid}",
            f"delete from activity_logs where target_id::text = '{oid}' or target_id::text in (select order_number from orders where id={oid})",
            f"delete from orders where id={oid}",
        ):
            psql(stmt)
    if ids:
        idl = ','.join(ids)
        psql(f"delete from notifications where user_id in ({idl}) or title like '%Uji %'")
        psql(f"delete from user_approvals where target_user_id in ({idl}) or approver_user_id in ({idl})")
        psql(f"delete from chat_group_members where user_id in ({idl})")
        psql(f"delete from activity_logs where user_id in ({idl})")
        psql(f"delete from user_profiles where user_id in ({idl})")
        psql(f"delete from auth_users where id in ({idl})")

purge()   # mulai dari kondisi bersih
created_orders.clear()


print('=== A. PENGURUS LINGKUNGAN (Bendahara, lingkungan 9471441) ===')
st, r = register(PH(1), 'Uji Bendahara', 'UMAT', pengurusPosition='Bendahara')
rec('A1', st == 201 and status(PH(1)) == 'PENDING_APPROVAL', 'Daftar pengurus -> PENDING_APPROVAL', f"HTTP {st}; {msg(r)[:110]}")
rec('A2', psql(f"select r.code||' pos='||p.pengurus_position||' aktif='||coalesce(p.is_jabatan_active::text,'null') from auth_users u join roles r on r.id=u.role_id join user_profiles p on p.user_id=u.id where u.phone_number='{PH(1)}'") == 'PENGURUS_LINGKUNGAN pos=Bendahara aktif=false', 'Role otomatis PENGURUS_LINGKUNGAN, jabatan Bendahara, belum aktif', psql(f"select r.code||' pos='||p.pengurus_position||' aktif='||coalesce(p.is_jabatan_active::text,'null') from auth_users u join roles r on r.id=u.role_id join user_profiles p on p.user_id=u.id where u.phone_number='{PH(1)}'"))
st, r = register(PH(2), 'Uji Bendahara Ganda', 'UMAT', pengurusPosition='Bendahara')
rec('A3', st == 400, 'Jabatan Bendahara ganda di lingkungan sama ditolak', f"HTTP {st}; {msg(r)[:120]}")
st, r = register(PH(3), 'Uji Ketua Ganda', 'UMAT', pengurusPosition='Ketua Lingkungan')
rec('A4', st == 400, 'Jabatan Ketua Lingkungan yang sudah terisi ditolak', f"HTTP {st}; {msg(r)[:120]}")
st, r = login(PH(1))
rec('A5', None, 'Login saat masih PENDING (perilaku saat ini)', f"HTTP {st}; statusCode={r.get('statusCode')}; accountStatus={(r.get('user') or {}).get('accountStatus')}; token={'ADA' if r.get('accessToken') else 'tidak ada'}")
pending_token = r.get('accessToken')
pid = uid(PH(1))
st, r = call('POST', '/auth/pengurus/process-approval', ADMIN, {'targetUserId': int(pid), 'approverUserId': 52, 'action': 'APPROVE'})
rec('A6', st in (200, 201) and status(PH(1)) == 'APPROVED', 'Admin menyetujui pengurus', f"HTTP {st}; status={status(PH(1))}; aktif={psql(f'select is_jabatan_active from user_profiles where user_id={pid}')}")
rec('A7', 'ACCOUNT_APPROVED' in notif_types(pid), 'Pengurus mendapat notifikasi ACCOUNT_APPROVED', notif_types(pid))
st, r = login(PH(1))
rec('A8', st in (200, 201) and r.get('accessToken') and r['user']['roleCode'] == 'PENGURUS_LINGKUNGAN', 'Login setelah disetujui', f"role={(r.get('user') or {}).get('roleCode')}; status={(r.get('user') or {}).get('accountStatus')}")
PENGURUS = r.get('accessToken')

print('=== B. UMAT PEMOHON ===')
st, r = register(PH(10), 'Uji Umat Pemohon', 'UMAT')
rec('B1', st == 201 and status(PH(10)) == 'PENDING_APPROVAL', 'Daftar umat -> PENDING_APPROVAL', f"HTTP {st}; approvalAssignedTo={(r or {}).get('approvalAssignedTo')}")
umat_id = uid(PH(10))
rec('B2', psql(f"select approval_assigned_to_user_id from auth_users where id={umat_id}") == '9', 'Penyetuju ditetapkan ke Ketua Lingkungan', f"assigned_to={psql(f'select approval_assigned_to_user_id from auth_users where id={umat_id}')}")
recip = psql("select string_agg(user_id::text, ',' order by user_id) from notifications where title like 'Pendaftaran Umat Baru: Uji Umat Pemohon%'")
rec('B3', None, 'Penerima notifikasi pendaftaran umat baru', f"user_id={recip} (Ketua=9, Sekretaris=11, Koordinator=10, Pengurus baru={pid} bila terhitung)")
st, r = call('GET', '/auth/pengurus/pending-umat', PENGURUS)
names = [u.get('full_name') for u in (r if isinstance(r, list) else [])]
rec('B4', 'Uji Umat Pemohon' in names, 'Pengurus melihat umat di daftar menunggu persetujuan', f"HTTP {st}; {len(names)} pending")
st, r = login(PH(10))
umat_pending_token = r.get('accessToken')
rec('B5', None, 'Login umat saat PENDING (perilaku saat ini)', f"HTTP {st}; accountStatus={(r.get('user') or {}).get('accountStatus')}; token={'ADA' if umat_pending_token else 'tidak ada'}")
if umat_pending_token:
    st, r = call('POST', '/orders', umat_pending_token, {'serviceCategoryId': 1, 'urgencyLevelId': 1, 'scheduledDate': '2026-12-30', 'scheduledTime': '10:00', 'locationName': 'RS Uji', 'addressDetail': 'K1', 'notes': 'uji-flow-pending'})
    if st in (200, 201):
        created_orders.append(r['order']['id'])
    rec('B6', st in (401, 403), 'Umat PENDING tidak boleh membuat pelayanan', f"HTTP {st} {'(DIBUAT order ' + r['order']['order_number'] + ')' if st in (200, 201) else msg(r)[:80]}")
st, r = call('POST', '/auth/pengurus/process-approval', PENGURUS, {'targetUserId': int(umat_id), 'approverUserId': int(pid), 'action': 'APPROVE'})
rec('B7', st in (200, 201) and status(PH(10)) == 'APPROVED', 'Pengurus (baru disetujui) menyetujui umat', f"HTTP {st}; status={status(PH(10))}")
rec('B8', 'ACCOUNT_APPROVED' in notif_types(umat_id), 'Umat mendapat notifikasi ACCOUNT_APPROVED', notif_types(umat_id))
st, r = login(PH(10))
UMAT = r.get('accessToken')
rec('B9', st in (200, 201) and bool(UMAT), 'Login umat setelah disetujui', f"accountStatus={(r.get('user') or {}).get('accountStatus')}")
st, r = call('POST', '/orders', UMAT, {'serviceCategoryId': 1, 'urgencyLevelId': 1, 'scheduledDate': '2026-12-30', 'scheduledTime': '10:00', 'locationName': 'RS Uji', 'addressDetail': 'K1', 'notes': 'uji-flow-umat'})
if st in (200, 201):
    created_orders.append(r['order']['id'])
rec('B10', st in (200, 201) and r['order']['order_number'].startswith('SM-'), 'Umat disetujui dapat membuat pelayanan (nomor SM-)', f"HTTP {st}; {r['order']['order_number'] if st in (200, 201) else msg(r)[:80]}")
st, r = register(PH(11), 'Uji Umat Ditolak', 'UMAT')
rid = uid(PH(11))
st, r = call('POST', '/auth/pengurus/process-approval', PENGURUS, {'targetUserId': int(rid), 'approverUserId': int(pid), 'action': 'REJECT', 'rejectionReason': 'Data tidak lengkap'})
rec('B11', st in (200, 201) and status(PH(11)) == 'REJECTED', 'Penolakan umat dengan alasan', f"HTTP {st}; status={status(PH(11))}; notif={psql(f'select body from notifications where user_id={rid} and type=' + chr(39) + 'ACCOUNT_REJECTED' + chr(39))[:110]}")
st, r = register(PH(12), 'Uji Dup', 'UMAT', phoneNumber=PH(10))
rec('B12', st == 400, 'Nomor HP ganda ditolak', f"HTTP {st}; {msg(r)[:90]}")
st, r = register(PH(13), 'Uji Sandi Pendek', 'UMAT', password='123')
rec('B13', st == 400, 'Kata sandi < 6 karakter ditolak', f"HTTP {st}; {msg(r)[:90]}")
st, r = register(PH(14), '', 'UMAT')
rec('B14', st == 400, 'Nama kosong ditolak', f"HTTP {st}; {msg(r)[:90]}")
st, r = register(PH(15), 'Uji Gender Salah', 'UMAT', gender='X')
rec('B15', st == 400, 'Gender tidak valid ditolak', f"HTTP {st}; {msg(r)[:90]}")
st, r = register(PH(16), 'Uji Tanpa Lingkungan', 'UMAT', lingkunganId=None, wilayahId=None)
rec('B16', st == 400, 'Umat tanpa lingkungan ditolak', f"HTTP {st}; {msg(r)[:90]}")

print('=== C. ROMO BIASA ===')
st, r = register(PH(20), 'Uji Romo Paroki Biasa', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', lingkunganId=None, wilayahId=None)
romo_p = uid(PH(20))
rec('C1', st == 201 and status(PH(20)) == 'PENDING_APPROVAL', 'Daftar Romo Paroki biasa -> PENDING_APPROVAL', f"HTTP {st}; approvalAssignedTo={(r or {}).get('approvalAssignedTo')}")
rec('C2', None, 'Penerima notifikasi pendaftaran Romo Paroki', psql("select string_agg(user_id::text, ',') from notifications where title like 'Pendaftaran Romo Paroki Baru: Uji Romo Paroki Biasa%'") + ' (Kepala seed paroki 256: 12 dan 13)')
st, r = call('GET', '/auth/romo/pending-romo', KETUA_ROMO_256)
rec('C3', 'Uji Romo Paroki Biasa' in [u.get('full_name') for u in (r if isinstance(r, list) else [])], 'Kepala Romo melihat Romo baru di daftar persetujuan', f"HTTP {st}")
st, r = call('GET', '/auth/romo/pending-romo', UMAT)
rec('C4', st == 403, 'Umat biasa tidak boleh melihat daftar persetujuan Romo', f"HTTP {st}")
st, r = call('POST', '/auth/romo/process-approval', KETUA_ROMO_256, {'targetUserId': int(romo_p), 'approverUserId': 12, 'action': 'APPROVE'})
rec('C5', st in (200, 201) and status(PH(20)) == 'APPROVED', 'Kepala Romo menyetujui Romo Paroki', f"HTTP {st}; status={status(PH(20))}")
st, r = login(PH(20))
rec('C6', st in (200, 201) and (r.get('user') or {}).get('roleCode') == 'ROMO_PAROKI', 'Login Romo Paroki setelah disetujui', f"role={(r.get('user') or {}).get('roleCode')}")
st, r = register(PH(21), 'Uji Romo Ordo Biasa', 'ROMO_ORDO', romoPosition='ROMO_BIASA', ordoId=2, parokiId=None, wilayahId=None, lingkunganId=None, keuskupanId=None)
romo_o = uid(PH(21))
rec('C7', st == 201 and status(PH(21)) == 'PENDING_APPROVAL', 'Daftar Romo Ordo biasa -> PENDING_APPROVAL', f"HTTP {st}; approvalAssignedTo={(r or {}).get('approvalAssignedTo')}")
st, r = call('GET', '/auth/romo/pending-romo', KETUA_ORDO_SJ)
rec('C8', 'Uji Romo Ordo Biasa' in [u.get('full_name') for u in (r if isinstance(r, list) else [])], 'Ketua Romo Ordo melihat Romo Ordo baru', f"HTTP {st}")
st, r = call('POST', '/auth/romo/process-approval', KETUA_ORDO_SJ, {'targetUserId': int(romo_o), 'approverUserId': 60, 'action': 'APPROVE'})
rec('C9', st in (200, 201) and status(PH(21)) == 'APPROVED', 'Ketua Romo Ordo menyetujui Romo Ordo', f"HTTP {st}; status={status(PH(21))}")

print('=== D. KETUA ROMO ===')
st, r = register(PH(30), 'Uji Kepala Romo Paroki', 'ROMO_PAROKI', romoPosition='KETUA_ROMO', parokiId=258, lingkunganId=None, wilayahId=None)
ketua_p = uid(PH(30))
rec('D1', st == 201 and status(PH(30)) == 'PENDING_APPROVAL', 'Daftar Kepala Romo Paroki (paroki 258 tanpa kepala) -> PENDING', f"HTTP {st}; approvalAssignedTo={(r or {}).get('approvalAssignedTo')}; aktif={psql(f'select coalesce(is_jabatan_active::text,chr(110)||chr(117)||chr(108)||chr(108)) from user_profiles where user_id={ketua_p}')}")
st, r = register(PH(31), 'Uji Kepala Kedua', 'ROMO_PAROKI', romoPosition='KETUA_ROMO', parokiId=258, lingkunganId=None, wilayahId=None)
rec('D2', st == 400, 'Kepala kedua untuk paroki yang sama (sedang diajukan) ditolak', f"HTTP {st}; {msg(r)[:100]}")
st, r = register(PH(32), 'Uji Kepala Paroki Berkepala', 'ROMO_PAROKI', romoPosition='KETUA_ROMO', parokiId=256, lingkunganId=None, wilayahId=None)
rec('D3', st == 400, 'Kepala untuk paroki yang sudah punya kepala aktif ditolak', f"HTTP {st}; {msg(r)[:100]}")
st, r = call('GET', '/auth/romo/pending-romo', ADMIN)
rec('D4', 'Uji Kepala Romo Paroki' in [u.get('full_name') for u in (r if isinstance(r, list) else [])], 'Admin melihat pendaftaran Kepala Romo di daftar persetujuan', f"HTTP {st}")
st, r = call('POST', '/auth/romo/process-approval', ADMIN, {'targetUserId': int(ketua_p), 'approverUserId': 52, 'action': 'APPROVE'})
rec('D5', st in (200, 201) and status(PH(30)) == 'APPROVED', 'Admin menyetujui Kepala Romo Paroki', f"HTTP {st}; aktif={psql(f'select is_jabatan_active from user_profiles where user_id={ketua_p}')}")
st, r = login(PH(30))
KETUA_NEW = r.get('accessToken')
rec('D6', st in (200, 201) and bool(KETUA_NEW), 'Login Kepala Romo baru', f"role={(r.get('user') or {}).get('roleCode')}; pos={(r.get('user') or {}).get('romoPosition')}")
st, r = register(PH(33), 'Uji Romo Di Paroki 258', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', parokiId=258, lingkunganId=None, wilayahId=None)
romo_258 = uid(PH(33))
rec('D7', psql(f"select approval_assigned_to_user_id from auth_users where id={romo_258}") == ketua_p, 'Romo baru di paroki 258 diarahkan ke Kepala yang baru', f"assigned_to={psql(f'select approval_assigned_to_user_id from auth_users where id={romo_258}')} (Kepala={ketua_p}); notif Kepala: {notif_types(ketua_p, 'and title like ' + chr(39) + 'Pendaftaran Romo%' + chr(39))}")
st, r = call('POST', '/auth/romo/process-approval', KETUA_NEW, {'targetUserId': int(romo_258), 'approverUserId': int(ketua_p), 'action': 'APPROVE'})
rec('D8', st in (200, 201) and status(PH(33)) == 'APPROVED', 'Kepala baru menyetujui Romo di parokinya', f"HTTP {st}")
st, r = register(PH(34), 'Uji Ketua Romo Ordo', 'ROMO_ORDO', romoPosition='KETUA_ROMO', ordoId=11, parokiId=None, wilayahId=None, lingkunganId=None, keuskupanId=None)
ketua_o = uid(PH(34))
rec('D9', st == 201 and status(PH(34)) == 'PENDING_APPROVAL', 'Daftar Ketua Romo Ordo (ordo 11 tanpa ketua) -> PENDING', f"HTTP {st}; approvalAssignedTo={(r or {}).get('approvalAssignedTo')}")
st, r = call('POST', '/auth/romo/process-approval', ADMIN, {'targetUserId': int(ketua_o), 'approverUserId': 52, 'action': 'APPROVE'})
rec('D10', st in (200, 201) and status(PH(34)) == 'APPROVED', 'Admin menyetujui Ketua Romo Ordo', f"HTTP {st}")

print('=== E. BATAS OTORISASI PERSETUJUAN (harapan: ditolak) ===')
def fresh(n, name, role, **kw):
    st, r = register(PH(n), name, role, **kw)
    return uid(PH(n))

# E1: umat biasa memproses persetujuan
t = fresh(40, 'Uji Target E1', 'UMAT')
st, r = call('POST', '/auth/pengurus/process-approval', UMAT_8, {'targetUserId': int(t), 'approverUserId': 8, 'action': 'APPROVE'})
rec('E1', st == 403 and status(PH(40)) == 'PENDING_APPROVAL', 'Umat biasa memproses persetujuan umat -> harus 403', f"HTTP {st}; status target={status(PH(40))}")
# E2: pengurus lingkungan menyetujui Romo
t = fresh(41, 'Uji Target E2 Romo', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', lingkunganId=None, wilayahId=None)
st, r = call('POST', '/auth/romo/process-approval', PENGURUS, {'targetUserId': int(t), 'approverUserId': int(pid), 'action': 'APPROVE'})
rec('E2', status(PH(41)) == 'PENDING_APPROVAL', 'Pengurus Lingkungan menyetujui Romo -> harus ditolak', f"HTTP {st}; status target={status(PH(41))}")
# E3: Romo biasa (bukan kepala) menyetujui Romo lain
t = fresh(42, 'Uji Target E3 Romo', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', lingkunganId=None, wilayahId=None)
st, r = login(PH(20))
ROMO_BIASA_TOKEN = r.get('accessToken')
st, r = call('POST', '/auth/romo/process-approval', ROMO_BIASA_TOKEN, {'targetUserId': int(t), 'approverUserId': int(romo_p), 'action': 'APPROVE'})
rec('E3', status(PH(42)) == 'PENDING_APPROVAL', 'Romo biasa (bukan Kepala) menyetujui Romo lain -> harus ditolak', f"HTTP {st}; status target={status(PH(42))}")
# E4: Kepala paroki lain (257) menyetujui Romo paroki 256
t = fresh(43, 'Uji Target E4 Romo', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', lingkunganId=None, wilayahId=None)
st, r = call('POST', '/auth/romo/process-approval', OTHER_KETUA_257, {'targetUserId': int(t), 'approverUserId': 47, 'action': 'APPROVE'})
rec('E4', status(PH(43)) == 'PENDING_APPROVAL', 'Kepala Romo paroki LAIN (257) menyetujui Romo paroki 256 -> harus ditolak', f"HTTP {st}; status target={status(PH(43))}")
# E5: Romo menyetujui Umat
t = fresh(44, 'Uji Target E5 Umat', 'UMAT')
st, r = call('POST', '/auth/pengurus/process-approval', ROMO_BIASA_TOKEN, {'targetUserId': int(t), 'approverUserId': int(romo_p), 'action': 'APPROVE'})
rec('E5', status(PH(44)) == 'PENDING_APPROVAL', 'Romo menyetujui Umat (bukan wewenangnya) -> harus ditolak', f"HTTP {st}; status target={status(PH(44))}")
# E6: pengurus lingkungan LAIN menyetujui umat di lingkungan 9471441
other_ling = psql("select l.id from lingkungan l join wilayah w on w.id=l.wilayah_id where w.paroki_id=256 and l.id<>9471441 limit 1")
st, r = register(PH(45), 'Uji Pengurus Lain', 'UMAT', pengurusPosition='Wakil Ketua', lingkunganId=int(other_ling) if other_ling else 9471442, wilayahId=None)
other_p = uid(PH(45))
call('POST', '/auth/pengurus/process-approval', ADMIN, {'targetUserId': int(other_p), 'approverUserId': 52, 'action': 'APPROVE'})
st, r = login(PH(45))
OTHER_PENGURUS = r.get('accessToken')
t = fresh(46, 'Uji Target E6 Umat', 'UMAT')
st, r = call('POST', '/auth/pengurus/process-approval', OTHER_PENGURUS, {'targetUserId': int(t), 'approverUserId': int(other_p), 'action': 'APPROVE'})
rec('E6', status(PH(46)) == 'PENDING_APPROVAL', 'Pengurus lingkungan LAIN menyetujui umat lingkungan 9471441 -> harus ditolak', f"HTTP {st}; status target={status(PH(46))}")
# E7: persetujuan diri sendiri oleh pengurus yang masih PENDING (login memberi token)
st, r = register(PH(47), 'Uji Pengurus Self', 'UMAT', pengurusPosition='Wakil')
self_id = uid(PH(47))
st, r = login(PH(47))
SELF_TOKEN = r.get('accessToken')
st2, r2 = call('POST', '/auth/pengurus/process-approval', SELF_TOKEN, {'targetUserId': int(self_id), 'approverUserId': int(self_id), 'action': 'APPROVE'}) if SELF_TOKEN else (0, None)
rec('E7', status(PH(47)) == 'PENDING_APPROVAL', 'Pengurus PENDING menyetujui akunnya sendiri -> harus ditolak', f"HTTP {st2}; status akun={status(PH(47))}")
# E8: akun PENDING / REJECTED memakai API terproteksi
st, r = login(PH(11))
rej_token = r.get('accessToken')
st, r = call('POST', '/orders', rej_token, {'serviceCategoryId': 1, 'urgencyLevelId': 1, 'scheduledDate': '2026-12-30', 'scheduledTime': '10:00', 'locationName': 'RS Uji', 'addressDetail': 'K1', 'notes': 'uji-flow-rejected'}) if rej_token else (0, None)
if st in (200, 201):
    created_orders.append(r['order']['id'])
rec('E8', st in (401, 403), 'Akun DITOLAK (REJECTED) membuat pelayanan -> harus ditolak', f"HTTP {st}")


print('=== F. HARDENING TAMBAHAN ===')
st, r = register(PH(50), 'Uji Role Admin', 'ADMIN')
rec('F1', st == 400 and status(PH(50)) == '', 'Pendaftaran dengan roleCode ADMIN ditolak', f"HTTP {st}; {msg(r)[:80]}; akun={status(PH(50)) or 'tidak dibuat'}")
st, r = register(PH(51), 'Uji Role Sembarang', 'HACKER')
rec('F2', st == 400 and status(PH(51)) == '', 'Pendaftaran dengan roleCode sembarang ditolak', f"HTTP {st}; {msg(r)[:80]}")
st, r = register(PH(52), 'Uji Romo Tanpa Paroki', 'ROMO_PAROKI', parokiId=None)
rec('F3', st == 400, 'Romo Paroki tanpa paroki ditolak', f"HTTP {st}; {msg(r)[:80]}")
# token akun PENDING: hanya endpoint allowlist
st, r = register(PH(53), 'Uji Pending Token', 'UMAT')
pend_id = uid(PH(53))
st, r = login(PH(53)); PT = r.get('accessToken')
phone53 = PH(53)
st1, r1 = call('GET', f'/auth/check-status?phone={phone53}', PT)
st2, r2 = call('GET', '/notifications', PT)
st3, r3 = call('GET', f'/auth/profile/{pend_id}', PT)
st4, r4 = call('GET', '/orders', PT)
st5, r5 = call('GET', '/chat/groups', PT)
rec('F4', (st1, st2, st3) == (200, 200, 200) and st4 == 403 and st5 == 403, 'Akun PENDING: cek status/notifikasi/profil sendiri boleh, endpoint lain 403', f"check-status={st1} notifikasi={st2} profil={st3} orders={st4} chat={st5}; pesan={msg(r4)[:70]}")
# persetujuan berlaku seketika untuk token yang sama
call('POST', '/auth/pengurus/process-approval', PENGURUS, {'targetUserId': int(pend_id), 'approverUserId': int(pid), 'action': 'APPROVE'})
time.sleep(6)
st6, r6 = call('GET', '/orders', PT)
rec('F5', st6 == 200, 'Setelah disetujui, token yang sama langsung dapat dipakai (tanpa login ulang)', f"orders={st6}")
# approve dua kali / akun sudah APPROVED
st, r = call('POST', '/auth/pengurus/process-approval', PENGURUS, {'targetUserId': int(pend_id), 'approverUserId': int(pid), 'action': 'APPROVE'})
rec('F6', st == 409, 'Menyetujui akun yang sudah APPROVED -> 409', f"HTTP {st}; {msg(r)[:80]}")
st, r = call('POST', '/auth/pengurus/process-approval', PENGURUS, {'targetUserId': int(pend_id), 'approverUserId': int(pid), 'action': 'REJECT'})
rec('F7', st == 409 and status(PH(53)) == 'APPROVED', 'Menolak akun yang sudah aktif -> 409 (tidak dapat menonaktifkan akun aktif lewat jalur persetujuan)', f"HTTP {st}; status={status(PH(53))}")
# akun REJECTED: ditolak di API, notifikasi tetap terbaca; Admin dapat mengaktifkan kembali
st, r = login(PH(11)); RT = r.get('accessToken')
s1, _ = call('GET', '/notifications', RT); s2, _ = call('GET', '/orders', RT)
rec('F8', s1 == 200 and s2 == 403, 'Akun REJECTED: notifikasi (alasan penolakan) terbaca, API lain 403', f"notifikasi={s1} orders={s2}")
st, r = call('POST', '/auth/approve-registration', ADMIN, {'targetUserId': int(rid), 'action': 'APPROVED'})
rec('F9', st in (200, 201) and status(PH(11)) == 'APPROVED', 'Admin dapat mengaktifkan kembali akun REJECTED', f"HTTP {st}; status={status(PH(11))}")
# daftar persetujuan dibatasi wilayah: parameter wilayah dari klien diabaikan
st, r = call('GET', '/auth/pengurus/pending-umat?lingkunganId=9471441&keuskupanId=30', OTHER_PENGURUS)
names = [u.get('full_name') for u in (r if isinstance(r, list) else [])]
rec('F10', st == 200 and 'Uji Target E6 Umat' not in names, 'Pengurus lingkungan lain tidak melihat umat lingkungan 9471441 meski meminta lewat parameter', f"HTTP {st}; terlihat={len(names)} pending")
st, r = call('GET', '/auth/romo/pending-romo?parokiId=256', ROMO_BIASA_TOKEN)
rec('F11', st == 200 and r == [], 'Romo biasa (bukan Kepala) tidak mendapat daftar persetujuan Romo', f"HTTP {st}; jumlah={len(r) if isinstance(r, list) else r}")
st, r = call('GET', '/auth/romo/pending-romo?parokiId=258', KETUA_ROMO_256)
rec('F12', st == 200 and isinstance(r, list) and not any('timur' in str(u.get('paroki_name')).lower() for u in r), 'Kepala paroki 256 tidak melihat pendaftar paroki 258 lewat parameter', f"HTTP {st}; jumlah={len(r) if isinstance(r, list) else r}")
# koordinator keuskupan menyetujui umat se-keuskupan
t = fresh(54, 'Uji Target F13 Umat', 'UMAT')
KOOR = jwt(53, 'KOORDINATOR_KEUSKUPAN')
st, r = call('POST', '/auth/pengurus/process-approval', KOOR, {'targetUserId': int(t), 'approverUserId': 53, 'action': 'APPROVE'})
rec('F13', st in (200, 201) and status(PH(54)) == 'APPROVED', 'Koordinator keuskupan menyetujui umat se-keuskupan', f"HTTP {st}")
t = fresh(55, 'Uji Target F14 Koordinator', 'KOORDINATOR_KEUSKUPAN', keuskupanId=30, pengurusPosition='Koordinator', lingkunganId=None, wilayahId=None, parokiId=None)
st, r = call('POST', '/auth/pengurus/process-approval', KOOR, {'targetUserId': int(t), 'approverUserId': 53, 'action': 'APPROVE'})
rec('F14', status(PH(55)) == 'PENDING_APPROVAL', 'Koordinator tidak dapat menyetujui Koordinator lain (hanya Admin)', f"HTTP {st}; status target={status(PH(55))}")
# persetujuan Kepala ganda saat approval (simulasi data: dua kepala diajukan lewat jalur lain)
t = fresh(56, 'Uji Target F15 Kepala Ganda', 'ROMO_PAROKI', romoPosition='ROMO_BIASA', parokiId=258, lingkunganId=None, wilayahId=None)
psql(f"update user_profiles set romo_position='KETUA_ROMO' where user_id={t}")
st, r = call('POST', '/auth/romo/process-approval', ADMIN, {'targetUserId': int(t), 'approverUserId': 52, 'action': 'APPROVE'})
rec('F15', st == 409 and status(PH(56)) == 'PENDING_APPROVAL', 'Admin menyetujui Kepala kedua untuk paroki yang sudah punya Kepala aktif -> 409', f"HTTP {st}; {msg(r)[:100]}")
# peran dari token tidak dipercaya
st, r = call('GET', '/auth/admin/users', jwt(8, 'ADMIN'))
rec('F16', st == 403, 'Token yang mengaku ADMIN padahal akunnya UMAT ditolak di endpoint admin (peran dibaca dari database)', f"HTTP {st}")

print('=== Pembersihan ===')
purge()
print('sisa akun uji:', psql("select count(*) from auth_users where phone_number like '62813000009%'"), '| sisa order uji:', psql("select count(*) from orders where notes like 'uji-flow%'"))

passed = sum(1 for r in results if r[1] == 'PASS'); failed = [r for r in results if r[1] == 'FAIL']; info = [r for r in results if r[1] == 'INFO']
print(f'\nRINGKASAN: {passed} PASS, {len(failed)} FAIL, {len(info)} INFO')
sys.exit(1 if failed else 0)
