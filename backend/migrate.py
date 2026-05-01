"""
Run all numbered SQL migrations in order.
Called by Railway's releaseCommand before each deploy.
Tracks applied migrations in _migrations table to avoid re-runs.
"""
import asyncio
import os
import sys

import asyncpg


async def run() -> None:
    raw_url = os.environ.get("DATABASE_URL", "")
    # asyncpg uses postgresql://, not postgresql+asyncpg://
    url = raw_url.replace("postgresql+asyncpg://", "postgresql://")
    if not url:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    conn = await asyncpg.connect(url)

    await conn.execute("""
        CREATE TABLE IF NOT EXISTS _migrations (
            filename   TEXT        PRIMARY KEY,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)

    migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
    files = sorted(
        f for f in os.listdir(migrations_dir)
        if f.endswith(".sql") and f[0].isdigit()
    )

    for filename in files:
        already = await conn.fetchval(
            "SELECT 1 FROM _migrations WHERE filename = $1", filename
        )
        if already:
            print(f"[skip] {filename}")
            continue

        path = os.path.join(migrations_dir, filename)
        sql = open(path).read()
        try:
            await conn.execute(sql)
            await conn.execute(
                "INSERT INTO _migrations(filename) VALUES($1)", filename
            )
            print(f"[done] {filename}")
        except Exception as e:
            print(f"[fail] {filename}: {e}", file=sys.stderr)
            await conn.close()
            sys.exit(1)

    await conn.close()
    print("All migrations applied.")


if __name__ == "__main__":
    asyncio.run(run())
