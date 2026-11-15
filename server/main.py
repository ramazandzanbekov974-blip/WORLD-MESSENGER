from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import secrets
import re
from datetime import datetime, timezone
from urllib.parse import urlsplit

from auth import register_user, login_user
from messaging import create_chat, send_message, get_messages, get_chats
from database import get_connection

sessions = {}

class MessengerHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Connection", "close")
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        self.wfile.flush()

    def read_json(self):
        if not self.headers.get("Content-Type", "").startswith("application/json"):
            self.send_json({"error": "Content-Type must be application/json"}, 415)
            return None

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 8192:
                self.send_json({"error": "Invalid request size"}, 400)
                return None

            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                self.send_json({"error": "JSON object required"}, 400)
                return None

            return data
        except (ValueError, json.JSONDecodeError):
            self.send_json({"error": "Invalid JSON"}, 400)
            return None

    def current_user(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return None

        token = header[7:].strip()
        return sessions.get(token)

    def do_GET(self):
        path = urlsplit(self.path).path

        if path == "/":
            self.send_json({
                "app": "WORLD MESSENGER",
                "status": "online",
                "version": "0.3"
            })

        elif path == "/health":
            self.send_json({
                "status": "healthy",
                "server_time": datetime.now(timezone.utc).isoformat()
            })

        elif path == "/me":
            user = self.current_user()
            if not user:
                self.send_json({"error": "Unauthorized"}, 401)
                return

            with get_connection() as conn:
                row = conn.execute(
                    """
                    SELECT id, username, display_name, phone,
                           phone_verified, bio, avatar, phone_visible
                    FROM users WHERE id = ?
                    """,
                    (user["id"],)
                ).fetchone()

            if row is None:
                self.send_json({"error": "User not found"}, 404)
                return

            profile = dict(row)
            profile["phone_verified"] = bool(profile["phone_verified"])
            profile["phone_visible"] = bool(profile["phone_visible"])
            self.send_json({"user": profile})

        elif path == "/chats":
            user = self.current_user()
            if not user:
                self.send_json({"error": "Unauthorized"}, 401)
                return

            self.send_json({"chats": get_chats(user["id"])})

        else:
            match = re.fullmatch(r"/chats/(\d+)/messages", path)

            if match:
                user = self.current_user()
                if not user:
                    self.send_json({"error": "Unauthorized"}, 401)
                    return

                chat_id = int(match.group(1))
                history = get_messages(chat_id, user["id"])

                if history is None:
                    self.send_json({"error": "Chat not found or access denied"}, 403)
                    return

                self.send_json({"messages": history})
            else:
                self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        path = urlsplit(self.path).path

        if path in ("/register", "/login"):
            data = self.read_json()
            if data is None:
                return

            username = data.get("username")
            password = data.get("password")

            if not isinstance(username, str) or not isinstance(password, str):
                self.send_json({"error": "Username and password are required"}, 400)
                return

            if path == "/register":
                try:
                    ok, message = register_user(username, password)
                    self.send_json(
                        {"success": ok, "message": message},
                        201 if ok else 400
                    )
                except Exception as error:
                    print("REGISTRATION ERROR:", repr(error), flush=True)
                    try:
                        self.send_json({"error": "Registration failed"}, 500)
                    except BrokenPipeError:
                        pass

            else:
                try:
                    user = login_user(username, password)
                    if user is None:
                        self.send_json({"error": "Invalid username or password"}, 401)
                        return

                    token = secrets.token_urlsafe(32)
                    sessions[token] = user

                    self.send_json({
                        "success": True,
                        "token": token,
                        "user": user
                    })
                except Exception as error:
                    print("LOGIN ERROR:", repr(error), flush=True)
                    try:
                        self.send_json({"error": "Login failed"}, 500)
                    except BrokenPipeError:
                        pass

            return

        user = self.current_user()
        if not user:
            self.send_json({"error": "Unauthorized"}, 401)
            return

        data = self.read_json()
        if data is None:
            return

        if path == "/profile":
            username = data.get("username")
            display_name = data.get("display_name")
            phone = data.get("phone")
            bio = data.get("bio")

            if not all(isinstance(v, str) for v in
                       (username, display_name, phone, bio)):
                self.send_json({"error": "Все поля профиля должны быть текстом"}, 400)
                return

            username = username.strip()
            display_name = display_name.strip()
            phone = phone.strip()
            bio = bio.strip()

            if not re.fullmatch(r"[A-Za-z0-9_]{3,24}", username):
                self.send_json({"error": "Username: 3-24 символа, только латиница, цифры и _"}, 400)
                return

            if not display_name or len(display_name) > 40:
                self.send_json({"error": "Имя должно содержать от 1 до 40 символов"}, 400)
                return

            if len(phone) > 25 or (phone and not re.fullmatch(r"[+0-9 ()-]{5,25}", phone)):
                self.send_json({"error": "Проверь формат номера телефона"}, 400)
                return

            if len(bio) > 160:
                self.send_json({"error": "Описание не должно превышать 160 символов"}, 400)
                return

            try:
                with get_connection() as conn:
                    duplicate_username = conn.execute(
                        "SELECT id FROM users WHERE username = ? COLLATE NOCASE AND id != ?",
                        (username, user["id"])
                    ).fetchone()

                    if duplicate_username:
                        self.send_json({"error": "Этот username уже занят"}, 409)
                        return

                    if phone:
                        duplicate_phone = conn.execute(
                            "SELECT id FROM users WHERE phone = ? AND id != ?",
                            (phone, user["id"])
                        ).fetchone()
                        if duplicate_phone:
                            self.send_json({"error": "Этот номер уже добавлен в другой профиль"}, 409)
                            return

                    conn.execute(
                        """
                        UPDATE users
                        SET username = ?, display_name = ?, phone = ?, bio = ?
                        WHERE id = ?
                        """,
                        (username, display_name, phone or None, bio, user["id"])
                    )

                    row = conn.execute(
                        """
                        SELECT id, username, display_name, phone,
                               phone_verified, bio, avatar, phone_visible
                        FROM users WHERE id = ?
                        """,
                        (user["id"],)
                    ).fetchone()

                profile = dict(row)
                profile["phone_verified"] = bool(profile["phone_verified"])
                profile["phone_visible"] = bool(profile["phone_visible"])

                token = self.headers.get("Authorization", "")[7:].strip()
                sessions[token] = {
                    key: profile[key]
                    for key in ("id", "username", "display_name", "phone",
                                "phone_verified", "bio", "avatar", "phone_visible")
                }

                self.send_json({"success": True, "user": profile})
            except Exception as error:
                print("PROFILE UPDATE ERROR:", repr(error), flush=True)
                self.send_json({"error": "Не удалось обновить профиль"}, 500)
            return

        if path == "/chats":
            recipient_id = data.get("recipient_id")

            if not isinstance(recipient_id, int) or isinstance(recipient_id, bool):
                self.send_json({"error": "recipient_id must be an integer"}, 400)
                return

            chat_id, message = create_chat(user["id"], recipient_id)

            if chat_id is None:
                self.send_json({"error": message}, 400)
                return

            self.send_json({
                "success": True,
                "chat_id": chat_id,
                "message": message
            }, 201)

            return

        match = re.fullmatch(r"/chats/(\d+)/messages", path)

        if match:
            chat_id = int(match.group(1))
            body = data.get("body")

            if not isinstance(body, str):
                self.send_json({"error": "body must be text"}, 400)
                return

            ok, message = send_message(chat_id, user["id"], body)

            if not ok:
                self.send_json({"error": message}, 400)
                return

            self.send_json({
                "success": True,
                "message": message
            }, 201)

            return

        self.send_json({"error": "Not found"}, 404)


server = ThreadingHTTPServer(("0.0.0.0", 8000), MessengerHandler)
print("WORLD MESSENGER SERVER STARTED")
server.serve_forever()
