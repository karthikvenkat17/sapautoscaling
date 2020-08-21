# Auto scaling of SAP app servers in Azure
This terraform template sets up components required to achieve auto scaling of SAP application servers in Azure based on SAP performance metrics. 

[Solution Overview](#solution-overview)
[Setup Instructions](#setup)

**Solution Overview**

SAP application server scale out architecture is as shown below

![scaleout image](images/scaleout.PNG)

SAP work process utilization data is collected from /sdf/mon table using logic app and dumped to log analytics workspace. Azure monitor is then used to query the table and alert based on set thresholds. The alert triggers an automation runbook which creates new app servers and uses another logic app to add the new SAP application server to logon groups. All config related to scaling is maintained in a table (called scalingconfig) within storage account. This includes properties of the new VM to be created, logon/server groups to be added to, max/min count for application servers etc. 

Scale down architecture is as shown 

![scaledown image](images/scaledown.PNG)

Scaledown is achieved by means of 2 automation runbooks.  The first runbook removes the application servers from the logon/server groups using logic app and schedules the second runbook based on a delay configurable using the scalingconfig table. This helps in existing user sessions to be drained out of SAP application server to be removed. The second runbook does a soft shutdown of the application server (shutdown timeout can also be configured using the config table) and then deletes the application servers.  Trigger for the scale down would depend on customer scenarios. It can be configured using one of the following methods

 - Schedule based - Schedule scale down runbook to be executed at the end of business day everyday. 
 - Utilization based
 - Alert status




