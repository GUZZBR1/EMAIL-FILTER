"""Canonical Gmail OAuth scopes for the MVP."""

GMAIL_OAUTH_SCOPES: tuple[str, ...] = (
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/gmail.readonly",
)

GMAIL_OAUTH_WRITE_SCOPE_MARKERS: tuple[str, ...] = (
    "gmail.compose",
    "gmail.insert",
    "gmail.labels",
    "gmail.modify",
    "gmail.send",
    "gmail.settings",
)
