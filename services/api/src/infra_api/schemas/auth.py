from pydantic import BaseModel


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 900


class UserResponse(BaseModel):
    id: int
    github_id: int
    github_login: str
    name: str | None = None
    email: str
    avatar_url: str | None = None
    role: str
    plan_name: str | None = None
