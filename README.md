# Three-tier app with Docker Compose (AkOps Labs build project)

Run a real multi-service stack with one command: **nginx** in front, a **Node.js API** behind it,
and **PostgreSQL** for data. This is how most teams run their apps on a laptop, a test server or a small VM.

```
browser → web (nginx :8080) → api (Node.js :3000, private) → db (PostgreSQL, private)
```

**Level:** Intermediate · **Time:** about 60 minutes · **Tools:** Docker, Docker Compose, nginx, PostgreSQL

## What to build

Write `docker-compose.yml` with three services:

| Service | What it needs |
|---|---|
| `db` | `postgres:16-alpine`, `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}` from `.env` (never in git), a named volume on `/var/lib/postgresql/data`, a health check with `pg_isready` |
| `api` | `build: ./api`, `DB_HOST: db`, starts only after `db` is **healthy**, **no** `ports:` (only nginx can reach it) |
| `web` | `nginx:1.27-alpine`, port `8080:80`, mounts `./web/nginx.conf` to `/etc/nginx/conf.d/default.conf`, starts after `api` |

## Run it

```bash
cp .env.example .env        # then set your own password in .env
docker compose up -d
docker compose ps           # db should say (healthy)
curl localhost:8080/api/health
docker compose down
```

`.env` is in `.gitignore`, so your password is never pushed. The **AkOps check** workflow starts the whole stack on GitHub
and calls `/api/health` through nginx.
