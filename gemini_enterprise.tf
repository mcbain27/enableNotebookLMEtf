# ---- Gemini Enterprise app + Gemini Notebook preview notes ----
# Gemini Notebook Enterprise is the current name for "NotebookLM Enterprise".

locals {
  # Single greppable reference point for the preview flag; consumed by outputs.tf.
  gemini_notebook_preview_enabled = var.enable_gemini_notebook_data_store_preview
}

# ---- Gemini Enterprise app ----
# A Gemini Enterprise app is modelled as a Discovery Engine search engine; there
# is no dedicated resource type. The engine location must match the location of
# every data store in data_store_ids or the API rejects it at apply time.
resource "google_discovery_engine_search_engine" "app" {
  count = var.enable_gemini_enterprise_app ? 1 : 0

  project           = var.project_id
  location          = var.location
  collection_id     = "default_collection"
  engine_id         = var.gemini_enterprise_app_id
  display_name      = var.gemini_enterprise_app_display_name
  industry_vertical = "GENERIC"

  # Ground on whatever datastores.tf built (GCS only, BigQuery only, or both).
  data_store_ids = local.grounding_data_store_ids

  search_engine_config {
    search_tier = var.search_tier

    # SEARCH_ADD_ON_LLM is the only supported add-on and requires enterprise
    # tier; the API rejects it on SEARCH_TIER_STANDARD.
    search_add_ons = var.search_add_ons
  }

  common_config {
    company_name = var.company_name
  }

  lifecycle {
    precondition {
      condition     = length(local.grounding_data_store_ids) > 0
      error_message = "enable_gemini_enterprise_app = true requires at least one grounding data store. Set enable_gcs_data_store and/or enable_bigquery_data_store to true."
    }
  }

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Gemini Notebook data store — Pre-GA gate ----
# A `check` (warning, non-blocking) rather than a precondition: the preview
# provisions no resource here, so there is nothing guaranteed to exist to hang a
# precondition on. Move it to a variable `validation` block if a hard failure is
# required.
check "gemini_notebook_preview_terms" {
  assert {
    condition     = !var.enable_gemini_notebook_data_store_preview || var.accept_pre_ga_terms
    error_message = "enable_gemini_notebook_data_store_preview = true opts you into a Pre-GA (Preview) Google Cloud offering. The Gemini Notebook data store integration is governed by the Pre-GA Offerings Terms of the Google Cloud Service Specific Terms and by the Generative AI Preview terms: it is provided 'as is', may have limited support, may change in backwards-incompatible ways, and is not covered by any SLA or deprecation policy. Set accept_pre_ga_terms = true to acknowledge these terms, or set enable_gemini_notebook_data_store_preview = false."
  }
}

# ---- Gemini Notebook data store — manual console runbook ----
# PREVIEW / Pre-GA (Pre-GA Offerings Terms apply). CONSOLE ONLY: no API and no
# Terraform resource exists, so this configuration provisions nothing for it.
# It indexes notebook TITLES ONLY (never notebook content), results are per-user,
# ONE data store per app, and the region must match across the notebooks, the
# data store and the app. OFF by default and gated behind accept_pre_ga_terms.
#
# Console steps:
#   1. Confirm the app exists: AI Applications -> Apps -> var.gemini_enterprise_app_id.
#   2. Confirm the notebooks are in the same project and multi-region as the app.
#   3. AI Applications -> Data Stores -> Create data store.
#   4. Choose the "Gemini Notebook" source type (absent = preview not enabled
#      for this project/region; raise it with your account team).
#   5. Name the data store and confirm its region matches step 2.
#   6. Create it, then attach it to the app from step 1 — only one per app.
#   7. Validate as an end user who owns notebooks, not as an admin.
#   8. Record it in change management: it is not in Terraform state and will not
#      be recreated by a rebuild nor removed by `terraform destroy`.
#
# # NEEDS VERIFICATION: console menu labels shift between preview releases.
#
# ILLUSTRATIVE ONLY — DO NOT UNCOMMENT; the arguments below are not real and
# will not plan.
#
# resource "google_discovery_engine_data_store" "gemini_notebook_preview" {
#   count          = local.gemini_notebook_preview_enabled ? 1 : 0
#   project        = var.project_id
#   location       = var.location
#   data_store_id  = "gemini-notebook-preview"
#   content_config = "GEMINI_NOTEBOOK"                     # NOT REAL
#   solution_types = ["SOLUTION_TYPE_GEMINI_NOTEBOOK"]     # NOT REAL
# }
#
# ...and the app would then append it to data_store_ids via concat().
