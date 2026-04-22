from pydantic import BaseModel, ConfigDict, Field, model_validator
from typing import List, Optional, Dict
from datetime import datetime


class QuestionBase(BaseModel):
    subject: str
    topic: str
    difficulty: str
    question_text: str
    options: List[str]
    correct_answer: str
    explanation: Optional[str] = None
    image_url: Optional[str] = None

    @model_validator(mode="after")
    def _normalize_image_url(self):
        if self.image_url is not None and not self.image_url.strip():
            self.image_url = None
        return self


class QuestionCreate(QuestionBase):
    pass


class QuestionResponse(QuestionBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class QuizAttemptBase(BaseModel):
    test_type: str = "full"
    subject: Optional[str] = None


class QuizAttemptCreate(QuizAttemptBase):
    question_count: int = 180


class QuizAttemptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    start_time: datetime
    end_time: Optional[datetime]
    time_taken: int
    duration_seconds: int
    score: float
    status: str
    cheat_count: int
    test_type: str
    subject: Optional[str]

class QuestionPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    subject: str
    topic: str
    difficulty: str
    question_text: str
    options: List[str]
    image_url: Optional[str] = None


class AttemptDetailResponse(QuizAttemptResponse):
    questions: List[QuestionPublic]


class AnswerSubmit(BaseModel):
    question_id: int
    selected_option: str


class CheatLogRequest(BaseModel):
    event: str = Field(default="app_backgrounded", min_length=3)


class SubjectAnalytics(BaseModel):
    subject: str
    attempted: int
    correct: int
    wrong: int
    score: int
    accuracy_percent: float


class QuestionResultItem(BaseModel):
    question_number: int
    question_id: int
    status: str
    selected_option: Optional[str] = None
    correct_answer: str


class QuizResultResponse(BaseModel):
    attempt_id: int
    score: int
    correct: int
    wrong: int
    unattempted: int
    accuracy_percent: float
    time_taken: int
    subject_wise: List[SubjectAnalytics]
    question_results: List[QuestionResultItem] = []


class StudyMaterialCreate(BaseModel):
    subject: str
    title: str
    pdf_url: str


class StudyMaterialResponse(StudyMaterialCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    uploaded_at: datetime


class BookmarkCreate(BaseModel):
    question_id: int


class BookmarkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    question_id: int
    created_at: datetime


class QuestionRevisionPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    subject: str
    topic: str
    difficulty: str
    question_text: str
    options: List[str]
    correct_answer: str
    explanation: Optional[str] = None
    image_url: Optional[str] = None


class BookmarkDetailResponse(BaseModel):
    id: int
    user_id: int
    question_id: int
    created_at: datetime
    question: QuestionRevisionPublic


class LeaderboardEntry(BaseModel):
    user_id: int
    full_name: str
    points: int
    streak_days: int
    badges_count: int


class GamificationProfileResponse(BaseModel):
    points: int
    streak_days: int
    badges: List[str]


class DashboardAnalyticsResponse(BaseModel):
    overall_accuracy: float
    avg_score: float
    completed_tests: int
    in_progress_tests: int
    weak_topics: List[str]
    strong_topics: List[str]
    trend: List[Dict[str, float | str]]


class StudyPlanItem(BaseModel):
    subject: str
    focus_topic: str
    recommended_questions: int
    target_accuracy: float


class StudyPlanResponse(BaseModel):
    date: str
    items: List[StudyPlanItem]
    revision_minutes: int
    mock_test_recommendation: str


class RankPredictionResponse(BaseModel):
    predicted_rank_min: int
    predicted_rank_max: int
    confidence_percent: float


class WrongQuestionItem(BaseModel):
    question: QuestionPublic
    selected_option: str
    correct_answer: str
    last_attempt_id: int
    last_attempted_at: datetime


class WrongQuestionListResponse(BaseModel):
    total: int
    items: List[WrongQuestionItem]


class ReattemptStartRequest(BaseModel):
    question_ids: Optional[List[int]] = None
    subject: Optional[str] = None
    question_count: int = 30
    from_latest_completed_test: bool = False


class AnnouncementCreate(BaseModel):
    title: str
    content: str


class AnnouncementResponse(AnnouncementCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


class ScheduledTestCreate(BaseModel):
    title: str
    test_type: str = "full"
    subject: Optional[str] = None
    scheduled_at: datetime
    duration_seconds: int = 10800


class ScheduledTestResponse(ScheduledTestCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


class ScheduledTestPublicResponse(BaseModel):
    id: int
    title: str
    test_type: str
    subject: Optional[str] = None
    scheduled_at: datetime
    duration_seconds: int
    status: str
    seconds_to_start: int


class JsonQuestionAttemptSubmit(BaseModel):
    question_id: int
    selected_option: Optional[str] = None


class JsonQuizResultSubmit(BaseModel):
    """Schema for submitting JSON quiz results (local quiz)"""
    score: int
    total: int
    time_taken_seconds: int
    duration_seconds: int = 10800
    accuracy_percent: Optional[float] = None
    test_type: str = "json_mock"
    subject: Optional[str] = None
    question_attempts: Optional[List[JsonQuestionAttemptSubmit]] = None
