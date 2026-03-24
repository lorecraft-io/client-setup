#Requires -Version 5.1
<#
.SYNOPSIS
    Step 2 — Dev Tools (Windows)
.DESCRIPTION
    Installs development tools on Windows 10/11
    Requires Step 1 to be completed first
.USAGE
    irm https://raw.githubusercontent.com/lorecraft-io/ai-super-user-setup/main/step-2/step-2-install.ps1 | iex
#>

$ErrorActionPreference = "Continue"
$script:Errors = 0

# --- Output helpers ---
function Write-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Blue }
function Write-Ok      { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$Msg) Write-Host "[FAIL] $Msg" -ForegroundColor Red; exit 1 }
function Write-SoftFail { param([string]$Msg) Write-Host "[FAIL] $Msg (non-critical, continuing...)" -ForegroundColor Red; $script:Errors++ }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ==========================================================================
# Verify Step 1 ran
# ==========================================================================
function Test-Prerequisites {
    if (!(Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Fail "Node.js not found. Run Step 1 first."
    }
    if (!(Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Fail "Claude Code not found. Run Step 1 first."
    }
    Write-Ok "Step 1 prerequisites verified (Node.js + Claude Code)"
}

# --- Generic winget install helper ---
function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$TestCommand
    )

    if (Get-Command $TestCommand -ErrorAction SilentlyContinue) {
        Write-Ok "$DisplayName already installed"
        return
    }

    Write-Info "Installing $DisplayName..."
    winget install --id $PackageId --accept-source-agreements --accept-package-agreements --silent 2>$null
    Refresh-Path

    if (Get-Command $TestCommand -ErrorAction SilentlyContinue) {
        Write-Ok "$DisplayName installed"
    } else {
        Write-SoftFail "$DisplayName installation failed"
    }
}

# ==========================================================================
# Python 3
# ==========================================================================
function Install-Python {
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        Write-Ok "Python 3 already installed ($(python3 --version))"
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pyVer = (python --version 2>&1).ToString()
        if ($pyVer -match "Python 3") {
            Write-Ok "Python 3 already installed ($pyVer)"
        } else {
            Write-Info "Installing Python 3..."
            winget install --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent 2>$null
            Refresh-Path
        }
    } else {
        Write-Info "Installing Python 3..."
        winget install --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent 2>$null
        Refresh-Path
    }

    $pyCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" }
             elseif (Get-Command python -ErrorAction SilentlyContinue) { "python" }
             else { $null }

    if ($pyCmd) {
        Write-Ok "Python available ($pyCmd)"
        & $pyCmd -m pip --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Info "Installing pip..."
            & $pyCmd -m ensurepip --upgrade 2>$null
        }
        Write-Ok "pip available"
    } else {
        Write-SoftFail "Python 3 installation failed"
    }

    $script:PythonCmd = $pyCmd
}

# ==========================================================================
# Pandoc
# ==========================================================================
function Install-Pandoc {
    Install-WithWinget -PackageId "JohnMacFarlane.Pandoc" -DisplayName "Pandoc" -TestCommand "pandoc"
}

# ==========================================================================
# xlsx2csv
# ==========================================================================
function Install-Xlsx2csv {
    $check = & $script:PythonCmd -c "import xlsx2csv" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "xlsx2csv already installed"
        return
    }

    Write-Info "Installing xlsx2csv..."
    & $script:PythonCmd -m pip install xlsx2csv --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $script:PythonCmd -m pip install --break-system-packages xlsx2csv --quiet 2>$null
    }

    $check2 = & $script:PythonCmd -c "import xlsx2csv" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "xlsx2csv installed"
    } else {
        Write-SoftFail "xlsx2csv installation failed"
    }
}

# ==========================================================================
# pdftotext (poppler)
# ==========================================================================
function Install-Pdftotext {
    if (Get-Command pdftotext -ErrorAction SilentlyContinue) {
        Write-Ok "pdftotext already installed"
        return
    }

    Write-Info "Installing poppler (pdftotext)..."
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install poppler -y --no-progress 2>$null
        Refresh-Path
        if (Get-Command pdftotext -ErrorAction SilentlyContinue) {
            Write-Ok "pdftotext installed"
        } else {
            Write-SoftFail "pdftotext installation failed. Try: choco install poppler"
        }
    } else {
        Write-SoftFail "pdftotext requires Chocolatey (choco install poppler) or manual install from: https://github.com/oschwartz10612/poppler-windows/releases"
    }
}

# ==========================================================================
# jq
# ==========================================================================
function Install-Jq {
    Install-WithWinget -PackageId "jqlang.jq" -DisplayName "jq" -TestCommand "jq"
}

# ==========================================================================
# ripgrep
# ==========================================================================
function Install-Ripgrep {
    Install-WithWinget -PackageId "BurntSushi.ripgrep.MSVC" -DisplayName "ripgrep" -TestCommand "rg"
}

# ==========================================================================
# GitHub CLI
# ==========================================================================
function Install-Gh {
    Install-WithWinget -PackageId "GitHub.cli" -DisplayName "GitHub CLI" -TestCommand "gh"
}

# ==========================================================================
# tree (built into Windows)
# ==========================================================================
function Install-Tree {
    Write-Ok "tree is built into Windows"
}

# ==========================================================================
# fzf
# ==========================================================================
function Install-Fzf {
    Install-WithWinget -PackageId "junegunn.fzf" -DisplayName "fzf" -TestCommand "fzf"
}

# ==========================================================================
# wget
# ==========================================================================
function Install-Wget {
    if (Get-Command wget.exe -ErrorAction SilentlyContinue) {
        Write-Ok "wget already installed"
        return
    }
    Install-WithWinget -PackageId "JernejSimoncic.Wget" -DisplayName "wget" -TestCommand "wget"
}

# ==========================================================================
# Self-test
# ==========================================================================
function Test-AllTools {
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Blue
    Write-Host "    Running Self-Test" -ForegroundColor Blue
    Write-Host "  ==========================================================" -ForegroundColor Blue
    Write-Host ""

    $pass = 0
    $fail = 0

    $tools = @(
        @("python3,python", "Python 3"),
        @("pandoc", "Pandoc"),
        @("pdftotext", "pdftotext"),
        @("jq", "jq"),
        @("rg", "ripgrep"),
        @("gh", "GitHub CLI"),
        @("fzf", "fzf"),
        @("wget.exe", "wget")
    )

    foreach ($tool in $tools) {
        $cmds = $tool[0] -split ","
        $name = $tool[1]
        $found = $false
        foreach ($cmd in $cmds) {
            if (Get-Command $cmd.Trim() -ErrorAction SilentlyContinue) { $found = $true; break }
        }
        if ($found) {
            Write-Ok "TEST: $name - installed"
            $pass++
        } else {
            Write-SoftFail "TEST: $name - not found"
            $fail++
        }
    }

    # tree is built-in
    Write-Ok "TEST: tree - built-in"
    $pass++

    # xlsx2csv
    $check = & $script:PythonCmd -c "import xlsx2csv" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "TEST: xlsx2csv - installed"
        $pass++
    } else {
        Write-SoftFail "TEST: xlsx2csv - not found"
        $fail++
    }

    Write-Host ""
    if ($fail -eq 0) {
        Write-Host "  All $pass tests passed." -ForegroundColor Green
    } else {
        Write-Host "  $pass passed, $fail failed." -ForegroundColor Yellow
        Write-Host "  Scroll up to see what went wrong." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Blue
}

# ==========================================================================
# Summary
# ==========================================================================
function Show-Summary {
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Green
    Write-Host "    Step 2 Complete - Dev Tools Installed" -ForegroundColor Green
    Write-Host "  ==========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Installed:"

    $tools = @(
        @("Python",     { & $script:PythonCmd --version 2>$null }),
        @("Pandoc",     { pandoc --version 2>$null | Select-Object -First 1 }),
        @("xlsx2csv",   { & $script:PythonCmd -c "import xlsx2csv; print('installed')" 2>$null }),
        @("pdftotext",  { if (Get-Command pdftotext -EA Silent) { "installed" } else { $null } }),
        @("jq",         { jq --version 2>$null }),
        @("ripgrep",    { rg --version 2>$null | Select-Object -First 1 }),
        @("GitHub CLI", { gh --version 2>$null | Select-Object -First 1 }),
        @("tree",       { "built-in" }),
        @("fzf",        { fzf --version 2>$null }),
        @("wget",       { if (Get-Command wget.exe -EA Silent) { "installed" } else { $null } })
    )

    foreach ($tool in $tools) {
        $name = $tool[0].PadRight(15)
        try {
            $ver = & $tool[1]
            if ($ver) {
                Write-Host "    $name $ver"
            } else {
                Write-Host "    $name -" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    $name -" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($script:Errors -gt 0) {
        Write-Host "  Warnings: $($script:Errors) non-critical tool(s) failed to install." -ForegroundColor Yellow
        Write-Host "  Scroll up to see which ones and install them manually." -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "  Next: Run Step 3 to set up ClaudeFlow (coming soon)"
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Green
}

# ==========================================================================
# Main
# ==========================================================================
function Main {
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Blue
    Write-Host "    Step 2 - Dev Tools (Windows)" -ForegroundColor Blue
    Write-Host "    10 tools - Windows 10/11" -ForegroundColor Blue
    Write-Host "  ==========================================================" -ForegroundColor Blue
    Write-Host ""

    Test-Prerequisites
    Install-Python
    Install-Pandoc
    Install-Xlsx2csv
    Install-Pdftotext
    Install-Jq
    Install-Ripgrep
    Install-Gh
    Install-Tree
    Install-Fzf
    Install-Wget
    Test-AllTools
    Show-Summary
}

Main
