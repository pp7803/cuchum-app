package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
)

// FuelPriceHandler handles fuel price endpoints
type FuelPriceHandler struct {
	fuelPriceService *service.FuelPriceService
}

// NewFuelPriceHandler creates a new FuelPriceHandler
func NewFuelPriceHandler(fuelPriceService *service.FuelPriceService) *FuelPriceHandler {
	return &FuelPriceHandler{
		fuelPriceService: fuelPriceService,
	}
}

// GetCombinedPrices returns fuel prices from both Petrolimex and PVOil
// @Summary Get combined fuel prices
// @Description Get fuel prices from both Petrolimex and PVOil
// @Tags Fuel Prices
// @Produce json
// @Success 200 {object} service.CombinedPriceResponse
// @Router /api/v1/prices [get]
func (h *FuelPriceHandler) GetCombinedPrices(c *gin.Context) {
	prices := h.fuelPriceService.GetCombinedPrices()
	utils.SuccessResponse(c, http.StatusOK, "Fuel prices retrieved successfully", prices)
}

// GetPetrolimexPrices returns fuel prices from Petrolimex only
// @Summary Get Petrolimex fuel prices
// @Description Get fuel prices from Petrolimex (Zone 1 + Zone 2)
// @Tags Fuel Prices
// @Produce json
// @Success 200 {object} service.PriceData
// @Router /api/v1/prices/petrolimex [get]
func (h *FuelPriceHandler) GetPetrolimexPrices(c *gin.Context) {
	prices := h.fuelPriceService.ScrapePetrolimex()
	utils.SuccessResponse(c, http.StatusOK, "Petrolimex prices retrieved successfully", prices)
}

// GetPVOilPrices returns fuel prices from PVOil only
// @Summary Get PVOil fuel prices
// @Description Get fuel prices from PVOil (Zone 1 only)
// @Tags Fuel Prices
// @Produce json
// @Success 200 {object} service.PriceData
// @Router /api/v1/prices/pvoil [get]
func (h *FuelPriceHandler) GetPVOilPrices(c *gin.Context) {
	prices := h.fuelPriceService.ScrapePVOil()
	utils.SuccessResponse(c, http.StatusOK, "PVOil prices retrieved successfully", prices)
}
