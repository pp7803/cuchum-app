# Hướng dẫn Kết nối PostgreSQL Từ Xa trên aaPanel

Tài liệu này hướng dẫn cách cấu hình máy chủ aaPanel và thiết lập kết nối từ xa đến cơ sở dữ liệu PostgreSQL cho dự án.

## 1. Thông tin Máy chủ & Database
* **Host / IP Address:** `14.225.212.86`
* **Port:** `5432`
* **Database Name:** `cuchum_db`
* **Username:** `cuchum_admin`
* **Password:** `[Mật_khẩu_đã_thiết_lập]`

---

## 2. Cấu hình trên aaPanel (Bắt buộc)
Mặc định, PostgreSQL chỉ cho phép kết nối nội bộ (localhost). Để mở kết nối từ xa, cần thực hiện các bước sau trên giao diện aaPanel:

### 2.1. Cấu hình PostgreSQL cho Remote Access

#### Bước 2.1: Cho phép kết nối từ xa (postgresql.conf)
Mở file cấu hình `/www/server/pgsql/data/postgresql.conf` và tìm dòng `listen_addresses`, sửa thành:
```
listen_addresses = '*'
```

#### Bước 2.2: Cấp quyền đăng nhập từ xa (pg_hba.conf)
Cùng trong thư mục `/www/server/pgsql/data/`, mở file `pg_hba.conf`.

Kéo xuống dòng cuối cùng của file và thêm cấu hình sau để cho phép xác thực bằng mật khẩu từ bất kỳ địa chỉ mạng nào:

```
host    all             all             0.0.0.0/0               md5
```

**Lưu ý:** Nếu PostgreSQL trên server đang dùng chuẩn mã hóa mới hơn, hãy thay `md5` bằng `scram-sha-256`.

#### Bước 2.3: Restart Service và Kiểm tra Firewall
Ngay trên cửa sổ Settings của PostgreSQL trong aaPanel, chuyển sang tab **Service** và nhấn **Restart** để áp dụng toàn bộ cấu hình mới.

Kiểm tra lại tab **Security (Firewall)** trên aaPanel, đảm bảo port **5432** đang ở trạng thái **Listening** và **Allow**. 

**Quan trọng:** Nếu dùng VPS của AWS/Google Cloud/DigitalOcean, cần đảm bảo Firewall trên trang quản trị của nhà cung cấp cũng đã mở port Inbound **5432**.