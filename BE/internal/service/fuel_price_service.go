package service

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/tsnn/ch-app/internal/config"
)

// FuelPrice represents the price of a specific fuel type
type FuelPrice struct {
	Name       string `json:"name"`
	PriceZone1 string `json:"price_zone1"`
	PriceZone2 string `json:"price_zone2,omitempty"`
}

// PriceData holds fuel prices and metadata for a single company
type PriceData struct {
	Company   string      `json:"company"`
	UpdatedAt string      `json:"updated_at,omitempty"`
	Prices    []FuelPrice `json:"prices"`
	Error     string      `json:"error,omitempty"`
}

// CombinedPriceResponse holds the scraped prices from both companies
type CombinedPriceResponse struct {
	Petrolimex PriceData `json:"petrolimex"`
	PVOil      PriceData `json:"pvoil"`
}

// PetrolimexAPIResponse represents the JSON structure from Petrolimex API
type PetrolimexAPIResponse struct {
	Objects []struct {
		Title        string  `json:"Title"`
		Zone1Price   float64 `json:"Zone1Price"`
		Zone2Price   float64 `json:"Zone2Price"`
		LastModified string  `json:"LastModified"`
		OrderIndex   int     `json:"OrderIndex"`
	} `json:"Objects"`
}

// FuelPriceService handles fuel price scraping
type FuelPriceService struct {
	petrolimexURL string
	pvoilURL      string
	client        *http.Client
}

// NewFuelPriceService creates a new FuelPriceService
func NewFuelPriceService(cfg *config.FuelPricesConfig) *FuelPriceService {
	return &FuelPriceService{
		petrolimexURL: cfg.PetrolimexURL,
		pvoilURL:      cfg.PVOilURL,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetCombinedPrices fetches prices from both Petrolimex and PVOil
func (s *FuelPriceService) GetCombinedPrices() *CombinedPriceResponse {
	return &CombinedPriceResponse{
		Petrolimex: s.ScrapePetrolimex(),
		PVOil:      s.ScrapePVOil(),
	}
}

// ScrapePetrolimex fetches the latest retail fuel prices directly from Petrolimex API.
func (s *FuelPriceService) ScrapePetrolimex() PriceData {
	data := PriceData{
		Company: "Petrolimex",
	}

	req, err := http.NewRequest("GET", s.petrolimexURL, nil)
	if err != nil {
		data.Error = fmt.Sprintf("failed to create request: %v", err)
		return data
	}

	// Setup necessary headers to look like a normal browser request
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "application/json, text/plain, */*")
	req.Header.Set("Origin", "https://www.petrolimex.com.vn")
	req.Header.Set("Referer", "https://www.petrolimex.com.vn/")

	res, err := s.client.Do(req)
	if err != nil {
		data.Error = fmt.Sprintf("failed to fetch: %v", err)
		return data
	}
	defer res.Body.Close()

	if res.StatusCode != 200 {
		data.Error = fmt.Sprintf("status code: %d", res.StatusCode)
		return data
	}

	var apiRes PetrolimexAPIResponse
	if err := json.NewDecoder(res.Body).Decode(&apiRes); err != nil {
		data.Error = fmt.Sprintf("failed to parse JSON: %v", err)
		return data
	}

	for _, item := range apiRes.Objects {
		// Only add items that have a price
		if item.Title != "" && item.Zone1Price > 0 {
			price1 := formatPrice(item.Zone1Price)
			price2 := formatPrice(item.Zone2Price)

			data.Prices = append(data.Prices, FuelPrice{
				Name:       item.Title,
				PriceZone1: price1,
				PriceZone2: price2,
			})

			// Set updated_at from the first item if not set
			if data.UpdatedAt == "" && item.LastModified != "" {
				data.UpdatedAt = item.LastModified
			}
		}
	}

	if len(data.Prices) == 0 {
		data.Error = "no prices extracted from API response"
	}

	return data
}

// ScrapePVOil fetches the latest retail fuel prices from PVOil.
func (s *FuelPriceService) ScrapePVOil() PriceData {
	data := PriceData{
		Company: "PVOil",
	}

	req, err := http.NewRequest("GET", s.pvoilURL, nil)
	if err != nil {
		data.Error = fmt.Sprintf("failed to create request: %v", err)
		return data
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept-Language", "vi-VN,vi;q=0.9,en;q=0.8")

	res, err := s.client.Do(req)
	if err != nil {
		data.Error = fmt.Sprintf("failed to fetch: %v", err)
		return data
	}
	defer res.Body.Close()

	if res.StatusCode != 200 {
		data.Error = fmt.Sprintf("status code: %d", res.StatusCode)
		return data
	}

	doc, err := goquery.NewDocumentFromReader(res.Body)
	if err != nil {
		data.Error = fmt.Sprintf("failed to parse HTML: %v", err)
		return data
	}

	// Extract update timestamp from h4.sub-box-title
	doc.Find("h4.sub-box-title").Each(func(i int, sel *goquery.Selection) {
		text := strings.TrimSpace(sel.Text())
		if strings.Contains(text, "Giá điều chỉnh") || strings.Contains(text, "điều chỉnh") {
			data.UpdatedAt = text
		}
	})

	// Extract fuel prices from a.gasoline-price-item elements
	doc.Find("a.gasoline-price-item").Each(func(i int, sel *goquery.Selection) {
		// Fuel name is in h3.title
		nameEl := sel.Find("h3.title")
		if nameEl.Length() == 0 {
			return
		}
		name := strings.TrimSpace(nameEl.Text())

		// Price is in span.count
		priceEl := sel.Find("span.count")
		if priceEl.Length() == 0 {
			return
		}
		priceText := strings.TrimSpace(priceEl.Text())
		priceText = strings.ReplaceAll(priceText, "đ", "")
		priceText = strings.TrimSpace(priceText)

		if name != "" && priceText != "" {
			data.Prices = append(data.Prices, FuelPrice{
				Name:       name,
				PriceZone1: priceText,
			})
		}
	})

	if len(data.Prices) == 0 {
		data.Error = "no prices extracted from page"
	}

	return data
}

// formatPrice converts a float64 (e.g., 27040) into formatted string "27.040"
func formatPrice(price float64) string {
	intPrice := int(price)
	s := fmt.Sprintf("%d", intPrice)
	if len(s) > 3 {
		return s[:len(s)-3] + "." + s[len(s)-3:]
	}
	return s
}
