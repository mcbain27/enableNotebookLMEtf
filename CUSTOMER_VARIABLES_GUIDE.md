# Customer Configuration Guide: Terraform Variables Reference

This guide provides step-by-step instructions for customer platform teams and cloud administrators on how to configure `terraform.tfvars` to deploy **Gemini Enterprise** and **NotebookLM Enterprise**.

---

## 1. Quick Start: Creating Your `terraform.tfvars`

1. Navigate to the repository directory:
   ```bash
   cd enableNotebookLMEtf
   ```
2. Copy the example file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Open `terraform.tfvars` in your preferred editor and update the parameters described below.

---

## 2. Variables Summary & Decision Matrix

| Category | Variable Name | Required? | Default | What to Supply |
| :--- | :--- | :---: | :--- | :--- |
| **Target Project** | `project_id` | **YES** | *None* | The exact Google Cloud Project ID where services will be enabled. |
| **Region** | `region` | No | `"australia-southeast1"` | Primary GCP region for regional storage (GCS buckets, BigQuery datasets). |
| **Location** | `discovery_engine_location` | No | `"global"` | Geographic location for Discovery Engine apps (`global`, `us`, `eu`). |
| **Identity Provider** | `idp_type` | No | `"GSUITE"` | `"GSUITE"` (Google Workspace / Cloud Identity) or `"THIRD_PARTY"` (WIF). |
| **Identity Provider** | `workforce_pool_name` | Conditional | `null` | Workforce pool resource name (only if `idp_type = "THIRD_PARTY"`). |
| **Search Engine** | `enable_gemini_enterprise_search` | No | `true` | Set `true` to provision the Gemini Enterprise Search app. |
| **Search Engine** | `company_name` | No | `"Enterprise Organization"` | Your company or division name displayed in the AI assistant. |
| **Data Grounding** | `enable_gcs_data_store` | No | `true` | Set `true` to provision an enterprise document bucket + search data store. |
| **Data Grounding** | `enable_bigquery_data_store` | No | `false` | Set `true` if you have structured data in BigQuery for search grounding. |
| **Access Personas** | `admin_users` | **YES** | `[]` | List of admin email addresses (`["ai-admin@yourdomain.com"]`). |
| **Access Personas** | `editor_users` | No | `[]` | List of content curators who will upload and manage documents. |
| **Access Personas** | `standard_users` | **YES** | `[]` | List of standard business users who will use NotebookLM & Search. |

---

## 3. Detailed Variable Explanations

### Target Environment

#### `project_id` *(Type: string, Mandatory)*
* **Description**: The target Google Cloud Project ID.
* **Requirements**: The project must already exist and have billing enabled. The deploying user or pipeline service account must hold `roles/resourcemanager.projectIamAdmin` and `roles/serviceusage.serviceUsageAdmin` on this project.
* **Example**: `"corp-ai-production"`

#### `region` *(Type: string, Default: `"australia-southeast1"`)*
* **Description**: The GCP region where underlying Cloud Storage buckets and BigQuery datasets are provisioned.
* **Recommendations**: Keep as `"australia-southeast1"` (Sydney) for Australian data residency, or adjust to `"australia-southeast2"` (Melbourne) or your preferred region.

#### `discovery_engine_location` *(Type: string, Default: `"global"`)*
* **Description**: The Discovery Engine multi-region / location where the Search Engine and Data Stores are registered.
* **Supported values**: `"global"`, `"us"`, `"eu"`.

---

### Identity & Authentication

#### `idp_type` *(Type: string, Default: `"GSUITE"`)*
* **Description**: Dictates how user identities are resolved for document access control and enterprise search.
* **Options**:
  * `"GSUITE"`: **Recommended for Google Workspace customers.** Users log in with their corporate Google accounts, enabling seamless Google Drive and Docs integration with NotebookLM.
  * `"THIRD_PARTY"`: Used if your organization federates external corporate identities (e.g. Microsoft Entra ID / Okta) via Google Cloud Workforce Identity Federation (WIF).

#### `workforce_pool_name` *(Type: string, Default: `null`)*
* **Description**: Required only when `idp_type = "THIRD_PARTY"`.
* **Example**: `"locations/global/workforcePools/my-entra-workforce-pool"`

---

### Enterprise Grounding Data Stores

#### `enable_gcs_data_store` *(Type: bool, Default: `true`)*
* **Description**: Automatically creates a dedicated Cloud Storage bucket and registers an Unstructured Document Data Store with Gemini Enterprise Search.
* **Why enable?**: Allows your team to upload PDF, Word, HTML, and text documents for AI grounding.

#### `gcs_bucket_name_prefix` *(Type: string, Default: `"gemini-enterprise-docs"`)*
* **Description**: Prefix used when generating the unique GCS bucket name.

#### `enable_bigquery_data_store` *(Type: bool, Default: `false`)*
* **Description**: Provisions a BigQuery dataset and structured Data Store for tabular data search.
* **Default**: `false` (enable only if structured SQL / analytics grounding is needed).

---

### IAM User Persona Lists

The blueprint uses non-destructive, persona-based IAM bindings:

#### `admin_users` *(Type: list of strings, Recommended)*
* **Roles Granted**: `roles/discoveryengine.admin`, `roles/aiplatform.user`
* **Purpose**: Full control over search engines, schemas, data store synchronization, and AI settings.
* **Example**: `["lead-architect@yourdomain.com", "cloud-admin@yourdomain.com"]`

#### `editor_users` *(Type: list of strings, Optional)*
* **Roles Granted**: `roles/discoveryengine.editor`, `roles/aiplatform.user`
* **Purpose**: Content curators who manage documents, trigger re-indexing, and curate knowledge bases without project admin rights.
* **Example**: `["knowledge-manager@yourdomain.com"]`

#### `standard_users` *(Type: list of strings, Recommended)*
* **Roles Granted**: `roles/discoveryengine.viewer`, `roles/discoveryengine.user`
* **Purpose**: End-users and researchers who interact with the Gemini Enterprise search portal and create research notebooks in NotebookLM.
* **Example**: `["analyst1@yourdomain.com", "researcher2@yourdomain.com"]`

---

## 4. Example Scenarios

### Scenario A: Standard Google Workspace Organization (Most Common)

```hcl
# terraform.tfvars
project_id                = "acme-corp-ai"
region                    = "australia-southeast1"
discovery_engine_location = "global"

idp_type     = "GSUITE"
company_name = "ACME Corporation"

enable_gcs_data_store      = true
enable_bigquery_data_store = false

admin_users = [
  "admin.alice@acme.com"
]

editor_users = [
  "curator.bob@acme.com"
]

standard_users = [
  "user.charlie@acme.com",
  "user.danielle@acme.com"
]
```

---

### Scenario B: Enterprise with Workforce Identity Federation (Microsoft Entra ID / Okta)

```hcl
# terraform.tfvars
project_id                = "acme-corp-ai"
region                    = "australia-southeast1"
discovery_engine_location = "global"

idp_type            = "THIRD_PARTY"
workforce_pool_name = "locations/global/workforcePools/acme-entra-pool"
company_name        = "ACME Corporation"

enable_gcs_data_store      = true
enable_bigquery_data_store = false

admin_users = [
  "admin.alice@acme.com"
]

standard_users = [
  "user.charlie@acme.com"
]
```

---

### Scenario C: Advanced Multi-Store Setup (Documents + BigQuery Analytics)

```hcl
# terraform.tfvars
project_id                = "acme-corp-ai"
region                    = "australia-southeast1"
discovery_engine_location = "global"

idp_type     = "GSUITE"
company_name = "ACME Corporation"

enable_gcs_data_store            = true
gcs_data_store_id                = "corporate-knowledge-base"
gcs_data_store_display_name      = "Corporate Knowledge Base"

enable_bigquery_data_store       = true
bigquery_data_store_id           = "sales-analytics-store"
bigquery_data_store_display_name = "Sales Analytics Data Store"
bigquery_dataset_id              = "enterprise_sales_grounding"

admin_users = [
  "admin.alice@acme.com"
]

editor_users = [
  "data-steward@acme.com"
]

standard_users = [
  "data-analyst@acme.com"
]
```

---

## 5. Pre-Deployment Validation Checklist

Before executing `terraform apply`, verify the following:

- [ ] `project_id` matches an active Google Cloud Project with billing linked.
- [ ] You have run `gcloud auth application-default login` with an account holding Project IAM Admin rights.
- [ ] All user emails in `admin_users`, `editor_users`, and `standard_users` are valid corporate email addresses.
- [ ] Run `terraform plan` to preview the 10+ resources to be created.
- [ ] If using Google Workspace, confirm Super Admin access to [admin.google.com](https://admin.google.com/) to toggle NotebookLM ON for your domain.
