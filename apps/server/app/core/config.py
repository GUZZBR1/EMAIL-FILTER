from typing import Literal, Self

from pydantic import Field, SecretStr, ValidationInfo, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.integrations.google.oauth_scopes import GMAIL_OAUTH_SCOPES
from app.integrations.google.oauth_urls import validate_http_url

AppEnvironment = Literal["development", "test", "staging", "production"]


class Settings(BaseSettings):
    """
    Application configuration loaded from environment variables.
    """
    APP_NAME: str = Field(default="Email Filter API")
    ENV: AppEnvironment = Field(default="development")
    DEBUG: bool = Field(default=True)
    API_VERSION: str = Field(default="v1")
    HOST: str = Field(default="0.0.0.0")
    PORT: int = Field(default=8000)
    GOOGLE_OAUTH_ENABLED: bool = Field(default=False)
    GOOGLE_OAUTH_CLIENT_ID: str | None = Field(default=None)
    GOOGLE_OAUTH_CLIENT_SECRET: SecretStr | None = Field(default=None)
    GOOGLE_OAUTH_REDIRECT_URI: str | None = Field(default=None)
    GOOGLE_OAUTH_SUCCESS_REDIRECT_URL: str | None = Field(default=None)
    GOOGLE_OAUTH_ERROR_REDIRECT_URL: str | None = Field(default=None)
    GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST: tuple[str, ...] = Field(
        default_factory=tuple
    )
    GOOGLE_OAUTH_STATE_TTL_SECONDS: int = Field(default=600, ge=300, le=900)
    GMAIL_OAUTH_SCOPES: tuple[str, ...] = Field(default=GMAIL_OAUTH_SCOPES)

    @field_validator("GOOGLE_OAUTH_CLIENT_ID")
    @classmethod
    def validate_optional_non_blank(cls, value: str | None) -> str | None:
        if value is None:
            return value
        if value != value.strip() or not value:
            raise ValueError("GOOGLE_OAUTH_CLIENT_ID must be a non-blank value")
        return value

    @field_validator("GOOGLE_OAUTH_CLIENT_SECRET")
    @classmethod
    def validate_optional_secret(cls, value: SecretStr | None) -> SecretStr | None:
        if value is None:
            return value
        secret = value.get_secret_value()
        if secret != secret.strip() or not secret:
            raise ValueError("GOOGLE_OAUTH_CLIENT_SECRET must be a non-blank value")
        return value

    @field_validator(
        "GOOGLE_OAUTH_REDIRECT_URI",
        "GOOGLE_OAUTH_SUCCESS_REDIRECT_URL",
        "GOOGLE_OAUTH_ERROR_REDIRECT_URL",
    )
    @classmethod
    def validate_optional_url(
        cls, value: str | None, info: ValidationInfo
    ) -> str | None:
        if value is None:
            return value
        field_name = getattr(info, "field_name", "URL")
        return validate_http_url(value, field_name)

    @field_validator("GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST")
    @classmethod
    def validate_frontend_redirect_allowlist(
        cls, value: tuple[str, ...]
    ) -> tuple[str, ...]:
        for url in value:
            validate_http_url(url, "GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST")
        if len(set(value)) != len(value):
            raise ValueError("GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST has duplicates")
        return value

    @field_validator("GMAIL_OAUTH_SCOPES")
    @classmethod
    def validate_gmail_scopes(cls, value: tuple[str, ...]) -> tuple[str, ...]:
        if value != GMAIL_OAUTH_SCOPES:
            raise ValueError("GMAIL_OAUTH_SCOPES must match the canonical Gmail scopes")
        return value

    @model_validator(mode="after")
    def validate_frontend_redirect_urls(self) -> Self:
        allowlist = set(self.GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST)
        for field_name in (
            "GOOGLE_OAUTH_SUCCESS_REDIRECT_URL",
            "GOOGLE_OAUTH_ERROR_REDIRECT_URL",
        ):
            url = getattr(self, field_name)
            if url is not None and allowlist and url not in allowlist:
                raise ValueError(f"{field_name} must be in the configured allowlist")
        return self

    @property
    def google_oauth_available(self) -> bool:
        return (
            self.GOOGLE_OAUTH_ENABLED
            and self.GOOGLE_OAUTH_CLIENT_ID is not None
            and self.GOOGLE_OAUTH_CLIENT_SECRET is not None
            and self.GOOGLE_OAUTH_REDIRECT_URI is not None
            and self.GOOGLE_OAUTH_SUCCESS_REDIRECT_URL is not None
            and self.GOOGLE_OAUTH_ERROR_REDIRECT_URL is not None
        )

    def require_google_oauth_available(self) -> None:
        if not self.google_oauth_available:
            raise RuntimeError(
                "Google OAuth is disabled or incompletely configured for this "
                "environment"
            )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
