# API Server
- **Objective**: Core business logic and API gateway.
- **Responsibility**: Profile management, OAuth orchestration, search job triggering, and secure attachment proxy.
- **Planned Tech**: FastAPI, Python, Pydantic.
- **Out of Scope**: Heavy data processing (delegated to Worker) or direct UI rendering.
- **Status**: Foundation initialized. Implementation in subsequent tasks.

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
