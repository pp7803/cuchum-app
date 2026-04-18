-- Ảnh minh chứng kèm yêu cầu cập nhật hồ sơ (DRIVER → PUT /profile)
ALTER TABLE profile_update_requests
    ADD COLUMN IF NOT EXISTS proof_image_url TEXT;

COMMENT ON COLUMN profile_update_requests.proof_image_url IS 'URL ảnh minh chứng (upload folder profile-proofs), tùy chọn';
