<#
Convert zdtp.txt to UTF-8
Usage: .\convert-zdtp-to-utf8.ps1 [-Input 'zdtp.txt'] [-Output 'zdtp.utf8.txt']
#>
param(
    [string]$Input = 'zdtp.txt',
    [string]$Output = 'zdtp.utf8.txt'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$inPath = Join-Path $scriptDir $Input
$outPath = Join-Path $scriptDir $Output

if (-not (Test-Path $inPath)) {
    Write-Error "Input file not found: $inPath"
    exit 1
}

# Read bytes and decode using Big5 (CP950). Change encoding if the original is different.
$bytes = [System.IO.File]::ReadAllBytes($inPath)
$srcEnc = [System.Text.Encoding]::GetEncoding(950)  # Big5 / Traditional Chinese
$text = $srcEnc.GetString($bytes)

# Write as UTF-8 without BOM. To include BOM, use New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($outPath, $text, [System.Text.Encoding]::UTF8)

Write-Output "Converted: $inPath -> $outPath (UTF-8)"