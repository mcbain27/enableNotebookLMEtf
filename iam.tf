# ==============================================================================
# IAM Role Bindings for Gemini Enterprise & NotebookLM Personas
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Administrator Persona
# ------------------------------------------------------------------------------
locals {
  admin_members = toset([for u in var.admin_users : "user:${u}"])

  admin_roles = [
    "roles/discoveryengine.admin",
    "roles/aiplatform.user"
  ]

  admin_role_pairs = flatten([
    for member in local.admin_members : [
      for role in local.admin_roles : {
        member = member
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "admin_role_bindings" {
  for_each = {
    for pair in local.admin_role_pairs : "${pair.member}-${pair.role}" => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [
    google_project_service.required_apis
  ]
}

# ------------------------------------------------------------------------------
# 2. Editor / Content Curator Persona
# ------------------------------------------------------------------------------
locals {
  editor_members = toset([for u in var.editor_users : "user:${u}"])

  editor_roles = [
    "roles/discoveryengine.editor",
    "roles/aiplatform.user"
  ]

  editor_role_pairs = flatten([
    for member in local.editor_members : [
      for role in local.editor_roles : {
        member = member
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "editor_role_bindings" {
  for_each = {
    for pair in local.editor_role_pairs : "${pair.member}-${pair.role}" => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [
    google_project_service.required_apis
  ]
}

# ------------------------------------------------------------------------------
# 3. Standard End-User Persona (NotebookLM & Search Consumers)
# ------------------------------------------------------------------------------
locals {
  standard_members = toset([for u in var.standard_users : "user:${u}"])

  standard_roles = [
    "roles/discoveryengine.viewer",
    "roles/discoveryengine.user"
  ]

  standard_role_pairs = flatten([
    for member in local.standard_members : [
      for role in local.standard_roles : {
        member = member
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "standard_role_bindings" {
  for_each = {
    for pair in local.standard_role_pairs : "${pair.member}-${pair.role}" => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [
    google_project_service.required_apis
  ]
}
