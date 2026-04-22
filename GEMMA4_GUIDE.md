# Hướng Dẫn Cài Đặt Gemma 4

Gemma 4 là dòng mô hình AI mã nguồn mở mới nhất của Google, hỗ trợ đa phương thức (text + hình ảnh) với kích thước từ 1B đến 27B tham số.

---

## Yêu Cầu Hệ Thống

| Mô hình       | RAM tối thiểu | GPU VRAM (khuyến nghị) |
|---------------|---------------|------------------------|
| gemma4:2b     | 4 GB          | 4 GB                   |
| gemma4:9b     | 16 GB         | 8 GB                   |
| gemma4:27b    | 32 GB         | 24 GB                  |

---

## Phương Pháp 1: Cài Qua Ollama (Đơn Giản Nhất)

### Bước 1 – Cài Ollama

```bash
# Linux / macOS
curl -fsSL https://ollama.com/install.sh | sh

# Windows: tải installer tại https://ollama.com/download
```

### Bước 2 – Tải và Chạy Gemma 4

```bash
# Phiên bản nhỏ (2B tham số) – chạy được trên máy thường
ollama run gemma4:2b

# Phiên bản trung bình (9B)
ollama run gemma4:9b

# Phiên bản lớn (27B) – cần GPU mạnh
ollama run gemma4:27b
```

### Bước 3 – Gọi API Cục Bộ

```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"gemma4:2b","prompt":"Xin chào!","stream":false}'
```

---

## Phương Pháp 2: Cài Qua Hugging Face + Transformers

### Bước 1 – Cài Thư Viện

```bash
pip install transformers accelerate torch huggingface_hub
```

### Bước 2 – Đăng Nhập Hugging Face

```bash
huggingface-cli login
```

> Cần chấp nhận điều khoản sử dụng tại: https://huggingface.co/google/gemma-4-2b-it

### Bước 3 – Tải và Chạy Mô Hình

```python
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

model_id = "google/gemma-4-2b-it"

tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto",
)

messages = [{"role": "user", "content": "Xin chào! Bạn là ai?"}]
inputs = tokenizer.apply_chat_template(
    messages,
    return_tensors="pt",
    return_dict=True,
).to(model.device)

outputs = model.generate(**inputs, max_new_tokens=256)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
```

---

## Phương Pháp 3: Cài Qua Google AI Studio / Vertex AI

### Dùng Google AI Python SDK

```bash
pip install google-generativeai
```

```python
import google.generativeai as genai

genai.configure(api_key="YOUR_API_KEY")
model = genai.GenerativeModel("gemma-4-9b-it")
response = model.generate_content("Xin chào!")
print(response.text)
```

> Lấy API key tại: https://aistudio.google.com/app/apikey

---

## Tích Hợp Vào Bot Zalo

### Cài Thư Viện

```bash
pip install zca-py requests
```

### Ví Dụ Kết Hợp Ollama + Zalo

```python
import requests
from zca import ZaloAPI

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma4:2b"

def ask_gemma(prompt: str) -> str:
    res = requests.post(OLLAMA_URL, json={
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
    })
    return res.json().get("response", "Lỗi kết nối mô hình.")

# Xử lý tin nhắn từ Zalo
def on_message(zalo: ZaloAPI, message):
    user_text = message.get("data", {}).get("content", "")
    reply = ask_gemma(user_text)
    zalo.send_message(message["data"]["idTo"], reply)
```

---

## Mẹo Tối Ưu

- **Quantization (4-bit):** Giảm VRAM cần dùng ~50%
  ```bash
  ollama run gemma4:9b-q4_0
  ```

- **GPU offload một phần:** Nếu VRAM không đủ, Ollama tự động offload sang RAM

- **Tắt streaming** khi dùng với bot để nhận kết quả trọn vẹn:
  ```json
  {"stream": false}
  ```

---

## Tài Nguyên

- Ollama: https://ollama.com/library/gemma4
- Hugging Face: https://huggingface.co/google/gemma-4-2b-it
- Google AI Studio: https://aistudio.google.com
