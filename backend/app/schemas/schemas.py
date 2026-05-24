from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    name: str
    role: str
    city: Optional[str] = None
    skills: List[str] = []
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class UserCreate(UserBase):
    password: str = Field(..., max_length=72, min_length=6)

class UserResponse(UserBase):
    id: int
    is_verified: bool
    karma_balance: int
    level: int
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class TaskBase(BaseModel):
    title: str
    description: str
    skills_required: List[str] = []
    duration_minutes: int
    karma_reward: int
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_physical: bool = False

class TaskCreate(TaskBase):
    expires_at: Optional[datetime] = None

class TaskResponse(TaskBase):
    id: int
    foundation_id: int
    status: str
    expires_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class TaskAssignmentResponse(BaseModel):
    id: int
    task_id: int
    volunteer_id: int
    status: str
    started_at: datetime
    submitted_at: Optional[datetime] = None
    result_text: Optional[str] = None
    foundation_comment: Optional[str] = None

    class Config:
        from_attributes = True

class ReportSubmit(BaseModel):
    result_text: str

class ReportReview(BaseModel):
    is_approved: bool
    foundation_comment: Optional[str] = None
