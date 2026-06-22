from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    """
    Application configuration loaded from environment variables.
    """
    APP_NAME: str = Field(default="Email Filter API")
    ENV: str = Field(default="development")
    DEBUG: bool = Field(default=True)
    API_VERSION: str = Field(default="v1")
    HOST: str = Field(default="0.0.0.0")
    PORT: int = Field(default=8000)

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
