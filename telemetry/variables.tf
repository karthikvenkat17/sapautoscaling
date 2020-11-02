variable "rgname" {
    description = "Resource group to deploy artifacts for SAP autoscaling solution"
}
variable "location" {
    description = "Specify Azure region to deploy the solution"
}
variable "logicapp-datacoll" {
    description = "Name of the Logic app to be used for SAP data collection"
}
variable "sapsid" {
    description = "SAP SystemID"
}
variable "loganalyticsworkspace" {
    description = "Log Analytics workspace to be used for SAP metrics collection"
}
variable "datacollectioninterval" {
        type = number
    description = "SAP performance Data collection interval in minutes"
}
variable "sapodatauri" {
    description = "SAP Odata Url to be used for data collection by logic app"
}
variable "sapinstnacenr" {
    description = "SAP Instance number"
}
variable "sapodatauser" {
    description = "SAP Username to be used for Odata calls"
}
variable "sapodatapasswd" {
    description = "Password for the SAP Odata user"
}
variable "sapclient" {
    description = "Client number of SAP system"
}
