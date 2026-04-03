# Azure Container Apps – KEDA HTTP Scaling Demo

Demonstrates automatic horizontal scaling on Azure Container Apps using a **KEDA HTTP scaling rule**. A .NET 10 minimal API returns its machineName in every response, letting you observe requests distributing across replicas as the app scales out under load.

Provisioned entirely via **Azure Developer CLI (`azd`)** with **Terraform** as the IaC provider.

## Architecture

```
┌───────────┐       ┌──────────────────────────────────────────────────┐
│   k6      │──────▶│  Azure Container Apps Environment               │
│  load     │       │  ┌──────────────────────────────────────┐       │
│  test     │       │  │  Container App (ca-api-*)            │       │
│           │       │  │  ┌─────────┐ ┌─────────┐ ┌────────┐ │       │
│           │       │  │  │Replica 1│ │Replica 2│ │Replica N│ │       │
│           │       │  │  │ :8080   │ │ :8080   │ │ :8080  │ │       │
│           │       │  │  └─────────┘ └─────────┘ └────────┘ │       │
│           │       │  │          KEDA HTTP Scaler            │       │
│           │       │  │    (concurrent_requests = 10)        │       │
│           │       │  └──────────────────────────────────────┘       │
│           │       │                                                  │
│           │       │  Log Analytics ◄── system & console logs        │
│           │       │  ACR (Basic)   ◄── container image              │
│           │       │  Managed Identity ── AcrPull (no passwords)     │
│           │       └──────────────────────────────────────────────────┘
└───────────┘
```

**Scaling behaviour**: min replicas = 0 (scale to zero), max replicas = 10. KEDA adds replicas when concurrent HTTP requests per replica exceed 10. After load subsides, replicas scale back to zero after a ~300 s cool-down.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Azure Developer CLI (`azd`) | latest | <https://aka.ms/azd-install> |
| Terraform | >= 1.1.7 | <https://developer.hashicorp.com/terraform/install> |
| Azure CLI (`az`) | >= 2.38 | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| Docker Desktop | latest | <https://www.docker.com/products/docker-desktop/> |
| .NET 10 SDK | 8.0+ | <https://dotnet.microsoft.com/download/dotnet/8.0> |
| k6 (Grafana) | latest | <https://k6.io/docs/get-started/installation/> |

## Quick Start

```PowerShell
# 1. Clone and navigate into the repo
cd aca-keda-demo

# 2. Log in to Azure
azd auth login

# 3. Provision infrastructure + build & deploy the container image
azd up
```

`azd up` will prompt for an environment name and Azure region, then:
1. Run `terraform apply` to create the Resource Group, Log Analytics Workspace, Container App Environment, ACR, Managed Identity, and Container App.
2. Build the .NET API Docker image and push it to ACR.
3. Deploy the image to the Container App.

## Run the Load Test

After `azd up` completes, grab the app URL:

```PowerShell
# Print the app URL
$ACA_ENDPOINT=$(azd env get-value SERVICE_API_ENDPOINT_URL)
```

Verify it works:

```PowerShell
curl $ACA_ENDPOINT
# → { "message": "Hello from the KEDA HTTP scaling demo!", "machineName": "...", "timestamp": "..." }
```

Run the k6 load test (ramps to 50 virtual users for 60 seconds):

```PowerShell
k6 run -e TARGET_URL=$ACA_ENDPOINT scripts/load-test.js
```

## Observe Scaling

### CLI – List Replicas

While the load test runs, check active replicas:

```PowerShell
# Get the resource group and app name
$RG=$(azd env get-value AZURE_RESOURCE_GROUP)
$APP=$(azd env get-value AZURE_CONTAINER_APP_NAME)

# List replicas (shows multiple replicas during load)
az containerapp replica list -n $APP -g $RG -o table
```

### Portal – Metrics Explorer

1. Open the Container App in the Azure portal.
2. Go to **Monitoring → Metrics**.
3. Select metric **Replica count**, aggregation **Max**, split by **Revision**.
4. Set the time range to the last 30 minutes.

You'll see the replica count spike during the load test and drop back after cool-down.

### Log Analytics – KQL Queries

Navigate to **Log Analytics workspace → Logs** in the Azure portal, or use the CLI:

```PowerShell
$WORKSPACE_ID=$(azd env get-value AZURE_LOG_ANALYTICS_WORKSPACE_ID)
```

> **Note**: Log Analytics has an ingestion delay of 2–5 minutes. Wait a few minutes after the load test before running queries.

The `queries/` directory contains ready-to-use KQL files:

#### 1. Scaling Events (`queries/scaling-events.kql`)

Shows system-level scaling events (revision provisioning, activation, deactivation):

```kql
ContainerAppSystemLogs_CL
| where ContainerAppName_s == "<CONTAINER_APP_NAME>"
| where Log_s has_any ("provisioned", "Provisioning", "Activating", "Deactivating", "scaling", "replica")
| project Timestamp = TimeGenerated, AppName = ContainerAppName_s, Revision = RevisionName_s, Message = Log_s
| order by Timestamp desc
| take 100
```

#### 2. Console Logs by Replica (`queries/console-logs-by-replica.kql`)

Request counts per replica — proves traffic was distributed across scaled-out instances:

```kql
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "<CONTAINER_APP_NAME>"
| where Log_s has "Request handled by replica"
| summarize RequestCount = count() by Replica = ContainerGroupName_s
| order by RequestCount desc
```

#### 3. Request Distribution Over Time (`queries/request-distribution.kql`)

Time-series view of requests per replica in 1-minute bins — visualises scale-out:

```kql
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "<CONTAINER_APP_NAME>"
| where Log_s has "Request handled by replica"
| summarize RequestCount = count() by Replica = ContainerGroupName_s, TimeBin = bin(TimeGenerated, 1m)
| order by TimeBin asc, Replica asc
| render timechart
```

#### 4. Replica Count Over Time (`queries/replica-count-over-time.kql`)

Approximate active replica count per minute:

```kql
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "<CONTAINER_APP_NAME>"
| summarize ReplicaCount = dcount(ContainerGroupName_s) by TimeBin = bin(TimeGenerated, 1m)
| order by TimeBin asc
| render timechart
```

## Scaling Configuration

The KEDA HTTP scale rule is defined in `infra/containerapp.tf`:

```hcl
http_scale_rule {
  name                = "http-scaling-example"
  concurrent_requests = var.http_concurrency_threshold
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `min_replicas` | 0 | Scale to zero when idle (300 s cool-down) |
| `max_replicas` | 10 | Maximum replica count |
| `http_concurrency_threshold` | 10 | Concurrent requests per replica before scaling out |

The intentionally low threshold (10) means KEDA will trigger scaling quickly during the demo. Adjust via Terraform variables:

```PowerShell
azd env set TF_VAR_max_replicas 20
azd env set TF_VAR_http_concurrency_threshold 50
azd provision
```

## Security

- **No admin credentials**: ACR admin is disabled; image pull uses a User-Assigned Managed Identity with the `AcrPull` role.
- **No secrets stored**: registry authentication is entirely identity-based.
- **External ingress**: auto transport with HTTPS.

## Clean Up

```PowerShell
azd down
```

This destroys all Azure resources created by the template.
