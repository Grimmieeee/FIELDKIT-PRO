#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName
)
Write-Host 'GET-AZURE-VPN-CONNECTIONS.ps1 // READ ONLY'
Write-Host ''
Write-Host 'Objective: Show Azure-reported VPN gateway connection status for one resource group.'
Write-Host ''

$moduleNames = @('Az.Accounts', 'Az.Network')
foreach ($moduleName in $moduleNames) {
    $minimum = if ($moduleName -eq 'ExchangeOnlineManagement') { [version]'3.2.0' }
    $module = Get-Module -ListAvailable -Name $moduleName |
        Where-Object { -not $minimum -or $_.Version -ge $minimum } |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
            throw "Cannot install $moduleName. Install-Module is unavailable in this PowerShell session."
        }
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        Write-Host "Installing $moduleName for the current user..."
        $install = @{ Name = $moduleName; Scope = 'CurrentUser'; Repository = 'PSGallery'; Force = $true; ErrorAction = 'Stop' }
        if ($minimum) { $install.MinimumVersion = $minimum }
        Install-Module @install
        $module = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { -not $minimum -or $_.Version -ge $minimum } |
            Sort-Object Version -Descending | Select-Object -First 1
        if (-not $module) { throw "Installed module $moduleName could not be found." }
    }
    Import-Module $module.Path -ErrorAction Stop
}


Write-Host 'Show Azure-reported VPN connection status for one resource group.'
Write-Host ''

$context = Get-AzContext -ErrorAction Stop
if (-not $context -or -not $context.Subscription.Id) {
    throw 'No active Azure subscription. Run Connect-AzAccount, select the client subscription, and retry.'
}

if (-not $PSBoundParameters.ContainsKey('ResourceGroupName')) {
    $ResourceGroupName = Read-Host 'Resource group name'
}
$ResourceGroupName = $ResourceGroupName.Trim()
if (-not $ResourceGroupName) {
    throw 'Enter a resource group name.'
}

Write-Host 'TARGET'
Write-Host "Subscription: $($context.Subscription.Name)"
Write-Host "Resource group: $ResourceGroupName"
Write-Host ''

$lookup = @{
    ResourceGroupName = $ResourceGroupName
    DefaultProfile = $context
    ErrorAction = 'Stop'
}
try {
    $connections = @(Get-AzVirtualNetworkGatewayConnection @lookup |
        Where-Object { $_.ConnectionType -in 'IPsec', 'Vnet2Vnet' } |
        Sort-Object Name)
}
catch {
    throw 'Unable to list VPN connections. Check the resource group name and Azure read access in the active subscription.'
}

Write-Host 'VPN CONNECTIONS'
if ($connections.Count -eq 0) {
    Write-Host 'Result: No VPN gateway connections found.'
}

$unverified = 0
foreach ($connection in $connections) {
    try {
        $detail = Get-AzVirtualNetworkGatewayConnection @lookup -Name $connection.Name
        $status = [string]$detail.ConnectionStatus
    }
    catch {
        $status = ''
    }
    if ([string]::IsNullOrWhiteSpace($status)) {
        $status = 'Unable to verify'
        $unverified++
    }
    Write-Host "Connection: $($connection.Name)"
    Write-Host "Status: $status"
    Write-Host ''
}

if ($unverified) {
    Write-Host "Unable to verify: $unverified of $($connections.Count). Retry or check connection health in Azure."
}
Write-Host ''
Write-Host ('COMPLETED: ' + (Get-Date -Format 'MM/dd/yyyy HH:mm'))
