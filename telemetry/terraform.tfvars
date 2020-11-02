#ResourceGroup to deploy resources related to autoscaling
rgname = "sapautoscale-test1"
#Location to deploy resources related to autoscaling
location = "NorthEurope"
#Name of the LogicApp to be used for data collection from SAP
logicapp-datacoll = "logicapp-datacoll1"
#SAP System ID for which autoscaling is configured. 
sapsid = "TST"
#Log analytics workspace to store SAP performance data. This workspace will be created by the template
loganalyticsworkspace = "kvsapmonloganalytics2" 
#Data collection interval in minutes. This will be used by the recurrence trigger of data collection logic app
datacollectioninterval = 5
#Odata url to be used by data collection logic app. 
sapodatauri = "http://40.69.93.19:8000/sap/opu/odata/sap/ZSCALINGDEMO_SRV/ZSDFMONSet"
#Instance number of the SAP system to be configured for autoscaling
sapinstnacenr = 00
#SAP User to be used by data collection logic app 
sapodatauser = "demouser"
#SAP System Client number
sapclient = "000"
