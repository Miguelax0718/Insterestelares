from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_version: str = "0.1.0"
    port: int = 8000

    # Auth & Security
    app_api_keys: str = ""
    auth_disabled: bool = False
    allowed_origins: str = "*"
    rate_limit_per_min: int = Field(default=30, ge=0)

    # Provider selection
    llm_provider: str = "agentrouter"
    stt_provider: str = "faster-whisper"
    tts_provider: str = "piper"

    # AgentRouter (OpenAI-compatible)
    agentrouter_base_url: str = "https://agentrouter.org/v1"
    agentrouter_api_key: str = ""
    agentrouter_model: str = "gpt-4o-mini"
    llm_timeout_s: float = Field(default=30.0, gt=0)

    # STT (faster-whisper)
    whisper_model: str = "base"
    whisper_compute_type: str = "int8"
    whisper_device: str = "cpu"
    whisper_download_root: str | None = None

    # TTS (piper-tts)
    piper_voice: str = "es_MX-claude-high"
    piper_voices_dir: str = "/app/voices"

    def parsed_api_keys(self) -> list[str]:
        return [k.strip() for k in self.app_api_keys.split(",") if k.strip()]

    def parsed_allowed_origins(self) -> list[str]:
        raw = self.allowed_origins.strip()
        if not raw or raw == "*":
            return ["*"]
        return [origin.strip() for origin in raw.split(",") if origin.strip()]
