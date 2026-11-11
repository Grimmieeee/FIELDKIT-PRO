$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$files = @(Get-ChildItem -Path (Join-Path $root 'dist'), (Join-Path $root 'scripts') -Recurse -File -Filter '*.ps1')

$raw = & node -e "const {q}=require(process.argv[1]);process.stdout.write(JSON.stringify(q.ITEMS.filter(x=>x.type==='Quick Command').map(x=>[x.name,q.interactiveCommandText(x)])));" (Join-Path $PSScriptRoot 'release-loader.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Could not generate catalog CLI wrappers.' }
$commands = ConvertFrom-Json -InputObject $raw -NoEnumerate
if ($files.Count -eq 0 -or $commands.Count -eq 0) { throw 'No scripts or CLI wrappers were found.' }

$failures = @(
    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        foreach ($parseError in $parseErrors) {
            '{0}:{1}: {2}' -f $file.FullName, $parseError.Extent.StartLineNumber, $parseError.Message
        }
    }
    foreach ($command in $commands) {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($command[1], [ref]$tokens, [ref]$parseErrors)
        foreach ($parseError in $parseErrors) {
            '{0}:{1}: {2}' -f $command[0], $parseError.Extent.StartLineNumber, $parseError.Message
        }
    }
)
if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
Write-Host ("Parsed {0} scripts and {1} CLI wrappers." -f $files.Count, $commands.Count)
