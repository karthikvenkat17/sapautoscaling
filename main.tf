provider "azurerm" {
  version = "=2.10.0"
  features {}
}

resource "azurerm_resource_group" "scaling-rg" {
    name = var.rgname
}

resource "azurerm_log_analytics_workspace" "sap-log" {
    name = "SAPMonitoringWorkspace"
    resource_group_name = azurerm_resource_group.scaling-rg.name
    location = var.location
    sku = "PerGB2018"
    retention_in_days = "30"
}

resource "azurerm_automation_account" "scalingaccount" {
     name = var.automationaccount
     location = var.location
     resource_group_name = azurerm_resource_group.scaling-rg.name

}

resource "azurerm_automation_runbook" "scaleout" {
    name = "SAPScaleOut"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "Powershell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for Scaling out SAP app servers"
 publish_content_link {
     uri = ""
 }
}

resource "azurerm_automation_runbook" "scaledown-delete" {
    name = "SAPScaleDown-Delete"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "Powershell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for deleting SAP app servers as part of scale down"
 publish_content_link {
     uri = ""
 }
}

resource "azurerm_automation_runbook" "scaledown-deregister" {
    name = "SAPScaleDown-Degister"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "Powershell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for deregistering SAP app servers as part of scale down"
 publish_content_link {
     uri = ""
 }
}

resource "azurerm_storage_account" "scalingstorageaccount" {
    name  = var.storageaccount
    resource_group_name = azurerm_resource_group.scaling-rg.name
    location = var.location
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "scalingartifacts" {
  name                   = "artifacts"
  storage_account_name   = azurerm_storage_account.scalingstorageaccount.name
  container_access_type = "private"
}

resource "azurerm_storage_table" "scalingconfig" {
    name  = "scalingconfig"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
}

