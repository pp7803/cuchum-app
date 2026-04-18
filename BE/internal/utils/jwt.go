package utils

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// JWTClaims represents the JWT claims
type JWTClaims struct {
	UserID uuid.UUID `json:"user_id"`
	Role   string    `json:"role"`
	jwt.RegisteredClaims
}

// JWTUtil handles JWT token generation and validation
type JWTUtil struct {
	secret            []byte
	accessExpireHours int
	refreshExpireDays int
}

// NewJWTUtil creates a new JWT utility
func NewJWTUtil(secret string, accessExpireHours, refreshExpireDays int) *JWTUtil {
	return &JWTUtil{
		secret:            []byte(secret),
		accessExpireHours: accessExpireHours,
		refreshExpireDays: refreshExpireDays,
	}
}

// GenerateAccessToken generates a new JWT access token
func (j *JWTUtil) GenerateAccessToken(userID uuid.UUID, role string) (string, error) {
	claims := JWTClaims{
		UserID: userID,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour * time.Duration(j.accessExpireHours))),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(j.secret)
}

// GenerateRefreshToken generates a new refresh token string and expiration
func (j *JWTUtil) GenerateRefreshToken() (string, time.Time, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", time.Time{}, err
	}
	token := hex.EncodeToString(bytes)
	expiresAt := time.Now().Add(time.Hour * 24 * time.Duration(j.refreshExpireDays))
	return token, expiresAt, nil
}

// ValidateToken validates and parses a JWT token
func (j *JWTUtil) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("invalid signing method")
		}
		return j.secret, nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// GenerateBiometricToken generates a long-lived opaque token for biometric authentication (1 year)
func (j *JWTUtil) GenerateBiometricToken() (string, time.Time, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", time.Time{}, err
	}
	token := hex.EncodeToString(bytes)
	expiresAt := time.Now().Add(365 * 24 * time.Hour) // 1 year
	return token, expiresAt, nil
}

// GetRefreshExpireDays returns refresh token expiration in days
func (j *JWTUtil) GetRefreshExpireDays() int {
	return j.refreshExpireDays
}
