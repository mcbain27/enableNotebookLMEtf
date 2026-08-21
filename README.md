# Gemini Notebook Enterprise — Terraform Blueprint

Terraform to enable **Gemini Notebook Enterprise** (formerly *NotebookLM Enterprise*) in an existing Google Cloud project, with optional grounding data stores and an optional Gemini Enterprise app.

> **Naming:** Google renamed the product to *Gemini Notebook Enterprise*. The **subscription is still sold as "NotebookLM Enterprise"**, and the IAM roles still use `notebookLm` spellings. Both names refer to the same thing.

---

## What this deploys

| | |
|---|---|
| **Always** | Discovery Engine API, service identity, API-propagation wait, IAM personas (admin / user / editor / viewer) |
| **Optional** | GCS grounding bucket + data store, BigQuery grounding dataset + data store, Gemini Enterprise app |

Everything optional is **off by default**. A minimal apply needs only `project_id` and one admin.

Encryption at rest uses **Google-managed keys** (the Google Cloud default). No key management required.

## What this does *not* do

These cannot be automated — Terraform has no API for them. They are covered in the [runbook](#manual-runbook) below.

- Purchasing the subscription and assigning user licences
- Setting the identity provider (console only, one per project)
- Creating the Preview notebook data store (console only)
- Creating and attaching a Model Armor template

---

## Prerequisites

1. **An existing project with billing enabled.**
2. **A NotebookLM Enterprise subscription** (see [Licensing](#licensing)). Terraform will apply successfully without one, but users cannot sign in.
3. **An identity provider** — Cloud Identity / Google Workspace, or Workforce Identity Federation.
4. **Deploy permissions:** `roles/serviceusage.serviceUsageAdmin`, `roles/resourcemanager.projectIamAdmin`, `roles/discoveryengine.admin`, plus `roles/storage.admin` / `roles/bigquery.admin` if using those data stores.
5. **Terraform >= 1.5** and `gcloud auth application-default login`.

---

## Quickstart

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — at minimum set project_id and notebooklm_admin_users
terraform init
terraform plan
terraform apply
```

Then work through the [runbook](#manual-runbook) — the deployment is not usable until the IdP is set and licences are assigned.

For remote state, see `backend.tf.example`.

---

## Variables

### Core

| Variable | Default | Purpose |
|---|---|---|
| `project_id` | *required* | Target project. |
| `location` | `"global"` | Where notebooks and indexes live. See [residency](#data-residency). |
| `region` | `"australia-southeast1"` | Grounding bucket / dataset region only. **Does not affect notebook residency.** |
| `labels` | `{}` | Applied to bucket and dataset. |
| `api_activation_wait` | `"120s"` | Pause after API enablement (fresh projects need this). |

### Identity

| Variable | Default | Purpose |
|---|---|---|
| `identity_provider_type` | `"google"` | `"google"` or `"workforce_identity_federation"`. One per project. |
| `workforce_pool_id` | `null` | Workforce pool short ID. |
| `workforce_provider_id` | `null` | Provider short ID, e.g. `"entra-id"`. |
| `workforce_pool_groups` | `[]` | External IdP group IDs granted user access. |
| `grant_all_workforce_pool_identities` | `false` | Grant every pool identity. Broad — prefer groups. |

### Access personas

Each persona takes both a `_users` and a `_groups` list. **Prefer groups.**

| Variable pair | Role granted |
|---|---|
| `notebooklm_admin_users` / `_groups` | `roles/discoveryengine.notebookLmOwner` |
| `notebooklm_users` / `notebooklm_user_groups` | `roles/discoveryengine.notebookLmUser` |
| `notebook_editor_users` / `_groups` | `roles/discoveryengine.notebookEditor` |
| `notebook_viewer_users` / `_groups` | `roles/discoveryengine.notebookViewer` |
| `gemini_enterprise_app_admin_users` / `_groups` | `roles/discoveryengine.agentspaceAdmin` |
| `gemini_enterprise_app_users` / `gemini_enterprise_app_groups` | `roles/discoveryengine.agentspaceUser` |
| `additional_iam_bindings` | Escape hatch; `member` must include its prefix. |

### Gemini Enterprise app (optional)

| Variable | Default | Purpose |
|---|---|---|
| `enable_gemini_enterprise_app` | `false` | Create the app. Billable. |
| `gemini_enterprise_app_id` | `"gemini-enterprise-app"` | Immutable. |
| `gemini_enterprise_app_display_name` | `"Gemini Enterprise"` | Shown to users. |
| `company_name` | `"Example Organisation"` | Surfaced in the app. |
| `search_tier` | `"SEARCH_TIER_ENTERPRISE"` | Required for the LLM add-on. |
| `search_add_ons` | `["SEARCH_ADD_ON_LLM"]` | Empty disables generative answers. |
| `enable_gemini_notebook_data_store_preview` | `false` | Preview integration — runbook only. |
| `accept_pre_ga_terms` | `false` | Must be `true` for the preview flag to apply. |

### Grounding data stores (optional)

| Variable | Default | Purpose |
|---|---|---|
| `enable_gcs_data_store` | `false` | Bucket + data store for documents. |
| `gcs_data_store_id` | `"documents-data-store"` | Immutable. |
| `gcs_bucket_name_prefix` | `"gne-docs"` | Used to generate a unique name. |
| `gcs_bucket_name_override` | `null` | Explicit bucket name. |
| `gcs_bucket_force_destroy` | `false` | Leave `false` outside dev. |
| `gcs_bucket_retention_days` | `null` | Retention policy. |
| `gcs_bucket_log_bucket` | `null` | Access log destination. |
| `enable_bigquery_data_store` | `false` | Dataset + data store for structured data. |
| `bigquery_data_store_id` | `"analytics-data-store"` | Immutable. |
| `bigquery_dataset_id` | `"gne_grounding"` | Letters, numbers, underscores only. |
| `bigquery_dataset_location` | `null` | Falls back to `region`. Immutable. |
| `enable_model_armor` | `false` | Signals intent; attachment is manual. |
| `model_armor_template_id` | `null` | Template ID for the runbook. |

Display-name variables (`*_display_name`) are omitted above; all default to sensible values.

---

## Manual runbook

Run **after** `terraform apply`. Order matters.

1. **Set the identity provider.** Console → Gemini Notebook Enterprise → identity settings. Choose Google, or third-party and supply the workforce pool and provider names. **One IdP per project, and there is no API for this.**
   - Workforce Identity Federation: `google.subject` must map to the user's email. For Microsoft Entra ID, add a group claim set to *All groups*. Configure SCIM if you want user/group autocomplete.
2. **Copy the end-user link** shown in the console and distribute it. It is generated per deployment — do not send users to the consumer NotebookLM site.
3. **Assign licences** (see below). Users cannot sign in without one, even with the correct IAM role.
4. *(Optional)* **Create the Preview notebook data store** — see [below](#preview-notebook-integration).
5. *(Optional)* **Create and attach a Model Armor template** if `enable_model_armor` is set.

### Licensing

- A licence is required **in addition to** the IAM role.
- Licences are **per multi-region** — a user needing both `global` and `us` needs one in each.
- Subscriptions hold 15–5,000 licences; above that, contact Google sales.
- A 14-day free trial (5,000 licences) is available.
- Assignment is manual per user, or automatic on first access.

---

## Data residency

**There is no Australian location for Gemini Notebook Enterprise.** Notebook content cannot be kept onshore today.

| Type | Locations |
|---|---|
| Multi-region | `global` (default), `us`, `eu` |
| In-country (GA, **allowlist only**) | `ca`, `in`, `asia-northeast1` (Japan), `sg`, `europe-west2` (UK) |

In-country access requires a request through your Google Cloud account team. Google recommends `global` unless you have a specific regulatory driver, as it gets the newest models and best latency.

`region` (the grounding bucket and BigQuery dataset) *can* be Australian — source documents stay onshore. The derived index and notebooks follow `location`, and do not.

---

## Preview notebook integration

Surfaces notebooks in the Gemini Enterprise app. **Pre-GA — off by default.**

Set `enable_gemini_notebook_data_store_preview = true` and `accept_pre_ga_terms = true`, then create the data store in the console (Gemini Enterprise → Data Stores → Create → *Gemini Notebook*) and attach it to the app.

Constraints worth knowing before you commit:

- **Titles only.** Notebook *content* is not indexed or searchable — users find a notebook by title, then open it.
- One Gemini Notebook data store per app; same project as the app.
- `location` must match across notebooks, data store and app.
- Each user sees only notebooks they created.
- Subject to Pre-GA Offerings Terms and the Generative AI Preview terms.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Discovery Engine API has not completed initialization` | API propagation. Increase `api_activation_wait` and re-apply. |
| User has the IAM role but cannot sign in | Missing licence, or a licence in the wrong multi-region. |
| `403` on the grounding bucket during ingestion | Service agent IAM still propagating; re-apply. |
| `Error 409: Data store already exists` | Data store IDs are immutable — a previous ID is still present. |
| `terraform init` checksum mismatch | Regenerate the lock file: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`. |
| Notebooks not appearing in the app | Preview data store missing, or `location` mismatch between notebooks, data store and app. |

---

## Before production

`terraform validate` confirms the configuration is internally sound but does not call Google APIs. **Run `terraform plan` against a real project first.** Console navigation paths change frequently; treat runbook steps as a guide.

See `MIGRATION_NOTES.md` if you are upgrading from an earlier version of this blueprint.
