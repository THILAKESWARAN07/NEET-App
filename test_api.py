import json
import os
import httpx

BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")
TIMEOUT = 20.0


def print_section(title: str) -> None:
    print("=" * 60)
    print(title)
    print("=" * 60)


def safe_json(response: httpx.Response):
    try:
        return response.json()
    except ValueError:
        return {"raw": response.text}


token = None

with httpx.Client(timeout=TIMEOUT) as client:
    # Test 1: Register user
    print_section("TEST 1: USER REGISTRATION")
    resp = client.post(
        f"{BASE_URL}/api/auth/register",
        json={
            "email": "testuser@neet.com",
            "password": "Test123!@",
            "name": "Test User",
        },
    )
    print(f"Status: {resp.status_code}")
    print(f"Response: {json.dumps(safe_json(resp), indent=2)}")
    if resp.status_code not in (200, 400):
        raise SystemExit("Registration test failed unexpectedly")
    print()

    # Test 2: Login
    print_section("TEST 2: USER LOGIN")
    resp = client.post(
        f"{BASE_URL}/api/auth/login",
        json={"email": "testuser@neet.com", "password": "Test123!@"},
    )
    print(f"Status: {resp.status_code}")
    resp_json = safe_json(resp)
    print(f"Response: {json.dumps(resp_json, indent=2)}")
    if resp.status_code == 200:
        token = resp_json.get("access_token")
        print(f"Token: {token[:50]}..." if token else "No token")
    print()

    # Test 3: Get user profile (requires auth)
    if token:
        print_section("TEST 3: GET USER PROFILE (with auth)")
        resp = client.get(
            f"{BASE_URL}/api/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        print(f"Status: {resp.status_code}")
        print(f"Response: {json.dumps(safe_json(resp), indent=2)}")
        print()

        print_section("TEST 3B: COMPLETE PROFILE")
        resp = client.post(
            f"{BASE_URL}/api/auth/profile/complete",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "full_name": "Test User",
                "dob": "2007-01-01",
                "target_exam_year": 2027,
                "preferred_language": "English",
            },
        )
        print(f"Status: {resp.status_code}")
        print(f"Response: {json.dumps(safe_json(resp), indent=2)}")
        print()

    # Test 4: AI Status
    print_section("TEST 4: AI STATUS")
    resp = client.get(f"{BASE_URL}/api/ai/status")
    print(f"Status: {resp.status_code}")
    print(f"Response: {json.dumps(safe_json(resp), indent=2)}")
    print()

    # Test 5: List materials
    print_section("TEST 5: LIST STUDY MATERIALS")
    resp = client.get(f"{BASE_URL}/api/materials/")
    print(f"Status: {resp.status_code}")
    print(f"Response: {json.dumps(safe_json(resp), indent=2)}")
