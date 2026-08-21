# ==============================================================================
# Gemini Notebook Enterprise — Terraform and provider configuration
# ==============================================================================
# Version floor 6.30.0 is the earliest provider carrying the resource schemas
# this blueprint uses (verified against v6.50.0); the < 7.0.0 ceiling stops a
# breaking major release being picked up silently. Do not lower the floor.
#
# Before committing, generate a multi-platform lock file so Linux CI, Apple
# Silicon/Intel Macs and Windows all validate against the same hashes:
#   terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 \
#     -platform=darwin_amd64 -platform=windows_amd64
# Commit the resulting .terraform.lock.hcl.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.30.0, < 7.0.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.30.0, < 7.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

# ---- Providers ----
# user_project_override + billing_project attribute quota and billing to the
# target project rather than the credential's own project — required by the
# Discovery Engine API under user or cross-project impersonated credentials.

provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

# google-beta is required, not a dead declaration: main.tf uses
# google_project_service_identity (google-beta only) to create the Discovery
# Engine service agent.

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}
