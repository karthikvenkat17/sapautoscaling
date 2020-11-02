# SAP Telemetry collection

This folder contains Terraform template to enable SAP telemetry collection bsaed on /SDF/MON data collection. The template deploys a logic app instance for data ingestion and log analytics workspace to dump the /sdf/mon_header data.

## Pre-requisites

- /SDF/MON or /SDF/SMON daily monitoring is enabled in SAP system. See here for details https://wiki.scn.sap.com/wiki/display/CPP/All+about+SMON#AllaboutSMON-Purpose
- This template uses ODATA for ingesting /sdf/mon_header table. ODATA service url is required as an input parameter for the template. Please see sample instructions [here](docs/sapodata.md) for creating the ODATA service in SAP.
- The SAP ODATA endpoint must be reachable from the Logic app instance. For prototype public IP can be used. For production use one of the VNET integration options available for Logic App.   
- Recurrence interval for Logic app instance needs to be decided. Based on this data for last 'n' minutes will be collected.  For example a recurrence interval of 5 min on Logic app will collect data for the past 5 minutes from the /sdf/mon_header table.
-  As this is a prototype we use Basic authentication with SAP credentials hardcoded directly in the Logic app. In production scenario the credentials should be fetched from Keyvault and/or alternate authentication mechannism like Client certificate should be considered.

## Installation

-  Clone this github repo. Navigate to telemetry folder and populate terraform.tfvars. Sample file with parameters is provided.
-  Run ``terraform init`` followed by ``terraform apply`` to deploy the required resources. 

## Post Steps

- Enable the data collection logic app. Check that the performance data is getting populated in Log analytics workspace. Custom log table will be created in log analytics workspace with naming convention SAPPerfmonSID_CL.

## Note 

Alternate mechanism of ingesting the performance data will be to use SAP connector of Logic app to make RFC calls for data collection. In this case ODATA service creation will not be required and on-prem data gateway can be leveraged for connectivity.  