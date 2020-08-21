    param(
        [Parameter(Mandatory = $true)]
        [string]$SAPSystemID,
        [string] $AzureEnvironment = 'AzureCloud',
        [int] $incrementsize = '1',
        [Parameter(Mandatory = $true)]
        [string]$ConfigStorageAccount,
        [Parameter(Mandatory = $true)]
        [string]$ConfigResourceGroup,
        [Parameter(Mandatory = $true)]
        [string]$ConfigTableName
    )

try {
##Logging in to Azure
$RunAsConnection = Get-AutomationConnection -Name "AzureRunAsConnection" 
Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $RunAsConnection.Tenantid `
        -ApplicationId $RunAsConnection.Applicationid `
        -CertificateThumbprint $RunAsConnection.CertificateThumbprint `

Select-AzSubscription -SubscriptionId $RunAsConnection.SubscriptionID  | Write-Verbose

Write-Output "Authenticated succcessfully"

##Get Scaling information from the config table

#$storageaccountkey = (Get-AzStorageAccountKey -ResourceGroupName $ConfigResourceGroup -AccountName $ConfigStorageAccount)| Where-Object {$_.KeyName -eq "key1"}
$storageaccountctx = (Get-AzStorageAccount -ResourceGroupName $ConfigResourceGroup -AccountName $ConfigStorageAccount).Context
$sas = New-AzStorageAccountSASToken -Service "Blob,Table" `
                                         -ResourceType "Service,Container,Object" `
                                         -Permission "rw" `
                                         -Context $storageaccountctx

#$storageaccountctx = New-AzStorageContext -StorageAccountName $ConfigStorageAccount -SasToken $sas
$configTable  = Get-AzStorageTable –Name $ConfigTableName -Context $storageaccountctx
$scalingconfig = Get-AzTableRow -table $configTable.CloudTable -partitionKey "partition1" -rowKey $SAPSystemID 
Write-Output "Scaling will be performed with below data"
Write-Output $configTabledata

$appserverlist = @()
[string[]]$logongroup = $scalingconfig.SAPLogonGroups.Split(",")
[string[]]$servergroup = $scalingconfig.SAPServerGroups.Split(",")

$TargetAppServerCount = ($scalingconfig.CurrentAppCount + $incrementsize)
    if ($TargetAppServerCount -gt $scalingconfig.MaxAppCount) {
        Write-Output "Target App Server Count exceeds Max app server count set in Config table. Exiting"
        Exit 1
    }

Write-Output "Increasing app server count from $scalingconfig.CurrentAppCount to $TargetAppServerCount"

for ($i = $scalingconfig.CurrentAppCount+1; $i -le $TargetAppServerCount; $i++) {
    $appservername = $scalingconfig.SAPAppNamingPrefix + $i
    Write-Output "Creating SAP app server $appservername using ARM template"

$vnet = Get-AzVirtualNetwork -Name $scalingconfig.SAPVnet -ResourceGroupName $scalingconfig.SAPResourceGroup

$today=Get-Date -Format "MM-dd-yyyy"
$deploymentName="$appservername"+"Deployment"+"$today"

##Download the parameters JSON and update the values for the current run
$temppath = $env:TEMP
Get-AzStorageBlobContent -Container "artifacts" `
                         -Blob "appserver_deploy.parameters.json" `
                         -Context $storageaccountctx `
                         -Destination $temppath
$params = Get-Content "$temppath\appserver_deploy.parameters.json" | ConvertFrom-Json

$params.parameters.location.value = $scalingconfig.SAPRegion
$params.parameters.VirtualNetworkId.value = $vnet.Id
$params.parameters.subnetName.value = $scalingconfig.SAPSubnet
$params.parameters.virtualMachineName.value = $appservername
$params.parameters.virtualMachineSize.value = $scalingconfig.SAPAppVmSize
$params.parameters.customimageid.value = $scalingconfig.SAPCustomImageId
$params.parameters.networkInterfaceName.value = "$appservername-nic"
$params.parameters.publicIpAddressName.value = "$appservername-publicIp"

$params | ConvertTo-Json | set-content "$temppath\appserver_deploy.parameters.json"
Set-AzStorageBlobContent -Container "artifacts" -Blob "deploy_$appservername.parameters.json" -File "$temppath\appserver_deploy.parameters.json" -Context $storageaccountctx -Force

$deployment = New-AzResourceGroupDeployment `
                -DeploymentName $deploymentName `
                -ResourceGroupName $scalingconfig.SAPResourceGroup `
                -TemplateUri "https://$ConfigStorageAccount.blob.core.windows.net/artifacts/appserver_deploy.json$sas" `
                -TemplateParameterUri "https://$ConfigStorageAccount.blob.core.windows.net/artifacts/deploy_$appservername.parameters.json$sas"    


if ($deployment.ProvisioningState -ne "Succeeded") {
    Write-Output "ARM template deployment failed. Please check deployment logs"
    Exit 1
}

Write-Output "Deployment of $appservername is successful"

#Installing app server
    $oldhostname = $scalingconfig.SAPImageHostname
    $Instancenr = $scalingconfig.SAPInstanceNr
    $scripturi = "https://$ConfigStorageAccount.blob.core.windows.net/artifacts/appserver_setup.sh$sas"
    $ProtectedSettings = @{"fileUris" = @($scripturi); "commandToExecute" = "./appserver_setup.sh $SAPSystemID $Instancenr $oldhostname $appservername"};
    #$ProtectedSettings = @{"storageAccountName" = $ConfigStorageAccount; "storageAccountKey" = $sas };

    Set-AzVMExtension `
        -ResourceGroupName $scalingconfig.SAPResourceGroup `
        -Location $scalingconfig.SAPRegion `
        -VMName $appservername `
        -Name "CustomScript" `
        -Publisher "Microsoft.Azure.Extensions" `
        -ExtensionType "CustomScript" `
        -TypeHandlerVersion "2.0" `
        -ProtectedSettings $ProtectedSettings 
        #ProtectedSettings $ProtectedSettings 

    Write-Output "SAP app server $appservername installed successfully"

##Getting logon groups list for the current app server  
     foreach ($item in $logongroup) {
        Write-Output $item
        $appserverlist += [PSCustomObject]@{
            Applserver = $appservername + "_" + $SAPSystemID + "_" + $scalingconfig.SAPInstanceNr
            Group = $item
            GroupType = ""
            Action = "I"
        }
     }
     foreach ($item in $servergroup) {
        Write-Output $item
        $appserverlist += [PSCustomObject]@{
            Applserver = $appservername + "_" + $SAPSystemID + "_" + $scalingconfig.SAPInstanceNr
            Group = $item
            GroupType = "S"
            Action = "I"
            }
     }

    
}
   
Write-Output "SAP app servers scaled from ($scalingconfig.CurrentAppCount) to $TargetAppServerCount"

##Update the azure table with new app server count
$scalingconfig.CurrentAppCount = $TargetAppServerCount
$scalingconfig | Update-AztableRow -table $configtable.cloudTable

##Adding VM to logon groups
$lpinput = $appserverlist | ConvertTo-Json

$requesturi = 'logicappuri'

$response = Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain' -UseBasicParsing

if ($response.StatusCode -ne 200) {
    Write-Output "Logic app to register logon group failed. Please check logs "
    Exit 1
}

Write-Output "App servers added to logon groups in SAP"

#Adding VM to loadbalancer
if($null -ne $scalingconfig.SAPAppLoadBalancer)
{
    $lb = Get-AzLoadBalancer –name $scalingconfig.SAPAppLoadBalancer -resourcegroupname $scalingconfig.SAPResourceGroup
    $backend = Get-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $lb
    $nic = Get-AzNetworkInterface –name "$appservername-nic" -resourcegroupname $scalingconfig.SAPResourceGroup
    $nic.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend
    Set-AzNetworkInterface -NetworkInterface $nic
    Write-Output "VM $appservername added to load balancer successfully"
}
else {
    Write-Output "App server not part of any LB pool. Nothing to do"
}

}

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
   Exit 1
}
