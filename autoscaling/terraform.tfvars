#ResourceGroup to deploy resources related to autoscaling
rgname = "sapautoscale-test1"
#Location to deploy resources related to autoscaling
location = "WestEurope"
#Storage account name to be used for autoscaling config
storageaccount = "sapautoscalestorage12"
#Automation account name to be used for autoscaling
automationaccount = "sapautoscale12"
#Name of the LogicApp to be used for logon group registration
logicapp-sapregister = "logicapp-sapregister12"
#SAP System ID for which autoscaling is configured. 
sapsid = "TST"
#Email recepient to receive notifications related to autoscaling
alertrecepient = "kavenka@microsoft.com"
#Name of the Onprem data gateway to be used by logicapp SAP connector. This should already be installed and configured
odgname = "kvscalinggw"
#Resource group of the Onprem data gateway
odgresourcegroup = "kvsapautoscaling"
#Location of the Onprem data gateway
odglocation = "WestCentralUS"
#Instance number of the SAP system to be configured for autoscaling
sapinstnacenr = 00
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
