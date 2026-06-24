"""PostgreSQL adapter for durable Google OAuth state storage.

This adapter expects a server-side database executor supplied by a future
backend data layer. It does not create connections or carry credentials.
"""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from typing import Any, Protocol
from uuid import UUID

from app.integrations.google.oauth_config import GoogleOAuthConfig
from app.integrations.google.oauth_state import (
    OAuthStateAlreadyConsumed,
    OAuthStateBindingMismatch,
    OAuthStateCleanupResult,
    OAuthStateConsumed,
    OAuthStateCreate,
    OAuthStateCreated,
    OAuthStateExpired,
    OAuthStateNotFound,
    OAuthStatePersistenceError,
    generate_oauth_state,
    hash_oauth_state,
    validate_oauth_state_ttl_seconds,
    validate_oauth_return_url,
)


class PostgresExecutor(Protocol):
    def fetch_one(
        self,
        sql: str,
        parameters: Mapping[str, object],
    ) -> Mapping[str, Any] | None:
        """Execute SQL and return one row."""
        ...

    def execute(
        self,
        sql: str,
        parameters: Mapping[str, object],
    ) -> int:
        """Execute SQL and return affected row count."""
        ...


class PostgresOAuthStateRepository:
    """Durable OAuth state repository backed by PostgreSQL/Supabase."""

    def __init__(self, executor: PostgresExecutor, config: GoogleOAuthConfig) -> None:
        self._executor = executor
        self._config = config

    def create(self, request: OAuthStateCreate) -> OAuthStateCreated:
        validate_oauth_state_ttl_seconds(request.ttl_seconds)
        return_url = validate_oauth_return_url(request.return_url, self._config)
        raw_state = generate_oauth_state()
        state_hash = hash_oauth_state(raw_state)

        try:
            row = self._executor.fetch_one(
                """
                insert into public.google_oauth_states (
                    profile_id,
                    state_hash,
                    return_url,
                    created_at,
                    expires_at
                )
                values (
                    %(profile_id)s,
                    %(state_hash)s,
                    %(return_url)s,
                    pg_catalog.now(),
                    pg_catalog.now() + (%(ttl_seconds)s * interval '1 second')
                )
                returning profile_id, return_url, expires_at
                """,
                {
                    "profile_id": request.profile_id,
                    "state_hash": state_hash,
                    "return_url": return_url,
                    "ttl_seconds": request.ttl_seconds,
                },
            )
        except Exception as exc:
            raise _persistence_failure() from exc
        if row is None:
            raise OAuthStatePersistenceError("OAuth state was not persisted")

        return OAuthStateCreated(
            raw_state=raw_state,
            profile_id=_require_uuid(row, "profile_id"),
            return_url=_require_str(row, "return_url"),
            expires_at=_require_datetime(row, "expires_at"),
        )

    def consume(
        self,
        raw_state: str,
        profile_id: UUID,
        return_url: str,
        now: datetime | None = None,
    ) -> OAuthStateConsumed:
        state_hash = hash_oauth_state(raw_state)
        validated_return_url = validate_oauth_return_url(return_url, self._config)

        try:
            row = self._executor.fetch_one(
                """
                update public.google_oauth_states
                   set consumed_at = pg_catalog.now()
                 where state_hash = %(state_hash)s
                   and profile_id = %(profile_id)s
                   and return_url = %(return_url)s
                   and consumed_at is null
                   and expires_at > pg_catalog.now()
                returning profile_id, return_url, consumed_at
                """,
                {
                    "state_hash": state_hash,
                    "profile_id": profile_id,
                    "return_url": validated_return_url,
                },
            )
        except Exception as exc:
            raise _persistence_failure() from exc
        if row is not None:
            return OAuthStateConsumed(
                profile_id=_require_uuid(row, "profile_id"),
                return_url=_require_str(row, "return_url"),
                consumed_at=_require_datetime(row, "consumed_at"),
            )

        try:
            reason = self._executor.fetch_one(
                """
                select
                    profile_id,
                    return_url,
                    expires_at,
                    consumed_at,
                    pg_catalog.now() as checked_at
                  from public.google_oauth_states
                 where state_hash = %(state_hash)s
                """,
                {"state_hash": state_hash},
            )
        except Exception as exc:
            raise _persistence_failure() from exc
        if reason is None:
            raise OAuthStateNotFound("OAuth state could not be consumed")
        if _require_uuid(reason, "profile_id") != profile_id:
            raise OAuthStateBindingMismatch("OAuth state binding mismatch")
        if _require_str(reason, "return_url") != validated_return_url:
            raise OAuthStateBindingMismatch("OAuth state binding mismatch")
        if _optional_datetime(reason, "consumed_at") is not None:
            raise OAuthStateAlreadyConsumed("OAuth state already consumed")
        if _require_datetime(reason, "expires_at") <= _require_datetime(
            reason,
            "checked_at",
        ):
            raise OAuthStateExpired("OAuth state expired")
        raise OAuthStateNotFound("OAuth state could not be consumed")

    def cleanup(self, older_than: datetime) -> OAuthStateCleanupResult:
        try:
            deleted_count = self._executor.execute(
                """
                delete from public.google_oauth_states
                 where expires_at <= %(older_than)s
                    or consumed_at <= %(older_than)s
                """,
                {"older_than": older_than},
            )
        except Exception as exc:
            raise _persistence_failure() from exc
        return OAuthStateCleanupResult(deleted_count=deleted_count)


def _require_uuid(row: Mapping[str, Any], key: str) -> UUID:
    value = row[key]
    if not isinstance(value, UUID):
        raise OAuthStatePersistenceError(f"Expected UUID for {key}")
    return value


def _require_str(row: Mapping[str, Any], key: str) -> str:
    value = row[key]
    if not isinstance(value, str):
        raise OAuthStatePersistenceError(f"Expected string for {key}")
    return value


def _require_datetime(row: Mapping[str, Any], key: str) -> datetime:
    value = row[key]
    if not isinstance(value, datetime):
        raise OAuthStatePersistenceError(f"Expected datetime for {key}")
    return value


def _optional_datetime(row: Mapping[str, Any], key: str) -> datetime | None:
    value = row[key]
    if value is None or isinstance(value, datetime):
        return value
    raise OAuthStatePersistenceError(f"Expected optional datetime for {key}")


def _persistence_failure() -> OAuthStatePersistenceError:
    return OAuthStatePersistenceError("OAuth state persistence operation failed")
