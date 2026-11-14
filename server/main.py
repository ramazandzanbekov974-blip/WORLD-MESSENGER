from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import secrets
import re
from datetime import datetime, timezone
from urllib.parse import urlsplit

from auth import register_user, login_user
from messaging import create_chat, send_message, get_messages

sessions = {}

class MessengerHandler(BaseHTTPRequestHandler):

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

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
            self.send_json({"user": user})

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
                except Exception:
                    self.send_json({"error": "Registration failed"}, 500)

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
                except Exception:
                    self.send_json({"error": "Login failed"}, 500)

            return

        user = self.current_user()
        if not user:
            self.send_json({"error": "Unauthorized"}, 401)
            return

        data = self.read_json()
        if data is None:
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


server = HTTPServer(("127.0.0.1", 8000), MessengerHandler)
print("WORLD MESSENGER SERVER STARTED")
server.serve_forever()
