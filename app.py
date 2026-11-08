# app.py
# -*- coding: utf-8 -*-
"""
Agris Zalo Relay Gateway — Tuân thủ chuẩn tài liệu chính thức: https://bot.zapps.me/docs/
Kiến trúc Cách B:
- Render KHÔNG chạy AI (không cần GEMINI_API_KEY trên Render).
- Render nhận tin từ Zalo (Webhook) -> Lưu vào hàng đợi.
- Bắn ngay trạng thái typing ("đang soạn tin nhắn...") về Zalo.
- Agris trên máy tính kéo tin về -> Bot Leader phân tích & điều phối -> Bắn lời giải về Zalo.
"""
import os
import time
import requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# BOT TOKEN chính thức từ Zalo Bot Platform (https://bot.zapps.me)
BOT_TOKEN = os.getenv("BOT_TOKEN") or os.getenv("ZALO_BOT_TOKEN") or ""

# Endpoint chuẩn theo tài liệu https://bot.zapps.me/docs/
ZALO_BOT_API_BASE = "https://bot-api.zapps.me"

# Hàng đợi tin nhắn chờ Bot Leader Agris xử lý
incoming_queue = []
MAX_QUEUE = 300

@app.route("/")
def home():
    token_status = "✅ Đã cấu hình BOT_TOKEN" if BOT_TOKEN else "⚠️ Chưa có BOT_TOKEN (Hãy thêm trên Render Environment)"
    return (
        "<div style='font-family: Arial, sans-serif; padding: 30px; line-height: 1.6;'>"
        "<h2>🚀 Agris Zalo Relay Gateway (Chuẩn bot.zapps.me - Cách B)</h2>"
        f"<p><b>Trạng thái:</b> Đang chạy online 24/7</p>"
        f"<p><b>Zalo Bot Token:</b> {token_status}</p>"
        f"<p><b>Tin nhắn chờ Bot Leader Agris xử lý:</b> {len(incoming_queue)}</p>"
        "<hr style='border: 0; border-top: 1px solid #ddd; margin: 20px 0;'>"
        "<p>👉 <b>Kích hoạt Webhook Zalo:</b> Truy cập <a href='/set_webhook'>/set_webhook</a></p>"
        "<p>👉 <b>Kiểm tra thông tin Bot Zalo:</b> Truy cập <a href='/get_me'>/get_me</a></p>"
        "</div>"
    )

@app.route("/get_me", methods=["GET"])
def get_me():
    """Kiểm tra thông tin Bot trực tiếp từ Zalo Server: https://bot-api.zapps.me/bot<TOKEN>/getMe"""
    if not BOT_TOKEN:
        return jsonify({"status": "error", "message": "Chưa cấu hình BOT_TOKEN trên Render Environment"}), 400
    try:
        url = f"{ZALO_BOT_API_BASE}/bot{BOT_TOKEN}/getMe"
        r = requests.get(url, timeout=10)
        return jsonify(r.json() if r.headers.get("content-type") == "application/json" else {"raw": r.text})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/set_webhook", methods=["GET"])
def setup_webhook():
    """Kích hoạt kết nối Webhook theo chuẩn bot.zapps.me: POST /bot<TOKEN>/setWebhook"""
    if not BOT_TOKEN:
        return jsonify({"status": "error", "message": "Chưa cấu hình BOT_TOKEN trên Render Environment!"}), 400
    
    render_url = os.environ.get("RENDER_EXTERNAL_URL", "https://bot-ai-zalo.onrender.com")
    webhook_url = f"{render_url}/webhook"
    zalo_url = f"{ZALO_BOT_API_BASE}/bot{BOT_TOKEN}/setWebhook"
    
    try:
        secret_token = request.args.get("secret_token") or "agris_zalo_secret_2026"
        payload = {
            "url": webhook_url,
            "secret_token": secret_token
        }
        r = requests.post(zalo_url, json=payload, timeout=15)
        res_data = r.json() if r.headers.get("content-type") == "application/json" else r.text
        return jsonify({
            "status": "ok",
            "message": "Đã thiết lập Webhook Zalo Bot thành công!",
            "webhook_url": webhook_url,
            "zalo_response": res_data
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/webhook", methods=["POST"])
def webhook():
    """Nhận Update từ Zalo theo chuẩn tài liệu https://bot.zapps.me/docs/"""
    data = request.get_json(force=True) or {}
    chat_id = None
    text = None
    sender_name = ""

    # Parse chuẩn Zalo Bot Update object
    if "message" in data:
        m = data["message"]
        text = m.get("text")
        chat = m.get("chat") or {}
        sender_from = m.get("from") or {}
        chat_id = chat.get("id") or sender_from.get("id")
        sender_name = sender_from.get("display_name") or sender_from.get("first_name") or sender_from.get("username") or ""

    if chat_id and text:
        # BẮN NGAY TRẠNG THÁI "ĐANG SOẠN TIN NHẮN..." (TYPING) VỀ ZALO
        if BOT_TOKEN:
            try:
                requests.post(f"{ZALO_BOT_API_BASE}/bot{BOT_TOKEN}/sendChatAction", json={"chat_id": chat_id, "action": "typing"}, timeout=4)
            except Exception:
                pass

        incoming_queue.append({
            "id": f"{chat_id}_{int(time.time()*1000)}",
            "chat_id": str(chat_id),
            "text": str(text).strip(),
            "sender_name": sender_name,
            "timestamp": time.time()
        })
        if len(incoming_queue) > MAX_QUEUE:
            incoming_queue.pop(0)

    return jsonify({"ok": True}), 200

@app.route("/api/get_incoming", methods=["GET"])
def get_incoming():
    """Phần mềm Agris trên máy tính định kỳ gọi API này để lấy tin nhắn về cho Bot Leader"""
    global incoming_queue
    msgs = list(incoming_queue)
    incoming_queue.clear()
    return jsonify({"status": "ok", "messages": msgs})

@app.route("/api/send_action", methods=["POST"])
def send_action():
    """Bot Leader Agris gửi trạng thái đang soạn tin (typing) về Zalo"""
    payload = request.get_json(force=True) or {}
    chat_id = payload.get("chat_id")
    action = payload.get("action", "typing")

    if not chat_id:
        return jsonify({"status": "error", "message": "Thiếu chat_id"}), 400

    if not BOT_TOKEN:
        return jsonify({"status": "error", "message": "Chưa có BOT_TOKEN"}), 500

    url = f"{ZALO_BOT_API_BASE}/bot{BOT_TOKEN}/sendChatAction"
    try:
        r = requests.post(url, json={"chat_id": chat_id, "action": action}, timeout=8)
        res_data = r.json() if r.headers.get("content-type") == "application/json" else r.text
        return jsonify({"status": "ok", "zalo_response": res_data})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/api/send_reply", methods=["POST"])
def send_reply():
    """Bot Leader Agris xử lý xong -> Gửi lên đây để chuyển cho Zalo qua /sendMessage"""
    payload = request.get_json(force=True) or {}
    chat_id = payload.get("chat_id")
    text = payload.get("text")

    if not chat_id or not text:
        return jsonify({"status": "error", "message": "Thiếu chat_id hoặc text"}), 400

    if not BOT_TOKEN:
        return jsonify({"status": "error", "message": "Chưa có BOT_TOKEN trên Render"}), 500

    # Gửi qua Zalo Bot API chuẩn bot-api.zapps.me
    url = f"{ZALO_BOT_API_BASE}/bot{BOT_TOKEN}/sendMessage"
    try:
        r = requests.post(url, json={"chat_id": chat_id, "text": text}, timeout=12)
        res_data = r.json() if r.headers.get("content-type") == "application/json" else r.text
        return jsonify({"status": "ok", "zalo_response": res_data})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
