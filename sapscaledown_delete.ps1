    param(
        [Parameter(Mandatory = $true)]
        [string]$ScalingAutomationAccountName,
        [Parameter(Mandatory = $true)]
        [string]$SAPSystemID,
        [string] $AzureEnvironment = 'AzureCloud',
        [Parameter(Mandatory = $true)]
        [string] $appservername,
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
        -Settings $Settings `
        -ProtectedSettings $ProtectedSettings

    Write-Output "SAP app server $appservername stoppped successfully"

    ##Deleteing App Server

    Remove-AzVM -ResourceGroupName $scalingconfig.SAPResourceGroup -Name $appservername -Force
    Remove-AzNetworkInterface -Name "$appservername-nic" -ResourceGroupName $scalingconfig.SAPResourceGroup -Force
    Remove-AzPublicIpAddress -Name "$appservername-pip" -ResourceGroupName $scalingconfig.SAPResourceGroup -Force


    ##Removing disks

    $disks = Get-AzDisk -ResourceGroupName $scalingconfig.SAPResourceGroup `
               -DiskName "$appservername*"

    foreach ($md in $disks) {
        if($null -eq $md.ManagedBy) {
            Write-Output "Deleting managed disk"
            $md | Remove-AzDisk -Force
            Write-Output "Deleted managed disk"
        }
        else{
            Write-Output "Managed disk still attached to $appservername"
        }
        
    }
      
       
    Write-Output "App server $appservername and associated resource deleted from resource group"
    
    ##Update the azure table with new app server count
    $scalingconfig.CurrentAppCount = ($scalingconfig.CurrentAppCount - 1)
    $scalingconfig | Update-AztableRow -table $configtable.CloudTable
    
    Write-Output "Config table updated the new app server count"
    Write-Output "Cleaning up schedule"
    Remove-AzAutomationSchedule -AutomationAccountName $ScalingAutomationAccountName `
                                -Name "Schedule1-$appservername" `
                                -ResourceGroupName $ConfigResourceGroup `
                                -Force 

    }

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
   Exit 1
}
