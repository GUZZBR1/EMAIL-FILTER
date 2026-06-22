from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
async def get_health():
    """
    Health check endpoint to verify the service is running.
    """
    return {
        "status": "ok",
        "service": "email-filter-api"
    }
