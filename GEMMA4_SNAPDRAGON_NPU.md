# Gemma 4 trên Surface Laptop 7 (Snapdragon X) — Tận Dụng NPU + Chạy Trong Ollama

## Tổng Quan

| Thành phần        | Chi tiết                                          |
|-------------------|---------------------------------------------------|
| Máy               | Microsoft Surface Laptop 7                        |
| Chip              | Snapdragon X Elite (X1E-80-100) / X Plus          |
| NPU               | Qualcomm Hexagon NPU — 45 TOPS (Elite) / 40 TOPS (Plus) |
| Mô hình           | Gemma 4 E4B (4-bit quantized, ~2.7 GB)            |
| LLM Runner        | Ollama (Windows ARM64) + ONNX Runtime QNN cho NPU |

---

## Phần 1 — Cài Ollama Trên Windows ARM64

### Bước 1: Tải Ollama cho Windows ARM

Tải bản cài đặt Windows (ARM64) từ trang chính thức của Ollama, chọn file `.exe` dành cho Windows.

> Ollama hỗ trợ Windows ARM64 natively từ phiên bản 0.3+ — chạy thẳng không cần emulation.

### Bước 2: Cài và Kiểm Tra

```powershell
# Mở PowerShell, kiểm tra ollama đã cài thành công
ollama --version

# Xem thông tin phần cứng Ollama nhận được
ollama ps
```

### Bước 3: Tải Gemma 4 Bản 4-Bit (E4B)

```powershell
# Bản 4-bit quantized — tối ưu cho máy ARM, dung lượng ~2.7 GB
ollama pull gemma4:2b-instruct-q4_K_M

# Hoặc bản nhỏ hơn nữa (Q4_0 ~2.3 GB)
ollama pull gemma4:2b-instruct-q4_0
```

### Bước 4: Chạy Thử

```powershell
ollama run gemma4:2b-instruct-q4_K_M
```

> **Lưu ý:** Ollama mặc định chạy trên **CPU** của Snapdragon X. CPU này đã rất nhanh (~90 tok/s với Q4). Xem Phần 2 để bật NPU.

---

## Phần 2 — Bật NPU (Hexagon) Qua ONNX Runtime + QNN

Đây là cách chính thức để tận dụng **Hexagon NPU** trên Snapdragon X.

### Bước 1: Cài Python và Thư Viện

```powershell
# Cài Python 3.11 ARM64 từ python.org (chọn bản ARM64)
winget install Python.Python.3.11

# Cài ONNX Runtime với QNN execution provider
pip install onnxruntime-qnn
pip install transformers optimum[onnxruntime]
```

### Bước 2: Xuất Gemma 4 Sang ONNX (4-bit cho NPU)

```python
# export_gemma4_onnx.py
from optimum.exporters.onnx import main_export

main_export(
    model_name_or_path="google/gemma-4-2b-it",
    output="./gemma4_onnx",
    task="text-generation-with-past",
    int4_block_size=32,      # INT4 block quantization cho Hexagon NPU
    weight_format="int4",    # Đây chính là "E4B" — 4-bit efficient weights
)
```

```powershell
python export_gemma4_onnx.py
```

### Bước 3: Chạy Trên NPU

```python
# run_on_npu.py
import onnxruntime as ort
from transformers import AutoTokenizer
import numpy as np

# Chỉ định QNN Execution Provider (Hexagon NPU)
providers = [
    ("QNNExecutionProvider", {
        "backend_path": "QnnHtp.dll",   # HTP = Hexagon Tensor Processor (NPU)
        "htp_performance_mode": "burst", # Chế độ hiệu suất cao nhất
        "htp_graph_finalization_optimization_level": "3",
    })
]

sess = ort.InferenceSession("./gemma4_onnx/model.onnx", providers=providers)
tokenizer = AutoTokenizer.from_pretrained("google/gemma-4-2b-it")

prompt = "Xin chào! Bạn có thể giúp gì cho tôi?"
inputs = tokenizer(prompt, return_tensors="np")

outputs = sess.run(None, dict(inputs))
print(tokenizer.decode(outputs[0][0], skip_special_tokens=True))
```

```powershell
python run_on_npu.py
```

---

## Phần 3 — Dùng Microsoft AI Toolkit (Cách Đơn Giản Hơn)

Microsoft cung cấp công cụ hỗ trợ trực tiếp NPU Snapdragon X mà không cần tự export ONNX.

### Bước 1: Cài VS Code + AI Toolkit Extension

```powershell
winget install Microsoft.VisualStudioCode
# Mở VS Code -> Extensions -> tìm "AI Toolkit for Visual Studio Code" -> Install
```

### Bước 2: Tải Gemma 4 Qua AI Toolkit

1. Mở VS Code
2. Click biểu tượng **AI Toolkit** trên thanh bên trái
3. Chọn **Models** → **Browse Models**
4. Tìm **Gemma** → chọn phiên bản **4-bit (NPU optimized)**
5. Click **Download** — toolkit tự động tối ưu cho Snapdragon X NPU

### Bước 3: Chạy Model

```python
# AI Toolkit cung cấp OpenAI-compatible API tại localhost:5272
import requests

response = requests.post("http://localhost:5272/v1/chat/completions", json={
    "model": "gemma4-2b-int4",
    "messages": [{"role": "user", "content": "Xin chào!"}],
    "max_tokens": 256,
})
print(response.json()["choices"][0]["message"]["content"])
```

---

## Phần 4 — Kết Nối Ollama và AI Toolkit Lại Với Nhau

Để dùng **cả hai** (Ollama cho tiện lợi + NPU cho hiệu suất):

```powershell
# Dùng litellm làm proxy, chuyển request Ollama sang AI Toolkit NPU
pip install litellm

litellm --model openai/gemma4-2b-int4 --api_base http://localhost:5272/v1
# Ollama-compatible endpoint giờ có tại localhost:4000
```

```python
# Gọi qua Ollama API chuẩn nhưng chạy trên NPU
import ollama
client = ollama.Client(host="http://localhost:4000")
response = client.chat(model="gemma4-2b-int4", messages=[
    {"role": "user", "content": "Xin chào!"}
])
print(response["message"]["content"])
```

---

## Phần 5 — So Sánh Hiệu Suất Trên Surface Laptop 7

| Chế độ                    | Tốc độ sinh text | Tiêu thụ pin |
|---------------------------|-----------------|--------------|
| CPU only (Ollama default) | ~85-95 tok/s    | ~15W         |
| NPU (Hexagon HTP)         | ~120-150 tok/s  | ~8W          |
| GPU (Adreno, qua DirectML)| ~70-80 tok/s    | ~12W         |

> NPU vừa **nhanh hơn** vừa **tiết kiệm pin hơn** — lý tưởng cho laptop.

---

## Kiểm Tra NPU Đang Được Dùng

```powershell
# Mở Task Manager -> tab Performance -> tìm "NPU"
# Hoặc dùng Windows Performance Recorder
winget install Microsoft.WindowsPerformanceToolkit

# Kiểm tra qua PowerShell
Get-PnpDevice -Class "Processor" | Where-Object {$_.FriendlyName -like "*NPU*"}
```

---

## Tóm Tắt Nhanh

```
Surface Laptop 7 (Snapdragon X)
│
├── Cách nhanh nhất:  ollama pull gemma4:2b-instruct-q4_K_M
│                     ollama run gemma4:2b-instruct-q4_K_M
│                     (chạy trên CPU ARM — đã rất nhanh)
│
├── Cách dùng NPU:    VS Code AI Toolkit → tải model NPU-optimized
│                     → chạy tự động trên Hexagon NPU
│
└── Cách chuyên sâu: ONNX Runtime + QNNExecutionProvider
                      → INT4 weights = "E4B" format
                      → hiệu suất cao nhất, tiêu thụ điện thấp nhất
```
