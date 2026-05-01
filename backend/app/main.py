import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.api.v1.router import api_router
from app.config import get_settings
from app.core.redis import close_redis
from app.database import engine
from app.tasks.expiry import start_scheduler, stop_scheduler

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──
    logger.info("Starting ShopHo API (env=%s)", settings.app_env)
    start_scheduler()
    yield
    # ── Shutdown ──
    stop_scheduler()
    await close_redis()
    await engine.dispose()
    logger.info("ShopHo API shut down cleanly")


app = FastAPI(
    title="ShopHo API",
    version="1.0.0",
    description="Kết nối người mua/ship hộ trong khu căn hộ",
    lifespan=lifespan,
    docs_url="/docs" if settings.app_env == "development" else None,
    redoc_url=None,
)

# ── Middleware ───────────────────────────────────────────────

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ──────────────────────────────────────────────────

app.include_router(api_router)


@app.get("/health", tags=["infra"])
async def health():
    return {"status": "ok"}
