#ResourceGroup to deploy resources related to autoscaling
rgname = "sapautoscale-test"
#Location to deploy resources related to autoscaling
location = "NorthEurope"
#Storage account name to be used for autoscaling config
storageaccount = "sapautoscalestorage"
#Automation account name to be used for autoscaling
automationaccount = "sapautoscale"
#Name of the LogicApp to be used for data collection from SAP
logicapp-datacoll = "logicapp-datacoll"
#Name of the LogicApp to be used for logon group registration
logicapp-sapregister = "logicapp-sapregister"
#SAP System ID for which autoscaling is configured. 
sapsid = "TST"
#Log analytics workspace to store SAP performance data. This workspace will be created by the template
loganalyticsworkspace = "sapmonloganalytics1" 
#Email recepient to receive notifications related to autoscaling
alertrecepient = "kavenka@microsoft.com"
#Name of the Onprem data gateway to be used by logicapp SAP connector. This should already be installed and configured
odgname = "kvscalinggw"
#Resource group of the Onprem data gateway
odgresourcegroup = "kvsapautoscaling"
#Location of the Onprem data gateway
odglocation = "WestCentralUS"
#Data collection interval in minutes. This will be used by the recurrence trigger of data collection logic app
datacollectioninterval = 5
#Odata url to be used by data collection logic app. 
sapodatauri = "http://40.69.93.19:8000/sap/opu/odata/sap/ZSCALINGDEMO_SRV/ZSDFMONSet"
#Instance number of the SAP system to be configured for autoscaling
sapinstnacenr = 00
#SAP User to be used by data collection logic app 
sapodatauser = "demouser"
#SAP User to be used by logon group registration logic app
sapregisteruser = "demouser"
#SAP System Client number
sapclient = "000"
#SAP Message server host. This will be used to configure RFC connection to be used by logic app SAP connector
sapmshost = "172.16.3.6"
#SAP message server port. This will be used to configure RFC connection to be used by logic app SAP connector
sapmsport = "3600"
#SAP Logongroup. This will be used to configure RFC connection to be used by logic app SAP connector
saplogongroup = "PUBLIC"
#Config below will be populated within a table in Storage account. They can be modified later after deployment as well.
scalingconfig = {
     sap1 = {
CurrentAppCount = 1
MaxAppCount = 4
MinAppAcount = 1
SAPAppLoadBalancer = "app-lb"
SAPAppNamingPrefix = "tst-app-avm-"
SAPAppVmSize = "Standard_D2s_v3"
SAPCustomImageid = "/subscriptions/afbba066-2190-4c21-b9ec-4a945b7bfbcc/resourceGroups/sap-images-rg/providers/Microsoft.Compute/galleries/s4hana1809.sles12/images/SAP-APP"
SAPDeleteTimeout = 10
SAPImageHostName = "tst-app-avm-0"
SAPInstanceNr = 00
SAPLogonGroups = "PUBLIC,TEST"
SAPRegion = "NorthEurope"
SAPResourceGroup = "SAP-Hack-Demo"
SAPServerGroups = "parallel_generators,TESTSERVERGROUP"
SAPShutdownTimeout = 10
SAPAvSet = "APP-AVSET"
SAPSubnet = "sap-subnet"
SAPVnet = "sap-vnet"
}
}
