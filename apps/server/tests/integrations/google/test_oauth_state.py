from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from pydantic import SecretStr

from app.integrations.google.oauth_config import GoogleOAuthConfig
from app.integrations.google.oauth_models import (
    GoogleOAuthCallback,
    GoogleOAuthConnectionResult,
    GoogleOAuthStartRequest,
    GoogleOAuthStateContract,
)
from app.integrations.google.oauth_state import (
    OAuthStateAlreadyConsumed,
    OAuthStateBindingMismatch,
    OAuthStateCleanupResult,
    OAuthStateConsumed,
    OAuthStateCreate,
    OAuthStateCreated,
    OAuthStateExpired,
    OAuthStateNotFound,
    OAuthStateRepository,
    OAuthStateStored,
    calculate_expires_at,
    generate_oauth_state,
    hash_oauth_state,
    validate_oauth_return_url,
)


SUCCESS_URL = "https://app.example.invalid/settings/accounts?gmail=connected"
ERROR_URL = "https://app.example.invalid/settings/accounts?gmail=error"


@dataclass
class StoredState:
    profile_id: UUID
    state_hash: str
    return_url: str
    created_at: datetime
    expires_at: datetime
    consumed_at: datetime | None = None


class FakeOAuthStateRepository:
    def __init__(self, config: GoogleOAuthConfig) -> None:
        self.records: dict[str, StoredState] = {}
        self.config = config

    def create(self, request: OAuthStateCreate) -> OAuthStateCreated:
        now = request.now or datetime.now(UTC)
        return_url = validate_oauth_return_url(request.return_url, self.config)
        expires_at = calculate_expires_at(now, request.ttl_seconds)
        raw_state = generate_oauth_state()
        state_hash = hash_oauth_state(raw_state)
        self.records[state_hash] = StoredState(
            profile_id=request.profile_id,
            state_hash=state_hash,
            return_url=return_url,
            created_at=now,
            expires_at=expires_at,
        )
        return OAuthStateCreated(
            raw_state=raw_state,
            profile_id=request.profile_id,
            return_url=return_url,
            expires_at=expires_at,
        )

    def consume(
        self,
        raw_state: str,
        profile_id: UUID,
        return_url: str,
        now: datetime | None = None,
    ) -> OAuthStateConsumed:
        consumed_at = now or datetime.now(UTC)
        validated_return_url = validate_oauth_return_url(return_url, self.config)
        state_hash = hash_oauth_state(raw_state)
        record = self.records.get(state_hash)
        if record is None:
            raise OAuthStateNotFound("OAuth state could not be consumed")
        if record.profile_id != profile_id:
            raise OAuthStateBindingMismatch("OAuth state binding mismatch")
        if record.return_url != validated_return_url:
            raise OAuthStateBindingMismatch("OAuth state binding mismatch")
        if record.consumed_at is not None:
            raise OAuthStateAlreadyConsumed("OAuth state already consumed")
        if record.expires_at <= consumed_at:
            raise OAuthStateExpired("OAuth state expired")

        record.consumed_at = consumed_at
        return OAuthStateConsumed(
            profile_id=record.profile_id,
            return_url=record.return_url,
            consumed_at=consumed_at,
        )

    def cleanup(self, older_than: datetime) -> OAuthStateCleanupResult:
        eligible_hashes = [
            state_hash
            for state_hash, record in self.records.items()
            if record.expires_at <= older_than
            or (
                record.consumed_at is not None
                and record.consumed_at <= older_than
            )
        ]
        for state_hash in eligible_hashes:
            del self.records[state_hash]
        return OAuthStateCleanupResult(deleted_count=len(eligible_hashes))


def oauth_config() -> GoogleOAuthConfig:
    return GoogleOAuthConfig(
        client_id="google-client-id.apps.googleusercontent.com",
        client_secret=SecretStr("google-client-secret-placeholder"),
        redirect_uri="https://api.example.invalid/api/v1/google/oauth/callback",
        success_redirect_url=SUCCESS_URL,
        error_redirect_url=ERROR_URL,
        scopes=("openid",),
    )


def create_state(
    repository: OAuthStateRepository,
    profile_id: UUID,
    now: datetime,
    return_url: str = SUCCESS_URL,
    ttl_seconds: int = 600,
) -> OAuthStateCreated:
    return repository.create(
        OAuthStateCreate(
            profile_id=profile_id,
            return_url=return_url,
            ttl_seconds=ttl_seconds,
            now=now,
        )
    )


def test_raw_state_has_adequate_entropy() -> None:
    first = generate_oauth_state()
    second = generate_oauth_state()

    assert first != second
    assert len(first) >= 43


def test_raw_state_is_not_persisted() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    created = create_state(repository, uuid4(), datetime(2026, 1, 1, tzinfo=UTC))

    stored = next(iter(repository.records.values()))
    assert stored.state_hash == hash_oauth_state(created.raw_state)
    assert created.raw_state not in repr(stored)
    assert not hasattr(stored, "raw_state")


def test_state_hash_is_deterministic() -> None:
    raw_state = "state-" + ("a" * 40)

    assert hash_oauth_state(raw_state) == hash_oauth_state(raw_state)
    assert len(hash_oauth_state(raw_state)) == 64


def test_different_states_produce_different_hashes() -> None:
    assert hash_oauth_state("state-" + ("a" * 40)) != hash_oauth_state(
        "state-" + ("b" * 40)
    )


def test_creation_rejects_disallowed_return_url() -> None:
    repository = FakeOAuthStateRepository(oauth_config())

    with pytest.raises(OAuthStateBindingMismatch):
        create_state(
            repository,
            uuid4(),
            datetime(2026, 1, 1, tzinfo=UTC),
            return_url="https://evil.example.invalid/settings/accounts",
        )


def test_expiration_is_short_and_in_the_future() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, uuid4(), now)

    assert created.expires_at == now + timedelta(seconds=600)


def test_valid_state_consumption_succeeds_once() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    profile_id = uuid4()
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, profile_id, now)

    consumed = repository.consume(
        created.raw_state,
        profile_id=profile_id,
        return_url=SUCCESS_URL,
        now=now + timedelta(seconds=60),
    )

    assert consumed.profile_id == profile_id
    assert consumed.return_url == SUCCESS_URL


def test_second_state_consumption_fails() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    profile_id = uuid4()
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, profile_id, now)

    repository.consume(created.raw_state, profile_id, SUCCESS_URL, now)

    with pytest.raises(OAuthStateAlreadyConsumed):
        repository.consume(created.raw_state, profile_id, SUCCESS_URL, now)


def test_expired_state_fails() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    profile_id = uuid4()
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, profile_id, now)

    with pytest.raises(OAuthStateExpired):
        repository.consume(
            created.raw_state,
            profile_id,
            SUCCESS_URL,
            now + timedelta(seconds=601),
        )


def test_missing_state_fails() -> None:
    repository = FakeOAuthStateRepository(oauth_config())

    with pytest.raises(OAuthStateNotFound):
        repository.consume(
            "state-" + ("z" * 40),
            uuid4(),
            SUCCESS_URL,
            datetime(2026, 1, 1, tzinfo=UTC),
        )


def test_wrong_profile_binding_fails() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, uuid4(), now)

    with pytest.raises(OAuthStateBindingMismatch):
        repository.consume(created.raw_state, uuid4(), SUCCESS_URL, now)


def test_wrong_return_binding_fails() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    profile_id = uuid4()
    now = datetime(2026, 1, 1, tzinfo=UTC)
    created = create_state(repository, profile_id, now, return_url=SUCCESS_URL)

    with pytest.raises(OAuthStateBindingMismatch):
        repository.consume(created.raw_state, profile_id, ERROR_URL, now)


def test_representations_do_not_expose_raw_state() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    created = create_state(repository, uuid4(), datetime(2026, 1, 1, tzinfo=UTC))

    assert created.raw_state not in repr(created)


def test_public_models_do_not_expose_state_hash() -> None:
    public_models = (
        GoogleOAuthStateContract,
        GoogleOAuthStartRequest,
        GoogleOAuthCallback,
        GoogleOAuthConnectionResult,
    )

    for model in public_models:
        assert "state_hash" not in model.model_fields
    assert "state_hash" in OAuthStateStored.__dataclass_fields__


def test_cleanup_identifies_eligible_records() -> None:
    repository = FakeOAuthStateRepository(oauth_config())
    now = datetime(2026, 1, 1, tzinfo=UTC)
    expired = create_state(repository, uuid4(), now - timedelta(minutes=30))
    consumed = create_state(repository, uuid4(), now)
    retained = create_state(repository, uuid4(), now)
    repository.consume(consumed.raw_state, consumed.profile_id, SUCCESS_URL, now)

    result = repository.cleanup(now)

    assert result.deleted_count == 2
    assert hash_oauth_state(expired.raw_state) not in repository.records
    assert hash_oauth_state(consumed.raw_state) not in repository.records
    assert hash_oauth_state(retained.raw_state) in repository.records
