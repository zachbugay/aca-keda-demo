resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.environment_name}"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  tags = merge(local.tags, {
    "azd-service-name" = "api"
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_pull.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.acr_pull.id
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = var.max_replicas
    polling_interval_in_seconds = 30
    cooldown_period_in_seconds = 30

    container {
      name   = "api"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    # ---------------------------------------------------------------
    # KEDA HTTP scaling rule
    # Scales out when concurrent HTTP requests exceed the threshold.
    # With a low threshold (default 10), this triggers visibly
    # during a k6 load test.
    # ---------------------------------------------------------------
    http_scale_rule {
      name                = "http-scaling-example"
      concurrent_requests = var.http_concurrency_threshold
    }
  }

  # Prevent Terraform from reverting the container image after azd deploy
  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}
