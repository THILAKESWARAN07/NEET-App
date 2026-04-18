import csv
import io
from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..models.quiz import Announcement, Question, QuizAttempt, ScheduledTest
from ..models.user import User
from ..services.storage import upload_question_image
from ..schemas.quiz import (
    AnnouncementCreate,
    AnnouncementResponse,
    QuestionCreate,
    QuestionResponse,
    ScheduledTestCreate,
    ScheduledTestResponse,
)
from ..schemas.user import UserResponse, UserRoleUpdate
from .deps import get_current_user, require_admin

router = APIRouter()


@router.get("/users", response_model=List[UserResponse])
def list_users(db: Session = Depends(get_db), admin: User = Depends(require_admin)):
    return db.query(User).order_by(User.created_at.desc()).all()


@router.get("/users/paginated")
def list_users_paginated(
    q: str = "",
    role: str = "all",
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    bounded_skip = max(0, skip)
    bounded_limit = max(1, min(limit, 100))

    query = db.query(User)
    if role in {"user", "admin"}:
        query = query.filter(User.role == role)
    if q.strip():
        term = f"%{q.strip()}%"
        query = query.filter(or_(User.full_name.ilike(term), User.email.ilike(term)))

    total = query.count()
    items = (
        query.order_by(User.created_at.desc())
        .offset(bounded_skip)
        .limit(bounded_limit)
        .all()
    )
    return {
        "total": total,
        "skip": bounded_skip,
        "limit": bounded_limit,
        "items": [UserResponse.model_validate(item).model_dump() for item in items],
    }


@router.get("/questions")
def list_questions_paginated(
    q: str = "",
    subject: str = "all",
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    bounded_skip = max(0, skip)
    bounded_limit = max(1, min(limit, 100))

    query = db.query(Question)
    if subject and subject != "all":
        query = query.filter(Question.subject == subject)
    if q.strip():
        term = f"%{q.strip()}%"
        query = query.filter(
            or_(
                Question.question_text.ilike(term),
                Question.topic.ilike(term),
                Question.difficulty.ilike(term),
            )
        )

    total = query.count()
    items = (
        query.order_by(Question.id.desc())
        .offset(bounded_skip)
        .limit(bounded_limit)
        .all()
    )
    return {
        "total": total,
        "skip": bounded_skip,
        "limit": bounded_limit,
        "items": [QuestionResponse.model_validate(item).model_dump() for item in items],
    }


@router.post("/questions/image")
async def upload_question_image_file(
    file: UploadFile = File(...),
    admin: User = Depends(require_admin),
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="Image file is required")

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Image file is empty")

    image_url = upload_question_image(
        file_bytes=file_bytes,
        original_filename=file.filename,
        content_type=file.content_type or "image/jpeg",
    )
    return {"image_url": image_url}


@router.put("/users/{user_id}/role", response_model=UserResponse)
def update_user_role(
    user_id: int,
    payload: UserRoleUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if payload.role not in {"user", "admin"}:
        raise HTTPException(status_code=400, detail="Invalid role")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.role = payload.role
    db.commit()
    db.refresh(user)
    return user


@router.put("/questions/{question_id}", response_model=QuestionResponse)
def update_question(
    question_id: int,
    payload: QuestionCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    question = db.query(Question).filter(Question.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    for key, value in payload.model_dump().items():
        setattr(question, key, value)

    db.commit()
    db.refresh(question)
    return question


@router.delete("/questions/{question_id}")
def delete_question(
    question_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    question = db.query(Question).filter(Question.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    db.delete(question)
    db.commit()
    return {"message": "question deleted"}


@router.post("/questions/bulk-csv")
def bulk_upload_questions(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported")

    content = file.file.read().decode("utf-8")
    reader = csv.DictReader(io.StringIO(content))

    created = 0
    for row in reader:
        options = [
            row.get("option_a", ""),
            row.get("option_b", ""),
            row.get("option_c", ""),
            row.get("option_d", ""),
        ]
        question = Question(
            subject=row.get("subject", "Physics"),
            topic=row.get("topic", "General"),
            difficulty=row.get("difficulty", "medium"),
            question_text=row.get("question", ""),
            options=options,
            correct_answer=row.get("correct_answer", "A"),
            explanation=row.get("explanation", ""),
            image_url=row.get("image_url") or None,
        )
        db.add(question)
        created += 1

    db.commit()
    return {"created": created}


@router.get("/cheat-dashboard")
def cheat_dashboard(
    db: Session = Depends(get_db), admin: User = Depends(require_admin)
):
    attempts = (
        db.query(QuizAttempt)
        .filter(QuizAttempt.cheat_count > 0)
        .order_by(QuizAttempt.cheat_count.desc())
        .limit(200)
        .all()
    )
    return [
        {
            "attempt_id": a.id,
            "user_id": a.user_id,
            "status": a.status,
            "cheat_count": a.cheat_count,
            "cheat_logs": a.cheat_logs,
        }
        for a in attempts
    ]


@router.get("/cheat-dashboard/paginated")
def cheat_dashboard_paginated(
    status: str = "all",
    min_cheat_count: int = 1,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    bounded_skip = max(0, skip)
    bounded_limit = max(1, min(limit, 100))
    bounded_min_cheat = max(1, min_cheat_count)

    query = db.query(QuizAttempt).filter(QuizAttempt.cheat_count >= bounded_min_cheat)
    if status in {"in_progress", "completed", "timeout", "terminated"}:
        query = query.filter(QuizAttempt.status == status)

    total = query.count()
    attempts = (
        query.order_by(QuizAttempt.cheat_count.desc(), QuizAttempt.id.desc())
        .offset(bounded_skip)
        .limit(bounded_limit)
        .all()
    )

    return {
        "total": total,
        "skip": bounded_skip,
        "limit": bounded_limit,
        "items": [
            {
                "attempt_id": a.id,
                "user_id": a.user_id,
                "status": a.status,
                "cheat_count": a.cheat_count,
                "cheat_logs": a.cheat_logs,
            }
            for a in attempts
        ],
    }


@router.post("/announcements", response_model=AnnouncementResponse)
def create_announcement(
    payload: AnnouncementCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    ann = Announcement(**payload.model_dump())
    db.add(ann)
    db.commit()
    db.refresh(ann)
    return ann


@router.delete("/announcements/{announcement_id}")
def delete_announcement(
    announcement_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    announcement = (
        db.query(Announcement).filter(Announcement.id == announcement_id).first()
    )
    if not announcement:
        raise HTTPException(status_code=404, detail="Announcement not found")

    db.delete(announcement)
    db.commit()
    return {"message": "announcement deleted"}


@router.get("/announcements", response_model=List[AnnouncementResponse])
def list_announcements(
    db: Session = Depends(get_db), admin: User = Depends(require_admin)
):
    return db.query(Announcement).order_by(Announcement.created_at.desc()).all()


@router.get("/announcements/paginated")
def list_announcements_paginated(
    q: str = "",
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    bounded_skip = max(0, skip)
    bounded_limit = max(1, min(limit, 100))

    query = db.query(Announcement)
    if q.strip():
        term = f"%{q.strip()}%"
        query = query.filter(
            or_(Announcement.title.ilike(term), Announcement.content.ilike(term))
        )

    total = query.count()
    items = (
        query.order_by(Announcement.created_at.desc())
        .offset(bounded_skip)
        .limit(bounded_limit)
        .all()
    )
    return {
        "total": total,
        "skip": bounded_skip,
        "limit": bounded_limit,
        "items": [
            AnnouncementResponse.model_validate(item).model_dump() for item in items
        ],
    }


@router.get("/announcements/public", response_model=List[AnnouncementResponse])
def public_announcements(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    return (
        db.query(Announcement).order_by(Announcement.created_at.desc()).limit(30).all()
    )


@router.post("/schedule-tests", response_model=ScheduledTestResponse)
def schedule_test(
    payload: ScheduledTestCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    test = ScheduledTest(**payload.model_dump())
    db.add(test)
    db.commit()
    db.refresh(test)
    return test


@router.put("/schedule-tests/{test_id}", response_model=ScheduledTestResponse)
def update_scheduled_test(
    test_id: int,
    payload: ScheduledTestCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    test = db.query(ScheduledTest).filter(ScheduledTest.id == test_id).first()
    if not test:
        raise HTTPException(status_code=404, detail="Scheduled test not found")

    for key, value in payload.model_dump().items():
        setattr(test, key, value)

    db.commit()
    db.refresh(test)
    return test


@router.delete("/schedule-tests/{test_id}")
def delete_scheduled_test(
    test_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    test = db.query(ScheduledTest).filter(ScheduledTest.id == test_id).first()
    if not test:
        raise HTTPException(status_code=404, detail="Scheduled test not found")

    db.delete(test)
    db.commit()
    return {"message": "scheduled test deleted"}


@router.get("/schedule-tests", response_model=List[ScheduledTestResponse])
def list_scheduled_tests(
    db: Session = Depends(get_db), admin: User = Depends(require_admin)
):
    return db.query(ScheduledTest).order_by(ScheduledTest.scheduled_at.asc()).all()


@router.get("/schedule-tests/paginated")
def list_scheduled_tests_paginated(
    q: str = "",
    status: str = "all",
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    bounded_skip = max(0, skip)
    bounded_limit = max(1, min(limit, 100))

    query = db.query(ScheduledTest)
    if q.strip():
        term = f"%{q.strip()}%"
        query = query.filter(
            or_(ScheduledTest.title.ilike(term), ScheduledTest.subject.ilike(term))
        )

    items_all = query.order_by(ScheduledTest.scheduled_at.asc()).all()

    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)
    filtered = []
    for item in items_all:
        scheduled_at = item.scheduled_at
        if scheduled_at.tzinfo is None:
            scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)
        end_time = scheduled_at + timedelta(seconds=item.duration_seconds)
        computed_status = (
            "live"
            if scheduled_at <= now <= end_time
            else ("completed" if now > end_time else "upcoming")
        )
        if status != "all" and computed_status != status:
            continue
        filtered.append((item, computed_status))

    total = len(filtered)
    window = filtered[bounded_skip : bounded_skip + bounded_limit]

    return {
        "total": total,
        "skip": bounded_skip,
        "limit": bounded_limit,
        "items": [
            {
                **ScheduledTestResponse.model_validate(item).model_dump(),
                "status": computed_status,
            }
            for item, computed_status in window
        ],
    }
