# Hướng Dẫn Chi Tiết: Cài Gemma 4 E4B + Ollama + OpenClaw Qua PowerShell

> Dành cho **Surface Laptop 7** (Snapdragon X Elite/Plus) — Windows 10/11 ARM64

---

## Yêu Cầu Trước Khi Bắt Đầu

| Thứ cần có | Chi tiết |
|-----------|----------|
| Windows | Windows 10 (build 19041+) hoặc Windows 11 |
| RAM | 8 GB tối thiểu (16 GB khuyến nghị) |
| Ổ cứng trống | ~15 GB (Ollama + model 9.6 GB + OpenClaw) |
| Node.js | 22.14+ hoặc 24 (cài trong bước dưới) |
| PowerShell | Chạy với quyền **Administrator** |

---

## BƯỚC 0 — Mở PowerShell Với Quyền Administrator

```
Nhấn phím Windows → gõ "PowerShell"
→ Chuột phải vào "Windows PowerShell"
→ Chọn "Run as administrator"
→ Click "Yes" ở hộp thoại UAC
```

> **Bắt buộc chạy Admin** vì OpenClaw cần tạo Windows Scheduled Task để tự khởi động cùng máy.

---

## BƯỚC 1 — Cài Node.js (Bắt Buộc Cho OpenClaw)

```powershell
# Cài Node.js 22 LTS qua winget
winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements

# Đóng và mở lại PowerShell (Admin), sau đó kiểm tra
node --version    # Phải hiện v22.x.x trở lên
npm --version
```

---

## BƯỚC 2 — Cài Ollama (Native ARM64 cho Snapdragon X)

```powershell
# Cài Ollama — tự nhận bản ARM64 cho Snapdragon X
winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements

# Đóng và mở lại PowerShell, kiểm tra
ollama --version
```

Xác nhận Ollama đang chạy nền:
```powershell
# Ollama tự khởi động service khi cài xong
# Kiểm tra service đang lắng nghe cổng 11434
Test-NetConnection -ComputerName localhost -Port 11434
# Kết quả "TcpTestSucceeded : True" là OK
```

---

## BƯỚC 3 — Tải Gemma 4 E4B

```powershell
# Tải model về (~9.6 GB, cần kết nối mạng ổn định)
ollama pull gemma4:e4b

# Xem danh sách model đã tải
ollama list
```

Kết quả `ollama list` sẽ trông như này:
```
NAME            ID              SIZE    MODIFIED
gemma4:e4b      abc123def456    9.6 GB  Just now
```

Chạy thử nhanh để xác nhận hoạt động:
```powershell
ollama run gemma4:e4b "Xin chào, bạn có thể làm gì?"
# Nhấn Ctrl+C để thoát sau khi xem kết quả
```

---

## BƯỚC 4 — Cài OpenClaw Qua PowerShell

```powershell
# Chạy script cài đặt chính thức từ openclaw.ai
irm https://openclaw.ai/install.ps1 | iex
```

Script sẽ tự động:
1. Kiểm tra Node.js (cần 22.14+)
2. Cài OpenClaw CLI toàn cục qua npm
3. Khởi động wizard thiết lập ban đầu (onboarding)

Khi wizard hỏi **"Choose your model provider"** → chọn **Ollama**.

---

## BƯỚC 5 — Chạy Onboarding Thủ Công (Nếu Bước 4 Bỏ Qua Wizard)

```powershell
# Khởi động lại wizard cấu hình và cài gateway daemon
openclaw onboard --install-daemon
```

Trong wizard, nhập theo hướng dẫn:

```
? Select model provider  →  Ollama
? Ollama base URL        →  http://127.0.0.1:11434    ← KHÔNG thêm /v1
? Select model           →  gemma4:e4b
? Install gateway daemon →  Yes
```

> **Cảnh báo quan trọng:** Khi nhập URL Ollama, phải là `http://127.0.0.1:11434` — **tuyệt đối không thêm `/v1`** vào cuối. Nếu thêm `/v1`, OpenClaw chuyển sang chế độ OpenAI-compatible khiến tool calling bị lỗi.

---

## BƯỚC 6 — Chỉnh File Config Thủ Công (Nếu Cần)

File config nằm tại:
```
C:\Users\<tên_user_của_bạn>\.openclaw\openclaw.json
```

Mở bằng Notepad:
```powershell
notepad "$env:USERPROFILE\.openclaw\openclaw.json"
```

Nội dung cần có:
```json5
{
  models: {
    providers: {
      ollama: {
        baseUrl: "http://127.0.0.1:11434",
        apiKey: "ollama-local",
        api: "ollama",
        models: [
          {
            id: "gemma4:e4b",
            name: "gemma4:e4b",
            input: ["text", "image"],
            contextWindow: 128000,
            maxTokens: 8192
          }
        ]
      }
    }
  },
  agents: {
    defaults: {
      model: {
        primary: "ollama/gemma4:e4b"
      }
    }
  }
}
```

Lưu file (Ctrl+S), sau đó khởi động lại gateway:
```powershell
openclaw gateway restart
```

---

## BƯỚC 7 — Khởi Động và Kiểm Tra

```powershell
# Kiểm tra trạng thái gateway (cổng 18789)
openclaw gateway status

# Xem danh sách model OpenClaw đang nhận từ Ollama
openclaw models list --provider ollama

# Mở giao diện web dashboard
openclaw dashboard
# → Tự động mở trình duyệt tại http://localhost:18789
```

Kết quả `gateway status` thành công trông như này:
```
● OpenClaw Gateway
  Status:  running
  PID:     12345
  Port:    18789
  Model:   ollama/gemma4:e4b
  Uptime:  0d 0h 2m
```

---

## BƯỚC 8 — Chat Thử Với Gemma 4 E4B

```powershell
# Chat trực tiếp trong terminal
openclaw chat "Xin chào! Bạn đang chạy trên máy gì?"

# Hoặc mở dashboard trên trình duyệt
openclaw dashboard
```

---

## Xử Lý Lỗi Thường Gặp

### Lỗi: `openclaw` không được nhận dạng sau khi cài
```powershell
# Làm mới PATH trong phiên hiện tại
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

# Thử lại
openclaw --version
```

### Lỗi: Gateway không khởi động (Scheduled Task bị từ chối)
```powershell
# Phải chạy PowerShell với quyền Administrator
# Sau đó cài lại daemon
openclaw gateway install
```

### Lỗi: Ollama không phản hồi (port 11434 đóng)
```powershell
# Khởi động lại Ollama service
Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden

# Chờ 3 giây rồi kiểm tra
Start-Sleep 3
Test-NetConnection -ComputerName localhost -Port 11434
```

### Lỗi: Model trả về JSON thô thay vì text thông thường
```
Nguyên nhân: Đã thêm /v1 vào URL Ollama trong config
Sửa: Đổi baseUrl thành "http://127.0.0.1:11434" (bỏ /v1)
```

---

## Tóm Tắt Toàn Bộ Lệnh (Copy-Paste)

```powershell
# === CHẠY TRONG POWERSHELL ADMIN ===

# 1. Cài Node.js
winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements

# 2. Cài Ollama (ARM64 native cho Snapdragon X)
winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements

# [Đóng và mở lại PowerShell Admin]

# 3. Tải Gemma 4 E4B
ollama pull gemma4:e4b

# 4. Cài OpenClaw
irm https://openclaw.ai/install.ps1 | iex

# 5. Nếu cần cấu hình lại
openclaw onboard --install-daemon

# 6. Kiểm tra
openclaw gateway status
openclaw models list --provider ollama

# 7. Mở dashboard
openclaw dashboard
```

---

## Cấu Trúc Hoàn Chỉnh Sau Khi Cài

```
Surface Laptop 7 (Snapdragon X)
│
├── Ollama (service, cổng 11434)
│   └── gemma4:e4b  ← 9.6 GB, chạy trên CPU ARM64
│
└── OpenClaw Gateway (service, cổng 18789)
    ├── Dashboard UI  →  http://localhost:18789
    ├── Provider      →  ollama/gemma4:e4b
    └── Channels      →  Telegram / Discord / WhatsApp (cấu hình thêm)
```
