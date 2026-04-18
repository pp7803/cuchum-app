package handler

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/config"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/utils"
)

// allowedFolders defines valid upload subfolders
var allowedFolders = map[string]bool{
	"":               true, // root Media/ (backward compat)
	"avatar":         true, // profile avatars
	"fuel-reports":   true, // fuel receipt + ODO images
	"receipts":       true, // general receipts
	"contracts":      true, // contract PDFs
	"incidents":      true, // incident evidence photos
	"payslips":       true, // payslip PDFs
	"profile-proofs": true, // ảnh minh chứng cập nhật hồ sơ
	"vehicles":       true, // ảnh phương tiện
}

type UploadHandler struct {
	config *config.UploadConfig
}

func NewUploadHandler(cfg *config.UploadConfig) *UploadHandler {
	uploadPath := cfg.Path
	if uploadPath == "" {
		uploadPath = "Media"
	}
	if err := os.MkdirAll(uploadPath, 0o755); err != nil {
		log.Printf("upload init: failed to create base upload directory %s: %v", uploadPath, err)
	}
	return &UploadHandler{config: cfg}
}

// Upload handles file uploads with optional subfolder routing.
// @route POST /api/v1/upload?folder=<subfolder>&vehicle_id=<uuid> (vehicle_id required when folder=vehicles)
// Valid folders: avatar, fuel-reports, receipts, contracts, incidents, payslips, profile-proofs, vehicles (or empty for root)
func (h *UploadHandler) Upload(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "No file uploaded")
		return
	}

	// ── Validate file size ───────────────────────────────────────────────────
	if file.Size > h.config.MaxSize {
		utils.ErrorResponse(c, http.StatusBadRequest,
			fmt.Sprintf("File size exceeds limit of %d bytes", h.config.MaxSize))
		return
	}

	// ── Validate file type ───────────────────────────────────────────────────
	fileExt := strings.ToLower(filepath.Ext(file.Filename))
	contentType := file.Header.Get("Content-Type")

	allowed := false
	for _, allowedType := range h.config.AllowedTypes {
		if contentType == allowedType ||
			(allowedType == "image/jpeg" && (fileExt == ".jpg" || fileExt == ".jpeg")) ||
			(allowedType == "image/png" && fileExt == ".png") ||
			(allowedType == "application/pdf" && fileExt == ".pdf") {
			allowed = true
			break
		}
	}
	if !allowed {
		utils.ErrorResponse(c, http.StatusBadRequest, "File type not allowed")
		return
	}

	// ── Validate folder param ────────────────────────────────────────────────
	folder := strings.TrimSpace(c.Query("folder"))
	if !allowedFolders[folder] {
		utils.ErrorResponse(c, http.StatusBadRequest,
			fmt.Sprintf("Invalid folder '%s'. Allowed: avatar, fuel-reports, receipts, contracts, incidents, payslips, profile-proofs, vehicles", folder))
		return
	}

	// ── Build upload directory ───────────────────────────────────────────────
	baseDir := h.config.Path
	if baseDir == "" {
		baseDir = "Media"
	}

	uploadDir := baseDir
	if folder != "" {
		uploadDir = filepath.Join(baseDir, folder)
		if err := os.MkdirAll(uploadDir, 0o755); err != nil {
			log.Printf("upload: failed to create directory %s: %v", uploadDir, err)
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to create upload directory")
			return
		}
	}

	// ── Determine filename ───────────────────────────────────────────────────
	// For avatar: name = {userID}.{ext} so re-uploading overwrites the old file.
	// For vehicles: name = {vehicle_id}.{ext} when ?vehicle_id= is set (overwrite; remove other ext for same id).
	// For other folders: timestamp-based unique name.
	var uniqueName string
	switch folder {
	case "avatar":
		userIDVal, exists := c.Get("user_id")
		if exists && userIDVal != nil {
			uniqueName = fmt.Sprintf("%s%s", userIDVal.(uuid.UUID).String(), fileExt)
		} else {
			uniqueName = fmt.Sprintf("%s%s", uuid.New().String(), fileExt)
		}
	case "vehicles":
		vid := strings.TrimSpace(c.Query("vehicle_id"))
		if vid == "" {
			utils.ErrorResponse(c, http.StatusBadRequest,
				"folder=vehicles requires query vehicle_id (UUID of the vehicle)")
			return
		}
		vidUUID, err := uuid.Parse(vid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "invalid vehicle_id (must be a UUID)")
			return
		}
		vidStr := vidUUID.String()
		// Drop previous files for this vehicle (e.g. .jpg then .png) so Media does not accumulate.
		matches, _ := filepath.Glob(filepath.Join(uploadDir, vidStr+".*"))
		for _, old := range matches {
			_ = os.Remove(old)
		}
		uniqueName = vidStr + fileExt
	default:
		uniqueName = fmt.Sprintf("%d_%s_%s",
			time.Now().Unix(),
			uuid.New().String()[:8],
			filepath.Base(file.Filename),
		)
	}

	// ── Save file ────────────────────────────────────────────────────────────
	filePath := filepath.Join(uploadDir, uniqueName)

	src, err := file.Open()
	if err != nil {
		log.Printf("upload: failed to open multipart file %s: %v", file.Filename, err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to open uploaded file")
		return
	}
	defer src.Close()

	dst, err := os.Create(filePath)
	if err != nil {
		log.Printf("upload: failed to create destination file %s: %v", filePath, err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to save file")
		return
	}
	defer dst.Close()

	if _, err = io.Copy(dst, src); err != nil {
		log.Printf("upload: failed to copy file to %s: %v", filePath, err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to save file")
		return
	}

	// ── Build public URL ─────────────────────────────────────────────────────
	// URL format: /Media/<uniqueName> or /Media/<folder>/<uniqueName>
	var fileURL string
	if folder != "" {
		fileURL = fmt.Sprintf("/%s/%s/%s", baseDir, folder, uniqueName)
	} else {
		fileURL = fmt.Sprintf("/%s/%s", baseDir, uniqueName)
	}

	utils.SuccessResponse(c, http.StatusOK, "File uploaded successfully", models.UploadResponse{
		FileURL:  fileURL,
		FileName: file.Filename,
		FileSize: file.Size,
	})
}

// GetUploadPath returns the base upload path from config
func (h *UploadHandler) GetUploadPath() string {
	if h.config.Path == "" {
		return "Media"
	}
	return h.config.Path
}
