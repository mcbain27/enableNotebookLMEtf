# ==============================================================================
# Google Cloud APIs Enablement
# ==============================================================================

locals {
  services = toset(concat(
    [
      "discoveryengine.googleapis.com",
      "aiplatform.googleapis.com",
    ],
    var.enable_gcs_data_store ? ["storage.googleapis.com"] : [],
    var.enable_bigquery_data_store ? ["bigquery.googleapis.com"] : []
  ))
}

resource "google_project_service" "required_apis" {
  for_each = local.services

  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

# ==============================================================================
# Gemini Enterprise Search Engine App
# ==============================================================================

resource "google_discovery_engine_search_engine" "gemini_search_engine" {
  count = var.enable_gemini_enterprise_search && var.enable_gcs_data_store ? 1 : 0

  project           = var.project_id
  location          = var.discovery_engine_location
  collection_id     = "default_collection"
  engine_id         = var.search_engine_id
  display_name      = var.search_engine_display_name
  industry_vertical = "GENERIC"
  data_store_ids    = [google_discovery_engine_data_store.gcs_data_store[0].data_store_id]

  common_config {
    company_name = var.company_name
  }

  search_engine_config {
    search_tier    = "SEARCH_TIER_ENTERPRISE"
    search_add_ons = ["SEARCH_ADD_ON_LLM"]
  }

  depends_on = [
    google_project_service.required_apis,
    google_discovery_engine_data_store.gcs_data_store
  ]
}
