import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Apartment(Base):
    __tablename__ = "apartments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[str] = mapped_column(Text, nullable=False)
    image_url: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("NOW()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("NOW()"), onupdate=datetime.utcnow)

    buildings: Mapped[list["ApartmentBuilding"]] = relationship(
        "ApartmentBuilding", back_populates="apartment", lazy="selectin",
        cascade="all, delete-orphan", order_by="ApartmentBuilding.name",
    )


class ApartmentBuilding(Base):
    __tablename__ = "apartment_buildings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    apartment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("apartments.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("NOW()"))

    apartment: Mapped["Apartment"] = relationship("Apartment", back_populates="buildings")

    __table_args__ = (UniqueConstraint("apartment_id", "name"),)
