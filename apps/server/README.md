# API Server
- **Objective**: Core business logic and API gateway.
- **Responsibility**: Profile management, OAuth orchestration, search job triggering, and secure attachment proxy.
- **Planned Tech**: FastAPI, Python, Pydantic.
- **Out of Scope**: Heavy data processing (delegated to Worker) or direct UI rendering.
- **Status**: Foundation initialized. Google/Gmail OAuth configuration and
  internal contracts are defined, but the real OAuth flow, Google API calls,
  token exchange, token encryption, and token persistence are not implemented
  yet.

## 🛠 Local Development

### Prerequisites
- Python 3.11+
- `pip` (Python package manager)

### Setup
1. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt # Or via pyproject.toml
   ```

### Execution
Run the server using uvicorn:
```bash
uvicorn app.main:app --reload
```
The API will be available at `http://localhost:8000` with documentation at `/docs`.

### Testing & Quality
- **Tests**: `pytest`
- **Linting**: `ruff check .`
- **Formatting**: `ruff format .`
- **Typing**: `mypy app`

## Google/Gmail OAuth configuration contracts

Email Filter login and Gmail authorization are separate flows. Supabase Auth
identifies the Email Filter user and resolves a `public.profiles` row. Google
OAuth for Gmail must be started only after that profile is authenticated; the
login Google account is not automatically inserted into
`public.gmail_connections`.

Required environment variables for future Gmail OAuth usage:

- `GOOGLE_OAUTH_ENABLED`: explicit feature flag. OAuth remains unavailable
  unless this is `True` and every required value below is configured.
- `GOOGLE_OAUTH_CLIENT_ID`: Google OAuth client ID placeholder or deployment
  secret value.
- `GOOGLE_OAUTH_CLIENT_SECRET`: Google OAuth client secret. It is typed as a
  secret and must not be logged or returned by APIs.
- `GOOGLE_OAUTH_REDIRECT_URI`: exact backend callback URI registered with
  Google. Future callback handling must require this configured URI and must
  not accept arbitrary client-supplied redirect URIs.
- `GOOGLE_OAUTH_SUCCESS_REDIRECT_URL`: configured frontend URL used after a
  successful Gmail connection.
- `GOOGLE_OAUTH_ERROR_REDIRECT_URL`: configured frontend URL used after a
  failed Gmail connection.
- `GOOGLE_OAUTH_FRONTEND_REDIRECT_ALLOWLIST`: optional exact-string allowlist
  for the success and error frontend URLs.

The canonical MVP scopes live in
`app.integrations.google.oauth_scopes.GMAIL_OAUTH_SCOPES`:

- `openid`
- `https://www.googleapis.com/auth/userinfo.email`
- `https://www.googleapis.com/auth/userinfo.profile`
- `https://www.googleapis.com/auth/gmail.readonly`

No Gmail write scopes are requested. This is enough to identify the connected
Google account, read the e-mail/profile information needed for display, search
messages, read required content, and fetch metadata or attachments on demand.

The OAuth `state` contract is server-side and future work must persist it in a
durable store that works across multiple backend instances. The state must be
high entropy, single-use, short-lived, bound to the authenticated profile,
bound to the configured return URL, and protected against replay. This stage
does not add a state table or an in-memory store.

This stage intentionally does not create OAuth endpoints, generate a real
authorization URL, exchange authorization codes, call Google APIs, write to
`gmail_connections`, or persist access/refresh tokens.
