# Gemini Notebook Enterprise - input variables.
# Served by the Discovery Engine API; the SKU is still sold as "NotebookLM
# Enterprise", hence the notebooklm_* variable names.

# ---- Core ----

variable "project_id" {
  description = "Project hosting Discovery Engine and grounding resources. Needs billing and the NotebookLM Enterprise subscription."
  type        = string
}

variable "region" {
  description = "Region for the grounding GCS bucket and (unless bigquery_dataset_location is set) the BigQuery dataset only."
  type        = string
  default     = "australia-southeast1"
}

# Australian at-rest data residency is NOT available for this product.
# Supported multi-regions: global, us, eu. In-country regions ca, in,
# asia-northeast1, sg, europe-west2 are GA but allowlist-only (contact your
# Google account team). Immutable in place - changing it recreates resources.
variable "location" {
  description = "Discovery Engine / Gemini Notebook Enterprise location - where notebooks and indexes live."
  type        = string
  default     = "global"

  validation {
    condition     = contains(["global", "us", "eu", "ca", "in", "asia-northeast1", "sg", "europe-west2"], var.location)
    error_message = "location must be one of: global, us, eu, ca, in, asia-northeast1, sg, europe-west2. The multi-regions global, us and eu are generally available to all customers. The in-country regions ca (Canada), in (India), asia-northeast1 (Japan), sg (Singapore) and europe-west2 (United Kingdom) are GA but ALLOWLIST-ONLY - contact your Google Cloud account team to be allowlisted before using them. There is NO Australian location for Gemini Notebook Enterprise and at-rest residency in Australia is not available."
  }
}

variable "labels" {
  description = "Labels for the resources that support them (grounding bucket, BigQuery dataset). Discovery Engine resources do not accept labels."
  type        = map(string)
  default     = {}
}

variable "api_activation_wait" {
  description = "Go duration to pause after API enablement (eventual consistency on fresh projects)."
  type        = string
  default     = "120s"
}

# ---- Identity provider ----
# Consumed by iam.tf (workforce principalSet:// members) and outputs.tf
# (manual runbook). Selecting the IdP itself is a console-only step.

variable "identity_provider_type" {
  description = "Authentication mode: \"google\" or \"workforce_identity_federation\". Exactly one per project, chosen once."
  type        = string
  default     = "google"

  validation {
    condition     = contains(["google", "workforce_identity_federation"], var.identity_provider_type)
    error_message = "identity_provider_type must be either \"google\" (Google Workspace / Cloud Identity) or \"workforce_identity_federation\" (external IdP via a Workforce Identity Pool). Exactly one identity provider is supported per project."
  }
}

variable "workforce_pool_id" {
  description = "Workforce Identity Pool short ID (always at locations/global). Null for Google identities."
  type        = string
  default     = null
}

variable "workforce_provider_id" {
  description = "Provider short ID within the pool, e.g. \"entra-id\". Runbook only. Null for Google identities."
  type        = string
  default     = null
}

variable "workforce_pool_groups" {
  description = "External IdP group IDs (google.groups assertion) granted user access, as per-group principalSet members."
  type        = list(string)
  default     = []
}

variable "grant_all_workforce_pool_identities" {
  description = "Grant user access to every identity in the pool. Broad - prefer workforce_pool_groups."
  type        = bool
  default     = false
}

# ---- Personas ----
# Bare email addresses only - iam.tf adds the "user:" / "group:" prefix.
# Prefer the *_groups variables so joiner/mover/leaver flows through the
# directory.

variable "notebooklm_admin_users" {
  description = "Users granted the administrator persona (service config and all notebooks)."
  type        = list(string)
  default     = []
}

variable "notebooklm_admin_groups" {
  description = "Groups granted the administrator persona."
  type        = list(string)
  default     = []
}

variable "notebooklm_users" {
  description = "Users granted the standard user persona (sign in, create notebooks)."
  type        = list(string)
  default     = []
}

variable "notebooklm_user_groups" {
  description = "Groups granted the standard user persona."
  type        = list(string)
  default     = []
}

variable "notebook_editor_users" {
  description = "Users granted notebook editor access (create and modify content)."
  type        = list(string)
  default     = []
}

variable "notebook_editor_groups" {
  description = "Groups granted notebook editor access."
  type        = list(string)
  default     = []
}

variable "notebook_viewer_users" {
  description = "Users granted read-only notebook access."
  type        = list(string)
  default     = []
}

variable "notebook_viewer_groups" {
  description = "Groups granted read-only notebook access."
  type        = list(string)
  default     = []
}

variable "gemini_enterprise_app_admin_users" {
  description = "Users granted admin access to the optional Gemini Enterprise app."
  type        = list(string)
  default     = []
}

variable "gemini_enterprise_app_admin_groups" {
  description = "Groups granted admin access to the optional Gemini Enterprise app."
  type        = list(string)
  default     = []
}

variable "gemini_enterprise_app_users" {
  description = "Users granted query access to the optional Gemini Enterprise app."
  type        = list(string)
  default     = []
}

variable "gemini_enterprise_app_groups" {
  description = "Groups granted query access to the optional Gemini Enterprise app."
  type        = list(string)
  default     = []
}

variable "additional_iam_bindings" {
  description = "Extra project-level IAM bindings, applied verbatim. `member` must include its prefix (user:, group:, serviceAccount:, principalSet://)."
  type = list(object({
    role   = string
    member = string
  }))
  default = []

  validation {
    condition     = alltrue([for b in var.additional_iam_bindings : startswith(b.role, "roles/") || startswith(b.role, "projects/")])
    error_message = "Every role in additional_iam_bindings must be either a predefined role starting with \"roles/\" (for example roles/discoveryengine.viewer) or a custom role starting with \"projects/\" (for example projects/my-project/roles/myCustomRole)."
  }
}

# ---- Gemini Enterprise app ----
# Optional Discovery Engine engine. Not required for notebooks; needs at least
# one grounding data store when enabled.

variable "enable_gemini_enterprise_app" {
  description = "Create the optional Gemini Enterprise application (Discovery Engine engine). Billable; consumes entitlements."
  type        = bool
  default     = false
}

variable "gemini_enterprise_app_id" {
  description = "Engine ID for the app. Immutable - changing it recreates the engine."
  type        = string
  default     = "gemini-enterprise-app"
}

variable "gemini_enterprise_app_display_name" {
  description = "Display name shown to end users for the app."
  type        = string
  default     = "Gemini Enterprise"
}

variable "company_name" {
  description = "Organisation name passed to the engine common config; may be surfaced to end users."
  type        = string
  default     = "Example Organisation"
}

variable "search_tier" {
  description = "Search tier for the app. Enterprise is required for the LLM add-on and affects billing."
  type        = string
  default     = "SEARCH_TIER_ENTERPRISE"

  validation {
    condition     = contains(["SEARCH_TIER_STANDARD", "SEARCH_TIER_ENTERPRISE"], var.search_tier)
    error_message = "search_tier must be either SEARCH_TIER_STANDARD or SEARCH_TIER_ENTERPRISE."
  }
}

variable "search_add_ons" {
  description = "Search add-ons. SEARCH_ADD_ON_LLM enables generative answers; empty list disables them."
  type        = list(string)
  default     = ["SEARCH_ADD_ON_LLM"]

  validation {
    condition     = alltrue([for a in var.search_add_ons : contains(["SEARCH_ADD_ON_LLM"], a)])
    error_message = "search_add_ons may only contain SEARCH_ADD_ON_LLM. Use an empty list to disable generative answers."
  }
}

# ---- Preview gate (Pre-GA) ----
# Exposing notebooks as a data store in a Gemini Enterprise app is Pre-GA and
# console-only: titles only (not notebook content), one data store per app, and
# region must match across notebooks, data store and app. Nothing is created by
# Terraform - these flags only emit the runbook. Off by default.

variable "enable_gemini_notebook_data_store_preview" {
  description = "Opt in to the Preview notebook-as-data-store integration; emits the console runbook only."
  type        = bool
  default     = false
}

variable "accept_pre_ga_terms" {
  description = "Acknowledge the Pre-GA Offerings Terms. Must be true before the preview flag is honoured (lifecycle precondition)."
  type        = bool
  default     = false
}

# ---- GCS grounding ----

variable "enable_gcs_data_store" {
  description = "Create a GCS bucket and data store for grounding documents. Bucket lives in `region`; the index in `location`."
  type        = bool
  default     = false
}

variable "gcs_data_store_id" {
  description = "Data store ID for the GCS grounding store. Immutable - recreating forces a full re-ingest."
  type        = string
  default     = "documents-data-store"
}

variable "gcs_data_store_display_name" {
  description = "Display name for the GCS grounding data store."
  type        = string
  default     = "Documents Grounding Store"
}

variable "gcs_bucket_name_prefix" {
  description = "Prefix for the generated unique bucket name. Ignored when gcs_bucket_name_override is set."
  type        = string
  default     = "gne-docs"

  # Only the prefix is checked here; the full name length (prefix + generated
  # suffix) is enforced by a lifecycle precondition in datastores.tf.
  validation {
    condition     = length(var.gcs_bucket_name_prefix) <= 20 && can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gcs_bucket_name_prefix))
    error_message = "gcs_bucket_name_prefix must be 20 characters or fewer and may contain only lowercase letters, numbers and hyphens, starting and ending with a letter or number. The final bucket name length (prefix plus the generated uniqueness suffix) is additionally enforced by a precondition in datastores.tf."
  }
}

variable "gcs_bucket_name_override" {
  description = "Explicit globally unique bucket name. Null generates one from gcs_bucket_name_prefix."
  type        = string
  default     = null

  validation {
    condition     = var.gcs_bucket_name_override == null || can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", coalesce(var.gcs_bucket_name_override, "xxx")))
    error_message = "gcs_bucket_name_override must be 3-63 characters long, contain only lowercase letters, numbers, hyphens, underscores and dots, and start and end with a letter or number. Bucket names must not begin with \"goog\" or contain \"google\" (or close misspellings), and dot-separated names have additional restrictions."
  }
}

variable "gcs_bucket_force_destroy" {
  description = "Let destroy delete the bucket while it still holds objects. Irreversible - leave false outside sandbox."
  type        = bool
  default     = false
}

variable "gcs_bucket_retention_days" {
  description = "Bucket retention policy in days; blocks delete/overwrite until objects reach that age. Null for none; not locked."
  type        = number
  default     = null
}

variable "gcs_bucket_log_bucket" {
  description = "Existing bucket to receive access logs for the grounding bucket. Null disables bucket logging."
  type        = string
  default     = null
}

# ---- BigQuery grounding ----

variable "enable_bigquery_data_store" {
  description = "Create a BigQuery dataset and data store for structured grounding data. Dataset and index locations are independent."
  type        = bool
  default     = false
}

variable "bigquery_data_store_id" {
  description = "Data store ID for the BigQuery grounding store. Immutable - recreating forces a full re-ingest."
  type        = string
  default     = "analytics-data-store"
}

variable "bigquery_data_store_display_name" {
  description = "Display name for the BigQuery grounding data store."
  type        = string
  default     = "Analytics Grounding Store"
}

variable "bigquery_dataset_id" {
  description = "BigQuery dataset ID. Letters, numbers and underscores only; immutable once created."
  type        = string
  default     = "gne_grounding"

  validation {
    # RE2 rejects repetition counts above 1000, so the length bound is checked
    # separately rather than inline as {1,1024}.
    condition     = can(regex("^[A-Za-z0-9_]+$", var.bigquery_dataset_id)) && length(var.bigquery_dataset_id) <= 1024
    error_message = "bigquery_dataset_id must contain only letters, numbers and underscores (no hyphens or spaces) and be between 1 and 1024 characters long."
  }
}

variable "bigquery_dataset_location" {
  description = "Dataset location, e.g. \"australia-southeast1\" or \"AU\". Null falls back to `region`. Immutable."
  type        = string
  default     = null
}

# ---- Model Armor ----
# Documentation only: no Model Armor resources are created. These values feed
# the manual runbook emitted by outputs.tf.

variable "enable_model_armor" {
  description = "Signal intent to use Model Armor. Creating and attaching the template is a manual console step."
  type        = bool
  default     = false
}

variable "model_armor_template_id" {
  description = "Model Armor template identifier for the outputs/runbook. Null if unused."
  type        = string
  default     = null
}
