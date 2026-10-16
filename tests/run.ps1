param(
    [string]$LuaPath,
    [string]$LuacPath,
    [string]$PythonPath
)

# Same shape as HCOneButton tests/run.ps1: parse every addon and test file with
# luac, then run each Lua suite in its own process; then the Python suites.
$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-Tool {
    param([string]$ExplicitPath, [string[]]$CommandNames, [string]$BundledPath)
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) { throw "Tool not found: $ExplicitPath" }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    foreach ($name in $CommandNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    if ($BundledPath -and $env:LOCALAPPDATA) {
        $bundled = Join-Path $env:LOCALAPPDATA $BundledPath
        if (Test-Path -LiteralPath $bundled) { return $bundled }
    }
    throw "Tool not found: $($CommandNames -join ', '). Pass it explicitly."
}

$lua = Resolve-Tool $LuaPath @("lua5.1", "lua") "Programs\Lua51\lua.exe"
$luac = Resolve-Tool $LuacPath @("luac5.1", "luac") "Programs\Lua51\luac.exe"
$python = Resolve-Tool $PythonPath @("py", "python3", "python") $null

Push-Location $repositoryRoot
try {
    & $python -B scripts/fetch_fixtures.py
    if ($LASTEXITCODE -ne 0) { throw "Fixture fetch failed" }

    $addonFiles = @(Get-ChildItem -LiteralPath "ForeverOneButton" -Recurse -Filter "*.lua" | Sort-Object FullName)
    foreach ($file in $addonFiles) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $($file.FullName)" }
    }
    Write-Host "addon parse: $($addonFiles.Count)/$($addonFiles.Count)"

    $testFiles = @(Get-ChildItem -LiteralPath "tests" -Filter "test_*.lua" | Sort-Object Name)
    foreach ($file in $testFiles) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test parse failed: $($file.FullName)" }
        & $lua $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $($file.FullName)" }
    }
    Write-Host "lua suites: $($testFiles.Count)/$($testFiles.Count)"

    & $python -B -m unittest discover -s tests -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) { throw "Python tests failed" }
}
finally {
    Pop-Location
}
