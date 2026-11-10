[CmdletBinding()]
param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$source = Join-Path $root 'ForeverVoice'
$manifest = Get-Content -LiteralPath (Join-Path $source 'ForeverVoice.toc') -Raw
$version = [regex]::Match($manifest, '(?m)^## Version: (\d+\.\d+\.\d+)\s*$').Groups[1].Value
if (-not $version) { throw 'Parlance manifest has no valid version.' }

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$output = New-Item -ItemType Directory -Path $OutputDirectory -Force
$destination = Join-Path $output.FullName "Parlance-$version-curseforge-review.zip"
$files = [ordered]@{}
foreach ($name in @('ForeverVoice.toc', 'Sharing.lua', 'Core.lua', 'Editor.lua', 'README.txt')) {
    $files["ForeverVoice/$name"] = Join-Path $source $name
}
$temporaryZip = Join-Path $output.FullName ([guid]::NewGuid().ToString() + '.tmp')
try {
    $archive = [IO.Compression.ZipFile]::Open($temporaryZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entryName in @($files.Keys | Sort-Object)) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $files[$entryName], $entryName, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $archive.Dispose() }

    $archive = [IO.Compression.ZipFile]::OpenRead($temporaryZip)
    try {
        if ($archive.Entries.Count -ne $files.Count) { throw 'Unexpected Parlance archive contents.' }
        foreach ($entry in $archive.Entries) {
            if (-not $files.Contains($entry.FullName)) { throw "Unexpected file $($entry.FullName)" }
            $stream = $entry.Open()
            try {
                if ((Get-FileHash -InputStream $stream).Hash -ne (Get-FileHash -LiteralPath $files[$entry.FullName]).Hash) {
                    throw "ZIP content mismatch for $($entry.FullName)"
                }
            } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
    if ([IO.File]::Exists($destination)) {
        [IO.File]::Replace($temporaryZip, $destination, [NullString]::Value)
    } else {
        [IO.File]::Move($temporaryZip, $destination)
    }
} finally { [IO.File]::Delete($temporaryZip) }
Write-Output "Parlance addon-only review ZIP: $destination"
