# ==============================================================================
# Cloud Storage Grounding Data Store
# ==============================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "grounding_docs_bucket" {
  count = var.enable_gcs_data_store ? 1 : 0

  project                     = var.project_id
  name                        = "${var.gcs_bucket_name_prefix}-${var.project_id}-${random_id.bucket_suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_discovery_engine_data_store" "gcs_data_store" {
  count = var.enable_gcs_data_store ? 1 : 0

  project                     = var.project_id
  location                    = var.discovery_engine_location
  data_store_id               = var.gcs_data_store_id
  display_name                = var.gcs_data_store_display_name
  industry_vertical           = "GENERIC"
  content_config              = "CONTENT_REQUIRED"
  solution_types              = ["SOLUTION_TYPE_SEARCH"]
  create_advanced_site_search = false

  depends_on = [
    google_project_service.required_apis
  ]
}

# ==============================================================================
# BigQuery Grounding Data Store
# ==============================================================================

resource "google_bigquery_dataset" "grounding_dataset" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project                    = var.project_id
  dataset_id                 = var.bigquery_dataset_id
  friendly_name              = "Gemini Enterprise Grounding Dataset"
  description                = "Dataset containing structured enterprise data for Gemini Search & NotebookLM grounding."
  location                   = var.region
  delete_contents_on_destroy = false

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_discovery_engine_data_store" "bigquery_data_store" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project                     = var.project_id
  location                    = var.discovery_engine_location
  data_store_id               = var.bigquery_data_store_id
  display_name                = var.bigquery_data_store_display_name
  industry_vertical           = "GENERIC"
  content_config              = "NO_CONTENT"
  solution_types              = ["SOLUTION_TYPE_SEARCH"]
  create_advanced_site_search = false

  depends_on = [
    google_project_service.required_apis
  ]
}
