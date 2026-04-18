package utils

import (
	"net/http"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

// Response represents a standard API response
type Response struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// SuccessResponse sends a successful response
func SuccessResponse(c *gin.Context, statusCode int, message string, data interface{}) {
	c.JSON(statusCode, Response{
		Success: true,
		Message: message,
		Data:    data,
	})
}

// ErrorResponse sends an error response
func ErrorResponse(c *gin.Context, statusCode int, message string) {
	c.JSON(statusCode, Response{
		Success: false,
		Error:   message,
	})
}

// ValidationErrorResponse sends a validation error response with user-friendly message
func ValidationErrorResponse(c *gin.Context, rawError string) {
	message := ParseValidationError(rawError)
	c.JSON(http.StatusBadRequest, Response{
		Success: false,
		Error:   message,
	})
}

// ParseValidationError converts Go validator errors to user-friendly messages
func ParseValidationError(err string) string {
	// Pattern: Key: 'StructName.FieldName' Error:Field validation for 'FieldName' failed on the 'tag' tag
	re := regexp.MustCompile(`Field validation for '(\w+)' failed on the '(\w+)' tag`)
	matches := re.FindStringSubmatch(err)

	if len(matches) == 3 {
		field := ToSnakeCase(matches[1])
		tag := matches[2]
		return FormatValidationMessage(field, tag)
	}

	// Return cleaned error if pattern doesn't match
	return CleanErrorMessage(err)
}

// FormatValidationMessage creates user-friendly validation messages
func FormatValidationMessage(field, tag string) string {
	fieldName := FormatFieldName(field)

	switch tag {
	case "required":
		return fieldName + " is required"
	case "email":
		return fieldName + " must be a valid email"
	case "min":
		return fieldName + " is too short"
	case "max":
		return fieldName + " is too long"
	case "gte":
		return fieldName + " must be greater than or equal to minimum"
	case "gt":
		return fieldName + " must be greater than zero"
	case "lte":
		return fieldName + " must be less than or equal to maximum"
	case "oneof":
		return fieldName + " has invalid value"
	case "uuid":
		return fieldName + " must be a valid UUID"
	default:
		return fieldName + " is invalid"
	}
}

// FormatFieldName converts snake_case to readable format
func FormatFieldName(field string) string {
	// Common field name mappings
	names := map[string]string{
		"identifier":        "Phone number or email",
		"phone_number":      "Phone number",
		"password":          "Password",
		"full_name":         "Full name",
		"email":             "Email",
		"role":              "Role",
		"status":            "Status",
		"driver_id":         "Driver ID",
		"vehicle_id":        "Vehicle ID",
		"contract_number":   "Contract number",
		"file_url":          "File URL",
		"start_date":        "Start date",
		"end_date":          "End date",
		"salary_month":      "Salary month",
		"report_date":       "Report date",
		"total_cost":        "Total cost",
		"total_trips":       "Total trips",
		"receipt_image_url": "Receipt image URL",
		"admin_note":        "Admin note",
		"refresh_token":     "Refresh token",
	}

	if name, ok := names[field]; ok {
		return name
	}

	// Default: capitalize and replace underscores
	return strings.Title(strings.ReplaceAll(field, "_", " "))
}

// ToSnakeCase converts CamelCase to snake_case
func ToSnakeCase(s string) string {
	var result strings.Builder
	for i, r := range s {
		if i > 0 && r >= 'A' && r <= 'Z' {
			result.WriteByte('_')
		}
		result.WriteRune(r)
	}
	return strings.ToLower(result.String())
}

// CleanErrorMessage removes technical details from error messages
func CleanErrorMessage(err string) string {
	// Remove "Key: 'xxx' Error:" prefix
	if idx := strings.Index(err, "Error:"); idx != -1 {
		err = strings.TrimSpace(err[idx+6:])
	}
	return err
}
