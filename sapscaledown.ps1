    param(
        [Parameter(Mandatory = $true)]
        [string]$SAPSystemID,
        [string] $AzureEnvironment = 'AzureCloud',
        [int] $decrementsize = '1',
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

    $storageaccountkey = (Get-AzStorageAccountKey -ResourceGroupName $ConfigResourceGroup -AccountName $ConfigStorageAccount)| Where-Object {$_.KeyName -eq "key1"}
    $storageaccountctx = New-AzStorageContext -StorageAccountName $ConfigStorageAccount -StorageAccountKey $storageaccountkey.value
    $configTable  = Get-AzStorageTable –Name $ConfigTableName -Context $storageaccountctx
    $scalingconfig = Get-AzTableRow -table $configTable.CloudTable -partitionKey "partition1" -rowKey $SAPSystemID 
    Write-Output "Scaling will be performed with below data"
    Write-Output $configTabledata

    $appserverlist = @()
    [string[]]$logongroup = $scalingconfig.SAPLogonGroups.Split(",")
    [string[]]$servergroup = $scalingconfig.SAPServerGroups.Split(",")

    Write-Output "Scaling down app servers"
    $TargetAppServerCount = ($scalingconfig.CurrentAppCount - $decrementsize)
    if ($TargetAppServerCount -lt $scalingconfig.MinAppCount) {
    Write-Output "Target App Server Count is lower than min app server count set in Config table. Exiting"
    Exit 1
    }

    Write-Output "Decreasing app server count from $scalingconfig.CurrentAppCount to $TargetAppServerCount"

    for ($i = $scalingconfig.CurrentAppCount; $i -ge $TargetAppServerCount; $i--) {
        $appservername = $scalingconfig.SAPAppNamingPrefix  + $i
        Write-Output "Deregistering app servers from SMLG"
        foreach ($item in $logongroup) {
            Write-Output $item
            $appserverlist += [PSCustomObject]@{
            Applserver = $appservername + "_" + $SAPSystemID + "_" + $scalingconfig.SAPInstanceNr
            Group = $item
            GroupType = ""
            Action = "D"
        }
        }

        foreach ($item in $servergroup) {
            Write-Output $item
            $appserverlist += [PSCustomObject]@{
                Applserver = $appservername + "_" + $SAPSystemID + "_" + $scalingconfig.SAPInstanceNr
                Group = $item
                GroupType = "S"
                Action = "D"
                }
        }

        $lpinput = $appserverlist | ConvertTo-Json
        $requesturi = 'https://prod-13.canadacentral.logic.azure.com:443/workflows/ab3a72323fb4439782629837019ba869/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cC_qcR0SvYNcFiGn94j-9_RaUX7WmheoFD-BtTNFjRE'
        Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain' -UseBasicParsing
        Write-Output "App servers deleted from logon groups in SAP"

        #Stopping App server
        Write-Output "Stopping Appserver $appservername"
        $Instancenr = $scalingconfig.SAPInstancenr
        $Timeout = $scalingconfig.SAPShutdownTimeout
        $scripturi = "https://$ConfigStorageAccount.blob.core.windows.net/script/appserver_decom.sh"
        $Settings = @{"fileUris" = @($scripturi); "commandToExecute" = "./appserver_decom.sh $SAPSystemID $Instancenr $Timeout"};
        $ProtectedSettings = @{"storageAccountName" = $ConfigStorageAccount; "storageAccountKey" = $storageaccountkey.value };

        Set-AzVMExtension `
            -ResourceGroupName $scalingconfig.SAPResourceGroup `
            -Location $scalingconfig.SAPRegion `
            -VMName $appservername `
            -Name "CustomScript" `
            -Publisher "Microsoft.Azure.Extensions" `
            -ExtensionType "CustomScript" `
            -TypeHandlerVersion "2.0" `
            -Settings $Settings 
            -ProtectedSettings $ProtectedSettings

        Write-Output "SAP app server $appservername stoppped successfully"

        ##Deleteing App Server

        Remove-AzVM -ResourceGroupName $scalingconfig.SAPResourceGroup -Name $appservername -Force
        Remove-AzNetworkInterface -Name "$appservername-nic" -ResourceGroupName $scalingconfig.SAPResourceGroup -Force
        Remove-AzDisk -ResourceGroupName $scalingconfig.SAPResourceGroup -DiskName "$appservername*" -Force

    Write-Output "App server $appservername and associated resource deleted from resource group"
    
    ##Update the azure table with new app server count
        $scalingconfig.CurrentAppCount = $TargetAppServerCount
        $scalingconfig | Update-AztableRow -table $configtable.CloudTable
    
    Write-Output "Config table updated the new app server count $(scalingconfig.CurrentAppCount)"

    }
}

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
   Exit 1
}
