import hashlib
import hmac
import secrets
import re
from database import get_connection

def hash_password(password):
    salt = secrets.token_bytes(16)
    password_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        200000
    )
    return salt.hex() + ":" + password_hash.hex()

def verify_password(password, stored_hash):
    try:
        salt_hex, hash_hex = stored_hash.split(":")
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(hash_hex)
        actual = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt,
            200000
        )
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False

def register_user(username, password):
    username = username.strip()

    if not re.fullmatch(r"[A-Za-z0-9_]{3,24}", username):
        return False, "Username must be 3-24 characters: letters, numbers or _"

    if len(password) < 10:
        return False, "Password must be at least 10 characters"

    password_hash = hash_password(password)

    try:
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO users (username, password_hash, display_name) VALUES (?, ?, ?)",
                (username, password_hash, username)
            )
        return True, "Account created"
    except Exception as error:
        if "UNIQUE constraint failed" in str(error):
            return False, "Username already exists"
        raise

def login_user(username, password):
    with get_connection() as conn:
        user = conn.execute(
            """
            SELECT id, username, display_name, phone,
                   phone_verified, bio, avatar, phone_visible,
                   password_hash
            FROM users
            WHERE username = ?
            """,
            (username.strip(),)
        ).fetchone()

    if user is None or not verify_password(password, user["password_hash"]):
        return None

    return {
        "id": user["id"],
        "username": user["username"],
        "display_name": user["display_name"],
        "phone": user["phone"],
        "phone_verified": bool(user["phone_verified"]),
        "bio": user["bio"],
        "avatar": user["avatar"],
        "phone_visible": bool(user["phone_visible"])
    }
