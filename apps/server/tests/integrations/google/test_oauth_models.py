from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.integrations.google.oauth_models import (
    AuthenticatedProfile,
    GmailConnectionStatus,
    GoogleOAuthCallback,
    GoogleOAuthConnectionResult,
    GoogleOAuthStartRequest,
    GoogleOAuthStateContract,
)
from app.integrations.google.oauth_scopes import GMAIL_OAUTH_SCOPES


def test_callback_model_accepts_success() -> None:
    callback = GoogleOAuthCallback(
        state="state-" + ("a" * 40),
        code="authorization-code-placeholder",
    )

    assert callback.code == "authorization-code-placeholder"
    assert callback.error is None


def test_callback_model_accepts_error() -> None:
    callback = GoogleOAuthCallback(
        state="state-" + ("b" * 40),
        error="access_denied",
        error_description="User denied\nGmail authorization.",
    )

    assert callback.error == "access_denied"
    assert callback.error_description == "User denied Gmail authorization."
    assert callback.code is None


@pytest.mark.parametrize(
    "payload",
    [
        {"state": "state-" + ("c" * 40)},
        {
            "state": "state-" + ("d" * 40),
            "code": "authorization-code-placeholder",
            "error": "access_denied",
        },
        {
            "state": "state-" + ("e" * 40),
            "error_description": "description without error",
        },
    ],
)
def test_invalid_callback_model_is_rejected(payload: dict[str, str]) -> None:
    with pytest.raises(ValidationError):
        GoogleOAuthCallback(**payload)


def test_start_contract_binds_state_to_profile_and_return_url() -> None:
    profile_id = uuid4()
    auth_user_id = uuid4()
    return_url = "https://app.example.invalid/settings/accounts?gmail=return"
    profile = AuthenticatedProfile(
        profile_id=profile_id,
        auth_user_id=auth_user_id,
    )
    state = GoogleOAuthStateContract(
        state_id="state-" + ("f" * 40),
        profile_id=profile_id,
        return_url=return_url,
        expires_in_seconds=300,
    )

    request = GoogleOAuthStartRequest(
        profile=profile,
        return_url=return_url,
        state=state,
        code_challenge="a" * 43,
        code_challenge_method="S256",
    )

    assert request.scopes == GMAIL_OAUTH_SCOPES


def test_start_contract_rejects_state_bound_to_another_profile() -> None:
    profile = AuthenticatedProfile(profile_id=uuid4(), auth_user_id=uuid4())
    state = GoogleOAuthStateContract(
        state_id="state-" + ("g" * 40),
        profile_id=uuid4(),
        return_url="https://app.example.invalid/settings/accounts?gmail=return",
        expires_in_seconds=300,
    )

    with pytest.raises(ValidationError):
        GoogleOAuthStartRequest(
            profile=profile,
            return_url="https://app.example.invalid/settings/accounts?gmail=return",
            state=state,
        )


def test_connection_result_accepts_initial_connected_status_without_tokens() -> None:
    result = GoogleOAuthConnectionResult(
        google_subject="google-subject-placeholder",
        email="user@example.invalid",
        display_name="Example User",
        avatar_url="https://example.invalid/avatar.png",
        granted_scopes=GMAIL_OAUTH_SCOPES,
        initial_status=GmailConnectionStatus.CONNECTED,
    )

    assert result.google_subject == "google-subject-placeholder"
    assert result.initial_status == GmailConnectionStatus.CONNECTED


def test_public_contract_models_do_not_define_token_fields() -> None:
    models = (
        AuthenticatedProfile,
        GoogleOAuthStateContract,
        GoogleOAuthStartRequest,
        GoogleOAuthCallback,
        GoogleOAuthConnectionResult,
    )

    for model in models:
        assert all("token" not in field_name for field_name in model.model_fields)
