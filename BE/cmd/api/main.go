package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tsnn/ch-app/internal/config"
	"github.com/tsnn/ch-app/internal/handler"
	"github.com/tsnn/ch-app/internal/middleware"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
	"github.com/tsnn/ch-app/pkg/database"
)

func main() {
	cfg, err := config.Load("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	db, err := database.New(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	log.Println("Connected to database successfully")

	// Initialize Firebase Cloud Messaging
	fcmService, err := service.InitFCM("firebase/service-account.json")
	if err != nil {
		log.Printf("Warning: FCM initialization failed: %v", err)
		log.Println("Push notifications will be disabled")
	}

	jwtUtil := utils.NewJWTUtil(cfg.JWT.Secret, cfg.JWT.AccessExpireHours, cfg.JWT.RefreshExpireDays)

	// Initialize repositories
	userRepo := repository.NewUserRepository(db.Pool)
	profileRepo := repository.NewProfileRepository(db.Pool)
	profileUpdateRequestRepo := repository.NewProfileUpdateRequestRepository(db.Pool)
	contractRepo := repository.NewContractRepository(db.Pool)
	payslipRepo := repository.NewPayslipRepository(db.Pool)
	vehicleRepo := repository.NewVehicleRepository(db.Pool)
	fuelReportRepo := repository.NewFuelReportRepository(db.Pool)
	tripReportRepo := repository.NewTripReportRepository(db.Pool)
	refreshTokenRepo := repository.NewRefreshTokenRepository(db.Pool)
	biometricTokenRepo := repository.NewBiometricTokenRepository(db.Pool)
	otpRepo := repository.NewOTPRepository(db.Pool)
	checklistRepo := repository.NewChecklistRepository(db.Pool)
	tripRepo := repository.NewTripRepository(db.Pool)
	incidentRepo := repository.NewIncidentRepository(db.Pool)
	notificationRepo := repository.NewNotificationRepository(db.Pool)
	deviceTokenRepo := repository.NewDeviceTokenRepository(db.Pool)

	// Initialize services
	authService := service.NewAuthService(userRepo, refreshTokenRepo, biometricTokenRepo, jwtUtil)
	notificationService := service.NewNotificationService(notificationRepo, deviceTokenRepo, fcmService)
	profileService := service.NewProfileService(profileRepo, profileUpdateRequestRepo, userRepo, notificationService)
	userService := service.NewUserService(userRepo, profileRepo)
	contractService := service.NewContractService(contractRepo, notificationService, userRepo)
	payslipService := service.NewPayslipService(payslipRepo, userRepo, notificationService)
	vehicleService := service.NewVehicleService(vehicleRepo, tripRepo)
	fuelReportService := service.NewFuelReportService(fuelReportRepo, userRepo, tripRepo, vehicleRepo, notificationService)
	tripReportService := service.NewTripReportService(tripReportRepo)
	emailService := service.NewEmailService(&cfg.Email)
	passwordResetService := service.NewPasswordResetService(otpRepo, userRepo, emailService, &cfg.Email)
	checklistService := service.NewChecklistService(checklistRepo, tripRepo, userRepo, vehicleRepo, notificationService)
	tripService := service.NewTripService(tripRepo, checklistRepo, userRepo, vehicleRepo, notificationService)
	go func() {
		ticker := time.NewTicker(1 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			ctx, cancel := context.WithTimeout(context.Background(), 55*time.Second)
			tripService.RunDepartureJobs(ctx)
			cancel()
		}
	}()
	incidentService := service.NewIncidentService(
		incidentRepo,
		tripRepo,
		notificationService,
		userRepo,
		vehicleRepo,
	)
	fuelPriceService := service.NewFuelPriceService(&cfg.FuelPrices)

	// Initialize handlers
	authHandler := handler.NewAuthHandler(authService, notificationService)
	userHandler := handler.NewUserHandler(userService)
	profileHandler := handler.NewProfileHandler(profileService)
	operationsHandler := handler.NewOperationsHandler(
		contractService,
		payslipService,
		vehicleService,
		fuelReportService,
		tripReportService,
		checklistService,
		tripService,
		incidentService,
		notificationService,
	)
	uploadHandler := handler.NewUploadHandler(&cfg.Upload)
	passwordResetHandler := handler.NewPasswordResetHandler(passwordResetService)
	fuelPriceHandler := handler.NewFuelPriceHandler(fuelPriceService)

	router := gin.Default()
	router.Use(middleware.CORSMiddleware())

	router.GET("/health", func(c *gin.Context) {
		utils.SuccessResponse(c, 200, "Server is running", gin.H{
			"status": "healthy",
		})
	})

	v1 := router.Group("/api/v1")
	{
		// Public fuel price endpoints (no auth required)
		prices := v1.Group("/prices")
		{
			prices.GET("", fuelPriceHandler.GetCombinedPrices)
			prices.GET("/petrolimex", fuelPriceHandler.GetPetrolimexPrices)
			prices.GET("/pvoil", fuelPriceHandler.GetPVOilPrices)
		}

		auth := v1.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
			auth.POST("/logout", authHandler.Logout)
			auth.POST("/forgot-password", passwordResetHandler.ForgotPassword)
			auth.POST("/reset-password", passwordResetHandler.ResetPassword)
			auth.POST("/biometric-login", authHandler.BiometricLogin) // PUBLIC: login with biometric token
		}

		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(jwtUtil))
		{
			// Change password (authenticated user)
			protected.POST("/auth/change-password", authHandler.ChangePassword)

			// Biometric authentication management (AUTH REQUIRED)
			biometric := protected.Group("/auth/biometric")
			{
				biometric.POST("/enable", authHandler.EnableBiometric)
				biometric.DELETE("/disable", authHandler.DisableBiometric)
			}

			users := protected.Group("/users")
			{
				users.GET("/me", authHandler.GetMe)
				users.GET("", middleware.RequireRole(models.RoleAdmin), userHandler.ListUsers)
				users.POST("", middleware.RequireRole(models.RoleAdmin), userHandler.CreateUser)
				users.PATCH("/:id/status", middleware.RequireRole(models.RoleAdmin), userHandler.UpdateUserStatus)
				users.PATCH("/:id/password", middleware.RequireRole(models.RoleAdmin), userHandler.UpdateUserPassword)
				users.GET("/:id/profile", middleware.RequireRole(models.RoleAdmin), profileHandler.GetDriverProfile)
			}

			profile := protected.Group("/profile")
			{
				profile.GET("", profileHandler.GetMyProfile)
				profile.PUT("", profileHandler.UpdateProfile)
			}

			// Profile update requests (Admin review queue)
			profileRequests := protected.Group("/profile-requests")
			{
				profileRequests.GET("", middleware.RequireRole(models.RoleAdmin), profileHandler.ListProfileUpdateRequests)
				profileRequests.PATCH("/:id/review", middleware.RequireRole(models.RoleAdmin), profileHandler.ReviewProfileUpdateRequest)
			}

			contracts := protected.Group("/contracts")
			{
				contracts.GET("", operationsHandler.ListContracts)
				contracts.POST("", middleware.RequireRole(models.RoleAdmin), operationsHandler.CreateContract)
				contracts.PATCH("/:id/view", middleware.RequireRole(models.RoleDriver), operationsHandler.MarkContractViewed)
				contracts.PATCH("/:id/respond", middleware.RequireRole(models.RoleDriver), operationsHandler.RespondContract)
			}

			payslips := protected.Group("/payslips")
			{
				payslips.GET("", operationsHandler.ListPayslips)
				payslips.POST("", middleware.RequireRole(models.RoleAdmin), operationsHandler.CreatePayslip)
				payslips.POST("/import", middleware.RequireRole(models.RoleAdmin), operationsHandler.ImportPayslips)
				payslips.PATCH("/:id/view", middleware.RequireRole(models.RoleDriver), operationsHandler.MarkPayslipViewed)
				payslips.PATCH("/:id/confirm", middleware.RequireRole(models.RoleDriver), operationsHandler.ConfirmPayslip)
			}

			vehicles := protected.Group("/vehicles")
			{
				vehicles.GET("", operationsHandler.ListVehicles)
				vehicles.POST("", middleware.RequireRole(models.RoleAdmin), operationsHandler.CreateVehicle)
				vehicles.GET("/:id/maintenance", operationsHandler.GetVehicleMaintenance)
				vehicles.PATCH("/:id", middleware.RequireRole(models.RoleAdmin), operationsHandler.UpdateVehicle)
				vehicles.DELETE("/:id", middleware.RequireRole(models.RoleAdmin), operationsHandler.DeleteVehicle)
			}

			fuelReports := protected.Group("/fuel-reports")
			{
				fuelReports.GET("", operationsHandler.ListFuelReports)
				fuelReports.GET("/export", middleware.RequireRole(models.RoleAdmin), operationsHandler.ExportFuelReports)
				fuelReports.POST("", middleware.RequireRole(models.RoleDriver), operationsHandler.CreateFuelReport)
				fuelReports.PATCH("/:id", middleware.RequireRole(models.RoleAdmin), operationsHandler.UpdateFuelReport)
			}

			tripReports := protected.Group("/trip-reports")
			{
				tripReports.GET("", operationsHandler.ListTripReports)
				tripReports.POST("", middleware.RequireRole(models.RoleDriver), operationsHandler.CreateTripReport)
			}

			checklists := protected.Group("/checklists")
			{
				checklists.GET("", operationsHandler.ListChecklists)
				checklists.POST("", middleware.RequireRole(models.RoleDriver), operationsHandler.CreateChecklist)
			}

			trips := protected.Group("/trips")
			{
				trips.GET("", operationsHandler.ListTrips)
				trips.GET("/:id", operationsHandler.GetTrip)
				trips.POST("/schedule", middleware.RequireRole(models.RoleAdmin), operationsHandler.ScheduleTrip)
				trips.POST("/start", middleware.RequireRole(models.RoleDriver), operationsHandler.StartTrip)
				trips.PATCH("/:id/respond", middleware.RequireRole(models.RoleDriver), operationsHandler.RespondTrip)
				trips.POST("/:id/start", middleware.RequireRole(models.RoleDriver), operationsHandler.StartScheduledTrip)
				trips.PATCH("/:id/end", middleware.RequireRole(models.RoleDriver), operationsHandler.EndTrip)
				trips.PATCH("/:id/cancel", middleware.RequireRole(models.RoleAdmin), operationsHandler.CancelTrip)
			}

			incidents := protected.Group("/incidents")
			{
				incidents.GET("", operationsHandler.ListIncidents)
				incidents.POST("", middleware.RequireRole(models.RoleDriver), operationsHandler.CreateIncident)
			}

			notifications := protected.Group("/notifications")
			{
				notifications.GET("", operationsHandler.ListNotifications)
				notifications.GET("/unread-count", operationsHandler.NotificationsUnreadCount)
				notifications.GET("/stream", operationsHandler.NotificationStream) // SSE
				notifications.POST("", middleware.RequireRole(models.RoleAdmin), operationsHandler.CreateNotification)
				notifications.PATCH("/:id/read", operationsHandler.MarkNotificationRead)
			}

			// Admin system notifications (profile updates, alerts)
			adminNotifs := protected.Group("/admin/notifications")
			{
				adminNotifs.GET("", middleware.RequireRole(models.RoleAdmin), operationsHandler.ListAdminNotifications)
				adminNotifs.PATCH("/:id/read", middleware.RequireRole(models.RoleAdmin), operationsHandler.MarkNotificationRead)
			}

			// Device token registration for FCM
			protected.POST("/devices/register", authHandler.RegisterDevice)
			protected.DELETE("/devices/unregister", authHandler.UnregisterDevice)

			protected.POST("/upload", uploadHandler.Upload)
		}
	}

	// Serve static files from Media folder
	router.Static("/Media", "./"+uploadHandler.GetUploadPath())

	serverAddr := fmt.Sprintf(":%s", cfg.Server.Port)
	log.Printf("Server starting on %s", serverAddr)

	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
