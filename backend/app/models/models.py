from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from sqlalchemy.sql import func
from app.db.session import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    is_verified = Column(Boolean, default=False)
    name = Column(String, nullable=False)
    role = Column(String, nullable=False) # 'volunteer' or 'foundation'
    city = Column(String, nullable=True)
    skills = Column(ARRAY(String), default=[])
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    karma_balance = Column(Integer, default=0)
    level = Column(Integer, default=1)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    tasks_created = relationship("Task", back_populates="foundation")
    assignments = relationship("TaskAssignment", back_populates="volunteer")
    achievements = relationship("UserAchievement", back_populates="user")

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    foundation_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    skills_required = Column(ARRAY(String), default=[])
    duration_minutes = Column(Integer, nullable=False)
    karma_reward = Column(Integer, nullable=False)
    city = Column(String, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    is_physical = Column(Boolean, default=False)
    status = Column(String, default="active") # active, completed, archived
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    foundation = relationship("User", back_populates="tasks_created")
    assignments = relationship("TaskAssignment", back_populates="task")

class TaskAssignment(Base):
    __tablename__ = "task_assignments"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False)
    volunteer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String, default="in_progress") # in_progress, under_review, completed, rejected
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    result_text = Column(Text, nullable=True)
    foundation_comment = Column(Text, nullable=True)

    task = relationship("Task", back_populates="assignments")
    volunteer = relationship("User", back_populates="assignments")

class Achievement(Base):
    __tablename__ = "achievements"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=False)
    required_karma = Column(Integer, nullable=False)
    icon_code = Column(String, nullable=True)

class UserAchievement(Base):
    __tablename__ = "user_achievements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    achievement_id = Column(Integer, ForeignKey("achievements.id"), nullable=False)
    unlocked_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="achievements")
    achievement = relationship("Achievement")
