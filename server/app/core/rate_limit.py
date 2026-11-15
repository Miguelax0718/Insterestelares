import asyncio
import time
from collections import defaultdict, deque

from fastapi import Depends, Request

from app.core.auth import verify_api_key
from app.core.config import Settings
from app.core.errors import RateLimitedError


class InMemoryRateLimiter:
    def __init__(self, limit_per_min: int, window_s: float = 60.0) -> None:
        self._limit = limit_per_min
        self._window_s = window_s
        self._buckets: dict[str, deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def check(self, bucket_key: str) -> None:
        if self._limit <= 0:
            return
        now = time.monotonic()
        cutoff = now - self._window_s
        async with self._lock:
            bucket = self._buckets[bucket_key]
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()
            if len(bucket) >= self._limit:
                retry_after = max(1, int(self._window_s - (now - bucket[0])) + 1)
                raise RateLimitedError(
                    f"Rate limit of {self._limit} requests/minute exceeded.",
                    retry_after_s=retry_after,
                )
            bucket.append(now)

            if len(self._buckets) > 1024:
                stale = [k for k, q in self._buckets.items() if not q or q[-1] <= cutoff]
                for k in stale:
                    del self._buckets[k]


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


async def enforce_rate_limit(
    request: Request,
    principal: str = Depends(verify_api_key),
) -> None:
    settings: Settings = request.app.state.settings
    if settings.rate_limit_per_min <= 0:
        return
    limiter: InMemoryRateLimiter = request.app.state.rate_limiter
    bucket_key = f"ip:{_client_ip(request)}" if principal == "auth-disabled" else principal
    await limiter.check(bucket_key)
