"""Pustaka bersama skrip uji alur (hanya untuk runtime pengembangan lokal: catu_backend :3005 + shared-postgres)."""
import datetime, json, os, subprocess, time, urllib.error, urllib.request

B = 'http://localhost:3005'
COMPOSE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docker-compose.yml')
results = []


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def psql(q):
    return sh(f'docker exec shared-postgres psql -U postgres -d catu_v2_db -tAc "{q}"')


def jwt(sub, role):
    return sh(f"docker compose -f {COMPOSE} exec -T backend node -e \"const j=require('jsonwebtoken');console.log(j.sign({{sub:{sub},roleCode:'{role}'}},process.env.JWT_SECRET,{{expiresIn:'2h'}}))\"")


def call(method, path, token=None, body=None):
    for _ in range(6):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(B + path, method=method, data=data)
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
    """Galat bisnis dapat berupa {statusCode: 4xx} di body dengan HTTP 2xx."""
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


def purge_order(oid):
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


def summary():
    passed = sum(1 for x in results if x[1] == 'PASS')
    failed = [x for x in results if x[1] == 'FAIL']
    info = [x for x in results if x[1] == 'INFO']
    print(f'\nRINGKASAN: {passed} PASS, {len(failed)} FAIL, {len(info)} INFO')
    if failed:
        print('GAGAL:')
        for x in failed:
            print(f'  - {x[0]} {x[2]}  -> {x[3]}')
    return 1 if failed else 0
