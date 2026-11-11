<#
.VERSION 1.0.3
#>
# OBJECTIVE: Install a sea-green PowerShell theme in your startup profile.

#Requires -Version 5.1

# seaglass.ps1
# MSSP Field Kit -- Sea Glass terminal theme installer.
# Applies ANSI syntax highlighting and console colors for the current session.
# Writes theme block to $PROFILE.CurrentUserAllHosts for persistence.
# Removes any previously installed kit theme before writing.


Write-Host "Theme: Sea Glass"
Write-Host 'Install Sea Glass Theme'
Write-Host 'Install a sea-green PowerShell theme in your startup profile.'

$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
$Host.UI.RawUI.WindowTitle     = 'MSSP - Sea Glass Theme'
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$esc = [char]27
$cT1 = "${esc}[38;2;115;195;165m"
$cT2 = "${esc}[38;2;150;215;185m"
$cT3 = "${esc}[38;2;60;120;100m"
$cWh = "${esc}[97m"
$cWn = "${esc}[38;2;255;179;0m"
$cFl = "${esc}[38;2;215;100;90m"
$cR  = "${esc}[0m"

Write-Host ""
Write-Host "${cT3}. . . . . . . . . . . . . . . . . . . . .${cR}"
Write-Host "${cT1} MSSP FIELD KIT  ${cT3}--  ${cT2}SEA GLASS THEME${cR}"
Write-Host "${cT3}. . . . . . . . . . . . . . . . . . . . .${cR}"
Write-Host "${cT3}  Tidal. Unhurried. Correct.${cR}"
Write-Host ""

# -- Console colors -- current session -----------------------------------------
$Host.UI.RawUI.BackgroundColor            = 'Black'
$Host.UI.RawUI.ForegroundColor            = 'White'
$Host.PrivateData.ErrorForegroundColor    = 'Red'
$Host.PrivateData.ErrorBackgroundColor    = 'Black'
$Host.PrivateData.WarningForegroundColor  = 'Yellow'
$Host.PrivateData.WarningBackgroundColor  = 'Black'
$Host.PrivateData.DebugForegroundColor    = 'Green'
$Host.PrivateData.DebugBackgroundColor    = 'Black'
$Host.PrivateData.VerboseForegroundColor  = 'Cyan'
$Host.PrivateData.VerboseBackgroundColor  = 'Black'
$Host.PrivateData.ProgressForegroundColor = 'Cyan'
$Host.PrivateData.ProgressBackgroundColor = 'Black'

Write-Host "${cT1}[OK]  ${cWh}Console colors applied${cR}"

# -- PSReadLine syntax highlighting -- current session -------------------------
try {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -Colors @{
            Command            = "$esc[38;2;115;195;165m"   # sea glass
            Keyword            = "$esc[38;2;115;195;165m"   # sea glass
            Type               = "$esc[38;2;115;195;165m"   # sea glass
            Member             = "$esc[38;2;215;100;90m"    # coral
            String             = "$esc[38;2;215;100;90m"    # coral
            Number             = "$esc[38;2;150;215;185m"   # sea glass light
            Comment            = "$esc[38;2;60;120;100m"    # sea glass dim
            Parameter          = "$esc[97m"                 # bright white
            Operator           = "$esc[97m"                 # bright white
            Variable           = "$esc[97m"                 # bright white
            Default            = "$esc[97m"                 # bright white
            ContinuationPrompt = "$esc[97m"                 # bright white
            Error              = "$esc[38;2;225;85;75m"     # coral bright
            Selection          = "$esc[48;2;30;70;55m"      # sea glass dark bg
        }
    } else {
        Set-PSReadLineOption -Colors @{
            Command   = [ConsoleColor]::Cyan
            Keyword   = [ConsoleColor]::Cyan
            Type      = [ConsoleColor]::Cyan
            Member    = [ConsoleColor]::Yellow
            String    = [ConsoleColor]::Yellow
            Number    = [ConsoleColor]::Cyan
            Comment   = [ConsoleColor]::DarkCyan
            Parameter = [ConsoleColor]::White
            Operator  = [ConsoleColor]::White
            Variable  = [ConsoleColor]::White
            Default   = [ConsoleColor]::White
            Error     = [ConsoleColor]::Red
        }
    }
    Write-Host "${cT1}[OK]  ${cWh}PSReadLine syntax colors applied${cR}"
} catch {
    Write-Host "${cWn}[!!]  ${cWh}PSReadLine not available -- skipping syntax colors${cR}"
}

# -- Write to profile ----------------------------------------------------------
$profileBlock = @"

# - - - MSSP FIELD KIT - SEA GLASS THEME - - -
`$Host.UI.RawUI.BackgroundColor            = 'Black'
`$Host.UI.RawUI.ForegroundColor            = 'White'
`$Host.PrivateData.ErrorForegroundColor    = 'Red'
`$Host.PrivateData.ErrorBackgroundColor    = 'Black'
`$Host.PrivateData.WarningForegroundColor  = 'Yellow'
`$Host.PrivateData.WarningBackgroundColor  = 'Black'
`$Host.PrivateData.DebugForegroundColor    = 'Green'
`$Host.PrivateData.DebugBackgroundColor    = 'Black'
`$Host.PrivateData.VerboseForegroundColor  = 'Cyan'
`$Host.PrivateData.VerboseBackgroundColor  = 'Black'
`$Host.PrivateData.ProgressForegroundColor = 'Cyan'
`$Host.PrivateData.ProgressBackgroundColor = 'Black'
try {
    if (`$PSVersionTable.PSVersion.Major -ge 7) {
        `$e = [char]27
        Set-PSReadLineOption -Colors @{
            Command            = "`$e[38;2;115;195;165m"
            Keyword            = "`$e[38;2;115;195;165m"
            Type               = "`$e[38;2;115;195;165m"
            Member             = "`$e[38;2;215;100;90m"
            String             = "`$e[38;2;215;100;90m"
            Number             = "`$e[38;2;150;215;185m"
            Comment            = "`$e[38;2;60;120;100m"
            Parameter          = "`$e[97m"
            Operator           = "`$e[97m"
            Variable           = "`$e[97m"
            Default            = "`$e[97m"
            ContinuationPrompt = "`$e[97m"
            Error              = "`$e[38;2;225;85;75m"
            Selection          = "`$e[48;2;30;70;55m"
        }
    } else {
        Set-PSReadLineOption -Colors @{
            Command   = [ConsoleColor]::Cyan
            Keyword   = [ConsoleColor]::Cyan
            Type      = [ConsoleColor]::Cyan
            Member    = [ConsoleColor]::Yellow
            String    = [ConsoleColor]::Yellow
            Number    = [ConsoleColor]::Cyan
            Comment   = [ConsoleColor]::DarkCyan
            Parameter = [ConsoleColor]::White
            Operator  = [ConsoleColor]::White
            Variable  = [ConsoleColor]::White
            Default   = [ConsoleColor]::White
            Error     = [ConsoleColor]::Red
        }
    }
} catch {}
# - - - END SEA GLASS THEME - - -
"@

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profilePath
$tempPath = $null
try {
    $exists = [IO.File]::Exists($profilePath)
    $original = if ($exists) { [IO.File]::ReadAllText($profilePath) } else { '' }
    $updated = $original
    foreach ($theme in @('SEA GLASS THEME','SILICON VALLEY THEME','COBALT THEME','MINT CORAL THEME')) {
        $label = [regex]::Escape($theme)
        $pattern = "(?ms)^# - - - MSSP FIELD KIT - $label - - -[^\S\r\n]*\r?\n.*?^# - - - END $label - - -[^\S\r\n]*(?:\r?\n|$)"
        $updated = [regex]::Replace($updated,$pattern,'')
    }
    if ($updated -match '(?im)^# - - - (?:MSSP FIELD KIT - |END )(?:SEA GLASS|SILICON VALLEY|COBALT|MINT CORAL) THEME - - -') {
        throw 'An incomplete managed theme block was found. Review the profile before installing.'
    }
    $eol = if ($original -match "\r\n") { "`r`n" } elseif ($original -match "\n") { "`n" } else { [Environment]::NewLine }
    $block = [regex]::Replace($profileBlock.TrimEnd("`r","`n"),'\r?\n',$eol)
    if ($updated.Length -gt 0 -and -not $updated.EndsWith("`n")) { $updated += $eol }
    $updated += $block + $eol

    Write-Host "Target profile: $profilePath"
    Write-Host 'Replace managed FIELD KIT theme blocks and install Sea Glass. Other profile content is preserved.'
    if ($updated -ceq $original) {
        Write-Host 'Status: Sea Glass is already installed.'
    } elseif ((Read-Host 'Type INSTALL to update the profile') -cne 'INSTALL') {
        Write-Host 'Status: Cancelled.'
    } else {
        [void][IO.Directory]::CreateDirectory($profileDir)
        $tempPath = Join-Path $profileDir ([IO.Path]::GetRandomFileName())
        [IO.File]::WriteAllText($tempPath,$updated,[Text.UTF8Encoding]::new($true))
        if ($exists) {
            if ([IO.File]::ReadAllText($profilePath) -cne $original) { throw 'Profile changed after preview. Run again.' }
            [IO.File]::Replace($tempPath,$profilePath,[System.Management.Automation.Language.NullString]::Value)
        } else {
            [IO.File]::Move($tempPath,$profilePath)
        }
        if ([IO.File]::ReadAllText($profilePath) -cne $updated) { throw 'Profile write could not be verified.' }
        Write-Host 'Status: Profile update verified.'
    }
} catch {
    Write-Host "Status: Profile update failed. $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($tempPath -and [IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
}

Write-Host ""
Write-Host "${cT3}. . . . . . . . . . . . . . . . . . . . .${cR}"
Write-Host "${cT3}  Tidal. Unhurried. Correct.${cR}"
Write-Host "${cT3}  Restart your terminal to confirm persistence.${cR}"
Write-Host "${cT3}  To revert: remove the SEA GLASS THEME block from your profile.${cR}"
Write-Host "${cT3}. . . . . . . . . . . . . . . . . . . . .${cR}"
Write-Host ""
Read-Host 'Press Enter to close session.'
