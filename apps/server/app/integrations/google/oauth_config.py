"""Small helpers for future Google OAuth orchestration."""

from pydantic import BaseModel, ConfigDict, SecretStr

from app.core.config import Settings


class GoogleOAuthConfig(BaseModel):
    """Validated OAuth settings for internal use only."""

    model_config = ConfigDict(frozen=True)

    client_id: str
    client_secret: SecretStr
    redirect_uri: str
    success_redirect_url: str
    error_redirect_url: str
    scopes: tuple[str, ...]

    def require_configured_redirect_uri(self, redirect_uri: str) -> None:
        if redirect_uri != self.redirect_uri:
            raise ValueError("Google OAuth redirect URI must match configuration")

    def is_frontend_redirect_allowed(self, redirect_url: str) -> bool:
        return redirect_url in {
            self.success_redirect_url,
            self.error_redirect_url,
        }


def get_google_oauth_config(settings: Settings) -> GoogleOAuthConfig:
    """Return complete Google OAuth configuration or fail closed."""

    settings.require_google_oauth_available()

    if settings.GOOGLE_OAUTH_CLIENT_ID is None:
        raise RuntimeError("Google OAuth client ID is not configured")
    if settings.GOOGLE_OAUTH_CLIENT_SECRET is None:
        raise RuntimeError("Google OAuth client secret is not configured")
    if settings.GOOGLE_OAUTH_REDIRECT_URI is None:
        raise RuntimeError("Google OAuth redirect URI is not configured")
    if settings.GOOGLE_OAUTH_SUCCESS_REDIRECT_URL is None:
        raise RuntimeError("Google OAuth success redirect URL is not configured")
    if settings.GOOGLE_OAUTH_ERROR_REDIRECT_URL is None:
        raise RuntimeError("Google OAuth error redirect URL is not configured")

    return GoogleOAuthConfig(
        client_id=settings.GOOGLE_OAUTH_CLIENT_ID,
        client_secret=settings.GOOGLE_OAUTH_CLIENT_SECRET,
        redirect_uri=settings.GOOGLE_OAUTH_REDIRECT_URI,
        success_redirect_url=settings.GOOGLE_OAUTH_SUCCESS_REDIRECT_URL,
        error_redirect_url=settings.GOOGLE_OAUTH_ERROR_REDIRECT_URL,
        scopes=settings.GMAIL_OAUTH_SCOPES,
    )
