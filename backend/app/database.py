from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.async_database_url,
    pool_size=settings.database_pool_size,
    max_overflow=settings.database_max_overflow,
    pool_pre_ping=True,      # reconnect on stale connections
    pool_recycle=1800,        # recycle every 30 min
    echo=settings.app_env == "development",
)

SessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        try:
            # Fail fast if a row lock can't be acquired within 8 s.
            # Prevents a single slow transaction from holding connections
            # and causing cascading timeouts across concurrent requests.
            await session.execute(text("SET LOCAL lock_timeout = '8000ms'"))
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
