from datetime import datetime, timedelta, timezone
from typing import Dict, List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..models.user import User
from ..models.quiz import (
    Answer,
    Bookmark,
    Question,
    ScheduledTest,
    QuizAttempt,
    QuizAttemptQuestion,
)
from ..schemas.quiz import (
    AnswerSubmit,
    AttemptDetailResponse,
    BookmarkDetailResponse,
    BookmarkCreate,
    BookmarkResponse,
    CheatLogRequest,
    DashboardAnalyticsResponse,
    GamificationProfileResponse,
    LeaderboardEntry,
    JsonQuizResultSubmit,
    QuestionCreate,
    QuestionResultItem,
    QuestionPublic,
    QuestionResponse,
    QuizAttemptCreate,
    QuizAttemptResponse,
    QuizResultResponse,
    RankPredictionResponse,
    ReattemptStartRequest,
    QuestionRevisionPublic,
    ScheduledTestPublicResponse,
    StudyPlanItem,
    StudyPlanResponse,
    SubjectAnalytics,
    WrongQuestionItem,
    WrongQuestionListResponse,
)
from .deps import get_current_user, require_admin

router = APIRouter()


def _to_utc_iso(dt: datetime | None) -> str:
    if not dt:
        return ""
    normalized = dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)
    return normalized.astimezone(timezone.utc).isoformat()


def _get_ordered_attempt_questions(db: Session, attempt_id: int) -> List[Question]:
    assigned = (
        db.query(QuizAttemptQuestion)
        .filter(QuizAttemptQuestion.attempt_id == attempt_id)
        .order_by(QuizAttemptQuestion.id.asc())
        .all()
    )
    q_ids = [item.question_id for item in assigned]
    if not q_ids:
        return []

    questions = db.query(Question).filter(Question.id.in_(q_ids)).all()
    question_by_id = {question.id: question for question in questions}
    return [question_by_id[qid] for qid in q_ids if qid in question_by_id]


def _award_gamification(current_user: User, now: datetime) -> None:
    today = now.date()

    if current_user.last_activity_date == today:
        pass
    elif current_user.last_activity_date == (today - timedelta(days=1)):
        current_user.streak_days = (current_user.streak_days or 0) + 1
        current_user.last_activity_date = today
    else:
        current_user.streak_days = 1
        current_user.last_activity_date = today

    badges = list(current_user.badges or [])
    badge_rules = [
        ("streak_3", current_user.streak_days >= 3),
        ("streak_7", current_user.streak_days >= 7),
        ("points_500", current_user.points >= 500),
        ("points_1000", current_user.points >= 1000),
    ]
    for badge_name, condition in badge_rules:
        if condition and badge_name not in badges:
            badges.append(badge_name)
    current_user.badges = badges


def _seconds_elapsed(attempt: QuizAttempt) -> int:
    if not attempt.start_time:
        return 0
    start = attempt.start_time
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    return int((datetime.now(timezone.utc) - start).total_seconds())


def _mark_timeout_if_needed(attempt: QuizAttempt) -> bool:
    if attempt.status != "in_progress":
        return attempt.status == "timeout"
    elapsed = _seconds_elapsed(attempt)
    if elapsed >= attempt.duration_seconds:
        attempt.status = "timeout"
        attempt.end_time = datetime.now(timezone.utc)
        attempt.time_taken = attempt.duration_seconds
        return True
    return False


def _compute_result(attempt: QuizAttempt, db: Session) -> QuizResultResponse:
    assigned = (
        db.query(QuizAttemptQuestion)
        .filter(QuizAttemptQuestion.attempt_id == attempt.id)
        .all()
    )
    assigned_question_ids = [item.question_id for item in assigned]

    if not assigned_question_ids:
        fallback_score = int(round(float(attempt.score or 0)))
        return QuizResultResponse(
            attempt_id=attempt.id,
            score=fallback_score,
            correct=0,
            wrong=0,
            unattempted=0,
            accuracy_percent=0,
            time_taken=attempt.time_taken,
            subject_wise=[],
            question_results=[],
        )

    questions = {
        q.id: q
        for q in db.query(Question).filter(Question.id.in_(assigned_question_ids)).all()
    }
    answers = {
        a.question_id: a
        for a in db.query(Answer).filter(Answer.attempt_id == attempt.id).all()
    }

    correct = 0
    wrong = 0
    unattempted = 0
    subject_map: Dict[str, Dict[str, int]] = {}
    question_results: List[QuestionResultItem] = []

    for index, question_id in enumerate(assigned_question_ids, start=1):
        question = questions.get(question_id)
        if not question:
            continue
        subject = question.subject
        if subject not in subject_map:
            subject_map[subject] = {
                "attempted": 0,
                "correct": 0,
                "wrong": 0,
                "score": 0,
            }

        answer = answers.get(question_id)
        if not answer or not answer.selected_option:
            unattempted += 1
            question_results.append(
                QuestionResultItem(
                    question_number=index,
                    question_id=question_id,
                    status="unattempted",
                    selected_option=None,
                    correct_answer=question.correct_answer,
                )
            )
            continue

        subject_map[subject]["attempted"] += 1
        if answer.selected_option == question.correct_answer:
            correct += 1
            subject_map[subject]["correct"] += 1
            subject_map[subject]["score"] += 4
            question_results.append(
                QuestionResultItem(
                    question_number=index,
                    question_id=question_id,
                    status="correct",
                    selected_option=answer.selected_option,
                    correct_answer=question.correct_answer,
                )
            )
        else:
            wrong += 1
            subject_map[subject]["wrong"] += 1
            subject_map[subject]["score"] -= 1
            question_results.append(
                QuestionResultItem(
                    question_number=index,
                    question_id=question_id,
                    status="wrong",
                    selected_option=answer.selected_option,
                    correct_answer=question.correct_answer,
                )
            )

    score = (correct * 4) - wrong
    attempted = correct + wrong
    accuracy = round((correct / attempted) * 100, 2) if attempted else 0.0

    subject_wise = []
    for subject, data in subject_map.items():
        sub_attempted = data["attempted"]
        sub_accuracy = (
            round((data["correct"] / sub_attempted) * 100, 2) if sub_attempted else 0.0
        )
        subject_wise.append(
            SubjectAnalytics(
                subject=subject,
                attempted=sub_attempted,
                correct=data["correct"],
                wrong=data["wrong"],
                score=data["score"],
                accuracy_percent=sub_accuracy,
            )
        )

    return QuizResultResponse(
        attempt_id=attempt.id,
        score=score,
        correct=correct,
        wrong=wrong,
        unattempted=unattempted,
        accuracy_percent=accuracy,
        time_taken=attempt.time_taken,
        subject_wise=subject_wise,
        question_results=question_results,
    )


def _get_latest_wrong_question_items(
    db: Session,
    user_id: int,
    subject: str | None = None,
    limit: int = 30,
) -> List[WrongQuestionItem]:
    attempts = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == user_id,
            QuizAttempt.status.in_(["completed", "timeout", "terminated"]),
        )
        .order_by(QuizAttempt.end_time.desc(), QuizAttempt.id.desc())
        .all()
    )

    if not attempts:
        return []

    attempts_by_id = {attempt.id: attempt for attempt in attempts}
    attempt_ids = list(attempts_by_id.keys())

    answers = (
        db.query(Answer)
        .filter(
            Answer.attempt_id.in_(attempt_ids),
            Answer.selected_option.isnot(None),
            Answer.selected_option != "",
        )
        .all()
    )

    if not answers:
        return []

    question_ids = list({answer.question_id for answer in answers})
    questions = {
        q.id: q for q in db.query(Question).filter(Question.id.in_(question_ids)).all()
    }

    ordered_attempt_ids = [attempt.id for attempt in attempts]
    latest_answer_by_question: Dict[int, Answer] = {}

    for attempt_id in ordered_attempt_ids:
        for answer in answers:
            if answer.attempt_id != attempt_id:
                continue
            if answer.question_id in latest_answer_by_question:
                continue
            latest_answer_by_question[answer.question_id] = answer

    wrong_items: List[WrongQuestionItem] = []
    for question_id, answer in latest_answer_by_question.items():
        question = questions.get(question_id)
        if not question:
            continue
        if subject and question.subject != subject:
            continue
        if answer.selected_option == question.correct_answer:
            continue

        attempt = attempts_by_id.get(answer.attempt_id)
        attempted_at = (
            (attempt.end_time if attempt and attempt.end_time else attempt.start_time)
            if attempt
            else None
        )
        if not attempted_at:
            attempted_at = datetime.now(timezone.utc)

        wrong_items.append(
            WrongQuestionItem(
                question=QuestionPublic.model_validate(question),
                selected_option=answer.selected_option,
                correct_answer=question.correct_answer,
                last_attempt_id=answer.attempt_id,
                last_attempted_at=attempted_at,
            )
        )

    if not wrong_items:
        return []

    wrong_items.sort(key=lambda item: item.last_attempted_at, reverse=True)
    return wrong_items[:limit]


@router.post("/questions/", response_model=QuestionResponse)
def create_question(
    question_in: QuestionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    new_q = Question(**question_in.model_dump())
    db.add(new_q)
    db.commit()
    db.refresh(new_q)
    return new_q


@router.get("/questions/", response_model=List[QuestionResponse])
def get_questions(subject: str = None, db: Session = Depends(get_db)):
    query = db.query(Question)
    if subject:
        query = query.filter(Question.subject == subject)
    return query.order_by(Question.id.asc()).all()


@router.get("/wrong-questions", response_model=WrongQuestionListResponse)
def get_wrong_questions(
    subject: str | None = None,
    limit: int = 30,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bounded_limit = max(1, min(limit, 180))
    items = _get_latest_wrong_question_items(
        db=db,
        user_id=current_user.id,
        subject=subject,
        limit=bounded_limit,
    )
    return WrongQuestionListResponse(total=len(items), items=items)


@router.post("/start-reattempt", response_model=AttemptDetailResponse)
def start_reattempt_quiz(
    payload: ReattemptStartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    active_attempt = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == current_user.id,
            QuizAttempt.status == "in_progress",
        )
        .first()
    )

    if active_attempt:
        if _mark_timeout_if_needed(active_attempt):
            db.commit()
            raise HTTPException(status_code=409, detail="Active attempt timed out")
        raise HTTPException(
            status_code=409,
            detail="Finish your active attempt before starting a reattempt",
        )

    source_questions: List[Question] = []

    if payload.from_latest_completed_test:
        latest_attempt = (
            db.query(QuizAttempt)
            .filter(
                QuizAttempt.user_id == current_user.id,
                QuizAttempt.status.in_(["completed", "timeout", "terminated"]),
            )
            .order_by(QuizAttempt.end_time.desc(), QuizAttempt.id.desc())
            .first()
        )
        if not latest_attempt:
            raise HTTPException(
                status_code=400,
                detail="No completed attempt available for latest-test reattempt",
            )

        assigned = (
            db.query(QuizAttemptQuestion)
            .filter(QuizAttemptQuestion.attempt_id == latest_attempt.id)
            .all()
        )
        source_ids = [item.question_id for item in assigned]
        if not source_ids:
            raise HTTPException(
                status_code=400,
                detail="Latest completed attempt has no assigned questions",
            )

        source_questions = (
            db.query(Question)
            .filter(Question.id.in_(source_ids))
            .order_by(Question.id.asc())
            .all()
        )
        if payload.subject:
            source_questions = [
                q for q in source_questions if q.subject == payload.subject
            ]
    else:
        wrong_pool = _get_latest_wrong_question_items(
            db=db,
            user_id=current_user.id,
            subject=payload.subject,
            limit=180,
        )
        source_questions = [item.question for item in wrong_pool]

    source_ids = [q.id for q in source_questions]
    source_id_set = set(source_ids)

    if payload.question_ids:
        requested_ids = []
        seen = set()
        for question_id in payload.question_ids:
            if question_id in seen:
                continue
            seen.add(question_id)
            requested_ids.append(question_id)

        invalid_ids = [
            question_id
            for question_id in requested_ids
            if question_id not in source_id_set
        ]
        if invalid_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Questions are not available in selected reattempt source: {invalid_ids}",
            )

        selected_ids = requested_ids
    else:
        bounded_count = max(1, min(payload.question_count, 180))
        selected_ids = source_ids[:bounded_count]

    if not selected_ids:
        raise HTTPException(
            status_code=400,
            detail="No questions available for reattempt from selected source",
        )

    selected_questions = db.query(Question).filter(Question.id.in_(selected_ids)).all()
    if not selected_questions:
        raise HTTPException(status_code=400, detail="Unable to load selected questions")

    question_by_id = {q.id: q for q in selected_questions}
    ordered_questions = [
        question_by_id[qid] for qid in selected_ids if qid in question_by_id
    ]

    new_attempt = QuizAttempt(
        user_id=current_user.id,
        start_time=datetime.now(timezone.utc),
        status="in_progress",
        duration_seconds=min(10800, max(1800, len(ordered_questions) * 120)),
        test_type="reattempt",
        subject=payload.subject,
        cheat_logs=[],
    )
    db.add(new_attempt)
    db.flush()

    for question in ordered_questions:
        db.add(QuizAttemptQuestion(attempt_id=new_attempt.id, question_id=question.id))

    db.commit()
    db.refresh(new_attempt)

    return {
        **QuizAttemptResponse.model_validate(new_attempt).model_dump(),
        "questions": [QuestionPublic.model_validate(q) for q in ordered_questions],
    }


@router.post("/start", response_model=AttemptDetailResponse)
def start_quiz(
    payload: QuizAttemptCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    active_attempt = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == current_user.id, QuizAttempt.status == "in_progress"
        )
        .first()
    )

    if active_attempt:
        if _mark_timeout_if_needed(active_attempt):
            db.commit()
            raise HTTPException(status_code=409, detail="Active attempt timed out")

        questions = _get_ordered_attempt_questions(db, active_attempt.id)
        return {
            **QuizAttemptResponse.model_validate(active_attempt).model_dump(),
            "questions": [QuestionPublic.model_validate(q) for q in questions],
        }

    question_count = payload.question_count if payload.question_count > 0 else 180
    query = db.query(Question)
    if payload.test_type == "subject":
        if not payload.subject:
            raise HTTPException(
                status_code=400, detail="subject is required for subject tests"
            )
        query = query.filter(Question.subject == payload.subject)

    selected_questions = query.order_by(Question.id.asc()).limit(question_count).all()
    if not selected_questions:
        raise HTTPException(
            status_code=400, detail="No questions found for selected test"
        )

    new_attempt = QuizAttempt(
        user_id=current_user.id,
        start_time=datetime.now(timezone.utc),
        status="in_progress",
        duration_seconds=10800,
        test_type=payload.test_type,
        subject=payload.subject,
        cheat_logs=[],
    )
    db.add(new_attempt)
    db.flush()

    for question in selected_questions:
        db.add(QuizAttemptQuestion(attempt_id=new_attempt.id, question_id=question.id))

    db.commit()
    db.refresh(new_attempt)
    return {
        **QuizAttemptResponse.model_validate(new_attempt).model_dump(),
        "questions": [QuestionPublic.model_validate(q) for q in selected_questions],
    }


@router.get("/active", response_model=AttemptDetailResponse)
def get_active_attempt(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == current_user.id,
            QuizAttempt.status == "in_progress",
        )
        .first()
    )
    if not attempt:
        raise HTTPException(status_code=404, detail="No active attempt")

    if _mark_timeout_if_needed(attempt):
        db.commit()
        raise HTTPException(status_code=409, detail="Attempt timed out")

    questions = _get_ordered_attempt_questions(db, attempt.id)
    return {
        **QuizAttemptResponse.model_validate(attempt).model_dump(),
        "questions": [QuestionPublic.model_validate(q) for q in questions],
    }


@router.post("/{attempt_id}/answer")
def submit_answer(
    attempt_id: int,
    payload: AnswerSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.id == attempt_id,
            QuizAttempt.user_id == current_user.id,
        )
        .first()
    )
    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found")
    if attempt.status != "in_progress":
        raise HTTPException(status_code=400, detail="Attempt already finalized")
    if _mark_timeout_if_needed(attempt):
        db.commit()
        raise HTTPException(status_code=409, detail="Attempt timed out")

    assigned = (
        db.query(QuizAttemptQuestion)
        .filter(
            QuizAttemptQuestion.attempt_id == attempt_id,
            QuizAttemptQuestion.question_id == payload.question_id,
        )
        .first()
    )
    if not assigned:
        raise HTTPException(
            status_code=400, detail="Question is not part of this attempt"
        )

    answer = (
        db.query(Answer)
        .filter(
            Answer.attempt_id == attempt_id,
            Answer.question_id == payload.question_id,
        )
        .first()
    )
    if not answer:
        answer = Answer(
            attempt_id=attempt_id,
            question_id=payload.question_id,
            selected_option=payload.selected_option,
        )
        db.add(answer)
    else:
        answer.selected_option = payload.selected_option

    db.commit()
    return {"message": "answer saved"}


@router.post("/{attempt_id}/submit", response_model=QuizAttemptResponse)
def submit_quiz(
    attempt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = (
        db.query(QuizAttempt)
        .filter(QuizAttempt.id == attempt_id, QuizAttempt.user_id == current_user.id)
        .first()
    )

    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found")

    if attempt.status != "in_progress":
        return attempt

    timed_out = _mark_timeout_if_needed(attempt)
    elapsed = _seconds_elapsed(attempt)

    end_time = datetime.now(timezone.utc)
    attempt.status = "timeout" if timed_out else "completed"
    attempt.end_time = end_time
    attempt.time_taken = min(elapsed, attempt.duration_seconds)

    result = _compute_result(attempt, db)
    attempt.score = result.score

    if attempt.status == "completed":
        current_user.points += max(int(result.score), 0)
        _award_gamification(current_user, end_time)

    db.commit()
    db.refresh(attempt)
    return attempt


@router.post("/{attempt_id}/log-cheat")
def log_cheat(
    attempt_id: int,
    payload: CheatLogRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = (
        db.query(QuizAttempt)
        .filter(QuizAttempt.id == attempt_id, QuizAttempt.user_id == current_user.id)
        .first()
    )

    if not attempt or attempt.status != "in_progress":
        raise HTTPException(status_code=400, detail="Active attempt not found")

    if _mark_timeout_if_needed(attempt):
        db.commit()
        return {"status": "timeout", "cheat_count": attempt.cheat_count}

    attempt.cheat_count += 1
    logs = list(attempt.cheat_logs or [])
    logs.append(
        {"event": payload.event, "timestamp": datetime.now(timezone.utc).isoformat()}
    )
    attempt.cheat_logs = logs

    if attempt.cheat_count >= 3:
        attempt.status = "terminated"
        attempt.end_time = datetime.now(timezone.utc)
        attempt.time_taken = min(_seconds_elapsed(attempt), attempt.duration_seconds)
        result = _compute_result(attempt, db)
        attempt.score = result.score

    db.commit()
    db.refresh(attempt)

    return {"status": attempt.status, "cheat_count": attempt.cheat_count}


@router.get("/{attempt_id}/result", response_model=QuizResultResponse)
def get_result(
    attempt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.id == attempt_id,
            QuizAttempt.user_id == current_user.id,
        )
        .first()
    )
    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found")

    if attempt.status == "in_progress" and _mark_timeout_if_needed(attempt):
        result = _compute_result(attempt, db)
        attempt.score = result.score
        db.commit()

    return _compute_result(attempt, db)


@router.post("/submit-json", response_model=QuizAttemptResponse)
def submit_json_quiz(
    payload: JsonQuizResultSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit results for a JSON-based quiz (local mock test).
    Creates a QuizAttempt record to track the score in analytics.
    """
    end_time = datetime.now(timezone.utc)
    
    # Create a new QuizAttempt record for the JSON quiz
    new_attempt = QuizAttempt(
        user_id=current_user.id,
        start_time=end_time - timedelta(seconds=payload.time_taken_seconds),
        end_time=end_time,
        status="completed",
        duration_seconds=payload.duration_seconds,
        time_taken=payload.time_taken_seconds,
        score=payload.score,
        test_type=payload.test_type,
        subject=payload.subject,
        cheat_logs=[],
    )
    
    db.add(new_attempt)
    db.flush()

    if payload.question_attempts:
        seen_question_ids: set[int] = set()
        ordered_attempts = []
        for attempt_item in payload.question_attempts:
            if attempt_item.question_id in seen_question_ids:
                continue
            seen_question_ids.add(attempt_item.question_id)
            ordered_attempts.append(attempt_item)

        available_questions = {
            question.id: question
            for question in db.query(Question)
            .filter(Question.id.in_([item.question_id for item in ordered_attempts]))
            .all()
        }

        for attempt_item in ordered_attempts:
            if attempt_item.question_id not in available_questions:
                continue

            question = available_questions[attempt_item.question_id]

            db.add(
                QuizAttemptQuestion(
                    attempt_id=new_attempt.id,
                    question_id=attempt_item.question_id,
                )
            )

            selected_option = (
                attempt_item.selected_option.strip()
                if attempt_item.selected_option
                else None
            )
            # Backward compatibility: older clients may send full option text instead
            # of answer key (A/B/C/D). Convert text to the matching option key.
            if selected_option and len(selected_option) != 1:
                options = [str(opt).strip() for opt in (question.options or [])]
                try:
                    matched_index = options.index(selected_option)
                    selected_option = chr(65 + matched_index)
                except ValueError:
                    pass
            if selected_option:
                db.add(
                    Answer(
                        attempt_id=new_attempt.id,
                        question_id=attempt_item.question_id,
                        selected_option=selected_option,
                    )
                )
    
    # Award gamification points
    current_user.points += max(payload.score, 0)
    _award_gamification(current_user, end_time)
    
    db.commit()
    db.refresh(new_attempt)
    
    return new_attempt


@router.get("/analytics/dashboard", response_model=DashboardAnalyticsResponse)
def dashboard_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempts = db.query(QuizAttempt).filter(QuizAttempt.user_id == current_user.id).all()
    completed = [
        a for a in attempts if a.status in ("completed", "timeout", "terminated")
    ]
    completed.sort(
        key=lambda attempt: (
            attempt.end_time or attempt.start_time or datetime.min.replace(tzinfo=timezone.utc),
            attempt.id,
        ),
        reverse=True,
    )
    in_progress = [a for a in attempts if a.status == "in_progress"]

    score_total = 0.0
    overall_accuracy = 0.0
    weak_topics: Dict[str, int] = {}
    strong_topics: Dict[str, int] = {}

    correct_total = 0
    attempted_total = 0
    for attempt in completed:
        result = _compute_result(attempt, db)
        score_total += float(result.score)
        correct_total += result.correct
        attempted_total += result.correct + result.wrong

        for sub in result.subject_wise:
            if sub.accuracy_percent < 60:
                weak_topics[sub.subject] = weak_topics.get(sub.subject, 0) + 1
            if sub.accuracy_percent >= 75:
                strong_topics[sub.subject] = strong_topics.get(sub.subject, 0) + 1

    if attempted_total:
        overall_accuracy = round((correct_total / attempted_total) * 100, 2)

    avg_score = (score_total / len(completed)) if completed else 0.0

    trend = []
    for attempt in completed[:10]:
        start_iso = _to_utc_iso(attempt.start_time)
        end_iso = _to_utc_iso(attempt.end_time)
        result = _compute_result(attempt, db)
        time_taken = int(attempt.time_taken or 0)
        if time_taken <= 0 and attempt.start_time and attempt.end_time:
            start_dt = (
                attempt.start_time
                if attempt.start_time.tzinfo is not None
                else attempt.start_time.replace(tzinfo=timezone.utc)
            )
            end_dt = (
                attempt.end_time
                if attempt.end_time.tzinfo is not None
                else attempt.end_time.replace(tzinfo=timezone.utc)
            )
            time_taken = max(0, int((end_dt - start_dt).total_seconds()))

        attempted_at = (
            end_iso
            if end_iso
            else start_iso
        )
        trend.append(
            {
                "score": float(result.score),
                "time_taken": float(time_taken),
                "attempted_at": attempted_at,
                "start_time": start_iso,
                "end_time": end_iso,
            }
        )

    return DashboardAnalyticsResponse(
        overall_accuracy=overall_accuracy,
        avg_score=round(avg_score, 2),
        completed_tests=len(completed),
        in_progress_tests=len(in_progress),
        weak_topics=sorted(weak_topics.keys()),
        strong_topics=sorted(strong_topics.keys()),
        trend=trend,
    )


@router.post("/bookmarks", response_model=BookmarkResponse)
def add_bookmark(
    payload: BookmarkCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = (
        db.query(Bookmark)
        .filter(
            Bookmark.user_id == current_user.id,
            Bookmark.question_id == payload.question_id,
        )
        .first()
    )
    if existing:
        return existing

    bookmark = Bookmark(user_id=current_user.id, question_id=payload.question_id)
    db.add(bookmark)
    db.commit()
    db.refresh(bookmark)
    return bookmark


@router.get("/bookmarks", response_model=List[BookmarkResponse])
def get_bookmarks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Bookmark).filter(Bookmark.user_id == current_user.id).all()


@router.get("/bookmarks/details", response_model=List[BookmarkDetailResponse])
def get_bookmark_details(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bookmarks = (
        db.query(Bookmark)
        .filter(Bookmark.user_id == current_user.id)
        .order_by(Bookmark.created_at.desc())
        .all()
    )
    if not bookmarks:
        return []

    question_ids = [bookmark.question_id for bookmark in bookmarks]
    questions = {
        q.id: q for q in db.query(Question).filter(Question.id.in_(question_ids)).all()
    }

    items: List[BookmarkDetailResponse] = []
    for bookmark in bookmarks:
        question = questions.get(bookmark.question_id)
        if not question:
            continue
        items.append(
            BookmarkDetailResponse(
                id=bookmark.id,
                user_id=bookmark.user_id,
                question_id=bookmark.question_id,
                created_at=bookmark.created_at,
                question=QuestionRevisionPublic.model_validate(question),
            )
        )
    return items


@router.delete("/bookmarks/{bookmark_id}")
def remove_bookmark(
    bookmark_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bookmark = (
        db.query(Bookmark)
        .filter(
            Bookmark.id == bookmark_id,
            Bookmark.user_id == current_user.id,
        )
        .first()
    )
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")

    db.delete(bookmark)
    db.commit()
    return {"message": "bookmark removed"}


@router.get("/leaderboard", response_model=List[LeaderboardEntry])
def leaderboard(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    users = (
        db.query(User)
        .order_by(User.points.desc(), User.created_at.asc())
        .limit(50)
        .all()
    )
    return [
        LeaderboardEntry(
            user_id=u.id,
            full_name=u.full_name or f"User {u.id}",
            points=u.points,
            streak_days=u.streak_days,
            badges_count=len(u.badges or []),
        )
        for u in users
    ]


@router.get("/gamification/me", response_model=GamificationProfileResponse)
def gamification_profile(current_user: User = Depends(get_current_user)):
    return GamificationProfileResponse(
        points=current_user.points,
        streak_days=current_user.streak_days,
        badges=list(current_user.badges or []),
    )


@router.get("/study-plan", response_model=StudyPlanResponse)
def study_plan(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    attempts = (
        db.query(QuizAttempt).filter(QuizAttempt.user_id == current_user.id).all()
    )
    completed = [
        a for a in attempts if a.status in ("completed", "timeout", "terminated")
    ]

    accuracy_by_subject: Dict[str, List[float]] = {}
    for attempt in completed:
        result = _compute_result(attempt, db)
        for subject in result.subject_wise:
            accuracy_by_subject.setdefault(subject.subject, []).append(
                subject.accuracy_percent
            )

    subjects = ["Physics", "Chemistry", "Botany", "Zoology"]
    subject_scores = []
    for subject in subjects:
        values = accuracy_by_subject.get(subject, [])
        avg = sum(values) / len(values) if values else 50.0
        subject_scores.append((subject, avg))

    subject_scores.sort(key=lambda item: item[1])
    weakest = subject_scores[:2]

    plan_items = []
    for subject, avg in weakest:
        plan_items.append(
            StudyPlanItem(
                subject=subject,
                focus_topic="NCERT core + PYQ revision",
                recommended_questions=60 if avg < 60 else 40,
                target_accuracy=round(min(avg + 10, 85), 2),
            )
        )

    recommendation = (
        "Take a full mock test today"
        if len(completed) >= 3
        else "Take a subject-wise test today"
    )
    return StudyPlanResponse(
        date=datetime.now(timezone.utc).date().isoformat(),
        items=plan_items,
        revision_minutes=90,
        mock_test_recommendation=recommendation,
    )


@router.get("/rank-prediction", response_model=RankPredictionResponse)
def rank_prediction(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    completed_attempts = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == current_user.id,
            QuizAttempt.status.in_(["completed", "timeout", "terminated"]),
        )
        .order_by(QuizAttempt.end_time.desc())
        .limit(5)
        .all()
    )
    if not completed_attempts:
        return RankPredictionResponse(
            predicted_rank_min=50000, predicted_rank_max=100000, confidence_percent=35.0
        )

    avg_score = sum(a.score for a in completed_attempts) / len(completed_attempts)

    # Simple heuristic baseline; replace with calibrated model in production.
    if avg_score >= 650:
        rank_min, rank_max = 1, 500
    elif avg_score >= 620:
        rank_min, rank_max = 500, 2500
    elif avg_score >= 580:
        rank_min, rank_max = 2500, 10000
    elif avg_score >= 520:
        rank_min, rank_max = 10000, 25000
    else:
        rank_min, rank_max = 25000, 120000

    confidence = min(85.0, 40.0 + (len(completed_attempts) * 8.0))
    return RankPredictionResponse(
        predicted_rank_min=rank_min,
        predicted_rank_max=rank_max,
        confidence_percent=confidence,
    )


@router.get("/scheduled-tests", response_model=List[ScheduledTestPublicResponse])
def user_scheduled_tests(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    tests = (
        db.query(ScheduledTest)
        .order_by(ScheduledTest.scheduled_at.asc())
        .limit(100)
        .all()
    )

    items: List[ScheduledTestPublicResponse] = []
    for test in tests:
        scheduled_at = test.scheduled_at
        if scheduled_at.tzinfo is None:
            scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)

        end_time = scheduled_at + timedelta(seconds=test.duration_seconds)
        if now > end_time:
            continue

        is_live = scheduled_at <= now <= end_time
        status = "live" if is_live else "upcoming"
        seconds_to_start = (
            0 if is_live else max(0, int((scheduled_at - now).total_seconds()))
        )

        items.append(
            ScheduledTestPublicResponse(
                id=test.id,
                title=test.title,
                test_type=test.test_type,
                subject=test.subject,
                scheduled_at=scheduled_at,
                duration_seconds=test.duration_seconds,
                status=status,
                seconds_to_start=seconds_to_start,
            )
        )

    return items
