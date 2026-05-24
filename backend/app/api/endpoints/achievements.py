from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.api import deps
from app.db.session import get_db
from app.models.models import Achievement, UserAchievement, User

router = APIRouter()


@router.get("/")
async def get_achievements(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
):
    result = await db.execute(select(Achievement))
    achievements = result.scalars().all()

    unlocked_result = await db.execute(
        select(UserAchievement.achievement_id).filter(
            UserAchievement.user_id == current_user.id
        )
    )
    unlocked_ids = {row[0] for row in unlocked_result.fetchall()}

    response = []
    for a in achievements:
        response.append({
            "id": a.id,
            "title": a.title,
            "description": a.description,
            "required_karma": a.required_karma,
            "icon_code": a.icon_code,
            "unlocked": a.id in unlocked_ids,
        })

    response.sort(key=lambda x: x["required_karma"])
    return response


@router.post("/check")
async def check_and_unlock(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
):
    result = await db.execute(select(Achievement))
    achievements = result.scalars().all()

    unlocked_result = await db.execute(
        select(UserAchievement.achievement_id).filter(
            UserAchievement.user_id == current_user.id
        )
    )
    unlocked_ids = {row[0] for row in unlocked_result.fetchall()}

    newly_unlocked = []
    for a in achievements:
        if a.id not in unlocked_ids and current_user.karma_balance >= a.required_karma:
            ua = UserAchievement(user_id=current_user.id, achievement_id=a.id)
            db.add(ua)
            newly_unlocked.append(a.title)

    if newly_unlocked:
        await db.commit()

    return {"newly_unlocked": newly_unlocked}
