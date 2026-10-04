[CmdletBinding()]
param()
# Builds the FileSqueeze FFmpeg payload in Docker. Output: ffmpeg/out/.
$ErrorActionPreference = 'Stop'
$image = 'filesqueeze-ffmpeg-build'
$cache = Join-Path $PSScriptRoot 'cache'
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force -Path $cache, $out | Out-Null
docker build -t $image $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Docker image build failed.' }
docker run --rm -v "${cache}:/cache" -v "${out}:/out" $image
if ($LASTEXITCODE -ne 0) { throw 'FFmpeg build failed.' }
Get-ChildItem $out
