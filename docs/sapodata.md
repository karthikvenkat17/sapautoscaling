## SAP ODATA service creation for /SDF/MON mertics

- Go to transaction SEGW in the backend system. Create a gateway service.

![segwimage1](../images/segw_create.PNG)

- Right Click data model and choose Import from DDIC structure. Use /sdf/mon_header or /sdf/smon_header depending on the scenario.

![step1wizard](../images/step1_ddic.PNG)

- Choose the parameters which you want consume with this gateway service

![step2wizard](../images/step2_params.PNG)

- Choose columns for Primary key and Finish

![step3wizard](../images/step3_key.PNG)

- Save and generate the service using the Generate Runtime Objects option at the top

- Redefine the GET_ENTTITYSET method with the below code. Replace the table name with **/sdf/smon_header** if SMON is being used. We are not going to use the other methods in this demo so we will leave them empty. Save and activate the objects

``` abapcode
data: lv_osql_where_clause type string.
lv_osql_where_clause = io_tech_request_context->get_osql_where_clause( ).
select * from /sdf/mon_header
      into corresponding fields of table @et_entityset
      where (lv_osql_where_clause).
```
![se80modify](../images/se80_modify.PNG)

- Register and activate the service using transaction /IWFND/MAINT_SERVICE in gateway system.
- Check using the gateway client that you are able to query the service based on filter crtieria. See below for example

![gatewayclient](../images/gatewayclient.PNG)
