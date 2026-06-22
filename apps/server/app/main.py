from fastapi import FastAPI
from app.api.routes import health
from app.core.config import settings

app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
)

# Routes
app.include_router(
    health.router,
    prefix=f"/api/{settings.API_VERSION}",
    tags=["System"]
)

@app.get("/")
async def root():
    return {"message": f"Welcome to {settings.APP_NAME}"}
