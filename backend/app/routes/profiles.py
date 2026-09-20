"""
User profile management endpoints with health category-based alert thresholds.
"""
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from app.database import get_db
from app.config import settings

router = APIRouter(prefix="/api", tags=["profiles"])


class ProfileCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    health_category: str = Field(default="normal", pattern="^(normal|asthmatic|elderly|children)$")
    custom_threshold: Optional[int] = Field(default=None, ge=50, le=500)
    fcm_token: Optional[str] = None


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    health_category: Optional[str] = Field(default=None, pattern="^(normal|asthmatic|elderly|children)$")
    custom_threshold: Optional[int] = Field(default=None, ge=50, le=500)
    fcm_token: Optional[str] = None


class ProfileResponse(BaseModel):
    id: str
    name: str
    health_category: str
    custom_threshold: Optional[int]
    effective_threshold: int
    fcm_token: Optional[str]
    created_at: str
    updated_at: str


@router.post("/profiles", response_model=ProfileResponse)
async def create_profile(profile: ProfileCreate):
    """Create a new user profile with health sensitivity settings."""
    user_id = str(uuid.uuid4())[:8]
    now = datetime.now().isoformat()

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO user_profiles (id, name, health_category, custom_threshold, fcm_token, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (user_id, profile.name, profile.health_category, profile.custom_threshold, profile.fcm_token, now, now))
    conn.commit()
    conn.close()

    effective = profile.custom_threshold or settings.HEALTH_THRESHOLDS.get(profile.health_category, 300)

    return ProfileResponse(
        id=user_id,
        name=profile.name,
        health_category=profile.health_category,
        custom_threshold=profile.custom_threshold,
        effective_threshold=effective,
        fcm_token=profile.fcm_token,
        created_at=now,
        updated_at=now
    )


@router.get("/profiles/{user_id}", response_model=ProfileResponse)
async def get_profile(user_id: str):
    """Get a user profile by ID."""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM user_profiles WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail=f"Profile {user_id} not found")

    effective = row[3] or settings.HEALTH_THRESHOLDS.get(row[2], 300)

    return ProfileResponse(
        id=row[0],
        name=row[1],
        health_category=row[2],
        custom_threshold=row[3],
        effective_threshold=effective,
        fcm_token=row[4],
        created_at=row[5],
        updated_at=row[6]
    )


@router.put("/profiles/{user_id}", response_model=ProfileResponse)
async def update_profile(user_id: str, updates: ProfileUpdate):
    """Update an existing user profile."""
    conn = get_db()
    cursor = conn.cursor()

    # Check profile exists
    cursor.execute("SELECT * FROM user_profiles WHERE id = ?", (user_id,))
    existing = cursor.fetchone()
    if existing is None:
        conn.close()
        raise HTTPException(status_code=404, detail=f"Profile {user_id} not found")

    # Build update query
    now = datetime.now().isoformat()
    name = updates.name or existing[1]
    health_category = updates.health_category or existing[2]
    custom_threshold = updates.custom_threshold if updates.custom_threshold is not None else existing[3]
    fcm_token = updates.fcm_token if updates.fcm_token is not None else existing[4]

    cursor.execute("""
        UPDATE user_profiles 
        SET name=?, health_category=?, custom_threshold=?, fcm_token=?, updated_at=?
        WHERE id=?
    """, (name, health_category, custom_threshold, fcm_token, now, user_id))
    conn.commit()
    conn.close()

    effective = custom_threshold or settings.HEALTH_THRESHOLDS.get(health_category, 300)

    return ProfileResponse(
        id=user_id,
        name=name,
        health_category=health_category,
        custom_threshold=custom_threshold,
        effective_threshold=effective,
        fcm_token=fcm_token,
        created_at=existing[5],
        updated_at=now
    )


@router.get("/profiles", response_model=List[ProfileResponse])
async def list_profiles():
    """List all user profiles."""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM user_profiles ORDER BY created_at DESC")
    rows = cursor.fetchall()
    conn.close()

    profiles = []
    for row in rows:
        effective = row[3] or settings.HEALTH_THRESHOLDS.get(row[2], 300)
        profiles.append(ProfileResponse(
            id=row[0],
            name=row[1],
            health_category=row[2],
            custom_threshold=row[3],
            effective_threshold=effective,
            fcm_token=row[4],
            created_at=row[5],
            updated_at=row[6]
        ))

    return profiles


@router.get("/profiles/{user_id}/alerts")
async def get_user_alerts(user_id: str, limit: int = 20):
    """Get recent alerts for a user."""
    from app.services.alerts import get_user_alerts as fetch_alerts
    return fetch_alerts(user_id, limit)
