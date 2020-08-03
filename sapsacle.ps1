param(
    [Parameter(Mandatory = $true)]
    [string] $SAPResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $AutomationAccountName,
    [Parameter(Mandatory = $true)]
    [string] $appserverprefix,
    [Parameter(Mandatory = $true)]
    [string] $sapvnet,
    [Parameter(Mandatory = $true)]
    [string] $sapsubnet,
    [Parameter(Mandatory = $true)]
    [string] $saplocation = '',
    [Parameter(Mandatory = $true)]
    [string]$customimageid,
    [Parameter(Mandatory = $true)]
    [string]$SAPSystemID,
    [Parameter(Mandatory = $true)]
    [string]$SAPInstanceNr = '00',
    [Parameter(Mandatory = $true)]
    [string]$SAPImageHostname,
    [string] $vmize = 'Standard_D2s_v3',
    [string] $AzureEnvironment = 'AzureCloud',
    ##[int] $CurrentAppServerCount = '1',
    [int] $incrementsize = '1',
    [bool] $scaleup = $true,
    [bool] $scaledown = $false,
    [Parameter(Mandatory = $true)]
    [string]$logongroups
)

Set-PSDebug -Trace 2

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

$appserverlist = @()
[string[]]$logongroup = $logongroups.Split(",")

##Get Current Appserver count
$storageaccountkey = (Get-AzStorageAccountKey -ResourceGroupName "kvsapautoscaling" -AccountName "kvscalingdemo")| Where-Object {$_.KeyName -eq "key1"}
$storageaccountctx = New-AzStorageContext -StorageAccountName "kvscalingdemo" -StorageAccountKey $storageaccountkey.value
##$storageaccountctx = New-AzStorageContext -ConnectionString "DefaultEndpointsProtocol=https;AccountName=kvscalingdemo;AccountKey=4MtxJCtakSQcJ/jo/MtyuEIi3kap9fGj1O6aYXJ6KOJQnHPBkw6UmdwpTqL5SUF9rcRb3UUgj+4EDRbqE/yy1Q==;EndpointSuffix=core.windows.net"

$configTable  = Get-AzStorageTable –Name "kvappservercount" -Context $storageaccountctx
$configTabledata = Get-AzTableRow -table $configTable.CloudTable -columnName "appservercount" 
Write-Output $configTabledata
$CurrentAppServerCount = $configTabledata.appservercount
Write-Output "Current appserver count $CurrentAppServerCount"

if ($scaleup){

$TargetAppServerCount = ($CurrentAppServerCount + $incrementsize)
Write-Output "Increasing app server count from $CurrentAppServerCount to $TargetAppServerCount"

for ($i = $CurrentAppServerCount+1; $i -le $TargetAppServerCount; $i++) {
    $appservername = $appserverprefix + $i
    Write-Output "Creating SAP app server $appservername"
    $vnet = Get-AzVirtualNetwork -Name $sapvnet -ResourceGroupName $SAPResourceGroupName
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $sapsubnet -VirtualNetwork $vnet 

    # Create a virtual network card for the additional SAP server
    $nic = New-AzNetworkInterface `
        -Name "$appservername-nic" `
        -ResourceGroupName $SAPResourceGroupName `
        -Location $saplocation `
        -SubnetId $subnet.id `
    
    Write-Output "Network Interface $nic.Name created"
  
    # Define a credential object
    $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

    # Create a virtual machine configuration
    $vmConfig = New-AzVMConfig `
        -VMName "$appservername" `
        -VMSize $vmize | `
    Set-AzVMOperatingSystem `
        -Linux `
        -ComputerName "$appservername" `
        -Credential $cred `
        -DisablePasswordAuthentication | `
    Set-AzVMSourceImage `
        -Id $customimageid | `
    Add-AzVMNetworkInterface `
        -Id $nic.Id

# Configure the SSH key
    $sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAxh8q9xepY+IqP5krrzh1sN20JfRycDJMh4WmXCWC4CNJUg/w6M7xQHSq9wNk9YiytVF+Y+bBz2TCYWj0iuvIrVPpsJBNNsDOeJ9O6/9XdXAcYKluMZrRlQlJETXACtOoPUE4kC/G2kxN2WzHRANmw2eSjUygcnzTitDWMyjXoQUGz4qjNF2gZ4KYl5Wt671LAefwHsbQjurr4VNHzvAXkUZ/bNBdrSKU5/bAU+4Qedivbor4udN1JMN6pouuUd+n9XHEdyhWbenynkkuI0nDTEWynG3afm0lfZuIPSo9iusA4I5Csy6RWabFNSUWXbCFZEDDrHexTNbkMEZGjkI/uw=="
    Add-AzVMSshPublicKey `
        -VM $vmconfig `
        -KeyData $sshPublicKey `
        -Path "/home/azureuser/.ssh/authorized_keys"

# Creating VM
    New-AzVM `
        -ResourceGroupName $SAPResourceGroupName `
        -Location $saplocation -VM $vmConfig

    Write-Output "App server $appservername creation completed"

#Installing app server
    $scripturi = "https://raw.githubusercontent.com/karthikvenkat17/sapautoscaling/master/appserver_install.sh?token=AKRWGXXGQEV4QBSDVS5JYRC67WQZG"
    $Settings = @{"fileUris" = @($scripturi); "commandToExecute" = "./appserver_install.sh $SAPSystemID $SAPImageHostname $appservername"};
    Set-AzVMExtension `
        -ResourceGroupName $SAPResourceGroupName `
        -Location $saplocation `
        -VMName $appservername `
        -Name "CustomScript" `
        -Publisher "Microsoft.Azure.Extensions" `
        -ExtensionType "CustomScript" `
        -TypeHandlerVersion "2.0" `
        -Settings $Settings 

    Write-Output "SAP app server $appservername installed successfully"

     foreach ($item in $logongroup) {
        Write-Output $item
        $appserverlist += [PSCustomObject]@{
            Applserver = $appservername + "_" + $SAPSystemID + "_" + $SAPInstanceNr
            Group = $item
            Action = "I"
        }
    }
}
   
Write-Output "SAP app servers scaled from $CurrentAppServerCount to $TargetAppServerCount"

##Update the azure table with new app server count
$configTabledata.appservercount = $TargetAppServerCount
$configTabledata | Update-AztableRow -table $cloudTabledata


$lpinput = $appserverlist | ConvertTo-Json

$requesturi = 'https://prod-13.canadacentral.logic.azure.com:443/workflows/ab3a72323fb4439782629837019ba869/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cC_qcR0SvYNcFiGn94j-9_RaUX7WmheoFD-BtTNFjRE'

$response = Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain'

Write-Output "Logic app output $response"
Write-Output "App servers added to logon groups in SAP"

##Start-AzLogicApp `
#    -ResourceGroupName "SAP-Open-hack" `
#    -Name "kvsmlgregister" `
#    -Parameters $lpinput `
#    -TriggerName "manual" 

}
elseif ($scaledown) {
Write-Output "Scaling down app servers"
$TargetAppServerCount = ($CurrentAppServerCount - $incrementsize)

Write-Output "Decreasing app server count from $CurrentAppServerCount to $TargetAppServerCount"
Write-Output "Deregistering app servers from SMLG"

for ($i = $CurrentAppServerCount-1; $i -ge $TargetAppServerCount; $i--) {
    $appservername = $appserverprefix + $i
    foreach ($item in $logongroup) {
        Write-Output $item
        $appserverlist += [PSCustomObject]@{
            Applserver = $appservername + "_" + $SAPSystemID + "_" + $SAPInstanceNr
            Group = $item
            Action = "D"
        }
    }
}

$lpinput = $appserverlist | ConvertTo-Json

$requesturi = 'https://prod-13.canadacentral.logic.azure.com:443/workflows/ab3a72323fb4439782629837019ba869/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cC_qcR0SvYNcFiGn94j-9_RaUX7WmheoFD-BtTNFjRE'

$response = Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain'

Write-Output "Logic app output $response"
Write-Output "App servers deleted from logon groups in SAP"

}

else {
    Write-Output "Nothing to do. Choose either scale up or scale down"
}
}

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
}
