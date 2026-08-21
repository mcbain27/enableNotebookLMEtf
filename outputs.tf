# ==============================================================================
# Deployment Information & Console Endpoints
# ==============================================================================

output "project_id" {
  description = "The Google Cloud Project ID hosting Gemini Enterprise and NotebookLM resources."
  value       = var.project_id
}

output "discovery_engine_location" {
  description = "The geographic location of Discovery Engine resources."
  value       = var.discovery_engine_location
}

output "idp_type" {
  description = "Configured Identity Provider type for Gemini Enterprise access control."
  value       = var.idp_type
}

output "search_engine_id" {
  description = "ID of the provisioned Gemini Enterprise Search / Chat App Engine."
  value       = var.enable_gemini_enterprise_search ? google_discovery_engine_search_engine.gemini_search_engine[0].engine_id : null
}

output "grounding_gcs_bucket" {
  description = "The Cloud Storage bucket provisioned for document grounding."
  value       = var.enable_gcs_data_store ? google_storage_bucket.grounding_docs_bucket[0].name : null
}

output "gcs_data_store_id" {
  description = "Data store ID for the Cloud Storage document repository."
  value       = var.enable_gcs_data_store ? google_discovery_engine_data_store.gcs_data_store[0].data_store_id : null
}

output "bigquery_dataset_id" {
  description = "The BigQuery dataset ID for structured grounding."
  value       = var.enable_bigquery_data_store ? google_bigquery_dataset.grounding_dataset[0].dataset_id : null
}

output "bigquery_data_store_id" {
  description = "Data store ID for the BigQuery grounding repository."
  value       = var.enable_bigquery_data_store ? google_discovery_engine_data_store.bigquery_data_store[0].data_store_id : null
}

# ==============================================================================
# Quick Access Portal URLs
# ==============================================================================

output "gemini_enterprise_console_url" {
  description = "Direct URL to manage Gemini Enterprise apps and search engines in the Google Cloud Console."
  value       = "https://console.cloud.google.com/gen-app-builder/engines?project=${var.project_id}"
}

output "discovery_engine_data_stores_url" {
  description = "Direct URL to view and manage grounding data stores in the Google Cloud Console."
  value       = "https://console.cloud.google.com/gen-app-builder/data-stores?project=${var.project_id}"
}

output "notebooklm_enterprise_portal_url" {
  description = "Direct link to access the NotebookLM web application."
  value       = "https://notebooklm.google.com/"
}

# ==============================================================================
# Access Control Summaries
# ==============================================================================

output "configured_admin_users" {
  description = "List of users configured with Discovery Engine Administrator privileges."
  value       = var.admin_users
}

output "configured_editor_users" {
  description = "List of users configured with Content Editor / Curator privileges."
  value       = var.editor_users
}

output "configured_standard_users" {
  description = "List of users configured with standard Viewer & NotebookLM user privileges."
  value       = var.standard_users
}
