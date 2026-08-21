# ---- Deployment identity & placement ----

output "project_id" {
  description = "Project hosting the deployment."
  value       = var.project_id
}

output "discovery_engine_location" {
  description = "Discovery Engine multi-region/region. RESIDENCY: Australian at-rest residency is NOT available; supported multi-regions global (default)/us/eu, with ca, in, asia-northeast1, sg, europe-west2 allowlist-only (contact your Google account team)."
  value       = var.location
}

# ---- Service agent ----

output "discoveryengine_service_agent_email" {
  description = "Discovery Engine service agent email; grant it read access to any source bucket or dataset you ingest from."
  value       = local.discoveryengine_service_agent_email
}

output "discoveryengine_service_agent_member" {
  description = "Service agent as an IAM member string for downstream bindings."
  value       = local.discoveryengine_service_agent_member
}

# ---- Cloud Storage data store ----

output "gcs_bucket_name" {
  description = "Source document bucket. Null when enable_gcs_data_store is false."
  value       = var.enable_gcs_data_store ? google_storage_bucket.documents[0].name : null
}

output "gcs_bucket_url" {
  description = "gs:// URL of the source document bucket. Null when disabled."
  value       = var.enable_gcs_data_store ? google_storage_bucket.documents[0].url : null
}

output "gcs_data_store_id" {
  description = "Short ID of the GCS-backed data store. Null when disabled."
  value       = var.enable_gcs_data_store ? google_discovery_engine_data_store.gcs[0].data_store_id : null
}

output "gcs_data_store_name" {
  description = "Resource name of the GCS-backed data store. Null when disabled."
  value       = var.enable_gcs_data_store ? google_discovery_engine_data_store.gcs[0].name : null
}

# ---- BigQuery data store ----

output "bigquery_dataset_id" {
  description = "Dataset ID for structured grounding data. Null when enable_bigquery_data_store is false."
  value       = var.enable_bigquery_data_store ? google_bigquery_dataset.grounding[0].dataset_id : null
}

output "bigquery_data_store_id" {
  description = "Short ID of the BigQuery-backed data store. Null when disabled."
  value       = var.enable_bigquery_data_store ? google_discovery_engine_data_store.bigquery[0].data_store_id : null
}

output "bigquery_data_store_name" {
  description = "Resource name of the BigQuery-backed data store. Null when disabled."
  value       = var.enable_bigquery_data_store ? google_discovery_engine_data_store.bigquery[0].name : null
}

output "grounding_data_store_ids" {
  description = "All data store IDs available for grounding; empty when none are enabled."
  value       = local.grounding_data_store_ids
}

# ---- Gemini Enterprise app ----

output "gemini_enterprise_app_id" {
  description = "Engine ID of the Gemini Enterprise app. Null when enable_gemini_enterprise_app is false."
  value       = var.enable_gemini_enterprise_app ? google_discovery_engine_search_engine.app[0].engine_id : null
}

output "gemini_enterprise_app_name" {
  description = "Resource name of the Gemini Enterprise app. Null when disabled."
  value       = var.enable_gemini_enterprise_app ? google_discovery_engine_search_engine.app[0].name : null
}

# ---- Console entry points ----
# NEEDS VERIFICATION: "gen-app-builder" is the historical Agent Builder path and
# may be renamed. If a link 404s, use cloud_console_url and navigate manually.

output "gen_app_builder_engines_console_url" {
  description = "Console list of Gemini Enterprise apps / engines."
  value       = "https://console.cloud.google.com/gen-app-builder/engines?project=${var.project_id}"
}

output "gen_app_builder_data_stores_console_url" {
  description = "Console list of Discovery Engine data stores."
  value       = "https://console.cloud.google.com/gen-app-builder/data-stores?project=${var.project_id}"
}

output "cloud_console_url" {
  description = "Console landing page; start every manual runbook step here."
  value       = "https://console.cloud.google.com/welcome?project=${var.project_id}"
}

# ---- End-user access ----

output "end_user_access_instructions" {
  description = "How to obtain and distribute the end-user link. Deliberately not a URL."
  value       = <<-EOT
    The end-user link is generated per project and shown in the Cloud console on
    the Gemini Notebook Enterprise page only AFTER an identity provider is set.
    It cannot be constructed or guessed, so none is emitted here.

    Open the console for project ${var.project_id}, go to the Gemini Notebook
    Enterprise page, confirm the IdP is set, copy the generated link, distribute
    it to licensed users and record it in operational docs.

    Do NOT distribute https://notebooklm.google.com/ — wrong product surface.
  EOT
}

# ---- Manual runbook ----

locals {
  runbook_step_billing = <<-EOT
    [BILLING] Confirm billing is enabled and the account active on project
    ${var.project_id}; Discovery Engine will not serve without it.
  EOT

  runbook_step_subscription = <<-EOT
    [LICENCES] A licence is required IN ADDITION to the IAM role and cannot be
    automated. Decide whether licences are assigned per user or on first access.
      * The product was renamed Gemini Notebook Enterprise, but the SUBSCRIPTION
        is still sold as "NotebookLM Enterprise" — ask procurement for that name.
      * Licences are per multi-region: a user needing both "global" and "us"
        needs one in each. This deployment targets "${var.location}".
      * 15-5,000 licences per subscription; above 5,000 needs Google sales.
        A 14-day free trial is available.
  EOT

  runbook_step_model_armor = <<-EOT
    [MODEL ARMOR] Apply template "${coalesce(var.model_armor_template_id, "<template-id>")}" manually;
    Terraform creates no association. NEEDS VERIFICATION: console path
    unconfirmed — find Model Armor via the console search bar, not a guess.
  EOT

  runbook_step_idp_workforce = <<-EOT
    [IDENTITY PROVIDER] Set it in the Cloud console on the Gemini Notebook
    Enterprise page for ${var.project_id}. Console only: one IdP per project, no
    API, so Terraform cannot detect or correct drift. Changing it later is
    disruptive. Workforce Identity Federation — pool ${coalesce(var.workforce_pool_id, "<pool-id>")},
    provider ${coalesce(var.workforce_provider_id, "<provider-id>")}. `google.subject` MUST map to the
    email address field or licensing and sharing break; Entra ID apps need a
    group claim with "All groups".
  EOT

  runbook_step_idp_google = <<-EOT
    [IDENTITY PROVIDER] Set it in the Cloud console on the Gemini Notebook
    Enterprise page for ${var.project_id}. Console only: one IdP per project, no
    API, so Terraform cannot detect or correct drift. Changing it later is
    disruptive. Select the Google identity option
    (identity_provider_type = "${var.identity_provider_type}").
  EOT

  runbook_step_end_user_link = <<-EOT
    [END-USER LINK] Copy the end-user link from the Gemini Notebook Enterprise
    page in the Cloud console and distribute it; it appears only after the IdP
    is set. Do NOT hardcode https://notebooklm.google.com/ — wrong surface.
  EOT

  runbook_step_data_import = <<-EOT
    [DATA IMPORT] Terraform creates empty data stores and ingests nothing. Load
    content via console, gcloud or documents.import. Confirm the Discovery
    Engine service agent (${local.discoveryengine_service_agent_email}) can read
    the source bucket or dataset, then check the LRO for per-document failures.
  EOT

  runbook_step_notebook_data_store_preview = <<-EOT
    [PREVIEW] The Gemini Notebook data store must be created in the console:
    Pre-GA terms apply ("as is", may change or be withdrawn), console only,
    titles only (not notebook content), one data store per app, and notebooks /
    data store / app must share ${var.project_id} and region "${var.location}".
  EOT

  runbook_step_identity_provider = var.identity_provider_type == "workforce_identity_federation" ? local.runbook_step_idp_workforce : local.runbook_step_idp_google

  manual_runbook_steps = concat(
    [
      local.runbook_step_billing,
      local.runbook_step_subscription,
    ],
    var.enable_model_armor ? [local.runbook_step_model_armor] : [],
    [
      local.runbook_step_identity_provider,
      local.runbook_step_end_user_link,
    ],
    var.enable_gcs_data_store || var.enable_bigquery_data_store ? [local.runbook_step_data_import] : [],
    var.enable_gemini_notebook_data_store_preview ? [local.runbook_step_notebook_data_store_preview] : [],
  )
}

output "manual_runbook_steps" {
  description = "Ordered post-apply manual steps. Render with: terraform output -json manual_runbook_steps | jq -r '.[]'"
  value       = local.manual_runbook_steps
}
