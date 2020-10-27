provider "azurerm" {
  version = "=2.23.0"
  features {}
}

resource "azurerm_resource_group" "scaling-rg" {
    name = var.rgname
    location = var.location
}

resource "azurerm_log_analytics_workspace" "sap-log" {
    name = var.loganalyticsworkspace
    resource_group_name = azurerm_resource_group.scaling-rg.name
    location = var.location
    sku = "PerGB2018"
    retention_in_days = "30"
}

resource "azurerm_template_deployment" "logicapp-datacoll" {
    name = "LogicAppDataCollDeployment"
    resource_group_name = azurerm_resource_group.scaling-rg.name
    template_body = file("logicapp_datacoll_deploy.json")
    parameters = {
        "LogicAppLocation" = var.location
        "LogicAppName" = var.logicapp-datacoll
        "RecurrenceInterval" = var.datacollectioninterval
        "LogAnalyticsWorkspaceId" = azurerm_log_analytics_workspace.sap-log.workspace_id
        "LogAnalyticsWorkspaceKey" = azurerm_log_analytics_workspace.sap-log.primary_shared_key
        "LogAnalyticsConnectionName" = "SapLogAnalyticsApiConn"
        "SAPUser" = var.sapodatauser
        "SAPPassword" = var.sapodatapasswd
        "SAPOdataUri" = var.sapodatauri
        "SAPSystemID" = var.sapsid   
    }
    deployment_mode = "Incremental"
}