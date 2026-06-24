"""URL validation helpers for Google OAuth contracts."""

from urllib.parse import urlsplit


def validate_http_url(value: str, field_name: str) -> str:
    """Validate a URL without normalizing or rewriting the configured value."""

    if value != value.strip():
        raise ValueError(f"{field_name} must not contain leading or trailing space")

    parsed = urlsplit(value)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError(f"{field_name} must use http or https")
    if not parsed.netloc or parsed.hostname is None:
        raise ValueError(f"{field_name} must include a host")
    if parsed.username or parsed.password:
        raise ValueError(f"{field_name} must not contain credentials")
    if parsed.fragment:
        raise ValueError(f"{field_name} must not contain a fragment")
    return value
