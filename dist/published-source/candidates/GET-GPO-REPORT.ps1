#Requires -Version 5.1
# .VERSION 0.1.0
# OBJECTIVE: Save an HTML settings report for one Group Policy Object.
<#
.SYNOPSIS
Read-only domain query with a local HTML export.
.DESCRIPTION
Resolves one exact GPO name, then reports by GUID in the resolved domain.
Optional Domain and Server pin the directory target; otherwise GroupPolicy's
current-domain/PDC defaults apply. Creates one new HTML file; never overwrites.
Does not edit/link/apply policy, open a browser or determine effective policy
on a user/computer. Requires GroupPolicy and GPO-read access.
#>
[CmdletBinding()]
param([string]$Name,[string]$Domain,[string]$Server,[string]$OutPath,[switch]$NoPause,[switch]$PassThru)
Write-Host "GPO Report"
$ErrorActionPreference='Stop'
try {
    Write-Host 'READ ONLY'
    Write-Host ''
    if ($env:OS -ne 'Windows_NT') { throw 'Windows with the GroupPolicy module is required.' }
    Import-Module GroupPolicy -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($Name)) {
        if ($NoPause) { throw 'Specify -Name.' }
        $Name=Read-Host 'GPO name'
    }
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Enter one exact GPO name.' }
    $query=@{Name=$Name;ErrorAction='Stop'}
    if ($Domain) { $query['Domain']=$Domain }
    if ($Server) { $query['Server']=$Server }
    $matches=@(Get-GPO @query)
    if ($matches.Count -ne 1) { throw 'One exact GPO must resolve.' }
    $gpo=$matches[0]
    if ($gpo.DisplayName -ine $Name -or -not $gpo.Id -or -not $gpo.DomainName) { throw 'GPO identity is incomplete or does not match the requested name.' }
    Write-Host "Policy: $($gpo.DisplayName)"
    Write-Host "Domain: $($gpo.DomainName)"
    if ($Server) { Write-Host "Controller: $Server" }
    if ([string]::IsNullOrWhiteSpace($OutPath)) {
        $OutPath=Join-Path $PSScriptRoot ('GPO-' + $gpo.Id + '-' + [guid]::NewGuid().ToString('N') + '.html')
    }
    if ([IO.Path]::GetExtension($OutPath) -ine '.html') { throw 'OutPath must be a new .html filename.' }
    $reportQuery=@{Guid=$gpo.Id;Domain=$gpo.DomainName;ReportType='Html';ErrorAction='Stop'}
    if ($Server) { $reportQuery['Server']=$Server }
    $html=Get-GPOReport @reportQuery
    if ([string]::IsNullOrWhiteSpace([string]$html)) { throw 'No report content returned.' }
    $reportPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)
    $stream=$null
    $writer=$null
    try {
        $stream=[IO.File]::Open($reportPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($true))
        $writer.Write([string]$html)
    } finally {
        if ($writer) { $writer.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
    Write-Host "Saved: $reportPath"
    Write-Host 'Policy settings only. Effective user/computer policy was not tested.'
    if ($PassThru) { [pscustomobject]@{Name=$gpo.DisplayName;Id=$gpo.Id;Domain=$gpo.DomainName;ReportPath=$reportPath} }
} catch {
    Write-Host ('FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the policy name, domain/controller, read permissions, and output path.'
    if ($NoPause) { throw }
} finally {
    if (-not $NoPause) { [void](Read-Host 'Press Enter to finish.') }
}
