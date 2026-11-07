# Miggo AWS integration module for Terraform

Integrate Miggo with AWS to increase visibility into your cloud environment, enriching data from Miggo Sensors or other APMs. This allows Miggo to detect internet-facing services, anomalies, gaps, and drifts.

## Usage

```hcl
module "miggo-integration" {
  source  = "miggo-io/miggo-integration/aws"
  version = "1.7.0"

  tenant_id    = "<tenant id>"
  project_id   = "<project id>"
  tenant_email = "<email>"
  webhook_url  = "https://app.miggo.io/webhooks/integrate/aws"
  external_id  = "<tenant id>"
  role_name    = "ClusterInteractionRole" # optional
}
```

## Inputs

| Name | Description | Default |
|---|---|---|
| `tenant_id` | Miggo tenant id | required |
| `project_id` | Miggo project id | required |
| `tenant_email` | Email of the user connecting the account | required |
| `webhook_url` | Miggo webhook the module reports the integration to | required |
| `external_id` | External ID required by the role's trust policy | required |
| `role_name` | Name of the IAM role Miggo assumes. Changing it and re-applying renames the role; Miggo picks up the new one | `ClusterInteractionRole` |
| `tags` | Tags applied to every created resource | `{}` |
