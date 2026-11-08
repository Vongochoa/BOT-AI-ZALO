# app.py
import os
import requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# ENV vars (Cấu hình trên Render Dashboard)
ZALO_ACCESS_TOKEN = os.getenv("ZALO_ACCESS_TOKEN", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
VERIFY_TOKEN = os.getenv("VERIFY_TOKEN", "my_verify_token")

# Zalo API endpoint for sending customer service messages
ZALO_SEND_URL = "https://openapi.zalo.me/v3.0/oa/message/cs"

def generate_ai_response(user_text):
    """Tạo câu trả lời thông minh bằng Google Gemini (Miễn phí & Siêu nhanh) hoặc OpenAI."""
    system_prompt = (
        "Bạn là Trợ lý Tín dụng & Dịch vụ Khách hàng thông minh của Agribank. "
        "Hãy phản hồi ngắn gọn, thân thiện, lịch sự, xưng hô phù hợp và chuẩn mực nghiệp vụ ngân hàng bằng tiếng Việt."
    )
    
    # 1. Ưu tiên Google Gemini (Gemini 2.5 Flash / 1.5 Flash)
    if GEMINI_API_KEY:
        for model in ["gemini-2.5-flash", "gemini-1.5-flash"]:
            try:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEMINI_API_KEY}"
                payload = {
                    "contents": [{
                        "role": "user",
                        "parts": [{"text": f"{system_prompt}\n\nKhách hàng nhắn: {user_text}"}]
                    }]
                }
                res = requests.post(url, json=payload, timeout=12)
                if res.status_code == 200:
                    data = res.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        parts = candidates[0].get("content", {}).get("parts", [])
                        if parts:
                            return parts[0].get("text", "").strip()
            except Exception as ex:
                print(f"Lỗi gọi Gemini {model}:", ex)

    # 2. Fallback OpenAI nếu có cấu hình
    if OPENAI_API_KEY:
        try:
            import openai
            openai.api_key = OPENAI_API_KEY
            resp = openai.ChatCompletion.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"Khách hàng: {user_text}"}
                ],
                max_tokens=400,
                temperature=0.3,
            )
            return resp["choices"][0]["message"]["content"].strip()
        except Exception as ex:
            print("Lỗi gọi OpenAI:", ex)

    return "Dạ Agribank xin chào Quý khách! Hệ thống đã ghi nhận tin nhắn và cán bộ tín dụng phụ trách sẽ liên hệ lại với Quý khách ngay nhé ạ."

@app.route("/")
def index():
    return "Zalo-Agent is running with Google Gemini & Agribank Core!"

@app.route("/webhook", methods=["GET"])
def verify():
    token = request.args.get("hub.verify_token") or request.args.get("verify_token")
    challenge = request.args.get("hub.challenge") or request.args.get("challenge")
    if token and token == VERIFY_TOKEN:
        return challenge or "ok"
    return "invalid verify token", 403

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True)
    try:
        sender_id = None
        text = None

        if isinstance(data, dict):
            sender = data.get("sender") or {}
            msg = data.get("message") or {}
            sender_id = sender.get("id") or data.get("sender_id")
            text = msg.get("text") or data.get("message_text") or (data.get("message") and data["message"].get("text"))

        if not sender_id:
            try:
                sender_id = data["events"][0]["source"]["userId"]
                text = data["events"][0]["message"]["text"]
            except Exception:
                pass

        if not sender_id or not text:
            return jsonify({"ok": True})

        # Tạo phản hồi AI từ Google Gemini
        answer = generate_ai_response(text)

        # Gửi phản hồi lại qua Zalo OA
        headers = {"access_token": ZALO_ACCESS_TOKEN}
        payload = {
            "recipient": {"user_id": sender_id},
            "message": {"text": answer}
        }
        r = requests.post(ZALO_SEND_URL, headers=headers, json=payload, timeout=10)
        return jsonify({"ok": True, "answer": answer}), 200

    except Exception as e:
        print("Webhook handling error:", e)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
