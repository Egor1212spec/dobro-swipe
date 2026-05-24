from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.api import deps
from app.db.session import get_db
from app.models.models import TaskAssignment, Task, User
from app.models.message import Message

router = APIRouter()


class MessageCreate(BaseModel):
    text: str


class MessageResponse(BaseModel):
    id: int
    sender_id: int
    sender_name: str
    text: str
    created_at: str
    is_mine: bool


@router.get("/{assignment_id}")
async def get_messages(
    assignment_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
):
    assignment = await _verify_access(db, assignment_id, current_user)

    result = await db.execute(
        select(Message)
        .filter(Message.assignment_id == assignment_id)
        .order_by(Message.created_at.asc())
    )
    messages = result.scalars().all()

    response = []
    for msg in messages:
        sender_result = await db.execute(select(User.name).filter(User.id == msg.sender_id))
        sender_name = sender_result.scalar() or "Неизвестный"
        response.append({
            "id": msg.id,
            "sender_id": msg.sender_id,
            "sender_name": sender_name,
            "text": msg.text,
            "created_at": msg.created_at.isoformat() if msg.created_at else "",
            "is_mine": msg.sender_id == current_user.id,
        })

    return response


@router.post("/{assignment_id}")
async def send_message(
    assignment_id: int,
    body: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
):
    await _verify_access(db, assignment_id, current_user)

    if not body.text.strip():
        raise HTTPException(status_code=400, detail="Сообщение не может быть пустым")

    msg = Message(
        assignment_id=assignment_id,
        sender_id=current_user.id,
        text=body.text.strip(),
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)

    return {
        "id": msg.id,
        "sender_id": msg.sender_id,
        "sender_name": current_user.name,
        "text": msg.text,
        "created_at": msg.created_at.isoformat() if msg.created_at else "",
        "is_mine": True,
    }


async def _verify_access(db: AsyncSession, assignment_id: int, current_user: User):
    result = await db.execute(
        select(TaskAssignment).filter(TaskAssignment.id == assignment_id)
    )
    assignment = result.scalars().first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Назначение не найдено")

    # Volunteer or foundation can access
    if assignment.volunteer_id == current_user.id:
        return assignment

    task_result = await db.execute(select(Task).filter(Task.id == assignment.task_id))
    task = task_result.scalars().first()
    if task and task.foundation_id == current_user.id:
        return assignment

    raise HTTPException(status_code=403, detail="Нет доступа к этому чату")
