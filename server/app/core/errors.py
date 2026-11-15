from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppError(Exception):
    def __init__(self, *, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message

    def to_payload(self) -> dict[str, Any]:
        return {"error": {"code": self.code, "message": self.message}}


class UnauthorizedError(AppError):
    def __init__(self, message: str = "Missing or invalid API key.") -> None:
        super().__init__(status_code=401, code="unauthorized", message=message)


class RateLimitedError(AppError):
    def __init__(
        self,
        message: str = "Rate limit exceeded. Try again shortly.",
        retry_after_s: int = 60,
    ) -> None:
        super().__init__(status_code=429, code="rate_limited", message=message)
        self.retry_after_s = retry_after_s


class InvalidRequestError(AppError):
    def __init__(self, message: str = "Invalid request.", status_code: int = 422) -> None:
        super().__init__(status_code=status_code, code="invalid_request", message=message)


class PayloadTooLargeError(AppError):
    def __init__(self, message: str = "Payload exceeds allowed size limit.") -> None:
        super().__init__(status_code=413, code="payload_too_large", message=message)


class UpstreamUnavailableError(AppError):
    def __init__(
        self,
        message: str = "Upstream provider is unavailable.",
        status_code: int = 502,
    ) -> None:
        super().__init__(status_code=status_code, code="upstream_unavailable", message=message)


def error_payload(code: str, message: str) -> dict[str, Any]:
    return {"error": {"code": code, "message": message}}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(_request: Request, exc: AppError) -> JSONResponse:
        headers: dict[str, str] = {}
        if isinstance(exc, RateLimitedError):
            headers["Retry-After"] = str(exc.retry_after_s)
        return JSONResponse(
            status_code=exc.status_code,
            content=exc.to_payload(),
            headers=headers,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        _request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        first = exc.errors()[0] if exc.errors() else {}
        loc = ".".join(str(part) for part in first.get("loc", ()) if part != "body")
        msg = str(first.get("msg", "Invalid request payload."))
        detail = f"{loc}: {msg}" if loc else msg
        return JSONResponse(
            status_code=422,
            content=error_payload("invalid_request", detail),
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(
        _request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        code_map = {
            400: "invalid_request",
            401: "unauthorized",
            413: "payload_too_large",
            422: "invalid_request",
            429: "rate_limited",
            502: "upstream_unavailable",
            503: "upstream_unavailable",
        }
        default_code = "invalid_request" if exc.status_code < 500 else "internal"
        code = code_map.get(exc.status_code, default_code)
        message = str(exc.detail) if exc.detail else "Request failed."
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload(code, message),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(_request: Request, _exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content=error_payload("internal", "Internal server error."),
        )
