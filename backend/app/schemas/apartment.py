import uuid
from datetime import datetime

from pydantic import BaseModel


class BuildingOut(BaseModel):
    id: uuid.UUID
    name: str
    model_config = {"from_attributes": True}


class ApartmentOut(BaseModel):
    id: uuid.UUID
    name: str
    address: str
    image_url: str | None = None
    created_at: datetime
    updated_at: datetime
    buildings: list[BuildingOut] = []
    model_config = {"from_attributes": True}


class BuildingIn(BaseModel):
    name: str


class ApartmentCreate(BaseModel):
    name: str
    address: str
    buildings: list[str] = []
    image_url: str | None = None


class ApartmentUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    buildings: list[str] | None = None
    image_url: str | None = None
