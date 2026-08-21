# Migration Notes — Gemini Notebook Enterprise Terraform Blueprint

Treat this as a **new deployment, not an in-place upgrade**: variable names, resource names and addresses all changed. No Terraform resource provisions Gemini Notebook Enterprise itself — this blueprint does IAM, an optional Gemini Enterprise app and optional grounding stores. See `README.md` for prerequisites and manual runbook steps.

| Old variable / resource | New | Why |
| :--- | :--- | :--- |
| `discovery_engine_location` (`"global"`, unvalidated) | `location` (`"global"`, validated) | Old value accepted any string, including Australian regions that don't exist for this product. |
| `region` (`"australia-southeast1"`) | `region` (same default, re-scoped) | Now documented as grounding GCS/BigQuery only. It never conferred residency. |
| `idp_type` (`GSUITE`\|`THIRD_PARTY`) | `identity_provider_type` (`google`\|`workforce_identity_federation`) | Renamed; descriptive enum. |
| `workforce_pool_name` | `workforce_pool_id` + `workforce_provider_id` | Split; the old variable was declared but never referenced — setting it did nothing. |
| `admin_users` | `notebooklm_admin_users` / `notebooklm_admin_groups` | `roles/discoveryengine.notebookLmOwner`. |
| `standard_users` | `notebooklm_users` / `notebooklm_user_groups` | `roles/discoveryengine.notebookLmUser`. |
| `editor_users` | `notebook_editor_users` / `notebook_editor_groups` | `roles/discoveryengine.notebookEditor`. |
| — | `notebook_viewer_users` / `notebook_viewer_groups` | Read-only persona was not previously expressible. |
| — | `gemini_enterprise_app_admin_users`/`_groups`, `gemini_enterprise_app_users`/`gemini_enterprise_app_groups` | `agentspaceAdmin` / `agentspaceUser`. |
| `"user:${u}"` hardcoded in locals | `*_users`/`*_groups` pairs + `workforce_pool_groups`, `grant_all_workforce_pool_identities` | Groups, service accounts and WIF principalSets were structurally impossible. |
| `roles/notebooklm.*` | `roles/discoveryengine.*` | No `notebooklm` IAM service exists; those bindings failed on apply. |
| `roles/aiplatform.user` on admins/editors | Removed; use `additional_iam_bindings` | Over-broad — arbitrary Vertex AI spend for a curation persona. |
| — | `additional_iam_bindings` (`list(object({role,member}))`) | Documented escape hatch for any fully qualified member. |
| `enable_gemini_enterprise_search` (`true`) | `enable_gemini_enterprise_app` (`false`) | Renamed; default flipped off. |
| `search_engine_id` / `_display_name` | `gemini_enterprise_app_id` / `gemini_enterprise_app_display_name` | Current product terminology. |
| Literals in `main.tf` | `search_tier`, `search_add_ons` | Tier and add-ons carry cost. |
| `enable_gcs_data_store` (`true`) | `enable_gcs_data_store` (`false`) | Default flipped off. |
| `gcs_bucket_name_prefix` (`"gemini-enterprise-docs"`) | `"gne-docs"`, validated, + `gcs_bucket_name_override` | 22-char prefix + project ID + suffix could break the 63-char limit mid-apply. |
| Bucket baseline | `public_access_prevention = "enforced"`, `gcs_bucket_retention_days`, `gcs_bucket_log_bucket`, `gcs_bucket_force_destroy` | Uniform access + versioning alone fail a public sector review. |
| `enable_bigquery_data_store` | Same name/default, now functional | The BigQuery store was never attached to the app. |
| Implicit dataset location | `bigquery_dataset_location` (`null` → `region`) | Was previously implicit. |
| Store/dataset ID defaults | `documents-data-store`, `analytics-data-store`, `gne_grounding`, `company_name = "Example Organisation"` | Defaults changed (incl. Australian English). |
| `count = enable_gemini_enterprise_search && enable_gcs_data_store` | `local.grounding_data_store_ids` + precondition | BigQuery-only was a silent no-op reporting success; now a plan-time error. |
| Service agent with no read access | `google_project_service_identity` (google-beta) + `storage.objectViewer`, `bigquery.dataViewer`, `bigquery.jobUser` | Stores existed and never populated. |
| Bucket ↔ store "pipeline" | Documented manual step | Import is console / `gcloud` / `documents.import`. No fake automation added. |
| — | `labels` (`map(string)`, `{}`) | No cost attribution, ownership or classification existed. |
| — | `api_activation_wait` (`"120s"`) | Fixes the first-apply API-initialisation race, previously shipped as a troubleshooting note. |
| — | `enable_gemini_notebook_data_store_preview`, `accept_pre_ga_terms` | Auditable Pre-GA decision; provisions nothing (console-only). |
| — | `enable_model_armor`, `model_armor_template_id` | Flags only; template creation/association are manual. |
| `aiplatform.googleapis.com` + invented APIs | `discoveryengine.googleapis.com` always, Storage/BigQuery conditionally | There is no `notebooklm.googleapis.com`. |
| `outputs.tf` hardcoded `https://notebooklm.google.com/` | Removed | Consumer/Workspace front door; the enterprise URL is console-generated. |
| `google-beta` unused; `random_id.bucket_suffix` unconditional | Beta used only for the service identity; suffix now conditional | Dead config and state churn. |
| Lock file with `darwin_arm64` only | `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64` | `terraform init` failed on Linux and CI. |
| No backend (local state) | `backend.tf.example` | No locking, durability or access control for a shared deployment. |
| README: enable NotebookLM in Workspace Admin Console | Configure the IdP in the Cloud console as a `notebookLmOwner` | The Workspace control governs a different product. |
| README: "e.g. Australia Region" | Explicit advisory: AU at-rest residency **not available** | Most serious defect — could have reached a security assessment or executive assurance. |

## Breaking changes

* No supported in-place state migration — plan a rebuild.
* Any access design written against `roles/notebooklm.*` must be redone.
* `enable_gemini_enterprise_app` and `enable_gcs_data_store` now default to `false`; set explicitly if you relied on the old `true`.
* `location` is validated (`global`, `us`, `eu`, `ca`, `in`, `asia-northeast1`, `sg`, `europe-west2`) and immutable in practice — changing it recreates Discovery Engine resources.
* `roles/aiplatform.user` is gone; re-add deliberately via `additional_iam_bindings`.
* Preconditions now fail at plan time where the old config silently did nothing or broke mid-apply — read that as the blueprint working.
* Data-store IDs, dataset ID and bucket prefix defaults changed; defaults create new resources rather than adopt old ones.
* Licensing is a prerequisite that cannot be automated: **a licence is required in addition to the IAM role.**
* Remote state (`backend.tf.example`) and a multi-platform lock file are expected before first apply.

Encryption at rest uses Google-managed keys by default; no configuration required.
