# app.py
import os
import requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import openai

load_dotenv()  # load .env locally (Railway sẽ set env vars riêng)
app = Flask(__name__)

# ENV vars (set trên Railway dashboard)
ZALO_ACCESS_TOKEN = os.getenv("ZALO_ACCESS_TOKEN", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
VERIFY_TOKEN = os.getenv("VERIFY_TOKEN", "my_verify_token")  # optional verify token

openai.api_key = OPENAI_API_KEY

# Zalo API endpoint for sending customer service messages
ZALO_SEND_URL = "https://openapi.zalo.me/v3.0/oa/message/cs"

@app.route("/")
def index():
    return "Zalo-Agent is running"

# Zalo webhook verification (if Zalo requests GET for verification)
@app.route("/webhook", methods=["GET"])
def verify():
    # Zalo may send verification params (example): hub.verify_token, hub.challenge
    # If Zalo uses different scheme, adapt accordingly.
    token = request.args.get("hub.verify_token") or request.args.get("verify_token")
    challenge = request.args.get("hub.challenge") or request.args.get("challenge")
    if token and token == VERIFY_TOKEN:
        return challenge or "ok"
    return "invalid verify token", 403

# Main webhook to receive messages from Zalo (POST)
@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True)
    # Basic safety: ensure structure
    try:
        # Zalo webhook payload structure may vary; adapt as needed
        # Try common shapes: message event under 'events' or 'message'
        # Here we try to handle common OA payloads
        event = data.get("event") or data  # adjust as Zalo sends
        # Attempt to extract sender id and text
        sender_id = None
        text = None

        # Common pattern: data["message"]["text"], data["sender"]["id"]
        if isinstance(data, dict):
            # many OA payloads contain "sender": {"id": ...} and "message": {"text": ...}
            sender = data.get("sender") or {}
            msg = data.get("message") or {}
            sender_id = sender.get("id") or data.get("sender_id")
            text = msg.get("text") or data.get("message_text") or (data.get("message") and data["message"].get("text"))
        # fallback
        if not sender_id:
            # try deeper
            try:
                sender_id = data["events"][0]["source"]["userId"]
                text = data["events"][0]["message"]["text"]
            except Exception:
                pass

        if not sender_id or not text:
            # we can't process
            return jsonify({"ok": True})

        # 1) Build a prompt or use RAG / context here
        system_prompt = (
            "Bạn là trợ lý nội bộ. Trả lời ngắn gọn, dễ hiểu, bằng tiếng Việt. "
            "Nếu yêu cầu truy xuất dữ liệu đặc thù, trả lời rằng sẽ kiểm tra (placeholder)."
        )
        user_message = f"Người dùng: {text}"

        # 2) Call OpenAI Chat API (GPT)
        resp = openai.ChatCompletion.create(
            model="gpt-4o-mini",  # hoặc model bạn được phép dùng; nếu không có, dùng "gpt-4o" hoặc "gpt-4o-mini"
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            max_tokens=500,
            temperature=0.2,
        )
        answer = resp["choices"][0]["message"]["content"].strip()

        # 3) Send message back to Zalo OA (customer service API)
        headers = {"access_token": ZALO_ACCESS_TOKEN}
        payload = {
            "recipient": {"user_id": sender_id},
            "message": {"text": answer}
        }
        r = requests.post(ZALO_SEND_URL, headers=headers, json=payload, timeout=10)
        # optional: log r.status_code, r.text
        return jsonify({"ok": True}), 200

    except Exception as e:
        # log error
        print("Webhook handling error:", e)
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    # Railway expects app to listen on PORT env var
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
