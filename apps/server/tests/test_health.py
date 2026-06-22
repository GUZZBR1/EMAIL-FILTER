import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings

client = TestClient(app)

def test_health_check():
    """
    Test that the health check endpoint returns 200 and the expected body.
    """
    response = client.get(f"/api/{settings.API_VERSION}/health")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "email-filter-api"
    }

def test_root_endpoint():
    """
    Test that the root endpoint is reachable.
    """
    response = client.get("/")
    assert response.status_code == 200
    assert "Welcome to" in response.json()["message"]

def test_404_not_found():
    """
    Test that a non-existent route returns 404.
    """
    response = client.get("/api/v1/non-existent")
    assert response.status_code == 404
