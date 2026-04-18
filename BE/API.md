# 🔌 Tài liệu API - DMS (Driver Management System)

**Dự án:** CucHum App (CH App) - Hệ thống Quản lý Vận hành & Nhân sự Đội xe  
**Base URL:** `http://localhost:8080/api/v1`  
**Xác thực:** JWT Bearer Token  
**Phiên bản:** 2.3.4

---

## Cấu trúc dự án (Backend)

```
BE/
├── cmd/api/main.go          # Entry point (HTTP + lịch nền mỗi phút)
├── internal/
│   ├── config/              # Load config.yaml
│   ├── models/              # Database models & DTOs
│   ├── repository/          # Data access
│   ├── service/             # Business logic
│   ├── handler/             # HTTP handlers
│   ├── middleware/          # JWT & Role auth
│   └── utils/               # JWT, Password, Response
├── pkg/database/            # PostgreSQL pool
├── migrations/              # Database migrations
├── Media/                   # Upload files
└── config.yaml
```

## Công nghệ sử dụng

| Nhóm               | Công nghệ                                                                                  | Mục đích                                                           |
| ------------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| Mobile App         | Flutter, Dart, Provider                                                                    | Xây dựng ứng dụng đa nền tảng cho tài xế và điều hành              |
| Backend API        | Golang, Gin, PostgreSQL                                                                    | Xử lý nghiệp vụ, phân quyền và lưu trữ dữ liệu vận hành            |
| Xác thực & Bảo mật | JWT (access/refresh/biometric token), Role middleware                                      | Bảo mật API và kiểm soát truy cập theo vai trò                     |
| Thông báo          | Firebase Cloud Messaging (FCM), APNs (qua FCM trên iOS/macOS), flutter_local_notifications | Gửi push notification đa nền tảng và hiển thị thông báo cục bộ     |
| Realtime           | Server-Sent Events (SSE)                                                                   | Cập nhật thông báo theo thời gian thực qua `/notifications/stream` |
| Hạ tầng            | Nginx, systemd                                                                             | Reverse proxy và quản lý tiến trình backend                        |
| File storage       | Media static files + upload multipart/form-data                                            | Lưu trữ avatar, hợp đồng, bảng lương, hóa đơn, ảnh sự cố           |

## Lịch nền (cron trong `cmd/api`)

Cùng process với API, **mỗi ~1 phút** gọi `TripService.RunDepartureJobs` (không cần cron hệ điều hành riêng).

| Mốc (so với `scheduled_start_at`) | Điều kiện                                         | Hành động                                                                                      |
| --------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **−10 phút** … **0**              | Chuyến **`DRIVER_ACCEPTED`**, chưa gửi mốc này    | **Thông báo** tài xế (lưu `notifications` + **SSE** + **FCM**): sắp tới giờ chạy (~10 phút).   |
| **≥ giờ dự kiến**                 | Tương tự, chưa gửi mốc “đúng giờ”                 | Thông báo: đến giờ chạy dự kiến; nhắc kiểm tra xe nếu chưa.                                    |
| **+10 phút**                      | Tương tự, vẫn **`DRIVER_ACCEPTED`**               | Thông báo trễ; nhắc bắt đầu trước khi hết **30 phút** sau giờ dự kiến.                         |
| **+30 phút**                      | Vẫn **`DRIVER_ACCEPTED`**, chưa **`IN_PROGRESS`** | **Tự hủy** → **`CANCELLED`**, ghi `admin_cancel_reason` dạng `[Hệ thống] …`; thông báo tài xế. |

Cột ghi nhận đã gửi (tránh trùng): migration **`017_trip_departure_notify.sql`** (`notify_departure_10m_sent_at`, `notify_departure_start_sent_at`, `notify_departure_late_sent_at`).

**Cửa sổ bắt đầu chạy (tài xế):** server `now` ∈ **[`scheduled_start_at` − 15 phút, `scheduled_start_at` + 30 phút]** — khớp mốc nhắc **22:50 / 23:00 / 23:10** cho chuyến **23:00** (ví dụ minh họa).

## Định dạng phản hồi

**Thành công (Success):**

```json
{
  "success": true,
  "message": "Thao tác thành công",
  "data": {...}
}
```

**Thất bại (Error):**

```json
{
  "success": false,
  "error": "Mô tả lỗi chi tiết"
}
```

## Xác thực

Header bắt buộc cho các API (trừ PUBLIC): `Authorization: Bearer <access_token>`

**Thời hạn Token:**

| Token             | Thời hạn | Mục đích                                       |
| ----------------- | -------- | ---------------------------------------------- |
| `access_token`    | 6 giờ    | Gọi các API protected (Bearer header)          |
| `refresh_token`   | 30 ngày  | Làm mới `access_token` khi hết hạn             |
| `biometric_token` | 1 năm    | Đăng nhập sinh trắc học (lưu ẩn trên thiết bị) |

---

## DANH SÁCH API ENDPOINTS

### 🔒 1. Xác thực (Authentication)

#### POST /api/v1/auth/login

Đăng nhập (bằng phone hoặc email).

**Role:** PUBLIC

**Request:**

```json
{
  "identifier": "0987654321",
  "password": "admin"
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "abc123...",
    "expires_in": 21600,
    "user": {
      "id": "uuid",
      "phone_number": "0987654321",
      "email": "admin@gmail.com",
      "full_name": "System Administrator",
      "role": "ADMIN",
      "status": "ACTIVE"
    }
  }
}
```

#### POST /api/v1/auth/refresh

Làm mới access token.

**Role:** PUBLIC

**Request:**

```json
{
  "refresh_token": "abc123..."
}
```

#### POST /api/v1/auth/logout

Đăng xuất (Hủy refresh token).

**Role:** ALL

**Request:**

```json
{
  "refresh_token": "abc123..."
}
```

#### POST /api/v1/auth/forgot-password

Gửi mã OTP về email để đặt lại mật khẩu.

**Role:** PUBLIC

**Request:**

```json
{
  "email": "admin@gmail.com"
}
```

#### POST /api/v1/auth/reset-password

Đặt lại mật khẩu bằng OTP.

**Role:** PUBLIC

**Request:**

```json
{
  "email": "admin@gmail.com",
  "otp": "123456",
  "new_password": "newpassword123",
  "confirm_password": "newpassword123"
}
```

#### POST /api/v1/auth/change-password

Đổi mật khẩu (user đã đăng nhập).

**Role:** ALL (Authenticated)

**Request:**

```json
{
  "current_password": "oldpassword",
  "new_password": "newpassword123",
  "confirm_password": "newpassword123"
}
```

---

#### POST /api/v1/auth/biometric-login `[NEW]`

Đăng nhập bằng sinh trắc học sử dụng `biometric_token` đã được lưu trước đó.

**Role:** PUBLIC (không cần Authorization header)

**Luồng hoạt động:**

1. Client thực hiện xác thực sinh trắc học cục bộ (FaceID / TouchID / Fingerprint).
2. Sau khi xác thực thành công trên thiết bị, client gửi `biometric_token` (đã lưu từ lần kích hoạt) lên server.
3. Server xác minh token, trả về `access_token` + `refresh_token` mới.

**Request:**

```json
{
  "biometric_token": "a1b2c3d4e5f6..."
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "abc123...",
    "expires_in": 21600,
    "user": {
      "id": "uuid",
      "phone_number": "0987654321",
      "full_name": "Nguyen Van A",
      "role": "DRIVER",
      "status": "ACTIVE"
    }
  }
}
```

---

#### POST /api/v1/auth/biometric/enable `[NEW]`

Kích hoạt đăng nhập sinh trắc học. Server tạo `biometric_token` dài hạn (1 năm) và trả về cho client lưu ẩn trong bộ nhớ thiết bị.

**Role:** ALL (Authenticated)

> **Lưu ý:** Mỗi user chỉ có một `biometric_token` hoạt động tại một thời điểm. Gọi lại endpoint này sẽ thay thế token cũ.

**Request:** _(không cần body)_

**Response:**

```json
{
  "success": true,
  "message": "Biometric authentication enabled",
  "data": {
    "biometric_token": "a1b2c3d4e5f6...",
    "expires_at": "2027-04-07T10:00:00Z"
  }
}
```

---

#### DELETE /api/v1/auth/biometric/disable `[NEW]`

Tắt đăng nhập sinh trắc học. Xóa `biometric_token` trên server; client cũng phải xóa token khỏi bộ nhớ thiết bị.

**Role:** ALL (Authenticated)

**Request:** _(không cần body)_

**Response:**

```json
{
  "success": true,
  "message": "Biometric authentication disabled",
  "data": null
}
```

---

### 👤 2. Quản lý Tài khoản & Hồ sơ (Users & Profile)

#### GET /api/v1/users/me

Lấy thông tin tài khoản hiện tại.

**Role:** ALL

#### GET /api/v1/users

Lấy danh sách tất cả tài xế (có phân trang).

**Role:** ADMIN

**Query:** `?page=1&limit=20&status=ACTIVE`

#### POST /api/v1/users

Tạo tài khoản tài xế mới. Có thể điền sẵn thông tin hồ sơ ngay khi tạo (áp dụng trực tiếp, không qua hàng chờ duyệt).

**Role:** ADMIN

**Request:**

```json
{
  "phone_number": "0987654321",
  "email": "driver@example.com",
  "password": "password123",
  "full_name": "Nguyen Van A",
  "role": "DRIVER",
  "citizen_id": "012345678901",
  "license_class": "B2",
  "license_number": "790012345678",
  "address": "41 Đường A, Phường B, Tỉnh C"
}
```

> `citizen_id`: tùy chọn, **phải có đúng 12 chữ số** nếu cung cấp.  
> `license_number`: tùy chọn — **số giấy phép lái xe (GPLX)**.  
> `address`: tùy chọn, định dạng "Số nhà + Tên đường, Xã/Phường, Tỉnh/Thành phố".

#### PATCH /api/v1/users/:id/status

Khóa/Mở khóa tài khoản tài xế (Deactivate).

**Role:** ADMIN

**Request:**

```json
{
  "status": "INACTIVE"
}
```

#### PATCH /api/v1/users/:id/password

Admin đổi mật khẩu cho user.

**Role:** ADMIN

**Request:**

```json
{
  "new_password": "newpassword123"
}
```

#### GET /api/v1/profile

Xem chi tiết hồ sơ cá nhân của mình. Nếu user là DRIVER và đang có yêu cầu cập nhật chờ duyệt, trường `pending_request` sẽ được trả về kèm theo.

**Role:** ALL

**Response (DRIVER with pending request):**

```json
{
  "success": true,
  "data": {
    "user_id": "uuid",
    "full_name": "Nguyen Van A",
    "role": "DRIVER",
    "citizen_id": "079123456789",
    "license_class": "B2",
    "license_number": "790012345678",
    "address": "123 ABC Street",
    "pending_request": {
      "id": "uuid",
      "citizen_id": "079999999999",
      "license_class": "C",
      "license_number": "790099999999",
      "address": "456 XYZ Street",
      "proof_image_url": "/Media/profile-proofs/1712345678_a1b2c3d4_cccd.jpg",
      "status": "PENDING",
      "created_at": "2026-04-07T10:00:00Z"
    }
  }
}
```

#### PUT /api/v1/profile `[UPDATED]`

Cập nhật thông tin hồ sơ cá nhân.

- **`avatar_url`**: Luôn được áp dụng **ngay lập tức** (không qua hàng chờ) cho cả DRIVER và ADMIN.
- **DRIVER** (citizen_id, license_class, license_number, address): Tạo yêu cầu PENDING → chờ Admin duyệt. Ghi đè yêu cầu PENDING cũ nếu có.
- **`proof_image_url`** (tùy chọn): Ảnh minh chứng (URL sau khi upload `POST /upload?folder=profile-proofs`). Với **DRIVER**, lưu cùng bản ghi yêu cầu PENDING; admin xem trong `GET /profile` (`pending_request.proof_image_url`) và `GET /profile-requests`. Với **ADMIN** cập nhật trực tiếp, trường này **bị bỏ qua** (không ghi vào `driver_profiles`).
- **ADMIN** (citizen_id, license_class, license_number, address): Áp dụng trực tiếp, không qua hàng chờ.

**Role:** ALL

**Request:**

```json
{
  "citizen_id": "079123456789",
  "license_class": "B2",
  "license_number": "790012345678",
  "address": "41 Đường A, Phường B, Tỉnh C",
  "avatar_url": "/Media/avatar/uuid.jpg",
  "proof_image_url": "/Media/profile-proofs/1712345678_a1b2c3d4_cccd.jpg"
}
```

> `citizen_id`: **phải có đúng 12 chữ số** nếu cung cấp.  
> `address`: định dạng "Số nhà + Tên đường, Xã/Phường, Tỉnh/Thành phố".

**Response (DRIVER → 202 Accepted):**

```json
{
  "success": true,
  "message": "Yêu cầu cập nhật hồ sơ đã được gửi và đang chờ Admin duyệt",
  "data": {
    "id": "uuid",
    "status": "PENDING",
    "citizen_id": "079123456789",
    "license_class": "B2",
    "address": "123 ABC Street",
    "created_at": "2026-04-07T10:00:00Z"
  }
}
```

#### GET /api/v1/users/:id/profile

Xem chi tiết hồ sơ của một tài xế cụ thể.

**Role:** ADMIN

---

### 📋 2b. Duyệt Yêu cầu Cập nhật Hồ sơ (Profile Update Requests) `[NEW]`

#### GET /api/v1/profile-requests

Lấy danh sách các yêu cầu cập nhật hồ sơ.

**Role:** ADMIN

**Query:** `?status=PENDING&page=1&limit=20`

> **Enum `status`:** PENDING, APPROVED, REJECTED

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "driver_name": "Nguyen Van A",
      "citizen_id": "079123456789",
      "license_class": "B2",
      "license_number": "790012345678",
      "address": "456 XYZ Street",
      "status": "PENDING",
      "created_at": "2026-04-07T10:00:00Z"
    }
  ]
}
```

#### PATCH /api/v1/profile-requests/:id/review

Admin duyệt (APPROVED) hoặc từ chối (REJECTED) một yêu cầu cập nhật hồ sơ.

- Nếu **APPROVED**: thông tin mới được áp dụng ngay vào hồ sơ tài xế.
- Nếu **REJECTED**: hồ sơ không thay đổi; `admin_note` được trả về cho tài xế xem qua `GET /profile`.

**Role:** ADMIN

**Request:**

```json
{
  "status": "APPROVED",
  "admin_note": "Đã xác minh CCCD hợp lệ"
}
```

```json
{
  "status": "REJECTED",
  "admin_note": "Ảnh CCCD bị mờ, vui lòng chụp lại"
}
```

---

### 📄 3. Hợp đồng & Pháp lý (Contracts)

#### GET /api/v1/contracts

- **DRIVER:** Danh sách hợp đồng **của chính mình** (theo `user_id` trong JWT). **Không** truyền `driver_id` (server bỏ qua nếu có).
- **ADMIN:** Danh sách hợp đồng của **một tài xế**; **bắt buộc** query `?driver_id=<uuid>`.
- **ADMIN (lọc):** `?acknowledgment_status=PENDING|ACKNOWLEDGED|DECLINED` — chỉ các hợp đồng đang chờ phản hồi / đã xác nhận / đã từ chối.

**Role:** DRIVER | ADMIN

**Query (ADMIN, bắt buộc):** `?driver_id=<uuid>`

**Query (ADMIN, tùy chọn):** `acknowledgment_status`

**Phần tử `data[]` (mỗi contract):**

| Trường                  | Ý nghĩa                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------- |
| `driver_full_name`      | Tên tài xế (khi JOIN được user)                                                     |
| `is_viewed`             | Tài xế đã mở xem PDF                                                                |
| `acknowledgment_status` | `PENDING` — chờ phản hồi; `ACKNOWLEDGED` — đã xác nhận; `DECLINED` — không xác nhận |
| `driver_note`           | Lý do khi `DECLINED` (nếu có)                                                       |
| `responded_at`          | Thời điểm tài xế phản hồi (nếu đã ACK/DECLINED)                                     |

#### POST /api/v1/contracts

Tạo/Upload hợp đồng mới cho tài xế.

**Role:** ADMIN

**Request:**

```json
{
  "driver_id": "uuid",
  "contract_number": "HD2026001",
  "file_url": "/Media/contract.pdf",
  "start_date": "2026-01-01",
  "end_date": "2027-01-01"
}
```

#### PATCH /api/v1/contracts/:id/view

Đánh dấu tài xế đã mở xem file PDF (gọi khi mở viewer).

**Role:** DRIVER

#### PATCH /api/v1/contracts/:id/respond

Tài xế **xác nhận** hoặc **không xác nhận** hợp đồng (chỉ khi đang `PENDING`).

**Role:** DRIVER

**Request (JSON):**

```json
{
  "status": "ACKNOWLEDGED"
}
```

hoặc từ chối (**bắt buộc** có `note`):

```json
{
  "status": "DECLINED",
  "note": "Nội dung cần chỉnh sửa …"
}
```

---

### 💰 4. Quản lý Lương (Payslips)

#### GET /api/v1/payslips

Danh sách bảng lương.

**Role:** ALL

- **DRIVER:** chỉ các bản ghi của chính mình.
- **ADMIN:** tất cả tài xế (có thể lọc theo tháng).

**Query:** `?month=2026-04` (tùy chọn, định dạng `YYYY-MM`)

**Phần tử `data[]` (mỗi payslip):**

| Trường         | Ý nghĩa                                              |
| -------------- | ---------------------------------------------------- |
| `id`           | UUID                                                 |
| `driver_id`    | UUID tài xế                                          |
| `salary_month` | Kỳ lương (ISO date, tháng)                           |
| `file_url`     | Đường dẫn PDF trong `/Media/payslips/`               |
| `is_viewed`    | Tài xế đã mở xem                                     |
| `status`       | `PENDING` \| `VIEWED` \| `CONFIRMED` \| `COMPLAINED` |
| `note`         | Ghi chú khi khiếu nại (nếu có)                       |
| `confirmed_at` | Thời điểm xác nhận / khiếu nại                       |
| `created_at`   | Tạo lúc                                              |

#### POST /api/v1/payslips

Tạo bảng lương đơn lẻ cho 1 tài xế.

**Role:** ADMIN

**Request:**

```json
{
  "driver_id": "uuid",
  "salary_month": "2026-04",
  "file_url": "/Media/payslip.pdf"
}
```

#### POST /api/v1/payslips/import `[NEW]`

Import file Excel để tự động phân phối bảng lương hàng loạt.

**Role:** ADMIN

**Content-Type:** multipart/form-data (file: .xlsx)

#### PATCH /api/v1/payslips/:id/view

Đánh dấu tài xế đã xem bảng lương.

**Role:** DRIVER

#### PATCH /api/v1/payslips/:id/confirm `[NEW]`

Tài xế xác nhận đúng lương hoặc khiếu nại nếu có sai sót.

**Role:** DRIVER

**Request (Xác nhận):**

```json
{
  "status": "CONFIRMED",
  "note": ""
}
```

**Request (Khiếu nại):**

```json
{
  "status": "COMPLAINED",
  "note": "Thiếu tiền phụ cấp ăn ca"
}
```

---

### 🚛 5. Quản lý Phương tiện (Vehicles & Checklists)

#### GET /api/v1/vehicles

Danh sách phương tiện của công ty.

**Role:** ALL

**Query:** `?status=ACTIVE`

Mỗi xe gồm **`license_plate`** (biển số), **`vehicle_type`**, **`status`**, **`image_url`** (tùy chọn — URL sau `POST /upload?folder=vehicles&vehicle_id=<id xe>`), và các trường ngày bảo trì như bảng `vehicles`.

#### GET /api/v1/vehicles/:id/maintenance `[NEW]`

Xem thông tin hạn bảo hiểm, hạn đăng kiểm của xe (Dùng để nhắc nhở). Response kèm **`image_url`** nếu có.

**Role:** ALL

#### POST /api/v1/vehicles `[NEW 2.2]`

Admin tạo phương tiện mới.

**Role:** ADMIN

**Request (JSON):**

```json
{
  "license_plate": "51H-12345",
  "vehicle_type": "Xe 16 chỗ",
  "status": "ACTIVE",
  "image_url": "/Media/vehicles/1712345678_a1b2c3d4_xe.jpg",
  "insurance_expiry": "2026-12-31",
  "registration_expiry": "2027-06-30",
  "last_maintenance_date": "2026-01-15",
  "next_maintenance_date": "2026-07-15"
}
```

> **`license_plate`**: biển số xe (bắt buộc khi tạo).  
> **`image_url`**: tùy chọn — sau khi đã có `id` xe: `POST /api/v1/upload?folder=vehicles&vehicle_id=<id>`, rồi gán `file_url` (hoặc PATCH `image_url`). Không upload `vehicles` thiếu `vehicle_id`.  
> Ngày tùy chọn, định dạng `YYYY-MM-DD`. `status` mặc định `ACTIVE` nếu bỏ qua.

#### PATCH /api/v1/vehicles/:id `[NEW 2.2]`

Admin cập nhật thông tin xe (chỉ gửi các trường cần đổi).

**Role:** ADMIN

#### DELETE /api/v1/vehicles/:id `[NEW 2.2]`

Admin xóa xe. **Không** cho phép khi xe còn chuyến **đang diễn ra hoặc còn hiệu lực trong hiện tại/tương lai** (theo lịch):

| Tình huống                                                                                                                                  | Cho phép xóa?                            |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Có chuyến **`IN_PROGRESS`**                                                                                                                 | Không                                    |
| Có chuyến **`SCHEDULED_PENDING`** hoặc **`DRIVER_ACCEPTED`** mà **chưa** có `scheduled_end_at`, **hoặc** `scheduled_end_at >= now` (UTC)    | Không                                    |
| Chỉ còn chuyến **`COMPLETED`**, **`CANCELLED`**, **`DRIVER_DECLINED`**                                                                      | Có                                       |
| Chuyến lên lịch đã **kết thúc theo lịch**: `scheduled_end_at IS NOT NULL` và `scheduled_end_at < now` (UTC), dù status vẫn pending/accepted | Có _(nên đổi status cho đúng nghiệp vụ)_ |

> So sánh thời gian dùng **UTC** (cột `TIMESTAMPTZ`). Để xóa xe, cần hoàn tất / hủy chuyến đang chạy hoặc đảm bảo không còn chuyến lên lịch “chưa quá” `scheduled_end_at`.

**Role:** ADMIN

#### GET /api/v1/checklists `[NEW]`

Xem lịch sử kiểm tra xe (theo chuyến).

**Role:** ADMIN

**Query:** `?vehicle_id=uuid&date=2026-04-07&trip_id=uuid` — `trip_id` (tùy chọn): chỉ bản ghi checklist gắn chuyến đó. **DRIVER** chỉ được khi `trip_id` là chuyến của mình.

#### POST /api/v1/checklists `[NEW]`

Tài xế submit form kiểm tra an toàn xe **trước / trong** một chuyến đã gán cho mình.

**Role:** DRIVER

**Request:**

```json
{
  "vehicle_id": "uuid",
  "trip_id": "uuid",
  "tire_check": true,
  "light_check": true,
  "clean_check": true,
  "brake_check": true,
  "oil_check": true,
  "note": "Đèn xi nhan trái hơi mờ"
}
```

> **`trip_id` (bắt buộc):** chuyến phải thuộc tài xế, `vehicle_id` phải trùng xe của chuyến, và trạng thái chuyến phải là **`DRIVER_ACCEPTED`** hoặc **`IN_PROGRESS`** (tài xế đã nhận lịch). **Mỗi chuyến chỉ một checklist:** gửi lại sẽ lỗi `vehicle checklist already submitted for this trip` (migration `015_checklist_one_per_trip.sql`, index duy nhất `trip_id` khi NOT NULL). Thời điểm thực tế trên app dùng `created_at` (RFC3339); `check_date` chỉ là ngày (DATE).  
> **Nghiệp vụ:** tài xế **phải** đã có checklist cho `trip_id` đó **trước** khi gọi **`POST /trips/:id/start`** (bắt đầu chạy); nếu chưa có → lỗi `complete the vehicle checklist for this trip before starting`.

---

### ⛽ 6. Quản lý Xăng Dầu (Fuel Reports)

#### GET /api/v1/fuel-reports

Xem lịch sử đổ xăng.

**Role:** ALL

**Query:** `?date=2026-04-07&vehicle_id=uuid&driver_id=uuid&trip_id=uuid` — `trip_id` (tùy chọn): chỉ báo cáo xăng gắn chuyến đó. **DRIVER** chỉ được khi `trip_id` là chuyến của mình.

#### GET /api/v1/fuel-reports/export `[NEW]`

Xuất báo cáo xăng dầu ra file Excel.

**Role:** ADMIN

**Query:** `?start_date=2026-04-01&end_date=2026-04-30`

#### POST /api/v1/fuel-reports `[UPDATED]`

Tài xế khai báo chi phí xăng/dầu (tối thiểu: **số tiền** + **ảnh hóa đơn**).

**Role:** DRIVER

**Request Payload:**

```json
{
  "vehicle_id": "uuid",
  "trip_id": "uuid",
  "report_date": "2026-04-07",
  "total_cost": 1000000,
  "receipt_image_url": "/Media/receipt_abc.jpg",
  "gps_latitude": 10.762622,
  "gps_longitude": 106.660172
}
```

> `fuel_purchased_at` (tùy chọn): **RFC3339** — thời điểm mua/đổ xăng; **không được sau** thời điểm hiện tại (server). Nếu **không gửi**, backend tự gán bằng thời điểm server hiện tại (`time.Now()`). Cột DB `fuel_purchased_at` (migration `014_fuel_purchased_at.sql`). GET danh sách báo cáo trả về kèm trường này.

> `odo_current`, `liters`, `odo_image_url` vẫn có thể gửi (tùy chọn, tương thích dữ liệu cũ); app hiện tại chỉ thu **tổng tiền** và **ảnh hóa đơn** (thời điểm mua do backend tự set).

> `trip_id` (tùy chọn): khi có, chuyến phải thuộc tài xế, trạng thái **`DRIVER_ACCEPTED`** hoặc **`IN_PROGRESS`**, và `vehicle_id` trùng với xe của chuyến; chuyến phải có **`scheduled_start_at`**. **Cửa sổ thời gian (giống bắt đầu chạy):** server `now` phải nằm trong **[`scheduled_start_at` − 15 phút, `scheduled_start_at` + 30 phút]**. Nếu client có gửi `fuel_purchased_at`, giá trị này cũng phải nằm trong cửa sổ trên. Báo không gắn `trip_id` không áp dụng giới hạn này.

#### PATCH /api/v1/fuel-reports/:id

Admin thêm ghi chú sau khi kiểm duyệt hóa đơn xăng.

**Role:** ADMIN

**Request:**

```json
{
  "admin_note": "Hình ảnh hóa đơn bị mờ, yêu cầu nộp lại bản cứng"
}
```

---

### 🗺️ 7. Quản lý Chuyến đi (Trips Tracking) `[UPDATED 2.3.4]`

> Luồng chính (2.2): **Admin lên lịch** → **Tài xế xác nhận** (đồng ý / từ chối) → **Tài xế bắt đầu chuyến** → **Kết thúc chuyến**.  
> **POST /trips/start** (ad-hoc, không lịch) vẫn có trên API nhưng **không dùng** trên app tài xế.

#### GET /api/v1/trips

Lấy danh sách các chuyến đi.

**Role:** ALL

**Query:** `?status=...&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&vehicle_id=uuid`

- **DRIVER:** chỉ chuyến của mình.
- **ADMIN:** toàn bộ chuyến, hoặc lọc `?driver_id=uuid` (tùy chọn), `vehicle_id`, `status`.

**Trạng thái (`status`):** `SCHEDULED_PENDING` | `DRIVER_ACCEPTED` | `DRIVER_DECLINED` | `IN_PROGRESS` | `COMPLETED` | `CANCELLED`

**Trường bổ sung trên mỗi chuyến:** `scheduled_start_at`, `scheduled_end_at`, `driver_note` (ghi chú admin cho tài xế), `driver_decline_note`, `admin_cancel_reason` (khi admin hủy chuyến), `cancelled_at` (thời điểm hủy), `start_time` (null cho tới khi tài xế bắt đầu chạy), `start_lat`, `start_lng`, `end_lat`, `end_lng` (tọa độ bắt đầu/kết thúc nếu có).

#### GET /api/v1/trips/:id `[NEW 2.2.5]`

Một chuyến theo `id` (app tài xế: màn **chi tiết chuyến**).

**Role:** DRIVER (chỉ chuyến của mình) hoặc ADMIN (mọi chuyến).

**Response:** cùng cấu trúc bản ghi chuyến, thêm **`license_plate`** (biển số xe) và **`driver_name`** (họ tên tài xế).

**Map data (cho app):** response gồm `start_lat`, `start_lng`, `end_lat`, `end_lng` để app render bản đồ hành trình (flutter_map) ở màn chi tiết chuyến.

**Ví dụ dữ liệu tọa độ trong response:**

```json
{
  "id": "uuid",
  "start_lat": 10.762622,
  "start_lng": 106.660172,
  "end_lat": 10.823099,
  "end_lng": 106.629662
}
```

#### POST /api/v1/trips/schedule `[NEW 2.2]`

Admin tạo chuyến lịch trước cho một tài xế. Trạng thái ban đầu: **SCHEDULED_PENDING**. Gửi push notification cho tài xế (nếu FCM bật).

**Role:** ADMIN

**Request:**

```json
{
  "driver_id": "uuid",
  "vehicle_id": "uuid",
  "scheduled_start_at": "2026-04-07T07:00:00+07:00",
  "scheduled_end_at": "2026-04-07T18:00:00+07:00",
  "driver_note": "Hôm nay chở công nhân của đối tác A"
}
```

> `scheduled_start_at` / `scheduled_end_at`: **RFC3339**. `driver_note` tùy chọn.  
> **Validation:** `scheduled_start_at` phải **sau** thời điểm hiện tại (server UTC). Nếu có `scheduled_end_at`, phải **sau** `scheduled_start_at`.  
> **Một xe — một chuyến tại một thời điểm:** không lên lịch nếu xe đang **`IN_PROGRESS`**, hoặc đã có chuyến **`SCHEDULED_PENDING` / `DRIVER_ACCEPTED`** có khoảng thời gian **giao** với chuyến mới. Khoảng mỗi chuyến: `[scheduled_start_at, scheduled_end_at)`; nếu không có `scheduled_end_at` thì giả định thêm **24 giờ** sau `scheduled_start_at` để kiểm tra trùng (nửa khoảng `[)`).

#### PATCH /api/v1/trips/:id/respond `[NEW 2.2]`

Tài xế **chấp nhận** hoặc **từ chối** chuyến đang **SCHEDULED_PENDING**.

**Role:** DRIVER

**Request:**

```json
{
  "status": "DRIVER_ACCEPTED"
}
```

hoặc từ chối (có thể kèm lý do):

```json
{
  "status": "DRIVER_DECLINED",
  "decline_note": "Bận ca khác"
}
```

#### POST /api/v1/trips/:id/start `[NEW 2.2]`

Tài xế **bắt đầu chạy** sau khi đã **DRIVER_ACCEPTED**. Chuyển trạng thái → **IN_PROGRESS**, ghi `start_time`.

**Role:** DRIVER

**Request (tất cả trường tùy chọn):**

```json
{
  "start_lat": 10.762622,
  "start_lng": 106.660172
}
```

> `start_odo` tùy chọn (app không còn thu ODO lúc đi).  
> **Kiểm tra xe:** phải đã tồn tại **một** bản ghi checklist với đúng `trip_id` (xem **POST /checklists**); nếu chưa → lỗi `complete the vehicle checklist for this trip before starting`.  
> **Cửa sổ khởi hành:** thời điểm server nằm trong **[`scheduled_start_at` − 15 phút, `scheduled_start_at` + 30 phút]** (so với cột `TIMESTAMPTZ`).

#### POST /api/v1/trips/start

Mở chuyến **ad-hoc** (không qua lịch). **App tài xế không gọi** endpoint này.

**Role:** DRIVER

**Request:**

```json
{
  "vehicle_id": "uuid",
  "start_lat": 10.762622,
  "start_lng": 106.660172
}
```

#### PATCH /api/v1/trips/:id/end

Tài xế bấm nút "Kết thúc chuyến" trên app.

**Role:** DRIVER

**Request:**

```json
{
  "end_lat": 10.823099,
  "end_lng": 106.629662
}
```

> `end_odo` tùy chọn (app tài xế **không** gửi ODO lúc về). `end_lat` / `end_lng` tùy chọn.

#### PATCH /api/v1/trips/:id/cancel `[NEW 2.2.8]`

Admin **hủy chuyến** chỉ khi **`SCHEDULED_PENDING`** hoặc **`DRIVER_ACCEPTED`**. Ghi `admin_cancel_reason`, `cancelled_at` (server `NOW()`), chuyển **`CANCELLED`**. **Không** hủy khi **`IN_PROGRESS`**, và **không** hủy khi thời điểm server đang nằm trong **[`scheduled_start_at` − 15 phút, `scheduled_start_at` + 30 phút]** (cửa sổ tài xế vẫn có thể bắt đầu chạy). **Thông báo** gửi cho **tài xế**.

**Role:** ADMIN

**Request (JSON):**

```json
{
  "reason": "Xe hỏng, dời lịch sang ngày khác"
}
```

---

### 🚨 8. Báo cáo Sự cố & Vi phạm (Incidents) `[NEW]`

#### GET /api/v1/incidents

Danh sách sự cố (tai nạn, hỏng hóc, phạt nguội).

**Role:** ALL

**Query (tuỳ chọn):** `?type=TRAFFIC_TICKET&trip_id=uuid`

- **DRIVER:** chỉ sự cố của chính mình; nếu có `trip_id` thì chuyến phải thuộc tài xế.
- **ADMIN:** xem toàn bộ, có thể lọc theo `type` và `trip_id`.

#### POST /api/v1/incidents

Tài xế báo cáo sự cố ngay tại hiện trường.

**Role:** DRIVER

**Request:**

```json
{
  "vehicle_id": "uuid",
  "trip_id": "uuid",
  "type": "ACCIDENT",
  "description": "Quẹt sơn với xe máy tại ngã tư",
  "image_url": "/Media/accident_1.jpg",
  "gps_lat": 10.776889,
  "gps_lng": 106.700806,
  "violation_at": "2026-04-05T14:30:00+07:00"
}
```

> **Enum `type`:** ACCIDENT, BREAKDOWN, TRAFFIC_TICKET  
> **`trip_id` (tùy chọn):** gắn sự cố vào chuyến cụ thể để hiển thị trong chi tiết chuyến; nếu gửi thì chuyến phải thuộc tài xế, `vehicle_id` phải trùng xe của chuyến, và chuyến phải đang **`IN_PROGRESS`**.  
> **`violation_at`** (tùy chọn): thời điểm vi phạm / sự cố — khuyến nghị với **TRAFFIC_TICKET**. Định dạng **RFC3339**, hoặc `YYYY-MM-DD`, hoặc `YYYY-MM-DD HH:MM` (giờ local). Nếu bỏ qua → server dùng thời điểm nhận báo cáo.

> Khi báo sự cố **gắn `trip_id`** (trong chuyến) hoặc khi `type = TRAFFIC_TICKET`, hệ thống tạo **admin notification** trong DB (`notifications.is_admin_notification = true`) và gửi **FCM** đến các thiết bị admin.

---

### 📢 9. Thông báo (Notifications)

Hệ thống có hai loại thông báo:

| Loại                    | `is_admin_notification` | Dành cho                                      |
| ----------------------- | ----------------------- | --------------------------------------------- |
| **Driver notification** | `false`                 | Tài xế (personal + broadcast)                 |
| **Admin notification**  | `true`                  | Admin (system alerts: profile requests, v.v.) |

---

#### GET /api/v1/notifications

Lấy danh sách thông báo của tài xế (`is_admin_notification = false`).

**Role:** DRIVER

**Response mẫu:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Thông báo",
      "body": "Nội dung...",
      "driver_id": "uuid-or-null",
      "is_read": false,
      "is_admin_notification": false,
      "created_at": "2026-04-07T20:00:00Z"
    }
  ]
}
```

---

#### GET /api/v1/notifications/unread-count `[NEW]`

Lấy số lượng thông báo chưa đọc.

**Role:** ALL

**Response:**

```json
{ "success": true, "data": { "unread_count": 3 } }
```

---

#### PATCH /api/v1/notifications/:id/read `[NEW]`

Đánh dấu một thông báo là đã đọc.

**Role:** ALL (DRIVER đọc notification của mình, ADMIN đọc admin notifications)

**Request:** _(không cần body)_

---

#### POST /api/v1/notifications

Admin tạo thông báo gửi cho toàn bộ hoặc 1 tài xế cụ thể.

**Role:** ADMIN

**Request:**

```json
{
  "title": "Thông báo: Thay đổi quy trình giao ca",
  "body": "Từ ngày mai, các anh em chú ý...",
  "driver_id": null
}
```

> Nếu `driver_id` = null → broadcast đến toàn bộ tài xế.

---

#### GET /api/v1/admin/notifications `[NEW]`

Lấy danh sách thông báo hệ thống dành cho Admin (`is_admin_notification = true`).  
Bao gồm: alert khi tài xế gửi yêu cầu cập nhật hồ sơ, kết quả duyệt/từ chối, v.v.

**Role:** ADMIN

**Response:** _(cùng format với `/api/v1/notifications`, có `is_admin_notification: true`)_

---

#### PATCH /api/v1/admin/notifications/:id/read `[NEW]`

Đánh dấu admin notification là đã đọc.

**Role:** ADMIN

---

#### GET /api/v1/notifications/stream `[NEW]` — SSE

Kết nối **Server-Sent Events** để nhận thông báo real-time.

**Role:** ALL (Authenticated)

**Headers yêu cầu:**

```
Authorization: Bearer <access_token>
Accept: text/event-stream
Cache-Control: no-cache
```

**Luồng hoạt động:**

1. Client kết nối, server trả về `Content-Type: text/event-stream`.
2. Server gửi event ngay khi có thông báo mới:
   - **Driver**: nhận notification `is_admin_notification = false` targeting driver ID hoặc broadcast
   - **Admin**: nhận notification `is_admin_notification = true`
3. Server gửi **heartbeat** mỗi 25 giây để giữ kết nối qua proxy: `: heartbeat\n\n`
4. Client **tự reconnect** khi mất kết nối (nên delay 3–5 giây).

**Event format:**

```
data: {"id":"uuid","title":"Tiêu đề","body":"Nội dung","is_admin_notification":false,"is_read":false,"created_at":"2026-04-07T20:00:00Z"}\n\n
```

**Connection acknowledgment:**

```
data: {"type":"connected"}\n\n
```

---

### 📤 10. Hệ thống Upload Files (Upload)

#### POST /api/v1/upload

Upload file hình ảnh/tài liệu lên server.

**Role:** ALL

**Content-Type:** multipart/form-data  
**Field:** `file` (Max 10MB, cho phép jpg, png, pdf)

**Query param (tùy chọn):** `?folder=<subfolder>`

| Subfolder        | Mục đích                                          | URL kết quả                    |
| ---------------- | ------------------------------------------------- | ------------------------------ |
| _(không có)_     | Thư mục gốc (backward compat)                     | `/Media/<file>`                |
| `avatar`         | Ảnh đại diện                                      | `/Media/avatar/<file>`         |
| `fuel-reports`   | Ảnh hóa đơn xăng + ODO                            | `/Media/fuel-reports/<file>`   |
| `receipts`       | Biên lai chung                                    | `/Media/receipts/<file>`       |
| `contracts`      | Hợp đồng PDF                                      | `/Media/contracts/<file>`      |
| `incidents`      | Ảnh sự cố                                         | `/Media/incidents/<file>`      |
| `payslips`       | Phiếu lương PDF                                   | `/Media/payslips/<file>`       |
| `profile-proofs` | Ảnh minh chứng cập nhật hồ sơ (CCCD/GPLX/địa chỉ) | `/Media/profile-proofs/<file>` |
| `vehicles`       | Ảnh phương tiện (gán vào `vehicles.image_url`)    | `/Media/vehicles/<file>`       |

**Query bắt buộc với `folder=vehicles`:** `vehicle_id=<UUID xe>` — tên file lưu là `{vehicle_id}.{ext}`, ghi đè lần sau; xóa file cũ cùng UUID khác đuôi (đổi jpg→png) để không đầy `Media`.

**Quy tắc đặt tên file:**

| Folder          | Tên file                             | Ghi chú                                           |
| --------------- | ------------------------------------ | ------------------------------------------------- |
| `avatar`        | `{userID}.{ext}`                     | Overwrite file cũ khi update lại avatar           |
| `vehicles`      | `{vehicle_id}.{ext}`                 | Bắt buộc `?vehicle_id=`; overwrite, một file / xe |
| Các folder khác | `{timestamp}_{uuid8}_{originalName}` | Unique mỗi lần upload                             |

**Response:**

```json
{
  "success": true,
  "data": {
    "file_url": "/Media/avatar/77acd865-f445-4cdd-9a8d-6587f6552d77.jpg",
    "file_name": "image.jpg",
    "file_size": 245678
  }
}
```

#### GET /Media/:subfolder/:filename

Truy cập file public đã upload (static files).

> Ví dụ: `GET http://localhost:8080/Media/avatar/1712345678_abc.jpg`

---

### ❤️ 11. Tiện ích Hệ thống (System)

#### GET /health

Kiểm tra trạng thái server hoạt động (Ping/Pong).

**Role:** PUBLIC

---

### ⛽ 12. Giá Xăng Dầu (Fuel Prices)

#### GET /api/v1/prices

Lấy giá xăng dầu từ cả Petrolimex và PVOil.

**Role:** PUBLIC

**Response:**

```json
{
  "success": true,
  "data": {
    "petrolimex": {
      "company": "Petrolimex",
      "updated_at": "2026-04-07T00:00:00Z",
      "prices": [
        {
          "name": "Xăng RON 95-V",
          "price_zone1": "25.940",
          "price_zone2": "26.440"
        },
        {
          "name": "Xăng RON 95-III",
          "price_zone1": "24.910",
          "price_zone2": "25.390"
        },
        {
          "name": "Xăng E5 RON 92-II",
          "price_zone1": "24.020",
          "price_zone2": "24.480"
        },
        {
          "name": "Dầu DO 0.05S-II",
          "price_zone1": "20.820",
          "price_zone2": "21.230"
        }
      ]
    },
    "pvoil": {
      "company": "PVOil",
      "updated_at": "Giá điều chỉnh từ 15h00 ngày 07/04/2026",
      "prices": [
        { "name": "Xăng RON 95-V", "price_zone1": "25.920" },
        { "name": "Xăng RON 95-III", "price_zone1": "24.890" },
        { "name": "Xăng E5 RON 92-II", "price_zone1": "24.000" },
        { "name": "Dầu DO 0.05S", "price_zone1": "20.800" }
      ]
    }
  }
}
```

#### GET /api/v1/prices/petrolimex

Lấy giá xăng dầu từ Petrolimex (Zone 1 + Zone 2).

**Role:** PUBLIC

#### GET /api/v1/prices/pvoil

Lấy giá xăng dầu từ PVOil (Zone 1).

**Role:** PUBLIC

---

## Setup

### 1. Chạy migrations

```bash
make migrate
```

### 2. Build và chạy

```bash
make build
./bin/ch-app
```

### 3. Test API

```bash
# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"admin@gmail.com","password":"admin"}'

# Get me
curl http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer <access_token>"

# Refresh token
curl -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'
```

---

## Config (config.yaml)

```yaml
jwt:
  secret: cuchumsecretkey
  access_expire_hours: 6
  refresh_expire_days: 30

upload:
  path: Media
  max_size: 10485760
```

## Admin mặc định

- **Phone:** `0987654321`
- **Email:** `admin@gmail.com`
- **Password:** `admin`

---

**Version:** 2.3.4

### Changelog

| Version | Thay đổi                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.3.4   | **Trips:** thêm `cancelled_at` để hiển thị thời điểm hủy trong chi tiết chuyến. **Incidents:** hỗ trợ `trip_id` để gắn sự cố theo chuyến và lọc `GET /incidents?trip_id=`. Khi báo sự cố gắn chuyến (`trip_id`) hoặc **`TRAFFIC_TICKET`**: tạo thông báo admin trong DB + gửi FCM đến admin. **App:** hiển thị mục **Vi phạm** trên chi tiết chuyến (Driver/Admin).                                                                                                                                                                   |
| 2.3.3   | **App Trips:** thêm nút **Báo cáo sự cố** ngay trong màn chi tiết chuyến khi trạng thái **IN_PROGRESS**. **Fuel report:** app không còn thu `fuel_purchased_at`; backend tự gán thời điểm mua = `now` nếu client không gửi.                                                                                                                                                                                                                                                                                                           |
| 2.3.2   | **App Trips:** màn chi tiết chuyến hiển thị bản đồ (flutter_map) dùng các trường tọa độ `start_lat`, `start_lng`, `end_lat`, `end_lng`. **Tài liệu API:** làm rõ các trường tọa độ này trong **GET `/trips`** và **GET `/trips/:id`**.                                                                                                                                                                                                                                                                                                |
| 2.3.1   | **Chuyến lên lịch:** `start_time` chỉ có sau khi tài xế **POST `/trips/:id/start`** (trước đây cột dùng `DEFAULT CURRENT_TIMESTAMP` nên nhìn như đã “bắt đầu chạy” ngay khi admin tạo / tài xế nhận). Migration **`018_trip_start_time_scheduled_null.sql`**: bỏ default, gán `NULL` cho chuyến có lịch còn **pending / accepted / declined / cancelled**; **POST `/trips/schedule`** insert `start_time = NULL` rõ ràng.                                                                                                             |
| 2.3.0   | **Tài xế:** **POST `/trips/:id/start`** bắt buộc đã có **checklist** cho chuyến; cửa sổ bắt đầu **[−15 phút, +30 phút]** quanh `scheduled_start_at`. **PATCH `/trips/:id/cancel`:** không hủy trong cùng cửa sổ **[−15, +30]**. **POST `/fuel-reports`** (có `trip_id`): cùng cửa sổ **[−15, +30]** cho `now` và `fuel_purchased_at`. **Lịch nền** trong `cmd/api` (mỗi phút): nhắc **T−10 / đúng giờ / +10 phút** + **tự hủy** **`DRIVER_ACCEPTED`** sau **+30 phút** (FCM + in-app); migration **`017_trip_departure_notify.sql`**. |
| 2.2.10  | **POST `/fuel-reports`** với **`trip_id`:** chỉ chấp nhận khi **server `now`** và (nếu có) **`fuel_purchased_at`** đều nằm trong **`scheduled_start_at ± 15 phút`**; chuyến phải có `scheduled_start_at`. Báo không gắn chuyến không đổi.                                                                                                                                                                                                                                                                                             |
| 2.2.9   | **POST `/trips/schedule`:** kiểm tra xe không trùng lịch (không `IN_PROGRESS` + không giao khoảng `[start,end)` với chuyến pending/accepted). **POST `/trips/:id/start`:** chỉ trong **`scheduled_start_at ± 15 phút`**. **PATCH `/trips/:id/cancel`:** không hủy `IN_PROGRESS`; không hủy trong cửa sổ **±15 phút** quanh `scheduled_start_at`.                                                                                                                                                                                      |
| 2.2.8   | **PATCH `/trips/:id/cancel`:** admin hủy chuyến + lý do + thông báo tài xế; cột `admin_cancel_reason` (migration `016_admin_cancel_reason.sql`). **Thông báo admin:** khi tài xế nhận/từ chối chuyến, bắt đầu chạy, kết thúc; khi có checklist / báo cáo xăng gắn chuyến. **GET checklists/fuel-reports** + `trip_id`: DRIVER chỉ chuyến của mình.                                                                                                                                                                                    |
| 2.2.7   | **POST `/checklists`:** tối đa **một bản ghi / chuyến** (`trip_id`); bỏ upsert theo `(driver, xe, ngày)`. **UI admin:** hiển thị giờ kiểm tra theo `created_at`. Migration `015_checklist_one_per_trip.sql`.                                                                                                                                                                                                                                                                                                                          |
| 2.2.6   | **GET `/checklists`**, **GET `/fuel-reports`:** thêm lọc `?trip_id=`. **POST fuel:** `fuel_purchased_at` không được trong tương lai. **PATCH `/trips/:id/end`:** `end_odo` tùy chọn (app không bắt buộc). Admin: checklist & xăng xem theo **từng chuyến** (chi tiết chuyến).                                                                                                                                                                                                                                                         |
| 2.2.5   | **GET `/trips/:id`:** chi tiết chuyến + `license_plate`, `driver_name`. **Fuel:** cột & body `fuel_purchased_at` (RFC3339), migration `014_fuel_purchased_at.sql`. App: luồng **Chuyến của bạn → chi tiết → checklist / xăng**.                                                                                                                                                                                                                                                                                                       |
| 2.2.4   | **App tài xế:** không còn chạy ad-hoc; bắt đầu chuyến theo lịch **không bắt buộc** `start_odo`. **Báo cáo xăng:** chỉ cần `total_cost` + `receipt_image_url` (ODO/lít/ảnh ODO tùy chọn trên API).                                                                                                                                                                                                                                                                                                                                     |
| 2.2.3   | **POST `/checklists`:** chỉ cho phép khi chuyến **`DRIVER_ACCEPTED`** hoặc **`IN_PROGRESS`** (tài xế đã nhận lịch).                                                                                                                                                                                                                                                                                                                                                                                                                   |
| 2.2.2   | **DELETE `/vehicles/:id`:** không cho xóa nếu còn chuyến `IN_PROGRESS` hoặc chuyến lên lịch `SCHEDULED_PENDING` / `DRIVER_ACCEPTED` mà chưa quá `scheduled_end_at` (UTC). Upload ảnh xe: `?vehicle_id=` + tên file `{vehicle_id}.{ext}`.                                                                                                                                                                                                                                                                                              |
| 2.2.1   | **Vehicles:** `image_url` + upload folder `vehicles`; biển số = `license_plate`. Migration `013_vehicle_image_url.sql`.                                                                                                                                                                                                                                                                                                                                                                                                               |
| 2.2.0   | **Vehicles:** ADMIN POST/PATCH/DELETE xe. **Trips:** lịch trước (`/trips/schedule`), tài xế `respond` / `/:id/start`, trường lịch + `driver_note`; GET lọc `vehicle_id`. **Fuel/Checklist:** `trip_id` tùy chọn. **Profile / tạo user:** `license_number` (GPLX). **Incidents:** `violation_at`. Migration `012_scheduled_trips_license_trip_links.sql`.                                                                                                                                                                              |
| 2.1.3   | GET `/payslips` trả thêm `status`, `note`, `confirmed_at`; App: màn Bảng lương (DRIVER + ADMIN), xem PDF in-app, xác nhận/khiếu nại; kiểm tra sinh trắc học khi bật trong Cài đặt                                                                                                                                                                                                                                                                                                                                                     |
| 2.1.2   | GET `/contracts`: DRIVER xem hợp đồng của mình (không `driver_id`); ADMIN vẫn bắt buộc `driver_id`                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 2.1.1   | GET `/contracts` chỉ ADMIN, bắt buộc `driver_id`; tài xế không truy cập danh sách hợp đồng qua API/app                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 2.1.0   | Thêm SSE real-time notifications; Admin notifications; Mark as read; Avatar bypass queue; CCCD 12 chữ số; CreateUser với profile fields; Upload subfolder + avatar UUID naming                                                                                                                                                                                                                                                                                                                                                        |
| 2.0.0   | DMS & Operations Sync (Trips, Checklists, Incidents, Notifications, Biometric Auth, Profile Update Queue)                                                                                                                                                                                                                                                                                                                                                                                                                             |
