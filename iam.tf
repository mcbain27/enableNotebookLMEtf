# ==============================================================================
# Gemini Notebook Enterprise (formerly "NotebookLM Enterprise")
# iam.tf - Persona IAM bindings for notebooks and the Gemini Enterprise app
# ==============================================================================
# A LICENCE is required IN ADDITION to the IAM role - granting the role alone
# does not give a user access, and licensing cannot be automated (manual console
# assignment or first-access, and licences are per multi-region).
# The identity provider is configured in the Cloud console only (one per
# project, no API), so Terraform cannot manage it or detect drift on it.
#
# Prefer the *_groups inputs over *_users so joiner/mover/leaver stays in the
# directory rather than in Terraform state.
#
# Verified Discovery Engine role IDs (only the granted subset is used below):
#   notebooks   roles/discoveryengine.notebookLmUser   (end users)
#               roles/discoveryengine.notebookLmOwner  (admins)
#               roles/discoveryengine.notebookEditor
#               roles/discoveryengine.notebookOwner
#               roles/discoveryengine.notebookViewer
#   Gemini app  roles/discoveryengine.agentspaceUser
#               roles/discoveryengine.agentspaceAdmin
#               roles/discoveryengine.agentspaceEditor
#               roles/discoveryengine.agentspaceViewer
#               roles/discoveryengine.agentspaceRestrictedUser
# Broad roles (roles/discoveryengine.admin, .editor, .viewer, .user,
# .serviceAgent, .podcastApiUser) are never granted by default - use
# var.additional_iam_bindings.
# ==============================================================================

# ---- Locals: Workforce Identity Federation principals ----

locals {
  # Guard on both so principalSet strings are never assembled from a null pool.
  wif_enabled = var.identity_provider_type == "workforce_identity_federation" && var.workforce_pool_id != null

  # Pools always live under locations/global - this is the pool's own namespace,
  # not the Discovery Engine multi-region in var.location.
  wif_principal_base = local.wif_enabled ? "principalSet://iam.googleapis.com/locations/global/workforcePools/${var.workforce_pool_id}" : ""

  wif_all_identities_members = local.wif_enabled && var.grant_all_workforce_pool_identities ? ["${local.wif_principal_base}/*"] : []

  # Group ids as they appear in the google.groups attribute mapping.
  wif_group_members = local.wif_enabled ? [
    for group_id in var.workforce_pool_groups : "${local.wif_principal_base}/group/${group_id}"
  ] : []

  wif_notebooklm_user_members = concat(local.wif_all_identities_members, local.wif_group_members)
}

# ---- Locals: persona member lists ----
# "user:"/"group:" prefixes are built here, never hardcoded at the resource, so
# groups - and therefore directory-driven access - work.

locals {
  notebooklm_admin_members = distinct(concat(
    [for u in var.notebooklm_admin_users : "user:${u}"],
    [for g in var.notebooklm_admin_groups : "group:${g}"],
  ))

  # The only persona that receives federated principals: it maps to "can sign in
  # and use notebooks".
  notebooklm_user_members = distinct(concat(
    [for u in var.notebooklm_users : "user:${u}"],
    [for g in var.notebooklm_user_groups : "group:${g}"],
    local.wif_notebooklm_user_members,
  ))

  notebook_editor_members = distinct(concat(
    [for u in var.notebook_editor_users : "user:${u}"],
    [for g in var.notebook_editor_groups : "group:${g}"],
  ))

  notebook_viewer_members = distinct(concat(
    [for u in var.notebook_viewer_users : "user:${u}"],
    [for g in var.notebook_viewer_groups : "group:${g}"],
  ))

  gemini_app_admin_members = distinct(concat(
    [for u in var.gemini_enterprise_app_admin_users : "user:${u}"],
    [for g in var.gemini_enterprise_app_admin_groups : "group:${g}"],
  ))

  gemini_app_user_members = distinct(concat(
    [for u in var.gemini_enterprise_app_users : "user:${u}"],
    [for g in var.gemini_enterprise_app_groups : "group:${g}"],
  ))
}

# ---- NotebookLM personas ----
# All bindings wait on time_sleep.wait_for_apis (main.tf) so grants are not
# attempted before the Discovery Engine control plane has initialised. for_each
# keys come only from input variables, so the plan is always known at plan time.

# Admin persona - also the persona permitted to set the identity provider.
resource "google_project_iam_member" "notebooklm_admin" {
  for_each = toset(local.notebooklm_admin_members)

  project = var.project_id
  role    = "roles/discoveryengine.notebookLmOwner"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

# End-user sign-in role (still needs a licence).
resource "google_project_iam_member" "notebooklm_user" {
  for_each = toset(local.notebooklm_user_members)

  project = var.project_id
  role    = "roles/discoveryengine.notebookLmUser"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

# Optional finer-grained notebook personas.
resource "google_project_iam_member" "notebook_editor" {
  for_each = toset(local.notebook_editor_members)

  project = var.project_id
  role    = "roles/discoveryengine.notebookEditor"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_project_iam_member" "notebook_viewer" {
  for_each = toset(local.notebook_viewer_members)

  project = var.project_id
  role    = "roles/discoveryengine.notebookViewer"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Gemini Enterprise app personas ----
# Deliberately NOT gated on var.enable_gemini_enterprise_app: the roles are
# project-level and inert without an app, and pre-staging lets access approval
# finish before the app is switched on. To reverse this, gate both resources
# below and note the change in the README.

resource "google_project_iam_member" "gemini_app_admin" {
  for_each = toset(local.gemini_app_admin_members)

  project = var.project_id
  role    = "roles/discoveryengine.agentspaceAdmin"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_project_iam_member" "gemini_app_user" {
  for_each = toset(local.gemini_app_user_members)

  project = var.project_id
  role    = "roles/discoveryengine.agentspaceUser"
  member  = each.value

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Escape hatch: explicit additional bindings ----
# For anything the personas do not cover - service accounts, podcastApiUser, a
# narrowly-scoped Vertex AI role. Each entry supplies its own fully-qualified
# member, so raw principalSet:// and principal:// values are accepted.
#
#   additional_iam_bindings = [
#     {
#       role   = "roles/discoveryengine.podcastApiUser"
#       member = "serviceAccount:podcast-job@my-project.iam.gserviceaccount.com"
#     },
#   ]

resource "google_project_iam_member" "additional" {
  for_each = {
    for binding in var.additional_iam_bindings :
    "${binding.role}::${binding.member}" => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [time_sleep.wait_for_apis]
}

# ---- Needs verification against the customer environment ----
# 1. google.subject MUST map to the user's EMAIL ADDRESS; an object id or UPN
#    breaks sign-in and notebook sharing.
# 2. Confirm roles/discoveryengine.notebookLmUser accepts principalSet://
#    members in this environment; if not, grant to synced Cloud Identity groups.
# 3. Microsoft Entra ID: add a group claim set to "All groups". With SCIM /
#    extended attributes the google.groups mapping is ignored, which changes how
#    var.workforce_pool_groups behaves. Confirm the attribute mapping against
#    your IdP's Workforce Identity Federation setup documentation.
