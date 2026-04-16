from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..models.quiz import StudyMaterial
from ..models.user import User
from ..schemas.quiz import StudyMaterialCreate, StudyMaterialResponse
from .deps import get_current_user, require_admin

router = APIRouter()


@router.post("/", response_model=StudyMaterialResponse)
def create_material(
    payload: StudyMaterialCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    material = StudyMaterial(**payload.model_dump())
    db.add(material)
    db.commit()
    db.refresh(material)
    return material


@router.put("/{material_id}", response_model=StudyMaterialResponse)
def update_material(
    material_id: int,
    payload: StudyMaterialCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    material = db.query(StudyMaterial).filter(StudyMaterial.id == material_id).first()
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")

    material.subject = payload.subject
    material.title = payload.title
    material.pdf_url = payload.pdf_url
    db.commit()
    db.refresh(material)
    return material


@router.get("/", response_model=List[StudyMaterialResponse])
def list_materials(subject: str = "", db: Session = Depends(get_db)):
    query = db.query(StudyMaterial)
    if subject:
        query = query.filter(StudyMaterial.subject == subject)
    return query.order_by(StudyMaterial.uploaded_at.desc()).all()


@router.delete("/{material_id}")
def delete_material(
    material_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    material = db.query(StudyMaterial).filter(StudyMaterial.id == material_id).first()
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")

    db.delete(material)
    db.commit()
    return {"message": "material deleted"}
