from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    tavily_api_key: str = Field(default="", alias="TAVILY_API_KEY")
    gemini_api_key: str = Field(default="", alias="GEMINI_API_KEY")
    app_api_key: str = Field(default="change-me", alias="APP_API_KEY")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
