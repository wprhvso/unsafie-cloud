from fastapi import APIRouter, Header, HTTPException

router = APIRouter(tags=["gateway"])


@router.post("/v1/chat/completions")
async def chat_completions(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401, detail="Valid API key required in Authorization header"
        )

    return {
        "id": "chatcmpl-mock",
        "object": "chat.completion",
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "API Gateway response routed to LLM provider successfully.",
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 12, "completion_tokens": 10, "total_tokens": 22},
    }


@router.post("/browser/v1/sessions")
async def lease_browser_session(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401, detail="Valid API key required in Authorization header"
        )

    return {
        "session_id": "sess_mock_12345",
        "ws_endpoint": "wss://kameleo.example.com/cdp/sess_mock_12345",
        "status": "ready",
        "node": "node1-aeza",
        "expires_in_seconds": 900,
    }
