# Hướng Dẫn Từ Đầu: Cài Gemma 4 E4B Chạy NPU Trên Surface Laptop 7

> Dành cho người **chưa biết gì** về AI, lập trình, hay terminal.
> Đọc từng bước, làm đúng thứ tự.

---

## Hiểu Nhanh Trước Khi Làm

```
Bạn cần 3 thứ:

  [1] Gemma 4 E4B     = bộ não AI (file model, ~5 GB)
  [2] Phần mềm chạy  = công cụ tải & khởi động bộ não đó
  [3] NPU hoạt động  = chip AI trong máy Surface xử lý thay CPU
```

**Công cụ dùng NPU được trên Surface Laptop 7:**

| Công cụ | NPU? | Dễ dùng? | Có Gemma 4? |
|---------|------|----------|-------------|
| **Microsoft Foundry Local** | **Có** | Trung bình | **Có** |
| LM Studio | Không (CPU) | Rất dễ | Có |
| Ollama | Không (CPU) | Trung bình | Có |

→ **Dùng Microsoft Foundry Local** nếu muốn NPU thật sự.
→ **Dùng LM Studio** nếu chỉ muốn chạy nhanh, không cần NPU.

---

## KIỂM TRA TRƯỚC KHI BẮT ĐẦU

### Kiểm tra 1 — Windows có đủ phiên bản không?

Foundry Local cần **Windows 11 bản 24H2 trở lên** để dùng NPU.

```
Nhấn   Windows + R
Gõ:    winver
Nhấn:  Enter
```

Cửa sổ hiện ra — nhìn dòng **"Version"**:
- `24H2` hoặc cao hơn → **OK, tiếp tục**
- Thấp hơn → cần cập nhật Windows trước (Settings → Windows Update)

### Kiểm tra 2 — Máy có đủ dung lượng không?

```
Mở File Explorer → nhìn ổ C:
Cần còn trống ít nhất 10 GB
```

---

## CON ĐƯỜNG A — Microsoft Foundry Local (Dùng NPU Thật)

### ━━ Bước A1: Mở PowerShell ━━

```
Nhấn phím Windows
Gõ:   PowerShell
Thấy "Windows PowerShell" → Chuột PHẢI vào đó
Chọn: "Run as administrator"
Bấm:  "Yes" khi hỏi
```

Cửa sổ đen hiện ra với chữ `PS C:\Windows\system32>` — đúng rồi.

---

### ━━ Bước A2: Cài Microsoft Foundry Local ━━

Gõ lệnh này vào cửa sổ đen, nhấn Enter:

```powershell
winget install Microsoft.FoundryLocal --accept-source-agreements --accept-package-agreements
```

Chờ đến khi thấy chữ **"Successfully installed"**.

> Nếu hỏi `[Y] Yes / [N] No` ở bất kỳ bước nào → gõ `Y` rồi Enter.

---

### ━━ Bước A3: Đóng và Mở Lại PowerShell Admin ━━

Đóng cửa sổ PowerShell. Mở lại bằng cách **chuột phải → Run as administrator** như bước A1.

Kiểm tra cài thành công:

```powershell
foundry --version
```

Nếu hiện số phiên bản (ví dụ `0.7.x`) → thành công.

---

### ━━ Bước A4: Xem Danh Sách Model Có Trong Foundry ━━

```powershell
foundry model list
```

Tìm dòng có chữ `gemma` trong danh sách. Ghi nhớ tên chính xác.

---

### ━━ Bước A5: Tải và Chạy Gemma 4 E4B ━━

```powershell
foundry model run gemma-4-e4b-it
```

**Lần đầu chạy:** Foundry tự động:
1. Phát hiện máy bạn có chip Snapdragon X + Hexagon NPU
2. Tải đúng bản model tối ưu cho NPU (~5 GB, chờ vài phút)
3. Khởi động model

Khi thấy dòng chờ nhập liệu → gõ thử:

```
Xin chào! Bạn có thể làm gì?
```

Nếu trả lời được bằng tiếng Việt → **thành công, NPU đang hoạt động!**

---

### ━━ Bước A6: Xác Nhận NPU Đang Được Dùng ━━

Mở **Task Manager** (Ctrl + Shift + Esc):
- Chọn tab **Performance**
- Kéo xuống tìm ô **NPU**
- Khi đang chat → thanh NPU tăng lên → NPU đang chạy

---

### ━━ Bước A7: Mở Giao Diện Web (Tùy Chọn) ━━

Nếu muốn giao diện đẹp hơn thay vì gõ lệnh:

```powershell
foundry service start
```

Sau đó mở trình duyệt, vào địa chỉ:
```
http://localhost:5273
```

---

## CON ĐƯỜNG B — LM Studio (Không Cần Gõ Lệnh, Không Có NPU)

Nếu muốn cách **đơn giản nhất**, không cần terminal, không cần NPU:

### Bước B1: Tải LM Studio

Vào trang lmstudio.ai → tải file `.exe` → cài như phần mềm bình thường.

### Bước B2: Mở LM Studio, Tìm Gemma 4

1. Mở LM Studio
2. Click tab **Discover** (kính lúp)
3. Gõ vào ô tìm kiếm: `gemma 4 e4b`
4. Chọn `google/gemma-4-e4b` → chọn bản **Q4_K_M** (~2.5 GB)
5. Click **Download**

### Bước B3: Chat

1. Click tab **Chat** (bong bóng thoại)
2. Chọn model vừa tải
3. Gõ câu hỏi bằng tiếng Việt → nhận kết quả

> **Lưu ý:** LM Studio chạy trên CPU ARM của Snapdragon X — không dùng NPU.
> Tốc độ vẫn ổn (~85 tok/s) nhưng tiêu thụ pin nhiều hơn Foundry Local.

---

## SAU KHI CÀI XONG — Kết Nối Với OpenClaw

Sau khi Foundry Local đang chạy (bước A5), cài OpenClaw để dùng qua Zalo/Telegram:

```powershell
# Cài Node.js trước
winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
```

Đóng và mở lại PowerShell Admin, sau đó:

```powershell
# Cài OpenClaw
irm https://openclaw.ai/install.ps1 | iex
```

Khi wizard hỏi provider → chọn **Foundry Local** (hoặc OpenAI-compatible).
Nhập URL: `http://localhost:5273/v1`

---

## XỬ LÝ LỖI PHỔ BIẾN

**"foundry không được nhận dạng"**
→ Đóng và mở lại PowerShell (Admin)

**"NPU variant không tải được"**
→ Vào Settings → Windows Update → cập nhật lên Windows 11 24H2

**Foundry tải bản CPU thay vì NPU**
→ Cài driver NPU Qualcomm:
```powershell
winget install Qualcomm.NPUDriver
```
Sau đó chạy lại `foundry model run gemma-4-e4b-it`

**Model chạy chậm**
→ Đóng các app không cần thiết, đặc biệt trình duyệt

---

## TÓM TẮT TOÀN BỘ (Chỉ 5 Lệnh)

```powershell
# 1. Cài Foundry Local
winget install Microsoft.FoundryLocal --accept-source-agreements --accept-package-agreements

# [Đóng & mở lại PowerShell Admin]

# 2. Kiểm tra
foundry --version

# 3. Chạy Gemma 4 E4B (tự tải + tự dùng NPU)
foundry model run gemma-4-e4b-it

# 4. Xem giao diện web
# Mở trình duyệt → http://localhost:5273
```

---

## SO SÁNH 2 CON ĐƯỜNG

```
CON ĐƯỜNG A — Foundry Local           CON ĐƯỜNG B — LM Studio
─────────────────────────────          ────────────────────────
NPU: CÓ (Hexagon, ~120 tok/s)          NPU: KHÔNG (CPU, ~85 tok/s)
Tiêu thụ pin: Thấp (~8W)               Tiêu thụ pin: Cao hơn (~15W)
Cài đặt: PowerShell (3 lệnh)           Cài đặt: Click chuột bình thường
Giao diện: Web (localhost:5273)         Giao diện: Desktop app đẹp
Dùng cho: Chạy lâu dài, bot            Dùng cho: Thử nghiệm nhanh
```
