import os
import time
from collections import defaultdict, deque

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel, Field
import openai
import pypdf
from sqlalchemy.orm import Session

from ..core.config import settings
from ..core.database import get_db
from ..models.ai_chat import AIChatMessage
from ..models.user import User
from .deps import get_current_user

router = APIRouter()

client = openai.OpenAI(
    api_key=settings.OPENAI_API_KEY or os.getenv("OPENAI_API_KEY", "")
)

MAX_CHAT_MESSAGE_LEN = 2000
MAX_EXPLAIN_CONTENT_LEN = 12000
RATE_LIMIT_WINDOW_SECONDS = 60
RATE_LIMIT_REQUESTS_PER_WINDOW = 20
_user_request_timestamps = defaultdict(deque)


def _ai_configured() -> bool:
    return bool(client.api_key and str(client.api_key).strip())


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=MAX_CHAT_MESSAGE_LEN)
    subject: str = "General"


class ExplainRequest(BaseModel):
    content: str = Field(min_length=1, max_length=MAX_EXPLAIN_CONTENT_LEN)
    task: str = "summarize"


class ChatHistoryItem(BaseModel):
    id: int
    role: str
    subject: str | None = None
    content: str
    created_at: str


def _load_recent_chat_history(
    db: Session, user_id: int, subject: str | None = None, limit: int = 12
) -> list[AIChatMessage]:
    query = db.query(AIChatMessage).filter(AIChatMessage.user_id == user_id)
    if subject:
        query = query.filter(
            (AIChatMessage.subject == subject) | (AIChatMessage.subject.is_(None))
        )
    rows = (
        query.order_by(AIChatMessage.created_at.desc(), AIChatMessage.id.desc())
        .limit(max(1, min(limit, 20)))
        .all()
    )
    return list(reversed(rows))


def _build_chat_messages(
    system_prompt: str, recent_history: list[AIChatMessage], current_message: str
) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]
    for row in recent_history:
        role = row.role if row.role in {"user", "assistant"} else "assistant"
        messages.append({"role": role, "content": row.content})
    messages.append({"role": "user", "content": current_message})
    return messages


def _check_rate_limit(user_id: int) -> None:
    now = time.time()
    queue = _user_request_timestamps[user_id]
    while queue and now - queue[0] > RATE_LIMIT_WINDOW_SECONDS:
        queue.popleft()

    if len(queue) >= RATE_LIMIT_REQUESTS_PER_WINDOW:
        raise HTTPException(
            status_code=429, detail="Rate limit exceeded. Please try again shortly."
        )

    queue.append(now)


def _generate_with_ai(system_prompt: str, user_prompt: str) -> str:
    if not _ai_configured():
        return "[MOCK] AI key not configured. Configure OPENAI_API_KEY to enable live responses."

    response = client.chat.completions.create(
        model=settings.OPENAI_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.4,
        max_tokens=700,
    )
    return response.choices[0].message.content or ""


@router.get("/status")
def ai_status():
    return {
        "configured": _ai_configured(),
        "model": settings.OPENAI_MODEL,
        "message": "OpenAI connected" if _ai_configured() else "OPENAI_API_KEY missing",
    }


@router.post("/chat")
def ask_ai(
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI Assistant to answer student doubts based on subject domain.
    """
    try:
        _check_rate_limit(current_user.id)
        recent_history = _load_recent_chat_history(
            db, current_user.id, subject=request.subject, limit=10
        )
        db.add(
            AIChatMessage(
                user_id=current_user.id,
                role="user",
                subject=request.subject,
                content=request.message,
            )
        )
        system_prompt = (
            "You are an expert NEET tutor for Physics, Chemistry, Zoology and Botany. "
            "Give concise and exam-focused explanations. Include formulas and memory hooks when useful. "
            "Use the conversation history to stay consistent with previous follow-up questions."
        )
        if _ai_configured():
            response = client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=_build_chat_messages(
                    system_prompt,
                    recent_history,
                    f"Subject: {request.subject}\nQuestion: {request.message}",
                ),
                temperature=0.4,
                max_tokens=700,
            )
            reply = response.choices[0].message.content or ""
        else:
            reply = _generate_with_ai(
                system_prompt=system_prompt,
                user_prompt=f"Subject: {request.subject}\nQuestion: {request.message}",
            )
        db.add(
            AIChatMessage(
                user_id=current_user.id,
                role="assistant",
                subject=request.subject,
                content=reply,
            )
        )
        db.commit()
        return {"response": reply}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/summarize-pdf")
def summarize_pdf(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        _check_rate_limit(current_user.id)
        reader = pypdf.PdfReader(file.file)
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        if not text.strip():
            raise HTTPException(
                status_code=400, detail="Could not extract text from PDF"
            )

        summary = _generate_with_ai(
            system_prompt="Summarize NEET study content into structured notes and revision bullets.",
            user_prompt=text[:12000],
        )
        return {"summary": summary, "filename": file.filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/explain")
def explain_content(
    payload: ExplainRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task_map = {
        "summarize": "Summarize this for NEET revision.",
        "notes": "Convert this to concise study notes and flashcards.",
        "concept": "Explain this concept for a NEET aspirant with simple examples.",
    }
    instruction = task_map.get(payload.task, task_map["summarize"])
    try:
        _check_rate_limit(current_user.id)
        response = _generate_with_ai(
            system_prompt="You are a NEET learning assistant.",
            user_prompt=f"Task: {instruction}\n\nContent:\n{payload.content[:12000]}",
        )
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/history", response_model=list[ChatHistoryItem])
def get_ai_chat_history(
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bounded_limit = max(1, min(limit, 200))
    rows = (
        db.query(AIChatMessage)
        .filter(AIChatMessage.user_id == current_user.id)
        .order_by(AIChatMessage.created_at.asc(), AIChatMessage.id.asc())
        .limit(bounded_limit)
        .all()
    )
    return [
        ChatHistoryItem(
            id=row.id,
            role=row.role,
            subject=row.subject,
            content=row.content,
            created_at=row.created_at.isoformat() if row.created_at else "",
        )
        for row in rows
    ]


@router.delete("/history")
def clear_ai_chat_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.query(AIChatMessage).filter(AIChatMessage.user_id == current_user.id).delete()
    db.commit()
    return {"message": "chat history cleared"}
