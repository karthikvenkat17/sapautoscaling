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
    [string] $vmize = 'Standard_D2s_v3',
    [string] $AzureEnvironment = 'AzureCloud',
    [int] $CurrentAppServerCount = '1',
    [int] $incrementsize = '1',
    [bool] $scaleup = $true,
    [bool] $scaledown = $false
)

##Logging in to Azure
$RunAsConnection = Get-AutomationConnection -Name "AzureRunAsConnection" 
Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $RunAsConnection.Tenantid `
    -ApplicationId $RunAsConnection.Applicationid `
    -CertificateThumbprint $RunAsConnection.CertificateThumbprint `

Select-AzSubscription -SubscriptionId $RunAsConnection.SubscriptionID  | Write-Verbose

Write-Output "Authenticated succcessfully"

$TargetAppServerCount = ($CurrentAppServerCount + $incrementsize)

Write-Output "Increasing app server count from $CurrentAppServerCount to $TargetAppServerCount"

if ($scaleup){
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
}   
Write-Output "SAP app servers scaled from $CurrentAppServerCount to $TargetAppServerCount"

}
elseif ($scaledown) {
Write-Output "Scaling down app servers"    
} 

else {
    Write-Output "Nothing to do. Choose either scale up or scale down"
}

