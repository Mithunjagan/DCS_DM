[CmdletBinding()]
param(
    [ValidateSet(16, 64, 128, 512)]
    [int]$Delta = 128,

    [int]$Samples = 4096,

    [string]$OutputDirectory = "build/sim/delta-$Delta"
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputPath = Join-Path $repoRoot $OutputDirectory
$sources = @(
    (Join-Path $repoRoot 'DCS/sine_gen.v'),
    (Join-Path $repoRoot 'DCS/delta_modulator.v'),
    (Join-Path $repoRoot 'DCS/delta_demodulator.v'),
    (Join-Path $repoRoot 'DCS/tb_dm.v')
)

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    throw 'Icarus Verilog was not found. Install it, reopen PowerShell, then run: iverilog -V'
}

if (-not (Get-Command vvp -ErrorAction SilentlyContinue)) {
    throw 'The Icarus vvp runtime was not found. Reinstall Icarus Verilog and ensure it is on PATH.'
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
Push-Location $outputPath
try {
    & iverilog -g2012 -s tb_dm "-Ptb_dm.DELTA=$Delta" "-Ptb_dm.N=$Samples" -o tb_dm.vvp @sources
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed with exit code $LASTEXITCODE." }

    & vvp ./tb_dm.vvp
    if ($LASTEXITCODE -ne 0) { throw "vvp failed with exit code $LASTEXITCODE." }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host "Simulation complete: delta=$Delta, samples=$Samples"
Write-Host "CSV: $outputPath/dm_out.csv"
Write-Host "VCD: $outputPath/tb_dm.vcd"
