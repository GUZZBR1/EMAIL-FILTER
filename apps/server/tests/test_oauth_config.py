import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.integrations.google.oauth_config import get_google_oauth_config
from app.integrations.google.oauth_scopes import (
    GMAIL_OAUTH_SCOPES,
    GMAIL_OAUTH_WRITE_SCOPE_MARKERS,
)
from app.main import app


def complete_oauth_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "GOOGLE_OAUTH_ENABLED": True,
        "GOOGLE_OAUTH_CLIENT_ID": "google-client-id.apps.googleusercontent.com",
        "GOOGLE_OAUTH_CLIENT_SECRET": "google-client-secret-placeholder",
        "GOOGLE_OAUTH_REDIRECT_URI": (
            "https://api.example.invalid/api/v1/google/oauth/callback"
        ),
        "GOOGLE_OAUTH_SUCCESS_REDIRECT_URL": (
            "https://app.example.invalid/settings/accounts?gmail=connected"
        ),
        "GOOGLE_OAUTH_ERROR_REDIRECT_URL": (
            "https://app.example.invalid/settings/accounts?gmail=error"
        ),
        "GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST": (
            "https://app.example.invalid/settings/accounts?gmail=connected",
            "https://app.example.invalid/settings/accounts?gmail=error",
        ),
    }
    values.update(overrides)
    return Settings(**values)


def test_backend_initializes_without_oauth_configuration() -> None:
    settings = Settings()

    assert settings.google_oauth_available is False


def test_health_check_works_without_oauth_configuration() -> None:
    client = TestClient(app)

    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "email-filter-api"}


def test_complete_oauth_configuration_is_accepted() -> None:
    settings = complete_oauth_settings()

    assert settings.google_oauth_available is True
    config = get_google_oauth_config(settings)
    assert config.client_id == "google-client-id.apps.googleusercontent.com"
    assert config.scopes == GMAIL_OAUTH_SCOPES
    config.require_configured_redirect_uri(
        "https://api.example.invalid/api/v1/google/oauth/callback"
    )
    assert config.is_frontend_redirect_allowed(
        "https://app.example.invalid/settings/accounts?gmail=connected"
    )
    assert not config.is_frontend_redirect_allowed(
        "https://evil.example.invalid/settings/accounts?gmail=connected"
    )


def test_redirect_uri_must_match_configuration_exactly() -> None:
    config = get_google_oauth_config(complete_oauth_settings())

    with pytest.raises(ValueError, match="must match configuration"):
        config.require_configured_redirect_uri(
            "https://api.example.invalid/api/v1/google/oauth/callback/"
        )


@pytest.mark.parametrize(
    "missing_field",
    [
        "GOOGLE_OAUTH_CLIENT_ID",
        "GOOGLE_OAUTH_CLIENT_SECRET",
    ],
)
def test_required_oauth_credentials_missing_make_oauth_unavailable(
    missing_field: str,
) -> None:
    settings = complete_oauth_settings(**{missing_field: None})

    assert settings.google_oauth_available is False
    with pytest.raises(RuntimeError, match="incompletely configured"):
        get_google_oauth_config(settings)


def test_invalid_redirect_uri_is_rejected() -> None:
    with pytest.raises(ValidationError):
        complete_oauth_settings(GOOGLE_OAUTH_REDIRECT_URI="javascript:alert(1)")


def test_success_url_outside_allowlist_is_rejected() -> None:
    with pytest.raises(ValidationError):
        complete_oauth_settings(
            GOOGLE_OAUTH_SUCCESS_REDIRECT_URL=(
                "https://evil.example.invalid/settings/accounts"
            )
        )


def test_error_url_outside_allowlist_is_rejected() -> None:
    with pytest.raises(ValidationError):
        complete_oauth_settings(
            GOOGLE_OAUTH_ERROR_REDIRECT_URL=(
                "https://evil.example.invalid/settings/accounts"
            )
        )


def test_gmail_scopes_do_not_contain_write_permissions() -> None:
    assert all(
        marker not in scope
        for scope in GMAIL_OAUTH_SCOPES
        for marker in GMAIL_OAUTH_WRITE_SCOPE_MARKERS
    )


def test_gmail_scopes_are_only_the_canonical_values() -> None:
    assert GMAIL_OAUTH_SCOPES == (
        "openid",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/gmail.readonly",
    )
    with pytest.raises(ValidationError):
        complete_oauth_settings(
            GMAIL_OAUTH_SCOPES=GMAIL_OAUTH_SCOPES
            + ("https://www.googleapis.com/auth/gmail.modify",)
        )


def test_settings_representation_does_not_expose_client_secret() -> None:
    settings = complete_oauth_settings()
    config = get_google_oauth_config(settings)

    assert "google-client-secret-placeholder" not in repr(settings)
    assert "google-client-secret-placeholder" not in settings.model_dump_json()
    assert "google-client-secret-placeholder" not in repr(config)
    assert "google-client-secret-placeholder" not in config.model_dump_json()
