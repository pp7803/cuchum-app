package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
)

type OperationsHandler struct {
	contractService     *service.ContractService
	payslipService      *service.PayslipService
	vehicleService      *service.VehicleService
	fuelReportService   *service.FuelReportService
	tripReportService   *service.TripReportService
	checklistService    *service.ChecklistService
	tripService         *service.TripService
	incidentService     *service.IncidentService
	notificationService *service.NotificationService
}

func NewOperationsHandler(
	contractService *service.ContractService,
	payslipService *service.PayslipService,
	vehicleService *service.VehicleService,
	fuelReportService *service.FuelReportService,
	tripReportService *service.TripReportService,
	checklistService *service.ChecklistService,
	tripService *service.TripService,
	incidentService *service.IncidentService,
	notificationService *service.NotificationService,
) *OperationsHandler {
	return &OperationsHandler{
		contractService:     contractService,
		payslipService:      payslipService,
		vehicleService:      vehicleService,
		fuelReportService:   fuelReportService,
		tripReportService:   tripReportService,
		checklistService:    checklistService,
		tripService:         tripService,
		incidentService:     incidentService,
		notificationService: notificationService,
	}
}

// ListContracts: DRIVER sees only their own contracts (JWT user_id). ADMIN must pass ?driver_id=.
// ADMIN optional: ?acknowledgment_status=PENDING|ACKNOWLEDGED|DECLINED
func (h *OperationsHandler) ListContracts(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userIDVal, _ := c.Get("user_id")

	var driverID *uuid.UUID
	var ackFilter *models.ContractAcknowledgmentStatus

	switch userRole {
	case string(models.RoleDriver):
		uid := userIDVal.(uuid.UUID)
		driverID = &uid
	case string(models.RoleAdmin):
		queryDriverID := c.Query("driver_id")
		if queryDriverID == "" {
			utils.ErrorResponse(c, http.StatusBadRequest, "driver_id query parameter is required")
			return
		}
		did, err := uuid.Parse(queryDriverID)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid driver_id")
			return
		}
		driverID = &did

		if s := strings.TrimSpace(c.Query("acknowledgment_status")); s != "" {
			st := models.ContractAcknowledgmentStatus(s)
			switch st {
			case models.ContractAckPending, models.ContractAckAcknowledged, models.ContractAckDeclined:
				ackFilter = &st
			default:
				utils.ErrorResponse(c, http.StatusBadRequest, "Invalid acknowledgment_status (use PENDING, ACKNOWLEDGED, or DECLINED)")
				return
			}
		}
	default:
		utils.ErrorResponse(c, http.StatusForbidden, "Access denied")
		return
	}

	contracts, err := h.contractService.List(c.Request.Context(), driverID, ackFilter)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Contracts retrieved successfully", contracts)
}

func (h *OperationsHandler) CreateContract(c *gin.Context) {
	var req models.CreateContractRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	contract, err := h.contractService.Create(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Contract created successfully", contract)
}

func (h *OperationsHandler) MarkContractViewed(c *gin.Context) {
	contractID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid contract ID")
		return
	}
	userID := c.MustGet("user_id").(uuid.UUID)
	if err := h.contractService.MarkAsViewed(c.Request.Context(), contractID, userID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Contract marked as viewed", nil)
}

func (h *OperationsHandler) RespondContract(c *gin.Context) {
	contractID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid contract ID")
		return
	}
	var req models.RespondContractRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	userID := c.MustGet("user_id").(uuid.UUID)
	if err := h.contractService.RespondContract(c.Request.Context(), contractID, userID, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Contract response recorded", nil)
}

// Payslips
func (h *OperationsHandler) ListPayslips(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	switch userRole {
	case string(models.RoleDriver):
		uid := userID.(uuid.UUID)
		driverID = &uid
	case string(models.RoleAdmin):
		if q := strings.TrimSpace(c.Query("driver_id")); q != "" {
			did, err := uuid.Parse(q)
			if err != nil {
				utils.ErrorResponse(c, http.StatusBadRequest, "Invalid driver_id")
				return
			}
			driverID = &did
		}
		// driverID nil → all drivers (month filter still applies)
	default:
		utils.ErrorResponse(c, http.StatusForbidden, "Access denied")
		return
	}

	month := c.Query("month")
	payslips, err := h.payslipService.List(c.Request.Context(), driverID, month)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Payslips retrieved successfully", payslips)
}

func (h *OperationsHandler) CreatePayslip(c *gin.Context) {
	var req models.CreatePayslipRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	payslip, err := h.payslipService.Create(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Payslip created successfully", payslip)
}

// ImportPayslips imports payslips from JSON (parsed Excel data)
func (h *OperationsHandler) ImportPayslips(c *gin.Context) {
	var req models.PayslipsImportRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	result, err := h.payslipService.ImportFromData(c.Request.Context(), req.Items)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Payslips import completed", result)
}

func (h *OperationsHandler) MarkPayslipViewed(c *gin.Context) {
	payslipID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payslip ID")
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.payslipService.MarkAsViewed(c.Request.Context(), payslipID, userID.(uuid.UUID)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Payslip marked as viewed", nil)
}

// Vehicles
func (h *OperationsHandler) ListVehicles(c *gin.Context) {
	status := c.Query("status")
	vehicles, err := h.vehicleService.List(c.Request.Context(), status)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Vehicles retrieved successfully", vehicles)
}

func (h *OperationsHandler) CreateVehicle(c *gin.Context) {
	var req models.CreateVehicleRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	v, err := h.vehicleService.Create(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusCreated, "Vehicle created successfully", v)
}

func (h *OperationsHandler) UpdateVehicle(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle ID")
		return
	}
	var req models.UpdateVehicleRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	if err := h.vehicleService.Update(c.Request.Context(), id, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Vehicle updated successfully", nil)
}

func (h *OperationsHandler) DeleteVehicle(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle ID")
		return
	}
	if err := h.vehicleService.Delete(c.Request.Context(), id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Vehicle deleted successfully", nil)
}

// Fuel Reports
func (h *OperationsHandler) ListFuelReports(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	if userRole == string(models.RoleDriver) {
		uid := userID.(uuid.UUID)
		driverID = &uid
	}

	date := c.Query("date")
	var vehicleID *uuid.UUID
	if vid := c.Query("vehicle_id"); vid != "" {
		parsed, err := uuid.Parse(vid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle_id")
			return
		}
		vehicleID = &parsed
	}
	var tripID *uuid.UUID
	if tid := c.Query("trip_id"); tid != "" {
		parsed, err := uuid.Parse(tid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip_id")
			return
		}
		tripID = &parsed
	}
	if tripID != nil && userRole == string(models.RoleDriver) {
		userID, _ := c.Get("user_id")
		if _, err := h.tripService.GetTripForViewer(c.Request.Context(), *tripID, userID.(uuid.UUID), string(models.RoleDriver)); err != nil {
			utils.ErrorResponse(c, http.StatusNotFound, "Trip not found")
			return
		}
	}

	reports, err := h.fuelReportService.List(c.Request.Context(), driverID, date, vehicleID, tripID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Fuel reports retrieved successfully", reports)
}

func (h *OperationsHandler) CreateFuelReport(c *gin.Context) {
	var req models.CreateFuelReportRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	report, err := h.fuelReportService.Create(c.Request.Context(), userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Fuel report created successfully", report)
}

func (h *OperationsHandler) UpdateFuelReport(c *gin.Context) {
	reportID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid report ID")
		return
	}

	var req models.UpdateFuelReportRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	if err := h.fuelReportService.UpdateAdminNote(c.Request.Context(), reportID, req.AdminNote); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Fuel report updated successfully", nil)
}

// ExportFuelReports exports fuel reports as JSON (can be converted to Excel by frontend or additional library)
func (h *OperationsHandler) ExportFuelReports(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "start_date and end_date are required")
		return
	}

	var driverID *uuid.UUID
	if did := c.Query("driver_id"); did != "" {
		parsed, err := uuid.Parse(did)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid driver_id")
			return
		}
		driverID = &parsed
	}

	reports, err := h.fuelReportService.ExportByDateRange(c.Request.Context(), startDate, endDate, driverID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Fuel reports exported successfully", reports)
}

// Trip Reports
func (h *OperationsHandler) ListTripReports(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	if userRole == string(models.RoleDriver) {
		uid := userID.(uuid.UUID)
		driverID = &uid
	}

	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	reports, err := h.tripReportService.List(c.Request.Context(), driverID, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Trip reports retrieved successfully", reports)
}

func (h *OperationsHandler) CreateTripReport(c *gin.Context) {
	var req models.CreateTripReportRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	report, err := h.tripReportService.CreateOrUpdate(c.Request.Context(), userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Trip report created successfully", report)
}

// ConfirmPayslip confirms or complains about a payslip
func (h *OperationsHandler) ConfirmPayslip(c *gin.Context) {
	payslipID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payslip ID")
		return
	}

	var req models.ConfirmPayslipRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.payslipService.ConfirmPayslip(c.Request.Context(), payslipID, userID.(uuid.UUID), req); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Payslip confirmed successfully", nil)
}

// GetVehicleMaintenance retrieves maintenance info for a vehicle
func (h *OperationsHandler) GetVehicleMaintenance(c *gin.Context) {
	vehicleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle ID")
		return
	}

	maintenance, err := h.vehicleService.GetMaintenance(c.Request.Context(), vehicleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Vehicle maintenance info not found")
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Vehicle maintenance info retrieved", maintenance)
}

// Checklists
func (h *OperationsHandler) ListChecklists(c *gin.Context) {
	var vehicleID *uuid.UUID
	if vid := c.Query("vehicle_id"); vid != "" {
		parsed, err := uuid.Parse(vid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle_id")
			return
		}
		vehicleID = &parsed
	}

	date := c.Query("date")
	var tripID *uuid.UUID
	if tid := c.Query("trip_id"); tid != "" {
		parsed, err := uuid.Parse(tid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip_id")
			return
		}
		tripID = &parsed
	}
	userRole, _ := c.Get("user_role")
	if tripID != nil && userRole == string(models.RoleDriver) {
		userID, _ := c.Get("user_id")
		if _, err := h.tripService.GetTripForViewer(c.Request.Context(), *tripID, userID.(uuid.UUID), string(models.RoleDriver)); err != nil {
			utils.ErrorResponse(c, http.StatusNotFound, "Trip not found")
			return
		}
	}
	checklists, err := h.checklistService.List(c.Request.Context(), vehicleID, date, tripID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Checklists retrieved successfully", checklists)
}

func (h *OperationsHandler) CreateChecklist(c *gin.Context) {
	var req models.CreateChecklistRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	checklist, err := h.checklistService.Create(c.Request.Context(), userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Checklist created successfully", checklist)
}

// Trips
func (h *OperationsHandler) ListTrips(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	if userRole == string(models.RoleDriver) {
		uid := userID.(uuid.UUID)
		driverID = &uid
	} else if queryDriverID := c.Query("driver_id"); queryDriverID != "" {
		did, err := uuid.Parse(queryDriverID)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid driver_id")
			return
		}
		driverID = &did
	}

	var status *models.TripStatus
	if s := c.Query("status"); s != "" {
		ts := models.TripStatus(s)
		status = &ts
	}

	var vehicleID *uuid.UUID
	if vid := c.Query("vehicle_id"); vid != "" {
		parsed, err := uuid.Parse(vid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid vehicle_id")
			return
		}
		vehicleID = &parsed
	}

	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	trips, err := h.tripService.List(c.Request.Context(), driverID, vehicleID, status, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Trips retrieved successfully", trips)
}

func (h *OperationsHandler) GetTrip(c *gin.Context) {
	tripID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip ID")
		return
	}
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")
	role, _ := userRole.(string)
	trip, err := h.tripService.GetTripForViewer(c.Request.Context(), tripID, userID.(uuid.UUID), role)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Trip retrieved successfully", trip)
}

func (h *OperationsHandler) StartTrip(c *gin.Context) {
	var req models.StartTripRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	trip, err := h.tripService.StartTrip(c.Request.Context(), userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Trip started successfully", trip)
}

func (h *OperationsHandler) EndTrip(c *gin.Context) {
	tripID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip ID")
		return
	}

	var req models.EndTripRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	trip, err := h.tripService.EndTrip(c.Request.Context(), tripID, userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Trip ended successfully", trip)
}

func (h *OperationsHandler) CancelTrip(c *gin.Context) {
	tripID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip ID")
		return
	}
	var req models.AdminCancelTripRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	reason := strings.TrimSpace(req.Reason)
	if reason == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "reason is required")
		return
	}
	trip, err := h.tripService.AdminCancelTrip(c.Request.Context(), tripID, reason)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Trip cancelled successfully", trip)
}

func (h *OperationsHandler) ScheduleTrip(c *gin.Context) {
	var req models.ScheduleTripRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	trip, err := h.tripService.ScheduleTrip(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusCreated, "Trip scheduled successfully", trip)
}

func (h *OperationsHandler) RespondTrip(c *gin.Context) {
	tripID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip ID")
		return
	}
	var req models.RespondTripRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	userID, _ := c.Get("user_id")
	trip, err := h.tripService.RespondTrip(c.Request.Context(), tripID, userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Trip response recorded", trip)
}

func (h *OperationsHandler) StartScheduledTrip(c *gin.Context) {
	tripID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip ID")
		return
	}
	var req models.StartScheduledTripRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	userID, _ := c.Get("user_id")
	trip, err := h.tripService.StartScheduledTrip(c.Request.Context(), tripID, userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.SuccessResponse(c, http.StatusOK, "Trip started successfully", trip)
}

// Incidents
func (h *OperationsHandler) ListIncidents(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	if userRole == string(models.RoleDriver) {
		uid := userID.(uuid.UUID)
		driverID = &uid
	}

	var incidentType *models.IncidentType
	if t := c.Query("type"); t != "" {
		it := models.IncidentType(t)
		incidentType = &it
	}

	var tripID *uuid.UUID
	if tid := c.Query("trip_id"); tid != "" {
		parsed, err := uuid.Parse(tid)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid trip_id")
			return
		}
		tripID = &parsed
	}
	if tripID != nil && userRole == string(models.RoleDriver) {
		if _, err := h.tripService.GetTripForViewer(c.Request.Context(), *tripID, userID.(uuid.UUID), string(models.RoleDriver)); err != nil {
			utils.ErrorResponse(c, http.StatusNotFound, "Trip not found")
			return
		}
	}

	incidents, err := h.incidentService.List(c.Request.Context(), driverID, incidentType, tripID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Incidents retrieved successfully", incidents)
}

func (h *OperationsHandler) CreateIncident(c *gin.Context) {
	var req models.CreateIncidentRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	incident, err := h.incidentService.Create(c.Request.Context(), userID.(uuid.UUID), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Incident reported successfully", incident)
}

// Notifications
func (h *OperationsHandler) ListNotifications(c *gin.Context) {
	userRole, _ := c.Get("user_role")
	userID, _ := c.Get("user_id")

	var driverID *uuid.UUID
	if userRole == string(models.RoleDriver) {
		uid := userID.(uuid.UUID)
		driverID = &uid
	}

	notifications, err := h.notificationService.List(c.Request.Context(), driverID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	if notifications == nil {
		notifications = []*models.Notification{}
	}
	utils.SuccessResponse(c, http.StatusOK, "Notifications retrieved successfully", notifications)
}

// ListAdminNotifications returns admin system alerts (is_admin_notification = TRUE)
// @route GET /api/v1/admin/notifications
func (h *OperationsHandler) ListAdminNotifications(c *gin.Context) {
	notifications, err := h.notificationService.ListAdminNotifications(c.Request.Context())
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	if notifications == nil {
		notifications = []*models.Notification{}
	}
	utils.SuccessResponse(c, http.StatusOK, "Admin notifications retrieved successfully", notifications)
}

// MarkNotificationRead marks a notification as read
// @route PATCH /api/v1/notifications/:id/read
func (h *OperationsHandler) MarkNotificationRead(c *gin.Context) {
	notifID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid notification ID")
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.notificationService.MarkAsRead(c.Request.Context(), notifID, userID.(uuid.UUID)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Marked as read", nil)
}

// NotificationsUnreadCount returns unread notification count
// @route GET /api/v1/notifications/unread-count
func (h *OperationsHandler) NotificationsUnreadCount(c *gin.Context) {
	userID, _ := c.Get("user_id")
	userRole, _ := c.Get("user_role")
	isAdmin := userRole == string(models.RoleAdmin)

	count, err := h.notificationService.UnreadCount(c.Request.Context(), userID.(uuid.UUID), isAdmin)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "OK", gin.H{"unread_count": count})
}

// NotificationStream serves a Server-Sent Events stream for real-time notifications.
// @route GET /api/v1/notifications/stream
func (h *OperationsHandler) NotificationStream(c *gin.Context) {
	userID, _ := c.Get("user_id")
	userRole, _ := c.Get("user_role")
	isAdmin := userRole.(string) == string(models.RoleAdmin)

	// Register this client in the SSE hub
	client := service.GetSSEHub().Register(userID.(uuid.UUID), isAdmin)
	defer service.GetSSEHub().Unregister(client)

	// SSE headers
	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Writer.Header().Set("X-Accel-Buffering", "no") // disable nginx buffering
	c.Writer.WriteHeader(http.StatusOK)

	// Send a "connected" ping so the client knows the stream is live
	fmt.Fprintf(c.Writer, "data: {\"type\":\"connected\"}\n\n")
	c.Writer.Flush()

	heartbeat := time.NewTicker(25 * time.Second)
	defer heartbeat.Stop()

	for {
		select {
		case notif, ok := <-client.Ch:
			if !ok {
				return
			}
			data, err := json.Marshal(notif)
			if err != nil {
				continue
			}
			fmt.Fprintf(c.Writer, "data: %s\n\n", data)
			c.Writer.Flush()

		case <-heartbeat.C:
			// Keep-alive comment line (not interpreted as data by clients)
			fmt.Fprintf(c.Writer, ": heartbeat\n\n")
			c.Writer.Flush()

		case <-c.Request.Context().Done():
			return
		}
	}
}

func (h *OperationsHandler) CreateNotification(c *gin.Context) {
	var req models.CreateNotificationRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	notification, err := h.notificationService.Create(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusCreated, "Notification created successfully", notification)
}
