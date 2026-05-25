import os
import json
import shutil
import uuid
import math
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
import redis.asyncio as redis
from app.api import deps
from app.core.config import settings
from app.db.session import get_db
from app.models.models import Task, TaskAssignment, User, Achievement, UserAchievement
from app.schemas.schemas import TaskCreate, TaskResponse, TaskAssignmentResponse, ReportSubmit, ReportReview

router = APIRouter()
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)


def _parse_str_list(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    raw = raw.strip()
    if not raw:
        return []
    if raw.startswith("["):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except json.JSONDecodeError:
            pass
    return [s.strip() for s in raw.split(",") if s.strip()]


@router.post("/", response_model=TaskResponse)
async def create_task(
    title: str = Form(...),
    description: str = Form(...),
    duration_minutes: int = Form(...),
    karma_reward: int = Form(...),
    skills_required: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    city: Optional[str] = Form(None),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    is_physical: bool = Form(False),
    image: UploadFile = File(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_foundation),
):
    image_url = None
    if image and image.filename:
        filename = f"{uuid.uuid4()}_{image.filename}"
        file_path = os.path.join("uploads", filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        image_url = f"http://localhost:8000/uploads/{filename}"

    db_task = Task(
        foundation_id=current_user.id,
        title=title,
        description=description,
        skills_required=_parse_str_list(skills_required),
        tags=_parse_str_list(tags),
        image_url=image_url,
        duration_minutes=duration_minutes,
        karma_reward=karma_reward,
        city=city,
        latitude=latitude,
        longitude=longitude,
        is_physical=is_physical,
    )
    db.add(db_task)
    await db.commit()
    await db.refresh(db_task)
    return db_task

@router.get("/foundation/dashboard")
async def get_foundation_dashboard(
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(deps.get_current_foundation)
):
    # Fetch tasks created by this foundation
    result = await db.execute(select(Task).filter(Task.foundation_id == current_user.id))
    tasks = result.scalars().all()
    
    # We will return the raw dict for simplicity in MVP
    response_data = []
    for t in tasks:
        # Get assignments for this task
        assign_result = await db.execute(select(TaskAssignment).filter(TaskAssignment.task_id == t.id))
        assignments = assign_result.scalars().all()
        
        response_data.append({
            "id": t.id,
            "title": t.title,
            "status": t.status,
            "assignments": [{"id": a.id, "status": a.status, "volunteer_id": a.volunteer_id, "result_text": a.result_text} for a in assignments]
        })
    return response_data

@router.get("/feed", response_model=List[TaskResponse])
async def get_task_feed(
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(deps.get_current_volunteer)
):
    # Get hidden tasks from Redis (swiped left)
    hidden_tasks_key = f"hidden_tasks:{current_user.id}"
    hidden_task_ids = await redis_client.smembers(hidden_tasks_key)
    hidden_ids = [int(tid) for tid in hidden_task_ids] if hidden_task_ids else []

    # Get tasks already assigned to this volunteer
    assigned_result = await db.execute(
        select(TaskAssignment.task_id).filter(
            TaskAssignment.volunteer_id == current_user.id,
            TaskAssignment.status.in_(["in_progress", "under_review", "completed"])
        )
    )
    assigned_task_ids = [row[0] for row in assigned_result.fetchall()]

    # Get active tasks
    query = select(Task).filter(Task.status == "active")
    if hidden_ids:
        query = query.filter(Task.id.not_in(hidden_ids))
    if assigned_task_ids:
        query = query.filter(Task.id.not_in(assigned_task_ids))

    # Filter out tasks created by the user (if any, though user is volunteer)
    query = query.filter(Task.foundation_id != current_user.id)

    result = await db.execute(query)
    tasks = result.scalars().all()

    # Smart Feed Matching: rank by skills overlap + geo distance
    user_skills = set(current_user.skills or [])
    user_lat = current_user.latitude
    user_lon = current_user.longitude

    def score_task(task):
        score = 0.0
        # Skills match: +10 per matching skill
        task_skills = set(task.skills_required or [])
        if user_skills and task_skills:
            score += len(user_skills & task_skills) * 10

        # Geo proximity for physical tasks (closer = higher score)
        if task.is_physical and user_lat and user_lon and task.latitude and task.longitude:
            dist = _haversine(user_lat, user_lon, task.latitude, task.longitude)
            score += max(0, 50 - dist)  # bonus up to 50 for tasks within 50km

        # City match bonus
        if current_user.city and task.city and current_user.city.lower() == task.city.lower():
            score += 20

        return score

    tasks.sort(key=score_task, reverse=True)
    return tasks


def _haversine(lat1, lon1, lat2, lon2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))

@router.get("/my-assignments")
async def get_my_assignments(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_volunteer)
):
    result = await db.execute(
        select(TaskAssignment).filter(
            TaskAssignment.volunteer_id == current_user.id,
            TaskAssignment.status.in_(["in_progress", "under_review"])
        ).order_by(TaskAssignment.started_at.desc())
    )
    assignments = result.scalars().all()

    response = []
    for a in assignments:
        task_result = await db.execute(select(Task).filter(Task.id == a.task_id))
        task = task_result.scalars().first()
        if task:
            response.append({
                "id": a.id,
                "status": a.status,
                "task": {
                    "id": task.id,
                    "foundation_id": task.foundation_id,
                    "title": task.title,
                    "description": task.description,
                    "duration_minutes": task.duration_minutes,
                    "karma_reward": task.karma_reward,
                    "status": task.status,
                    "city": task.city,
                    "is_physical": task.is_physical,
                    "skills_required": task.skills_required or [],
                    "tags": task.tags or [],
                    "image_url": task.image_url,
                },
            })
    return response


@router.post("/{task_id}/swipe_left")
async def swipe_left(
    task_id: int, 
    current_user: User = Depends(deps.get_current_volunteer)
):
    hidden_tasks_key = f"hidden_tasks:{current_user.id}"
    await redis_client.sadd(hidden_tasks_key, task_id)
    await redis_client.expire(hidden_tasks_key, 86400) # 24 hours TTL
    return {"status": "hidden"}

@router.post("/{task_id}/swipe_right", response_model=TaskAssignmentResponse)
async def swipe_right(
    task_id: int, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(deps.get_current_volunteer)
):
    # Check if user already has an active task
    active_assignment = await db.execute(
        select(TaskAssignment).filter(
            TaskAssignment.volunteer_id == current_user.id,
            TaskAssignment.status == "in_progress"
        )
    )
    if active_assignment.scalars().first():
        raise HTTPException(status_code=400, detail="You already have a task in progress.")

    # Check if task is active
    task_result = await db.execute(select(Task).filter(Task.id == task_id))
    task = task_result.scalars().first()
    if not task or task.status != "active":
        raise HTTPException(status_code=400, detail="Task not available.")

    # Create assignment
    assignment = TaskAssignment(
        task_id=task.id,
        volunteer_id=current_user.id,
        status="in_progress"
    )
    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)
    return assignment

@router.post("/assignments/{assignment_id}/submit")
async def submit_report(
    assignment_id: int, 
    result_text: str = Form(None),
    image: UploadFile = File(None),
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(deps.get_current_volunteer)
):
    result = await db.execute(select(TaskAssignment).filter(TaskAssignment.id == assignment_id))
    assignment = result.scalars().first()
    
    if not assignment or assignment.volunteer_id != current_user.id:
        raise HTTPException(status_code=404, detail="Assignment not found")
        
    if assignment.status != "in_progress":
        raise HTTPException(status_code=400, detail="Assignment is not in progress")

    final_result_text = result_text or ""
    
    if image:
        # Save image locally
        filename = f"{uuid.uuid4()}_{image.filename}"
        file_path = os.path.join("uploads", filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        
        # Append image link to result text
        image_url = f"http://localhost:8000/uploads/{filename}"
        final_result_text += f"\n[Image: {image_url}]"

    assignment.status = "under_review"
    assignment.result_text = final_result_text.strip()
    assignment.submitted_at = datetime.utcnow()
    
    await db.commit()
    return {"status": "submitted"}

@router.post("/assignments/{assignment_id}/review")
async def review_report(
    assignment_id: int, 
    review: ReportReview, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(deps.get_current_foundation)
):
    result = await db.execute(select(TaskAssignment).join(Task).filter(TaskAssignment.id == assignment_id))
    assignment = result.scalars().first()
    
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
        
    task_result = await db.execute(select(Task).filter(Task.id == assignment.task_id))
    task = task_result.scalars().first()

    if task.foundation_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to review this task")

    if assignment.status != "under_review":
        raise HTTPException(status_code=400, detail="Assignment is not under review")

    if review.is_approved:
        assignment.status = "completed"
        task.status = "completed"

        # Reward karma
        vol_result = await db.execute(select(User).filter(User.id == assignment.volunteer_id))
        volunteer = vol_result.scalars().first()
        volunteer.karma_balance += task.karma_reward
        volunteer.level = (volunteer.karma_balance // 100) + 1

        # Auto-unlock achievements
        ach_result = await db.execute(select(Achievement))
        all_achievements = ach_result.scalars().all()
        unlocked_result = await db.execute(
            select(UserAchievement.achievement_id).filter(UserAchievement.user_id == volunteer.id)
        )
        unlocked_ids = {row[0] for row in unlocked_result.fetchall()}

        for ach in all_achievements:
            if ach.id not in unlocked_ids and volunteer.karma_balance >= ach.required_karma:
                db.add(UserAchievement(user_id=volunteer.id, achievement_id=ach.id))

    else:
        if not review.foundation_comment:
            raise HTTPException(status_code=400, detail="Комментарий обязателен при отклонении")
        assignment.status = "rejected"
        assignment.foundation_comment = review.foundation_comment
        task.status = "active"

    await db.commit()
    return {"status": "reviewed"}
