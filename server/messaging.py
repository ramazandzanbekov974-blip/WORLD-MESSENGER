from database import get_connection

def create_chat(user1_id, user2_id):
    if user1_id == user2_id:
        return None, "Cannot create a chat with yourself"

    with get_connection() as conn:
        users = conn.execute(
            "SELECT id FROM users WHERE id IN (?, ?)",
            (user1_id, user2_id)
        ).fetchall()

        if len(users) != 2:
            return None, "User not found"

        existing = conn.execute("""
            SELECT c.id
            FROM chats c
            JOIN chat_members a ON a.chat_id = c.id
            JOIN chat_members b ON b.chat_id = c.id
            WHERE a.user_id = ? AND b.user_id = ?
              AND (
                SELECT COUNT(*) FROM chat_members
                WHERE chat_id = c.id
              ) = 2
            LIMIT 1
        """, (user1_id, user2_id)).fetchone()

        if existing:
            return existing["id"], "Chat already exists"

        cursor = conn.execute("INSERT INTO chats DEFAULT VALUES")
        chat_id = cursor.lastrowid

        conn.executemany(
            "INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)",
            [(chat_id, user1_id), (chat_id, user2_id)]
        )

        return chat_id, "Chat created"


def send_message(chat_id, sender_id, body):
    body = body.strip()

    if not body:
        return False, "Message cannot be empty"

    if len(body) > 4000:
        return False, "Message is too long"

    with get_connection() as conn:
        member = conn.execute(
            "SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?",
            (chat_id, sender_id)
        ).fetchone()

        if not member:
            return False, "You are not a member of this chat"

        conn.execute(
            "INSERT INTO messages (chat_id, sender_id, body) VALUES (?, ?, ?)",
            (chat_id, sender_id, body)
        )

    return True, "Message sent"


def get_messages(chat_id, user_id, limit=50):
    limit = max(1, min(int(limit), 100))

    with get_connection() as conn:
        member = conn.execute(
            "SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?",
            (chat_id, user_id)
        ).fetchone()

        if not member:
            return None

        rows = conn.execute("""
            SELECT id, sender_id, body, created_at
            FROM messages
            WHERE chat_id = ?
            ORDER BY id DESC
            LIMIT ?
        """, (chat_id, limit)).fetchall()

        return [dict(row) for row in reversed(rows)]
