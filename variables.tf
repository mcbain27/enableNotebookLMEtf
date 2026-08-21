# ==============================================================================
# Target Environment Variables
# ==============================================================================

variable "project_id" {
  description = "The target Google Cloud Project ID where Gemini Enterprise and NotebookLM Enterprise resources will be provisioned."
  type        = string
}

variable "region" {
  description = "The primary Google Cloud region for regional resources (e.g., Cloud Storage buckets, BigQuery datasets)."
  type        = string
  default     = "australia-southeast1"
}

variable "discovery_engine_location" {
  description = "The location for Discovery Engine / Gemini Enterprise resources ('global', 'us', 'eu', or regional where available)."
  type        = string
  default     = "global"
}

# ==============================================================================
# Identity & Authentication Configuration
# ==============================================================================

variable "idp_type" {
  description = "The Identity Provider type used for Gemini Enterprise and NotebookLM access ('GSUITE' for native Google Workspace/Cloud Identity or 'THIRD_PARTY' for Workforce Identity Federation)."
  type        = string
  default     = "GSUITE"
  validation {
    condition     = contains(["GSUITE", "THIRD_PARTY"], var.idp_type)
    error_message = "The idp_type variable must be either 'GSUITE' or 'THIRD_PARTY'."
  }
}

variable "workforce_pool_name" {
  description = "The full resource name of the Workforce Identity Pool (e.g., 'locations/global/workforcePools/my-pool') if idp_type is set to 'THIRD_PARTY'."
  type        = string
  default     = null
}

# ==============================================================================
# Gemini Enterprise Engine & App Configuration
# ==============================================================================

variable "enable_gemini_enterprise_search" {
  description = "Whether to provision a Gemini Enterprise Search / Chat App Engine linked to grounding data stores."
  type        = bool
  default     = true
}

variable "search_engine_id" {
  description = "Unique ID for the Gemini Enterprise Search Engine."
  type        = string
  default     = "gemini-enterprise-search"
}

variable "search_engine_display_name" {
  description = "Human-readable display name for the Gemini Enterprise Search Engine."
  type        = string
  default     = "Gemini Enterprise Search & Assistant"
}

variable "company_name" {
  description = "Company or Organization name displayed in the Gemini Enterprise assistant app."
  type        = string
  default     = "Enterprise Organization"
}

# ==============================================================================
# Optional Grounding Data Stores
# ==============================================================================

variable "enable_gcs_data_store" {
  description = "Whether to provision a dedicated Cloud Storage bucket and Discovery Engine Data Store for enterprise document grounding."
  type        = bool
  default     = true
}

variable "gcs_data_store_id" {
  description = "Unique identifier for the GCS-backed Discovery Engine Data Store."
  type        = string
  default     = "enterprise-docs-store"
}

variable "gcs_data_store_display_name" {
  description = "Display name for the GCS-backed Data Store."
  type        = string
  default     = "Enterprise Documents Grounding Store"
}

variable "gcs_bucket_name_prefix" {
  description = "Prefix used to generate the Cloud Storage bucket name for enterprise documents."
  type        = string
  default     = "gemini-enterprise-docs"
}

variable "enable_bigquery_data_store" {
  description = "Whether to provision a BigQuery dataset and Discovery Engine structured Data Store."
  type        = bool
  default     = false
}

variable "bigquery_data_store_id" {
  description = "Unique identifier for the BigQuery Discovery Engine Data Store."
  type        = string
  default     = "enterprise-analytics-store"
}

variable "bigquery_data_store_display_name" {
  description = "Display name for the BigQuery Data Store."
  type        = string
  default     = "Enterprise Analytics Grounding Store"
}

variable "bigquery_dataset_id" {
  description = "Dataset ID for the BigQuery grounding dataset."
  type        = string
  default     = "gemini_enterprise_grounding"
}

# ==============================================================================
# IAM Persona Mappings
# ==============================================================================

variable "admin_users" {
  description = "List of user emails (e.g. ['admin@example.com']) to grant Discovery Engine Admin and NotebookLM Admin permissions."
  type        = list(string)
  default     = []
}

variable "editor_users" {
  description = "List of user emails (e.g. ['curator@example.com']) to grant Discovery Engine Editor / Content Curator permissions."
  type        = list(string)
  default     = []
}

variable "standard_users" {
  description = "List of user emails (e.g. ['user1@example.com', 'user2@example.com']) to grant standard Discovery Engine Viewer and NotebookLM User access."
  type        = list(string)
  default     = []
}
