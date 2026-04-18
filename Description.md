# CucHum App - Mô tả dự án (Cập nhật)

CucHum App (CH App) là hệ thống quản lý vận hành đội xe và hồ sơ nhân sự nội bộ, tập trung cho đội tài xế và bộ phận điều hành. Mục tiêu chính là số hóa quy trình vận hành hằng ngày, minh bạch dữ liệu chi phí và nâng cao tốc độ phản hồi giữa tài xế với quản lý.

## 1. Tổng quan

- Tên dự án: CucHum App
- Phạm vi: Ứng dụng Flutter đa nền tảng (Android, iOS, macOS, Web) + Backend API Golang
- Đối tượng sử dụng:
  - Tài xế
  - Điều hành/Admin
- Trạng thái: Đang vận hành và tiếp tục cập nhật tính năng

## 2. Bài toán nghiệp vụ giải quyết

- Tập trung hóa dữ liệu nhân sự, tài xế, phương tiện, chuyến đi và báo cáo nhiên liệu.
- Giảm báo cáo thủ công qua tin nhắn rời rạc.
- Chuẩn hóa quy trình kiểm tra xe, báo cáo sự cố, đối soát chi phí.
- Số hóa tài liệu hành chính (hợp đồng, bảng lương, xác nhận/không xác nhận).
- Tăng khả năng điều hành theo thời gian thực bằng thông báo và đồng bộ dữ liệu.

## 3. Tính năng chính

### 3.1 Cho tài xế

- Đăng nhập tài khoản bằng mật khẩu hoặc sinh trắc học.
- Xem hồ sơ và gửi yêu cầu cập nhật hồ sơ chờ Admin duyệt.
- Nhận chuyến theo lịch, phản hồi nhận/từ chối, bắt đầu và kết thúc chuyến đúng cửa sổ thời gian nghiệp vụ.
- Xem chi tiết chuyến đi kèm bản đồ hành trình (GPS tọa độ đầu/cuối).
- Gửi checklist an toàn xe theo từng chuyến trước khi bắt đầu chạy.
- Báo cáo nhiên liệu với tối thiểu tổng tiền và ảnh hóa đơn (ODO/lít là tùy chọn).
- Báo cáo sự cố/vi phạm trong chuyến và nhận thông báo từ công ty theo thời gian thực.
- Xem hợp đồng, bảng lương, xác nhận hoặc khiếu nại ngay trên ứng dụng.

### 3.2 Cho điều hành/Admin

- Quản lý tài khoản tài xế và trạng thái hoạt động.
- Duyệt/từ chối yêu cầu cập nhật hồ sơ tài xế.
- Lên lịch chuyến, theo dõi trạng thái chuyến và hủy chuyến theo quy tắc nghiệp vụ.
- Quản lý phương tiện, bảo trì và kiểm soát trùng lịch sử dụng xe.
- Theo dõi checklist, báo cáo nhiên liệu, sự cố và xuất báo cáo phục vụ đối soát.
- Gửi thông báo broadcast hoặc theo từng tài xế; theo dõi trạng thái đã đọc/chưa đọc.
- Nhận admin notifications qua push và SSE khi phát sinh sự kiện quan trọng.

## 4. Công nghệ sử dụng

### 4.1 Mobile app

- Flutter + Dart
- State management: Provider
- Bản đồ: flutter_map + latlong2
- Định vị: geolocator
- Xác thực cục bộ: local_auth
- Push notification: firebase_core + firebase_messaging + flutter_local_notifications
- Upload media: image_picker, file_picker

### 4.2 Backend

- Golang + Gin
- PostgreSQL + migrations SQL
- Phân lớp rõ ràng: handler, service, repository, middleware
- Xác thực JWT (access token, refresh token, biometric token)
- Realtime notification stream bằng Server-Sent Events (SSE)
- Lưu media theo thư mục chức năng: avatar, contracts, payslips, fuel-reports, incidents, vehicles

### 4.3 Notification pipeline (Firebase/APNs)

- Ứng dụng đăng ký device token về backend theo user và role.
- Backend lưu token và fan-out thông báo theo đúng đối tượng nhận.
- Firebase Cloud Messaging (FCM) là kênh push chính cho Android/iOS/macOS.
- Trên thiết bị Apple, push đi qua APNs thông qua tích hợp FCM (bridge FCM ↔ APNs).
- Ứng dụng đồng thời nhận realtime in-app qua SSE endpoint `/api/v1/notifications/stream`.

### 4.4 Hạ tầng triển khai

- Nginx reverse proxy backend trên cổng 8080.
- systemd quản lý tiến trình backend trên Linux.
- Cloudflare/WAF kết hợp User-Agent chuẩn hóa để tăng khả năng nhận diện request hợp lệ.

## 5. Vận hành và bảo mật

- Header bắt buộc cho API protected: `Authorization: Bearer <access_token>`.
- Access token và refresh token phục vụ đăng nhập phiên làm việc chuẩn.
- Biometric token hỗ trợ đăng nhập nhanh, thời hạn dài trên thiết bị đã kích hoạt.
- Phân quyền theo vai trò (PUBLIC, DRIVER, ADMIN) áp dụng tại middleware.
- Upload file có giới hạn dung lượng và whitelist định dạng để giảm rủi ro.

## 6. Cập nhật nổi bật gần đây

- Bổ sung `cancelled_at` trong chi tiết chuyến để hiển thị rõ thời điểm hủy.
- Hỗ trợ gắn sự cố theo `trip_id` và lọc dữ liệu sự cố theo chuyến.
- Đồng bộ thông báo admin cho các sự kiện quan trọng (profile requests, incidents, vận hành chuyến).
- Chuẩn hóa luồng checklist bắt buộc trước khi tài xế bắt đầu chuyến theo lịch.
- Hoàn thiện luồng push notification đa nền tảng với FCM/APNs và realtime SSE.

## 7. Mô tả ngắn để upload TestFlight (English)

CucHum App is an internal fleet operations app for drivers and dispatchers. This build focuses on scheduled trip operations, GPS trip tracking, fuel receipt uploads, profile update approval workflow, and reliable push notifications on iOS/macOS via FCM and APNs.

---

Cập nhật lần cuối: 2026-04-18
