# Implementation Plan: Email Filter

## 1. Overview
This document translates the functional specification for the **Email Filter** project into a technical execution roadmap. The project is a greenfield monorepo implementation focusing on a high-efficiency Gmail search and attachment discovery tool.

### Core Architectural Pillars
- **Query-First Search**: Maximize Gmail API efficiency by translating visual filters to native queries.
- **Asynchronous Job Execution**: All searches are treated as persistent jobs (PostgreSQL-based queue) to ensure stability, avoid timeouts, and provide a fluid UX.
- **Zero-Persistence Content Policy**: No permanent storage of email bodies or attachment binaries.
- **Secure Backend Proxy**: All Google API interactions and binary streams are handled exclusively by the backend. Tokens are encrypted at rest and never sent to the frontend.

---

## 2. Proposed Architecture

### System Diagram (Conceptual)
`Frontend (Next.js)` $\leftrightarrow$ `Backend API (FastAPI)` $\leftrightarrow$ `Database (Supabase/Postgres)`
`Backend API` $\leftrightarrow$ `Gmail API (Google OAuth 2.0)`

### Monorepo Structure
```text
Email-Filter/
├── apps/
│   ├── web/                # Next.js + TypeScript (Tailwind/ShadcnUI)
│   └── server/             # FastAPI + Python (Pydantic, SQLAlchemy/SQLModel)
├── packages/
│   └── shared/             # Shared types and constants (if applicable)
├── docs/
│   ├── EMAIL_FILTER_SPECIFICATION.md
│   └── IMPLEMENTATION_PLAN.md
├── .gitignore
└── README.md
```

### Tech Stack Detail
- **Frontend**: Next.js 14+ (App Router), TypeScript, Tailwind CSS, Lucide Icons.
- **Backend**: Python 3.11+, FastAPI, Uvicorn, Pydantic v2.
- **Database**: PostgreSQL (via Supabase), SQLAlchemy 2.0 for ORM.
- **Security**: Fernet (Symmetric encryption) for OAuth tokens, JWT for session management.
- **Infrastructure**: Docker, GitHub Actions, Vercel (FE), Railway/Render (BE).

---

## 3. RALPLAN-DR Summary

### Principles
1. **Least Privilege**: Only requested OAuth scopes; tokens encrypted at rest.
2. **Stateless Results**: Results are transient; only metadata and job state are persisted.
3. **Separation of Concerns**: Auth (Identity) is decoupled from Authorization (Gmail Access).
4. **User-Centric Performance**: Async jobs ensure the UI never hangs during large searches.

### Decision Drivers
- **API Quotas**: Gmail API limits are the primary bottleneck $\rightarrow$’Query-First’ is mandatory.
- **Privacy (LGPD)**: Minimal data retention $\rightarrow$ No local bodies/binaries.
- **Maintenance**: Managed PaaS to minimize DevOps overhead for a small team.

### Viable Options
- **Option A: Serverless Backend (AWS Lambda/Vercel Functions)**. Fast scaling, but difficult to maintain long-running async search jobs.
- **Option B: Containerized Backend (FastAPI on Railway/Render) [SELECTED]**. Supports persistent background workers (Celery/RQ or internal asyncio queues) and consistent connection pooling.
- **Option C: Full-stack Next.js (Server Actions)**. Simpler architecture, but Python's ecosystem (Google API libs, data processing) is superior for this use case.

### ADR: Core Execution Model
- **Decision**: Use a persistent FastAPI backend with an internal async job queue managed via PostgreSQL.
- **Drivers**: Need for long-running searches across multiple accounts without timing out HTTP requests.
- **Alternatives**: Simple request-response (rejected: timeouts); Serverless (rejected: execution limits); External Broker like RabbitMQ/Celery (deferred: avoided to minimize MVP complexity).
- **Consequences**: Requires a persistent process (Docker); adds complexity in job state tracking. The system will start with a PostgreSQL-based queue and migrate to a dedicated broker only if performance data justifies it.

---

## 4. Implementation Phases

### Phase 1: Foundation & Tooling
**Objective**: Establish the development environment and project structure.
**Order**: Prerequisite for all other work.
**Deliverables**: Monorepo skeleton, Docker config, CI pipeline.
- **T1.1**: Create monorepo structure (`apps/web`, `apps/server`). [Gemma]
- **T1.2**: Configure `docker-compose.yml` for local development (Python, Postgres). [Codex]
- **T1.3**: Setup GitHub Actions for linting and basic health checks. [Gemma]
- **T1.4**: Define global environment variable schema (pydantic-settings). [Codex]
- **T1.5**: Establish project-wide linting and formatting rules (ruff, prettier). [Gemma]
- **T1.6**: Configure basic TypeScript and Python type-checking pipelines. [Gemma]

### Phase 2: Data Layer & Identity Base
**Objective**: Implement the core user profile and secure data isolation.
**Order**: Must precede connectivity.
**Deliverables**: DB Schema, RLS policies, Internal Profile logic.
- **T2.1**: Create `User Profile` table and initial migrations. [Codex] (Implemented and validated in disposable staging.)
- **T2.2**: Implement Supabase Row Level Security (RLS) for profile isolation. [Codex] (Implemented and validated in disposable staging.)
- **T2.3**: Create internal API endpoints for profile management (CRUD). [Gemma]
- **T2.4**: Implement a basic "Health Check" endpoint for the backend. [Gemma]
- **T2.5**: Implement backend authorization middleware to verify User Profile ownership on every request. [Codex]

### Phase 3: Connectivity & OAuth
**Objective**: Enable secure linking of one or more Gmail accounts.
**Order**: Prerequisite for any search functionality.
**Deliverables**: OAuth flow, token encryption, account management.
- **T3.1a**: Define Google/Gmail OAuth configuration, scopes, redirect
  validation, state strategy, and typed backend contracts without Google calls
  or token persistence. [Codex] (Implemented.)
- **T3.1b**: Implement Google OAuth 2.0 authorization flow
  (Frontend $\rightarrow$ Backend), including durable `state` persistence and
  callback handling. [Codex]
- **T3.2**: Create `Gmail Connection` table and state machine (`connected`, `revoked`, etc). [Codex] (Schema, RLS, and runtime behavior validated in disposable staging.)
- **T3.3**: Implement symmetric encryption for `access_token` and `refresh_token`. [Codex]
- **T3.4**: Implement token refresh logic and automatic renewal. [Codex]
- **T3.5**: Create endpoint to link/unlink Gmail accounts. [Gemma]
- **T3.6**: Implement the "Max 5 accounts" technical limit check. [Gemma]
- **T3.7**: Implement explicit separation between App Auth and Gmail Authorization flows. [Codex]

### Phase 4: The Search Engine (Core)
**Objective**: Translate visual filters into efficient Gmail API calls.
**Order**: Core value proposition.
**Deliverables**: Query compiler, Gmail API client, base search logic.
- **T4.1**: Define the internal `SearchFilter` structured model (JSON schema). [Codex]
- **T4.2**: Implement the "Query Compiler" (Translate Filter $\rightarrow$ Gmail Search String). [Codex]
- **T4.3**: Build the Gmail API Client with support for multi-account pagination. [Codex]
- **T4.4**: Implement basic search (Server-side only) returning a list of message IDs. [MiniMax]

### Phase 5: Asynchronous Job System
**Objective**: Manage search lifecycle and prevent timeouts.
**Order**: Necessary for multi-account/large searches.
**Deliverables**: Job state machine, persistence, progress tracking.
- **T5.1**: Create `Search Job` table and state transition logic. [Codex]
- **T5.2**: Implement the job orchestrator (handles queueing and execution). [Codex]
- **T5.3**: Implement "Search Cancellation" mechanism (interrupting API loops). [Codex]
- **T5.4**: Create endpoint for polling job status and retrieving results. [Gemma]

### Phase 6: Attachment Processor & Refinement
**Objective**: Implement the hybrid refinement for attachment discovery.
**Order**: Extends the search engine.
**Deliverables**: MIME analyzer, binary proxy, metadata gallery.
- **T6.1**: Implement "Hybrid Refinement" (Fetch metadata for candidates $\rightarrow$ Filter locally). [Codex]
- **T6.2**: Build the attachment metadata extractor (name, size, extension, MIME). [Codex]
- **T6.3**: Implement a secure binary stream proxy for on-demand downloads. [Codex]
- **T6.4**: Implement filename sanitization for downloads. [Gemma]

### Phase 7: Results Interface (Frontend)
**Objective**: Provide the tabbed navigation and Master-Detail experience.
**Order**: Visualizes all previous phases.
**Deliverables**: Tabbed UI, Result lists, Detail panel.
- **T7.1**: Implement "Emails" tab with paginated result list. [Gemma]
- **T7.2**: Implement "Files" tab (The Attachment Gallery). [Gemma]
- **T7.3**: Create the Master-Detail panel for e-mail/attachment details. [Gemma]
- **T7.4**: Implement "Load Body" on-demand with HTML sanitization. [Codex]
- **T7.5**: Integrate "Open in Gmail" external links. [Gemma]

### Phase 8: Workspace & History
**Objective**: Persist productivity patterns (Saved Filters & History).
**Order**: Final polish for user retention.
**Deliverables**: Filter storage, History log, "Repeat Search" flow.
- **T8.1**: Implement "Save Filter" and "Favorite" logic. [Gemma]
- **T8.2**: Implement "Search History" log with summary statistics. [Gemma]
- **T8.3**: Create "Repeat Search" flow (Job $\rightarrow$ Result). [Gemma]
- **T8.4**: Implement CSV export of result metadata. [Gemma]

### Phase 9: Operational Hardening & Compliance
**Objective**: Secure the system and ensure LGPD compliance.
**Order**: Critical before production.
**Deliverables**: Audit logs, data deletion flow, monitoring.
- **T9.1**: Implement "Delete Profile" (Cascade deletion of tokens/filters/jobs). [Codex]
- **T9.2**: Implement structured logging and centralized error handling. [Codex]
- **T9.3**: Add health checks and basic monitoring metrics. [Gemma]
- **T9.4**: Final Security Review: Token leak check, RLS validation. [Codex]

### Phase 10: QA, Audit & Deploy
**Objective**: Validate MVP and move to production.
**Order**: Final gate.
**Deliverables**: Test suite, deployed app, final MVP report.
- **T10.1**: Write integration tests for the "Auth $\rightarrow$ Connect $\rightarrow$ Search" flow. [Codex]
- **T10.2**: Execute an "Ambiguity Audit" vs the original Specification. [MiniMax]
- **T10.3**: Configure CI/CD pipeline for automated deploy. [Gemma]
- **T10.4**: Deploy to production environment. [Gemma]

---

## 5. Dependency Map & Model Distribution

### Critical Path (Sequential)
`Foundation` $\rightarrow$ `Data/Auth` $\rightarrow$ `Connectivity` $\rightarrow$ `Search Engine` $\rightarrow$ `Jobs` $\rightarrow$ `Refinement` $\rightarrow$ `UI` $\rightarrow$ `Hardening`.

### Parallelizable Tasks
- Frontend UI shells (T7.1, T7.2) can be built in parallel with the Search Engine (Phase 4) using **contract-driven development** (e.g., OpenAPI specifications) and **local mocks/fixtures**. All UI components must be integrated and verified against the real backend API before being considered complete.
- Workspace features (Phase 8) can be developed in parallel with the Results Interface (Phase 7).
- Operational hardening (Phase 9) can start as soon as basic endpoints are stable.

### Model Allocation Summary
- **Gemma**: ( ~40% )- Tooling, simple CRUD, UI components, a la carte documentation.
- **MiniMax**: ( ~15% )- Broad mapping, complex result aggregation, final MVP audit.
- **Codex**: ( ~45% )- OAuth, Encryption, SQL Migrations, Async Job Logic, Gmail API Integration, Security.

---

## 6. Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Gmail API Quota Exhaustion | High | Strict Query-First approach; cache result IDs; implement a global rate-limiter. |
| Token Compromise | Critical | Tokens encrypted at rest (Symmetric); never sent to frontend; strict backend-only proxy. |
| Workspace Admin Blocks | Medium | Explicit `blocked_by_workspace_admin` state and user guidance. |
| Async Job Leak | Medium | TTL on `Search Job` results; periodic cleanup of expired jobs. |

## 7. Definition of Done (MVP)
The MVP is complete when:
1. A user can login via Google and link up to 5 Gmail accounts.
2. A visual filter can be created and executed as an asynchronous job.
3. The user can see a list of matching emails and a separate gallery of matching attachments.
4. An attachment can be downloaded securely via the backend.
5. A user can delete their entire profile and all associated data.
6. The app is deployed on a managed cloud platform.
