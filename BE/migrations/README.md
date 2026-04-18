# Database Migrations

Thu muc chua cac file migration cho database.

## Cau truc Migrations

- `000_init_schema.sql` - Schema chinh (tables, indexes)
- `001_add_admin_user.sql` - User admin mac dinh
- `002_add_password_reset_otp.sql` - Bang OTP cho reset mat khau
- `003_add_new_modules.sql` - Checklists, Trips, Incidents, Notifications
- `004_add_device_tokens.sql` - FCM device tokens
- `005_add_biometric_tokens.sql` - Token dang nhap sinh trac hoc (1 token/user)

## Su dung

### Chay tat ca migrations

```bash
make migrate
```

Migration an toan, khong mat du lieu:

- Su dung `CREATE TABLE IF NOT EXISTS`
- Su dung `CREATE INDEX IF NOT EXISTS`
- Su dung `ON CONFLICT DO NOTHING` cho insert

### Kiem tra ket noi

```bash
make migrate-check
```

### Ket noi database shell

```bash
make db-shell
```

### Xem danh sach tables

```bash
make db-list-tables
```

### Backup database

```bash
make db-backup
```

### Reset database (XOA TAT CA)

```bash
make db-reset
```

## Them migration moi

1. Tao file moi: `002_xxx.sql`
2. Su dung `IF NOT EXISTS` de tranh loi
3. Chay: `make migrate`

## Admin mac dinh

- Phone: `admin`
- Password: `admin`
