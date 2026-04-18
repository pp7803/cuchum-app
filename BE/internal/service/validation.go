package service

import "errors"

// validateCitizenID checks that a citizen ID is exactly 12 numeric digits.
// Shared across user_service and profile_service.
func validateCitizenID(id string) error {
	if len(id) != 12 {
		return errors.New("CCCD phải có đúng 12 chữ số")
	}
	for _, c := range id {
		if c < '0' || c > '9' {
			return errors.New("CCCD chỉ được chứa chữ số")
		}
	}
	return nil
}
