# ==============================================================================
# Gemini Notebook Enterprise (formerly "NotebookLM Enterprise")
# main.tf - API enablement, Discovery Engine service agent, activation wait
# ==============================================================================
# The product was renamed NotebookLM Enterprise -> Gemini Notebook Enterprise;
# the SUBSCRIPTION is still sold under the old name.
#
# There is no Terraform resource for the product itself. This blueprint enables
# the Discovery Engine API, creates the service agent and wires IAM/grounding.
# Selecting the identity provider, assigning licences and creating notebooks are
# Cloud console / admin tasks with no Terraform surface.
#
# Providers: hashicorp/google, hashicorp/google-beta
# (google_project_service_identity), hashicorp/time (time_sleep).
# ==============================================================================

# ---- Locals ----

locals {
  # discoveryengine.googleapis.com is the only mandated API; the rest are added
  # only because an optional feature of this blueprint needs them.
  # Deliberately NOT enabled: notebooklm.googleapis.com (not a real API) and
  # aiplatform.googleapis.com (not required by the setup documentation).
  required_services = concat(
    ["discoveryengine.googleapis.com"],
    var.enable_gcs_data_store ? ["storage.googleapis.com"] : [],
    var.enable_bigquery_data_store ? ["bigquery.googleapis.com"] : []
  )

  # Label keys must be lowercase and hyphenated - "managedBy" is not valid.
  common_labels = merge(var.labels, {
    "managed-by" = "terraform"
    "solution"   = "gemini-notebook-enterprise"
  })

  # Sourced from the resource below so consumers get an implicit dependency.
  discoveryengine_service_agent_email  = google_project_service_identity.discoveryengine.email
  discoveryengine_service_agent_member = "serviceAccount:${local.discoveryengine_service_agent_email}"
}

# ---- API enablement ----

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  # Leave APIs enabled on destroy: other workloads likely depend on them, and
  # disabling Discovery Engine can orphan notebooks and data stores.
  disable_on_destroy         = false
  disable_dependent_services = false
}

# ---- Discovery Engine service agent (P4SA) ----

# google_project_service_identity is google-beta only. The service agent is
# needed for the grounding bucket / BigQuery dataset read grants in datastores.tf.
resource "google_project_service_identity" "discoveryengine" {
  provider = google-beta

  project = var.project_id
  service = "discoveryengine.googleapis.com"

  depends_on = [google_project_service.required]
}

# ---- Post-enablement activation wait ----

# Enabling the API returns success before the Discovery Engine control plane
# accepts resource-creation calls, so a fresh project fails the first apply with
# "Discovery Engine API has not completed initialization". Every downstream
# Discovery Engine resource MUST depend on this sleep, not on
# google_project_service.required directly.
resource "time_sleep" "wait_for_apis" {
  create_duration = var.api_activation_wait

  depends_on = [
    google_project_service.required,
    google_project_service_identity.discoveryengine
  ]
}
