import hashlib
import hmac

from fastapi import Request

from app.core.config import Settings
from app.core.errors import UnauthorizedError


def _constant_time_match(candidate: str, valid_keys: list[str]) -> bool:
    if not candidate or not valid_keys:
        return False
    candidate_bytes = candidate.encode("utf-8")
    matched = False
    for expected in valid_keys:
        if hmac.compare_digest(candidate_bytes, expected.encode("utf-8")):
            matched = True
    return matched


async def verify_api_key(request: Request) -> str:
    settings: Settings = request.app.state.settings
    if settings.auth_disabled:
        return "auth-disabled"

    provided = request.headers.get("x-astramed-key", "").strip()
    valid_keys = settings.parsed_api_keys()
    if not _constant_time_match(provided, valid_keys):
        raise UnauthorizedError("Missing or invalid X-AstraMed-Key header.")

    digest = hashlib.sha256(provided.encode("utf-8")).hexdigest()[:16]
    return f"key:{digest}"
