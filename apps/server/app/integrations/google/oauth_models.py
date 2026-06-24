"""Typed internal contracts for the future Google OAuth flow.

These models intentionally do not represent access tokens or refresh tokens.
Token exchange, encrypted storage, and callback endpoints are later tasks.
"""

from enum import StrEnum
from typing import Self
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    HttpUrl,
    field_validator,
    model_validator,
)

from app.integrations.google.oauth_scopes import GMAIL_OAUTH_SCOPES
from app.integrations.google.oauth_urls import validate_http_url


class GmailConnectionStatus(StrEnum):
    CONNECTED = "connected"
    REVOKED = "revoked"
    BLOCKED_BY_WORKSPACE_ADMIN = "blocked_by_workspace_admin"
    EXPIRED = "expired"
    REFRESHING = "refreshing"
    DISCONNECTED = "disconnected"


class AuthenticatedProfile(BaseModel):
    """Profile resolved from Supabase Auth before Gmail authorization starts."""

    model_config = ConfigDict(frozen=True)

    profile_id: UUID
    auth_user_id: UUID


class GoogleOAuthStateContract(BaseModel):
    """Server-side state persistence contract for the next OAuth task."""

    model_config = ConfigDict(frozen=True)

    state_id: str = Field(min_length=32, max_length=256)
    profile_id: UUID
    return_url: str
    expires_in_seconds: int = Field(gt=0, le=900)
    single_use: bool = True

    @field_validator("return_url")
    @classmethod
    def validate_return_url(cls, value: str) -> str:
        return validate_http_url(value, "return_url")


class GoogleOAuthStartRequest(BaseModel):
    """Internal request needed to create a future Google authorization URL."""

    model_config = ConfigDict(frozen=True)

    profile: AuthenticatedProfile
    return_url: str
    state: GoogleOAuthStateContract
    code_challenge: str | None = Field(default=None, min_length=43, max_length=128)
    code_challenge_method: str | None = Field(default=None, pattern="^S256$")
    scopes: tuple[str, ...] = Field(default=GMAIL_OAUTH_SCOPES)

    @field_validator("return_url")
    @classmethod
    def validate_return_url(cls, value: str) -> str:
        return validate_http_url(value, "return_url")

    @model_validator(mode="after")
    def validate_state_binding(self) -> Self:
        if self.state.profile_id != self.profile.profile_id:
            raise ValueError("OAuth state must be bound to the authenticated profile")
        if self.state.return_url != self.return_url:
            raise ValueError("OAuth state must be bound to the return URL")
        if self.scopes != GMAIL_OAUTH_SCOPES:
            raise ValueError("OAuth start scopes must match the canonical Gmail scopes")
        if (self.code_challenge is None) != (self.code_challenge_method is None):
            raise ValueError("PKCE challenge and method must be provided together")
        return self


class GoogleOAuthCallback(BaseModel):
    """Google OAuth callback payload accepted by future callback handling."""

    model_config = ConfigDict(frozen=True)

    state: str = Field(min_length=32, max_length=256)
    code: str | None = Field(default=None, min_length=1)
    error: str | None = Field(
        default=None,
        min_length=1,
        max_length=128,
        pattern=r"^[A-Za-z0-9_.-]+$",
    )
    error_description: str | None = Field(default=None, max_length=512)

    @field_validator("error_description")
    @classmethod
    def sanitize_error_description(cls, value: str | None) -> str | None:
        if value is None:
            return value
        sanitized = " ".join(value.split())
        return sanitized or None

    @model_validator(mode="after")
    def validate_success_or_error(self) -> Self:
        if bool(self.code) == bool(self.error):
            raise ValueError("OAuth callback must contain either code or error")
        if self.error is None and self.error_description is not None:
            raise ValueError("OAuth error_description requires error")
        return self


class GoogleOAuthConnectionResult(BaseModel):
    """Internal result after future code exchange and Google identity lookup."""

    model_config = ConfigDict(frozen=True)

    google_subject: str = Field(min_length=1)
    email: str = Field(min_length=1)
    display_name: str | None = None
    avatar_url: HttpUrl | None = None
    granted_scopes: tuple[str, ...]
    initial_status: GmailConnectionStatus = GmailConnectionStatus.CONNECTED

    @model_validator(mode="after")
    def validate_granted_scopes(self) -> Self:
        unknown_scopes = set(self.granted_scopes) - set(GMAIL_OAUTH_SCOPES)
        if unknown_scopes:
            raise ValueError("Granted scopes contain values outside the MVP contract")
        return self
