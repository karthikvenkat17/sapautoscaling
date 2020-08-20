provider "azurerm" {
  version = "=2.10.0"
  features {}
}

resource "azurerm_resource_group" "scaling-rg" {
    name = var.rgname
    location = var.location
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
     sku_name = "Basic"
}


resource "azurerm_automation_runbook" "scaleout" {
    depends_on = [azurerm_template_deployment.logicapp-sapregister]
    name = "SAPScaleOut"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "PowerShell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for Scaling out SAP app servers"
    content = replace(file("scalingartifacts/AutomationRunbooks/sapscaleup.ps1"),"logicappuri",azurerm_template_deployment.logicapp-sapregister.outputs["logicappuri"])
 publish_content_link {
     uri = "http://microsoft.com"
 }
}

resource "azurerm_automation_runbook" "scaledown-delete" {
    name = "SAPScaleDown-Delete"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "PowerShell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for deleting SAP app servers as part of scale down"
    content = file("scalingartifacts/AutomationRunbooks/sapscaledown_delete.ps1")
 publish_content_link {
     uri = "http://microsoft.com"
 }
}

resource "azurerm_automation_runbook" "scaledown-deregister" {
    depends_on = [azurerm_template_deployment.logicapp-sapregister]
    name = "SAPScaleDown-Degister"
    location = var.location
    resource_group_name = azurerm_resource_group.scaling-rg.name
    automation_account_name = azurerm_automation_account.scalingaccount.name
    runbook_type = "PowerShell"
    log_progress = "true"
    log_verbose = "true"
    description = "Runbook for deregistering SAP app servers as part of scale down"
    content = replace(file("scalingartifacts/AutomationRunbooks/sapscaledown_deregister.ps1"),"logicappuri",azurerm_template_deployment.logicapp-sapregister.outputs["logicappuri"])
 publish_content_link {
     uri = "http://microsoft.com"
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

resource "azurerm_storage_blob" "scalingscripts1" {
    name = "appserver_setup.sh"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
    storage_container_name = azurerm_storage_container.scalingartifacts.name
    type = "Block"
    source  = "./scalingartifacts/SAPSetupScripts/appserver_install.sh"
}

resource "azurerm_storage_blob" "scalingscripts2" {
    name = "appserver_decom.sh"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
    storage_container_name = azurerm_storage_container.scalingartifacts.name
    type = "Block"
    source  = "./scalingartifacts/SAPSetupScripts/appserver_decom.sh"
}

resource "azurerm_storage_blob" "scalingtemplates1" {
    name = "appserver_deploy.json"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
    storage_container_name = azurerm_storage_container.scalingartifacts.name
    type = "Block"
    source  = "./scalingartifacts/ARMTemplates/appserver_deploy.json"
}

resource "azurerm_storage_blob" "scalingtemplates" {
    name = "appserver_deploy.parameters.json"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
    storage_container_name = azurerm_storage_container.scalingartifacts.name
    type = "Block"
    source  = "./scalingartifacts/ARMTemplates/appserver_deploy.parameters.json"
}

resource "azurerm_storage_table" "scalingconfig" {
    name  = "scalingconfig"
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
}

resource "azurerm_storage_table_entity" "config" {
    storage_account_name = azurerm_storage_account.scalingstorageaccount.name
    table_name = azurerm_storage_table.scalingconfig.name
    partition_key = "partition1"
    row_key = var.sapsid
    for_each = var.scalingconfig
        entity = {
                CurrentAppCount = each.value["CurrentAppCount"]
                            MaxAppCount = each.value["MaxAppCount"]
        MinAppAcount = each.value["MinAppAcount"]
        SAPAppLoadBalancer = each.value["SAPAppLoadBalancer"]
        SAPAppNamingPrefix = each.value["SAPAppNamingPrefix"]
        SAPAppVmSize = each.value["SAPAppVmSize"]
        SAPCustomImageid = each.value["SAPCustomImageid"]
        SAPDeleteTimeout = each.value["SAPDeleteTimeout"]
        SAPImageHostName = each.value["SAPImageHostName"]
        SAPInstanceNr = each.value["SAPInstanceNr"]
        SAPLogonGroups = each.value["SAPLogonGroups"]
        SAPRegion = each.value["SAPRegion"]
        SAPResourceGroup = each.value["SAPResourceGroup"]
        SAPServerGroups = each.value["SAPServerGroups"]
        SAPShutdownTimeout = each.value["SAPShutdownTimeout"]
        SAPSubnet = each.value["SAPSubnet"]
        SAPVnet = each.value["SAPVnet"]

           }
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

resource "azurerm_template_deployment" "logicapp-sapregister" {
    name = "LogicAppSapRegisterDeployment"
    resource_group_name = azurerm_resource_group.scaling-rg.name
    template_body = file("logicapp_sapregister_deploy.json")
    parameters = {
        "LogicAppLocation" = var.location
        "LogicAppName" = var.logicapp-sapregister
        "SAPConnectionName" = "SapApiConnection"
        "OnPremGatewayName" = var.odgname
        "OnPremGatewayResourceGroup" = var.odgresourcegroup
        "OnPremGatewayLocation" = var.odglocation
        "SAPClient" = var.sapclient
        "SAPUserName" = var.sapregisteruser
        "SAPPassword" = var.sapregisterpasswd
        "SAPMessageServerHost" = var.sapmshost
        "SAPMessageServerPort" = var.sapmsport
        "SAPSystemId" = var.sapsid
        "SAPLogonGroup" = var.saplogongroup
        "office365ConnectionName" = "office365-1"
        "AlertEmailRecepient" = "alertrecepient"
    }
    deployment_mode = "Incremental"
}