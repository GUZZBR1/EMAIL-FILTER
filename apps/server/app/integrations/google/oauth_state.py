"""Durable Google OAuth state contracts and helpers."""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Protocol
from uuid import UUID

from app.integrations.google.oauth_config import GoogleOAuthConfig
from app.integrations.google.oauth_urls import validate_http_url

STATE_ENTROPY_BYTES = 32
STATE_HASH_HEX_LENGTH = 64


class OAuthStateError(Exception):
    """Base class for internal OAuth state failures."""


class OAuthStateNotFound(OAuthStateError):
    """The supplied OAuth state was not found or cannot be consumed."""


class OAuthStateExpired(OAuthStateError):
    """The supplied OAuth state exists but is expired."""


class OAuthStateAlreadyConsumed(OAuthStateError):
    """The supplied OAuth state has already been consumed."""


class OAuthStateBindingMismatch(OAuthStateError):
    """The supplied OAuth state is not bound to the expected profile or return."""


class OAuthStatePersistenceError(OAuthStateError):
    """Generic persistence failure for OAuth state storage."""


@dataclass(frozen=True)
class OAuthStateCreate:
    profile_id: UUID
    return_url: str
    ttl_seconds: int
    now: datetime | None = None


@dataclass(frozen=True, repr=False)
class OAuthStateCreated:
    raw_state: str
    profile_id: UUID
    return_url: str
    expires_at: datetime

    def __repr__(self) -> str:
        return (
            "OAuthStateCreated("
            "raw_state=<redacted>, "
            f"profile_id={self.profile_id!r}, "
            f"return_url={self.return_url!r}, "
            f"expires_at={self.expires_at!r})"
        )


@dataclass(frozen=True)
class OAuthStateStored:
    profile_id: UUID
    state_hash: str
    return_url: str
    created_at: datetime
    expires_at: datetime


@dataclass(frozen=True)
class OAuthStateConsumed:
    profile_id: UUID
    return_url: str
    consumed_at: datetime


@dataclass(frozen=True)
class OAuthStateCleanupResult:
    deleted_count: int


class OAuthStateRepository(Protocol):
    def create(self, request: OAuthStateCreate) -> OAuthStateCreated:
        """Create and persist a hashed OAuth state."""
        ...

    def consume(
        self,
        raw_state: str,
        profile_id: UUID,
        return_url: str,
        now: datetime | None = None,
    ) -> OAuthStateConsumed:
        """Atomically consume one valid OAuth state."""
        ...

    def cleanup(
        self,
        older_than: datetime,
    ) -> OAuthStateCleanupResult:
        """Remove expired or old consumed OAuth state records."""
        ...


def generate_oauth_state() -> str:
    """Return a high-entropy URL-safe state value for the OAuth redirect."""

    return secrets.token_urlsafe(STATE_ENTROPY_BYTES)


def hash_oauth_state(raw_state: str) -> str:
    """Return the deterministic SHA-256 hex digest for a raw OAuth state."""

    if raw_state != raw_state.strip() or not raw_state:
        raise ValueError("OAuth state must be a non-blank exact value")
    return hashlib.sha256(raw_state.encode("utf-8")).hexdigest()


def calculate_expires_at(now: datetime, ttl_seconds: int) -> datetime:
    validate_oauth_state_ttl_seconds(ttl_seconds)
    return now + timedelta(seconds=ttl_seconds)


def validate_oauth_state_ttl_seconds(ttl_seconds: int) -> None:
    if ttl_seconds < 300 or ttl_seconds > 900:
        raise ValueError("OAuth state TTL must be between 300 and 900 seconds")


def validate_oauth_return_url(return_url: str, config: GoogleOAuthConfig) -> str:
    validated = validate_http_url(return_url, "return_url")
    if not config.is_frontend_redirect_allowed(validated):
        raise OAuthStateBindingMismatch("OAuth return URL is not allowed")
    return validated


def utc_now() -> datetime:
    return datetime.now(UTC)
