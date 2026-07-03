resource "azurerm_monitor_action_group" "oncall" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "dev-oncall"
  enabled             = true

  email_receiver {
    name                    = "email-on-call"
    email_address           = var.alert_email_address
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-bidirectional-dev-error-rate"
  resource_group_name = var.resource_group_name
  scopes              = [var.appi_id]
  description         = "Soak gate: failed requests exceeded threshold — investigate before advancing deployment ring"
  severity            = 1
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "alert-bidirectional-dev-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_id]
  description         = "Soak gate: HTTP 5xx spike on App Service — possible regression"
  severity            = 2
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT1M"

  criteria {
    metric_namespace = "microsoft.web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}
