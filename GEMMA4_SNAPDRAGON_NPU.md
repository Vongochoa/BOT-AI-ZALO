# Gemma 4 E4B trên Surface Laptop 7 (Snapdragon X) — NPU + OpenClaw

## Tổng Quan

| Thành phần | Chi tiết |
|------------|----------|
| Máy | Microsoft Surface Laptop 7 |
| Chip | Snapdragon X Elite (X1E-80-100) / X Plus |
| NPU | Qualcomm Hexagon NPU — 45 TOPS (Elite) / 40 TOPS (Plus) |
| Mô hình | Gemma 4 E4B ("Effective 4 Billion" params, 9.6 GB) |
| LLM Runner | Ollama (Windows ARM64) |
| AI Agent | OpenClaw (kết nối với Ollama) |

> **"E4B" = Effective 4 Billion parameters** — dòng Gemma 4 thiết kế cho edge device,
> không phải quantization format. Dùng Ollama là `gemma4:e4b` (không có dấu cách).

---

## Phần 1 — Cài Ollama và Tải Gemma 4 E4B

### Bước 1: Cài Ollama cho Windows ARM64

Tải file `.exe` từ trang chính thức Ollama (chọn bản Windows).

```powershell
# Hoặc cài qua winget
winget install Ollama.Ollama

# Kiểm tra phiên bản
ollama --version
```

### Bước 2: Tải Gemma 4 E4B

```powershell
# Tên đúng — không có dấu cách, không có prefix "2b-instruct"
ollama pull gemma4:e4b
```

> Dung lượng ~9.6 GB. Nếu muốn nhỏ hơn, dùng `gemma4:e2b` (~7.2 GB).

### Bước 3: Chạy Thử

```powershell
ollama run gemma4:e4b
```

```
>>> Xin chào! Bạn là ai?
Tôi là Gemma, một mô hình AI được tạo bởi Google DeepMind...
```

---

## Phần 2 — Kết Nối OpenClaw Với Ollama

**OpenClaw** là AI agent framework mã nguồn mở, chạy cục bộ, kết nối với Ollama làm LLM backend. Hỗ trợ chat, coding agent, và tích hợp với Zalo/Discord/Telegram.

### Cài Nhanh (One Command)

```powershell
# Tự động cài OpenClaw + cấu hình dùng gemma4:e4b qua Ollama
ollama launch openclaw --model gemma4:e4b
```

### Cài Thủ Công

```powershell
# 1. Cài OpenClaw
openclaw onboard
# → Chọn "Ollama" từ danh sách provider
# → Nhập Ollama URL: http://127.0.0.1:11434

# 2. Set model — BẮT BUỘC có prefix "ollama/"
openclaw models set ollama/gemma4:e4b
```

> **Quan trọng:** Phải dùng prefix `ollama/gemma4:e4b`, không phải chỉ `gemma4:e4b`.
> Nếu thiếu prefix, OpenClaw sẽ gọi lên cloud thay vì chạy local.

### Kiểm Tra Đang Dùng Local

```powershell
openclaw config show
# Dòng "provider: ollama" và "model: ollama/gemma4:e4b" là đúng
```

---

## Phần 3 — Bật NPU (Hexagon) Qua ONNX Runtime

Ollama mặc định dùng CPU ARM (đã đạt ~85-95 tok/s). Để tận dụng thêm NPU Hexagon:

### Bước 1: Cài Thư Viện

```powershell
winget install Python.Python.3.11   # Chọn bản ARM64

pip install onnxruntime-qnn
pip install transformers optimum[onnxruntime]
```

### Bước 2: Export Model Sang ONNX INT4

```python
# export_gemma4_onnx.py
from optimum.exporters.onnx import main_export

main_export(
    model_name_or_path="google/gemma-4-pt",   # base model từ Hugging Face
    output="./gemma4_onnx",
    task="text-generation-with-past",
    weight_format="int4",
    int4_block_size=32,
)
```

```powershell
python export_gemma4_onnx.py
```

### Bước 3: Chạy Trên Hexagon NPU

```python
# run_npu.py
import onnxruntime as ort
from transformers import AutoTokenizer

providers = [
    ("QNNExecutionProvider", {
        "backend_path": "QnnHtp.dll",        # HTP = Hexagon Tensor Processor
        "htp_performance_mode": "burst",
        "htp_graph_finalization_optimization_level": "3",
    })
]

sess = ort.InferenceSession("./gemma4_onnx/model.onnx", providers=providers)
tokenizer = AutoTokenizer.from_pretrained("google/gemma-4-pt")

inputs = tokenizer("Xin chào!", return_tensors="np")
outputs = sess.run(None, dict(inputs))
print(tokenizer.decode(outputs[0][0], skip_special_tokens=True))
```

---

## Phần 4 — Dùng Microsoft AI Toolkit (NPU, Không Cần Code)

Cách đơn giản nhất để kích hoạt NPU mà không cần tự export ONNX:

```powershell
winget install Microsoft.VisualStudioCode
# Mở VS Code → Extensions → tìm "AI Toolkit for Visual Studio Code" → Install
```

1. Mở **AI Toolkit** trong VS Code
2. **Models → Browse Models → Gemma**
3. Chọn phiên bản **NPU optimized**
4. Click **Download** — tự động tối ưu cho Hexagon NPU

API tương thích OpenAI tại `http://localhost:5272`:
```python
import requests
r = requests.post("http://localhost:5272/v1/chat/completions", json={
    "model": "gemma4-e4b-npu",
    "messages": [{"role": "user", "content": "Xin chào!"}],
})
print(r.json()["choices"][0]["message"]["content"])
```

---

## So Sánh Hiệu Suất

| Chế độ | Tốc độ | Tiêu thụ pin |
|--------|--------|--------------|
| CPU ARM (Ollama mặc định) | ~85-95 tok/s | ~15W |
| **NPU Hexagon (AI Toolkit / QNN)** | **~120-150 tok/s** | **~8W** |
| GPU Adreno (DirectML) | ~70-80 tok/s | ~12W |

---

## Tóm Tắt Nhanh

```
Surface Laptop 7 (Snapdragon X)
│
├── Bước 1:  winget install Ollama.Ollama
│
├── Bước 2:  ollama pull gemma4:e4b
│
├── Bước 3 (OpenClaw):
│            ollama launch openclaw --model gemma4:e4b
│            # hoặc thủ công: openclaw models set ollama/gemma4:e4b
│
└── Bước 4 (NPU nhanh hơn, tùy chọn):
             VS Code AI Toolkit → tải Gemma 4 NPU optimized
```
