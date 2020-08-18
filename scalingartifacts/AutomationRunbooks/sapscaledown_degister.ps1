    param(
        [Parameter(Mandatory = $true)]
        [string]$ScalingAutomationAccountName,
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

    [string[]]$logongroup = $scalingconfig.SAPLogonGroups.Split(",")
    [string[]]$servergroup = $scalingconfig.SAPServerGroups.Split(",")

    Write-Output "Scaling down app servers"
    $TargetAppServerCount = ($scalingconfig.CurrentAppCount - $decrementsize)
    if ($TargetAppServerCount -lt $scalingconfig.MinAppCount) {
    Write-Output "Target App Server Count is lower than min app server count set in Config table. Exiting"
    Exit 1
    }

    Write-Output "Decreasing app server count from $scalingconfig.CurrentAppCount to $TargetAppServerCount"

    for ($i = $scalingconfig.CurrentAppCount; $i -gt $TargetAppServerCount; $i--) {
        $appservername = $scalingconfig.SAPAppNamingPrefix  + $i
        Write-Output "Deregistering app servers from SMLG"
        $appserverlist = @()
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
        $response = Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain' -UseBasicParsing

        if ($response.StatusCode -ne 200) {
            Write-Output "Logic app to register logon group failed. Please check logs "
            Exit 1
        }
              
        Write-Output "App servers removed from logon groups in SAP"
        
        $TimeZone = ([System.TimeZoneInfo]::Local).Id
        $ScheduleTime = (Get-Date).AddMinutes($scalingconfig.SAPDeleteTimeout)
        New-AzAutomationSchedule -AutomationAccountName $ScalingAutomationAccountName `
                                 -Name "Schedule1-$appservername" `
                                 -StartTime $ScheduleTime `
                                 -ResourceGroupName $ConfigResourceGroup `
                                 -TimeZone $TimeZone `
                                 -OneTime

        Register-AzAutomationScheduledRunbook -RunbookName "SAPScaleDown-Delete" `
                                              -ScheduleName "Schedule1-$appservername"  `
                                              -ResourceGroupName $ConfigResourceGroup `
                                              -AutomationAccountName $ScalingAutomationAccountName `
                                              -Parameters @{"ScalingAutomationAccountName" = $ScalingAutomationAccountName ; "SAPSystemId" = $SAPSystemId ; "appservername" = $appservername ; "ConfigStorageAccount" = $ConfigStorageAccount ; "ConfigResourceGroup" = $ConfigResourceGroup ; "ConfigTableName" = $ConfigTableName}

        Write-Output "App server deletion runbook scheduled to run at $ScheduleTime"
    }
}

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
   Exit 1
}
