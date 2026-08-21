# ==============================================================================
# datastores.tf — grounding data stores for Gemini Notebook / Gemini Enterprise
# ==============================================================================
# Provisions the containers for grounding content — an optional GCS bucket plus
# unstructured data store, an optional BigQuery dataset plus structured data
# store — and the IAM the Discovery Engine service agent needs to read them.
#
# Terraform creates EMPTY data stores. No provider resource imports documents;
# after apply, ingest via the console (AI Applications -> Data Stores -> Import
# data) or the Discovery Engine documents:import API. Re-applying never
# refreshes or re-imports content.
#
# region vs location — two different knobs:
#   var.region   = where the storage resources live (GCS bucket, BQ dataset).
#   var.location = the Discovery Engine multi-region holding the data stores
#                  and notebooks. Not a Compute region, not interchangeable.
# Australian at-rest residency is NOT available for var.location: supported
# multi-regions are global / us / eu; ca, in, asia-northeast1, sg and
# europe-west2 are allowlist-only (contact your Google account team). The
# default is "global".
# ==============================================================================

locals {
  # Build our own bucket only when GCS grounding is on and no pre-existing
  # bucket was supplied.
  create_gcs_bucket = var.enable_gcs_data_store && var.gcs_bucket_name_override == null

  # Splat over a counted resource yields [] when count = 0; the length() guard
  # keeps this a string (never null) so template interpolation cannot fail.
  gcs_bucket_suffix_candidates = random_id.bucket_suffix[*].hex
  gcs_bucket_suffix            = length(local.gcs_bucket_suffix_candidates) > 0 ? one(local.gcs_bucket_suffix_candidates) : ""

  gcs_bucket_generated_name = "${var.gcs_bucket_name_prefix}-${var.project_id}-${local.gcs_bucket_suffix}"
  gcs_bucket_name           = coalesce(var.gcs_bucket_name_override, local.gcs_bucket_generated_name)

  # Single source of truth consumed by gemini_enterprise.tf. Each branch
  # contributes an ID or "" (never null); compact() drops the empties.
  grounding_data_store_ids = compact(concat(
    [var.enable_gcs_data_store ? one(google_discovery_engine_data_store.gcs[*].data_store_id) : ""],
    [var.enable_bigquery_data_store ? one(google_discovery_engine_data_store.bigquery[*].data_store_id) : ""],
  ))
}

# ==============================================================================
# Cloud Storage grounding (unstructured documents)
# ==============================================================================

# ---- Bucket name uniqueness suffix ----
# Counted so BigQuery-only / bring-your-own-bucket runs leave no orphan in state.
resource "random_id" "bucket_suffix" {
  count = local.create_gcs_bucket ? 1 : 0

  byte_length = 4
}

# ---- Grounding document bucket ----
# gcs_bucket_name_override RENAMES the managed bucket; it does not adopt one. To
# point at an existing bucket, run
#   terraform import 'google_storage_bucket.documents[0]' <project>/<bucket-name>
# first, otherwise create fails with 409 alreadyExists.
resource "google_storage_bucket" "documents" {
  count = var.enable_gcs_data_store ? 1 : 0

  project       = var.project_id
  name          = local.gcs_bucket_name
  force_destroy = var.gcs_bucket_force_destroy

  # The GCS API canonicalises location to upper case; matching it avoids
  # cosmetic drift on refresh.
  location = upper(var.region)

  # ---- Hardening baseline ----
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = local.common_labels

  versioning {
    enabled = true
  }

  # ---- Optional access logging ----
  # The log bucket must already exist and grant the GCS log-delivery principal
  # write access; that is out of scope for this module.
  dynamic "logging" {
    for_each = var.gcs_bucket_log_bucket != null ? [1] : []

    content {
      log_bucket = var.gcs_bucket_log_bucket
    }
  }

  # ---- Optional WORM-style retention ----
  # retention_period is in seconds, hence the days * 86400 conversion.
  dynamic "retention_policy" {
    for_each = var.gcs_bucket_retention_days != null ? [1] : []

    content {
      retention_period = var.gcs_bucket_retention_days * 86400
    }
  }

  # ---- Noncurrent-version cleanup ----
  # Disabled whenever retention is in force: retention blocks deletion, so a
  # delete rule would only generate continuous failure noise.
  dynamic "lifecycle_rule" {
    for_each = var.gcs_bucket_retention_days == null ? [1] : []

    content {
      action {
        type = "Delete"
      }

      condition {
        num_newer_versions = 3
        with_state         = "ARCHIVED"
      }
    }
  }

  # Fail at plan time on an over-long bucket name rather than at apply time.
  lifecycle {
    precondition {
      condition     = length(local.gcs_bucket_name) >= 3 && length(local.gcs_bucket_name) <= 63
      error_message = "Computed Cloud Storage bucket name '${local.gcs_bucket_name}' is ${length(local.gcs_bucket_name)} characters; Cloud Storage requires 3-63 characters for a name without dots. Shorten gcs_bucket_name_prefix (the generated name is '<prefix>-<project_id>-<8 hex chars>', so the prefix must be at most 54 - length(project_id) characters) or set gcs_bucket_name_override to an explicit bucket name."
    }
  }

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Discovery Engine service agent -> read the grounding bucket ----
# Without this, imports fail on the source objects. Scoped to the bucket.
resource "google_storage_bucket_iam_member" "discoveryengine_reader" {
  count = var.enable_gcs_data_store ? 1 : 0

  bucket = google_storage_bucket.documents[0].name
  role   = "roles/storage.objectViewer"
  member = local.discoveryengine_service_agent_member

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Unstructured (GCS) data store ----
resource "google_discovery_engine_data_store" "gcs" {
  count = var.enable_gcs_data_store ? 1 : 0

  project           = var.project_id
  location          = var.location
  data_store_id     = var.gcs_data_store_id
  display_name      = var.gcs_data_store_display_name
  industry_vertical = "GENERIC"
  content_config    = "CONTENT_REQUIRED"
  solution_types    = ["SOLUTION_TYPE_SEARCH"]

  # Only relevant to PUBLIC_WEBSITE data stores.
  create_advanced_site_search = false

  # skip_default_schema_creation is left at its default (false): the Gemini
  # Enterprise app expects the default schema.

  lifecycle {
    ignore_changes = [
      document_processing_config,
    ]
  }

  depends_on = [
    time_sleep.wait_for_apis,
    google_storage_bucket_iam_member.discoveryengine_reader,
  ]
}

# ==============================================================================
# BigQuery grounding (structured records)
# ==============================================================================

# ---- Grounding dataset ----
resource "google_bigquery_dataset" "grounding" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project    = var.project_id
  dataset_id = var.bigquery_dataset_id

  # BigQuery echoes back the case you send, so no upper() normalisation here.
  location = coalesce(var.bigquery_dataset_location, var.region)

  labels = local.common_labels

  # delete_contents_on_destroy is deliberately left at its default (false):
  # dropping every table on destroy is an unacceptable blast radius.

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Discovery Engine service agent -> read the dataset ----
resource "google_bigquery_dataset_iam_member" "discoveryengine_reader" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project    = var.project_id
  dataset_id = google_bigquery_dataset.grounding[0].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = local.discoveryengine_service_agent_member

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Discovery Engine service agent -> run the import query jobs ----
# jobUser is project-level by design: BQ jobs are created in a project, not a
# dataset, so this cannot be scoped tighter.
resource "google_project_iam_member" "discoveryengine_bq_job_user" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = local.discoveryengine_service_agent_member

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Structured (BigQuery) data store ----
# NO_CONTENT is correct for structured records: documents are field/value data
# rather than uploaded files.
resource "google_discovery_engine_data_store" "bigquery" {
  count = var.enable_bigquery_data_store ? 1 : 0

  project           = var.project_id
  location          = var.location
  data_store_id     = var.bigquery_data_store_id
  display_name      = var.bigquery_data_store_display_name
  industry_vertical = "GENERIC"
  content_config    = "NO_CONTENT"
  solution_types    = ["SOLUTION_TYPE_SEARCH"]

  lifecycle {
    ignore_changes = [
      document_processing_config,
    ]
  }

  depends_on = [
    time_sleep.wait_for_apis,
    google_bigquery_dataset_iam_member.discoveryengine_reader,
    google_project_iam_member.discoveryengine_bq_job_user,
  ]
}
