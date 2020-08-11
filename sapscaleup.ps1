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

    $storageaccountkey = (Get-AzStorageAccountKey -ResourceGroupName $ConfigResourceGroup -AccountName $ConfigStorageAccount)| Where-Object {$_.KeyName -eq "key1"}
    $storageaccountctx = New-AzStorageContext -StorageAccountName $ConfigStorageAccount -StorageAccountKey $storageaccountkey.value
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
    Write-Output "Creating SAP app server $appservername"
    $vnet = Get-AzVirtualNetwork -Name $scalingconfig.SAPVnet -ResourceGroupName $scalingconfig.SAPResourceGroup
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $scalingconfig.SAPSubnet -VirtualNetwork $vnet 

    # Create a virtual network card for the additional SAP server
    $nic = New-AzNetworkInterface `
        -Name "$appservername-nic" `
        -ResourceGroupName $scalingconfig.SAPResourceGroup `
        -Location $scalingconfig.SAPRegion `
        -SubnetId $subnet.id `
    
    Write-Output "Network Interface $nic.Name created"
  
    # Define a credential object
    $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

    # Create a virtual machine configuration
    $vmConfig = New-AzVMConfig `
        -VMName "$appservername" `
        -VMSize $scalingconfig.SAPAppVmSize | `
    Set-AzVMOperatingSystem `
        -Linux `
        -ComputerName "$appservername" `
        -Credential $cred `
        -DisablePasswordAuthentication | `
    Set-AzVMSourceImage `
        -Id $scalingconfig.SAPCustomImageid | `
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
        -ResourceGroupName $scalingconfig.SAPResourceGroup `
        -Location $scalingconfig.SAPRegion -VM $vmConfig

    Write-Output "App server $appservername creation completed"

#Installing app server
    $oldhostname = $scalingconfig.SAPImageHostname
    $Instancenr = $scalingconfig.SAPInstanceNr
    $scripturi = "https://$ConfigStorageAccount.blob.core.windows.net/script/appserver_install.sh"
    $Settings = @{"fileUris" = @($scripturi); "commandToExecute" = "./appserver_install.sh $SAPSystemID $Instancenr $oldhostname $appservername"};
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

    Write-Output "SAP app server $appservername installed successfully"

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

##Adding VM to logon groups
$lpinput = $appserverlist | ConvertTo-Json

$requesturi = 'https://prod-13.canadacentral.logic.azure.com:443/workflows/ab3a72323fb4439782629837019ba869/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cC_qcR0SvYNcFiGn94j-9_RaUX7WmheoFD-BtTNFjRE'

$response = Invoke-WebRequest $requesturi -Body $lpinput -Method 'POST' -ContentType 'text/plain' -UseBasicParsing

if ($response.StatusCode -ne 200) {
    Write-Output "Logic app to register logon group failed. Please check logs "
    Exit 1
}

Write-Output "App servers added to logon groups in SAP"

##Start-AzLogicApp `
#    -ResourceGroupName "SAP-Open-hack" `
#    -Name "kvsmlgregister" `
#    -Parameters $lpinput `
#    -TriggerName "manual" 

}

catch{
   Write-Output "Appserver scaling failed. See previous errors"
   Write-Output $_.Exception.Message`n
   Exit 1
}
