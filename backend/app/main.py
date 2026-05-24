import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.endpoints import auth, tasks, achievements, chat
from app.core.config import settings
from contextlib import asynccontextmanager
from app.db.session import engine, Base, AsyncSessionLocal
from app.models.models import User, Task, TaskAssignment, Achievement, UserAchievement
from app.models.message import Message
from sqlalchemy import select


SEED_ACHIEVEMENTS = [
    {"title": "Первый шаг", "description": "Заверши свою первую задачу", "required_karma": 10, "icon_code": "star"},
    {"title": "Активист", "description": "Набери 100 кармы", "required_karma": 100, "icon_code": "fire"},
    {"title": "Герой", "description": "Набери 500 кармы", "required_karma": 500, "icon_code": "heart"},
    {"title": "Легенда", "description": "Набери 1000 кармы", "required_karma": 1000, "icon_code": "trophy"},
    {"title": "Космос", "description": "Набери 2500 кармы", "required_karma": 2500, "icon_code": "rocket"},
    {"title": "Молния", "description": "Набери 5000 кармы", "required_karma": 5000, "icon_code": "lightning"},
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Achievement))
        if not result.scalars().first():
            for a in SEED_ACHIEVEMENTS:
                db.add(Achievement(**a))
            await db.commit()

    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(tasks.router, prefix=f"{settings.API_V1_STR}/tasks", tags=["tasks"])
app.include_router(achievements.router, prefix=f"{settings.API_V1_STR}/achievements", tags=["achievements"])
app.include_router(chat.router, prefix=f"{settings.API_V1_STR}/chat", tags=["chat"])


@app.get("/")
def read_root():
    return {"message": "Welcome to DobroSwipe API"}
