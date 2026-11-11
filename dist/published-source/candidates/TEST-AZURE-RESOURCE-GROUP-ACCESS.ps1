#Requires -Version 5.1
param([Parameter(Mandatory)][ValidatePattern('^[\w.()-]{1,90}$')][string]$ResourceGroupName)
Write-Host "Test Azure Resource Group Access"
$ErrorActionPreference = 'Stop'
$context = Get-AzContext
if (-not $context.Subscription) { throw 'Connect to Azure and select the intended subscription.' }
$group = Get-AzResourceGroup -Name $ResourceGroupName -DefaultProfile $context
$resources = @(Get-AzResource -ResourceGroupName $group.ResourceGroupName -DefaultProfile $context)
Write-Host "Azure resource reads passed: $($context.Subscription.Name) / $($group.ResourceGroupName) ($($resources.Count) visible)"
$resources | Select-Object Name, ResourceType, Location
