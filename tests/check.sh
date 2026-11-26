#!/usr/bin/env bash
# AkOps Labs check for the Docker Compose project. Please don't edit this file.
set -uo pipefail
fail=0
pass() { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; fail=1; }
F=docker-compose.yml

[ -f "$F" ] && pass "$F exists" || { bad "$F exists"; exit 1; }
grep -Eq '#[[:space:]]*TODO:' "$F" && bad "no # TODO: lines left in $F" || pass "no TODOs left"
grep -qx '\.env' .gitignore 2>/dev/null && pass ".env is in .gitignore" || bad ".env is in .gitignore (never commit passwords)"
[ -f .env ] && bad ".env must not be committed (it holds your password)" || pass ".env is not in the repository"
cp .env.example .env

if ! docker compose config -q; then bad "$F is valid (docker compose config)"; exit 1; fi
pass "$F is valid"
json="$(docker compose config --format json)"
chk() { # chk "label" "python expression on c (the config)"
  if python3 -c "import json,sys; c=json.load(sys.stdin); s=c.get('services',{}); assert ($2)" <<<"$json" 2>/dev/null; then pass "$1"; else bad "$1"; fi
}
chk "three services: web, api and db" "{'web','api','db'} <= set(s)"
chk "db uses a pinned postgres image (not latest)" "s['db']['image'].startswith('postgres:') and 'latest' not in s['db']['image']"
grep -Eq 'POSTGRES_PASSWORD[:=][[:space:]]*"?\$\{POSTGRES_PASSWORD' "$F" && pass "the db password comes from .env" || bad 'the db password comes from .env: POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}'
chk "db keeps its data in a named volume" "any(v.get('type')=='volume' and v.get('target')=='/var/lib/postgresql/data' for v in s['db'].get('volumes',[]))"
chk "db has a pg_isready health check" "'pg_isready' in ' '.join(s['db']['healthcheck']['test'])"
chk "api is built from ./api" "s['api']['build']['context'].rstrip('/').endswith('/api')"
chk "api gets DB_HOST=db" "s['api']['environment']['DB_HOST']=='db'"
chk "api waits until db is healthy" "s['api']['depends_on']['db']['condition']=='service_healthy'"
chk "api is private (no ports)" "not s['api'].get('ports')"
chk "web uses nginx" "s['web']['image'].startswith('nginx:')"
chk "web is on port 8080" "any(str(p.get('published'))=='8080' and int(p.get('target'))==80 for p in s['web'].get('ports',[]))"
chk "web uses web/nginx.conf" "any(v.get('target')=='/etc/nginx/conf.d/default.conf' for v in s['web'].get('volumes',[]))"
chk "web starts after api" "'api' in s['web'].get('depends_on',{})"

if docker compose up -d --build --wait --wait-timeout 180; then
  pass "the stack starts and db is healthy"
  ok=0
  for _ in $(seq 1 15); do
    if curl -fsS localhost:8080/api/health | grep -q '"db_host":"db"'; then ok=1; break; fi
    sleep 2
  done
  [ $ok -eq 1 ] && pass "nginx → api works: /api/health answers on :8080" || bad "curl localhost:8080/api/health answers through nginx"
else
  bad "the stack starts and db is healthy (docker compose up -d --wait)"
  docker compose logs --no-color | tail -40
fi
docker compose down -v >/dev/null 2>&1
rm -f .env

echo
[ $fail -eq 0 ] && echo "All checks passed. Push and submit your repo on AkOps Labs." || echo "Some checks failed. Fix them and push again."
exit $fail
