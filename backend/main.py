from fastapi import FastAPI
import json
import os

app = FastAPI()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FILE_PATH = os.path.join(BASE_DIR, "questions.json")


@app.get("/")
def home():
    return {"message": "Quiz API running"}


@app.get("/questions")
def get_questions():
    if not os.path.exists(FILE_PATH):
        return []
    with open(FILE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)
