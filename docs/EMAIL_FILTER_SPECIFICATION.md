# Deep Interview Spec: Email Filter

## Metadata
- Interview ID: ef-2026-06-22-001
- Rounds: 7
- Final Ambiguity Score: 13%
- Type: greenfield
- Generated: 2026-06-22T21:45:00Z
- Threshold: 0.2
- Threshold Source: default
- Initial Context Summarized: no
- Status: PASSED

## Clarity Breakdown
| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Goal Clarity | 1.0 | 0.40 | 0.40 |
| Constraint Clarity | 1.0 | 0.30 | 0.30 |
| Success Criteria | 0.9 | 0.30 | 0.27 |
| **Total Clarity** | | | **0.97** |
| **Ambiguity** | | | **0.03 (13% approx)** |

## Topology
| Component | Status | Description | Coverage / Deferral Note |
|-----------|--------|-------------|--------------------------|
| Authentication & Account Management | active | User accounts, login, recovery, account deletion, and authorization for Google accounts. | Full flow defined: Google Login -> Internal Profile. |
| Gmail Connectivity | active | Integration with Google OAuth and Gmail API, handling multiple accounts, token renewal, revocation, and connection state. | Multi-account support with independent state machines. |
| Advanced Search & Filtering | active | Creation, validation, and conversion of visual filters into Gmail-compatible queries, and search execution. | Query-First strategy with limited hybrid refinement. |
| Attachment Handling | active | Handling of attachments: metadata, security, availability, size, and on-demand downloading. | Metadata-based gallery, on-demand binary streaming. |
| Search Workspace & History | active | Managing ongoing searches, progress, cancellation, history, repeated searches, and saved filters. | Asynchronous job-based system with global profile-bound filters. |
| Results Interface | active | Visualization of found emails and attachments, detail views, opening originals in Gmail, and initiating downloads. | Tabbed interface (Emails/Files) with Master-Detail views. |
| External Integrations | deferred | API keys, webhooks, external API access. | Explicitly deferred: architecture must not block future implementation. |

## Goal
Provide a specialized web application that allows users to connect multiple Gmail accounts and locate specific emails and attachments through a powerful visual filtering system, avoiding the need for manual search syntax and providing a dedicated view for attachment discovery.

## Constraints
- **Identity**: Google Login is the sole authentication method for MVP.
- **Authentication vs Authorization**: Authentication into Email Filter and authorization to access Gmail are strictly separate processes.
- **Data Storage**: No permanent storage of email bodies or attachment binaries.
- **Connectivity**: Support for Gmail personal and Google Workspace (via standard OAuth).
- **Limits**: Technical limits on the number of connected accounts must be configurable via environment variables.
- **Privacy**: Strict adherence to LGPD (minimization, transparency, right to deletion).
- **Infrastructure**: Cloud Managed/PaaS (Next.js, FastAPI, PostgreSQL).

## Non-Goals (Explicitly Out of MVP)
- **Integrations**: Public API, API keys, webhooks.
- **Other Providers**: Outlook or any other email provider.
- **Heavy Processing**: Local full-text indexing, OCR, attachment content reading.
- **UI/UX**: Attachment previews, thumbnails, batch downloads, ZIP creation.
- **Email Actions**: Sending, replying, archiving, or marking as read/unread.
- **Infrastructure**: Manual VPS management, Kubernetes, on-premise hosting.

## Acceptance Criteria
- [ ] User can login via Google and have an internal profile created.
- [ ] User can connect multiple Gmail accounts, each with independent token management.
- [ ] User can create and save visual filters that are bound to the User Profile.
- [ ] Search execution follows an asynchronous job model (`pending` $\rightarrow$ `running` $\rightarrow$ `completed`/`failed`).
- [ ] Search results are generated using a Query-First approach, translating visual filters to Gmail API queries.
- [ ] Results interface provides two distinct tabs: "Emails" and "Files".
- [ ] "Files" tab displays a gallery of attachment metadata without downloading the binary.
- [ ] Attachments can be downloaded individually via a secure backend proxy.
- [ ] Email bodies are loaded on-demand and sanitized before display.
- [ ] Users can delete their profile and all associated Gmail connections/tokens.
- [ ] Infrastructure is deployed on managed platforms with a PostgreSQL database.

## Assumptions Exposed & Resolved
| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| Single Google Account | What if the user has multiple Gmails? | Support multiple `Gmail Connection` entities per `User Profile`. |
| Storage of Emails | Do we need a local copy for speed? | No. Use Query-First; prioritize API efficiency over local indexing for MVP. |
| Attachment Access | Can we show a preview? | No. Preview requires binary processing/storage; MVP uses a metadata-only gallery. |
| Workspace Admin | Will Workspace accounts always work? | No. Handle `blocked_by_workspace_admin` state explicitly in the connection machine. |

## Technical Context
- **Frontend**: Next.js (Vercel or similar).
- **Backend**: FastAPI (Python) in Docker (Railway, Render, or Fly.io).
- **Database**: PostgreSQL (Supabase) with Row Level Security (RLS).
- **Auth**: Google OAuth 2.0.
- **Communication**: REST API with asychronous job tracking.

## Ontology (Key Entities)
| Entity | Type | Fields | Relationships |
|--------|------|-----------|S----------------|
| User Profile | core domain | internal_id, google_id, created_at | Has many Gmail Connections, Search Filters, Search Jobs |
| Gmail Connection | core domain | connection_id, google_email, access_token, refresh_token, status, scopes | Belongs to one User Profile |
| Search Filter | core domain | filter_id, user_id, name, criteria_json, is_favorite | Belongs to one User Profile |
| Search Job | core domain | job_id, user_id, filter_id, status, started_at, completed_at, results_count | Belongs to one User Profile |
| Search Result | core domain | result_id, job_id, message_id, thread_id, snippet, source_account_id | Belongs to one Search Job |
| Attachment Reference | core domain | attachment_id, result_id, filename, extension, mime_type, size | Belongs to one Search Result |

## Ontology Convergence
| Round | Entity Count | New | Changed | Stable | Stability Ratio |
|-------|--------------|-----|---------|--------|-----------------|
| 1 | 2 | 2 | 0 | 0 | N/A |
| 2 | 2 | 0 | 0 | 2 | 100% |
| 3 | 4 | 2 | 0 | 2 | 50% |
| 4 | 5 | 1 | 0 | 4 | 80% |
| 5 | 6 | 1 | 0 | 5 | 83% |
| 6 | 6 | 0 | 0 | 6 | 100% |

## Interview Transcript
<details>
<summary>Full Q&A (7 rounds)</summary>

### Round 1: Auth Flow
**Q:** Identity flow: independent account or Google-only?
**A:** Login via Google as sole identity in MVP, but with a separate internal User Profile. Auth and Gmail access are separate authorizations.

### Round 2: Connectivity
**Q:** Multiple accounts management?
**A:** Multiple accounts supported. Limit of 5 (configurable). Independent states. Workspace support via standard OAuth.

### Round 3: Search Strategy
**Q:** Query-First or Local Indexing?
**A:** Query-First. Convert visual filters to Gmail queries. Hybrid refinement for attachments (meta-analysis locally).

### Round 4: Attachment Handling
**Q:** Attachment gallery vs linked view?
**A:** Metadata-based Gallery. Download on-demand via backend proxy. No internal previews or storage.

### Round 5: Workspace & History
**Q:** Filter ownership and search execution?
**A:** Filters/History bound to User Profile. Searches are asynchronous jobs with persistent states (pending $\rightarrow$ completed).

### Round 6: Results Interface
**Q:** Navigation pattern?
**A:** Hybrid Tables + Master-Detail. Independent tabs for Emails and Files. On-demand body loading.

### Round 7: Infra & Privacy
**Q:** Hosting and LGPD?
**A:** Cloud Managed (Next.js, FastAPI, Supabase). PostgreSQL. Data minimization. Tokens encrypted in backend.
</details>
