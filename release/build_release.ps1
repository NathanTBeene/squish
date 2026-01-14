#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build release packages for Squish
.DESCRIPTION
    Reads version info from dist.info and builds release packages
.PARAMETER Clean
    Remove existing dist directory before building
.EXAMPLE
    .\build_release.ps1 -Clean
#>

param(
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script directory and project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Change to project root
Push-Location $projectRoot

try {
    # Read dist.info
    Write-Host "Reading dist.info..." -ForegroundColor Cyan
    $distInfo = Get-Content "dist.info" -Raw

    # Parse version
    if ($distInfo -match 'version\s*=\s*"([^"]+)"') {
        $version = $Matches[1]
    } else {
        throw "Could not find version in dist.info"
    }

    # Parse name
    if ($distInfo -match 'name\s*=\s*"([^"]+)"') {
        $name = $Matches[1]
    } else {
        throw "Could not find name in dist.info"
    }

    Write-Host "Building $name version $version" -ForegroundColor Green

    # Create dist directory
    $distDir = Join-Path $scriptDir "dist"
    if ($Clean -and (Test-Path $distDir)) {
        Write-Host "Cleaning dist directory..." -ForegroundColor Yellow
        Remove-Item $distDir -Recurse -Force
    }

    if (-not (Test-Path $distDir)) {
        New-Item -ItemType Directory -Path $distDir | Out-Null
    }

    # List of variants to build
    $variants = @(
        @{name=""; desc="base"},
        @{name="-minify"; desc="with minify"},
        @{name="-uglify"; desc="with uglify"},
        @{name="-minify-uglify"; desc="with minify and uglify"},
        @{name="-debug"; desc="with debug"},
        @{name="-all"; desc="with all modules"}
    )

    foreach ($variant in $variants) {
        $variantName = $variant.name
        $variantDesc = $variant.desc
        $packageName = "${name}-${version}${variantName}"
        $packageDir = Join-Path $distDir $packageName

        Write-Host "`nBuilding ${packageName} ($variantDesc)..." -ForegroundColor Cyan

        # Create package directory
        if (Test-Path $packageDir) {
            Remove-Item $packageDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $packageDir | Out-Null

        # Build with appropriate squishy
        $squishyFile = "squishy"
        $tempSquishy = $false

        if ($variantName -eq "-minify") {
            # Create minify squishy
            $squishyFile = "squishy.tmp"
            $tempSquishy = $true
            $squishyContent = Get-Content "squishy" -Raw
            $squishyContent += "`nModule `"squish.minify`" `"minify/squish.minify.lua`""
            $squishyContent += "`nModule `"optlex`" `"minify/optlex.lua`""
            $squishyContent += "`nModule `"optparser`" `"minify/optparser.lua`""
            $squishyContent += "`nModule `"llex`" `"minify/llex.lua`""
            $squishyContent += "`nModule `"lparser`" `"minify/lparser.lua`""
            Set-Content -Path $squishyFile -Value $squishyContent
        } elseif ($variantName -eq "-uglify") {
            # Create uglify squishy
            $squishyFile = "squishy.tmp"
            $tempSquishy = $true
            $squishyContent = Get-Content "squishy" -Raw
            $squishyContent += "`nModule `"squish.uglify`" `"uglify/squish.uglify.lua`""
            $squishyContent += "`nModule `"uglify.llex`" `"uglify/llex.lua`""
            Set-Content -Path $squishyFile -Value $squishyContent
        } elseif ($variantName -eq "-minify-uglify") {
            # Create combined squishy
            $squishyFile = "squishy.tmp"
            $tempSquishy = $true
            $squishyContent = Get-Content "squishy" -Raw
            $squishyContent += "`nModule `"squish.minify`" `"minify/squish.minify.lua`""
            $squishyContent += "`nModule `"optlex`" `"minify/optlex.lua`""
            $squishyContent += "`nModule `"optparser`" `"minify/optparser.lua`""
            $squishyContent += "`nModule `"llex`" `"minify/llex.lua`""
            $squishyContent += "`nModule `"lparser`" `"minify/lparser.lua`""
            $squishyContent += "`nModule `"squish.uglify`" `"uglify/squish.uglify.lua`""
            $squishyContent += "`nModule `"uglify.llex`" `"uglify/llex.lua`""
            Set-Content -Path $squishyFile -Value $squishyContent
        } elseif ($variantName -eq "-debug") {
            # Create debug squishy
            $squishyFile = "squishy.tmp"
            $tempSquishy = $true
            $squishyContent = Get-Content "squishy" -Raw
            $squishyContent += "`nModule `"squish.debug`" `"debug/squish.debug.lua`""
            $squishyContent += "`nModule `"debug.minichunkspy`" `"debug/minichunkspy.lua`""
            Set-Content -Path $squishyFile -Value $squishyContent
        } elseif ($variantName -eq "-all") {
            # Create combined squishy with all modules
            $squishyFile = "squishy.tmp"
            $tempSquishy = $true
            $squishyContent = Get-Content "squishy" -Raw
            $squishyContent += "`nModule `"squish.minify`" `"minify/squish.minify.lua`""
            $squishyContent += "`nModule `"optlex`" `"minify/optlex.lua`""
            $squishyContent += "`nModule `"optparser`" `"minify/optparser.lua`""
            $squishyContent += "`nModule `"llex`" `"minify/llex.lua`""
            $squishyContent += "`nModule `"lparser`" `"minify/lparser.lua`""
            $squishyContent += "`nModule `"squish.uglify`" `"uglify/squish.uglify.lua`""
            $squishyContent += "`nModule `"uglify.llex`" `"uglify/llex.lua`""
            $squishyContent += "`nModule `"squish.debug`" `"debug/squish.debug.lua`""
            $squishyContent += "`nModule `"debug.minichunkspy`" `"debug/minichunkspy.lua`""
            $squishyContent += "`nModule `"squish.gzip`" `"gzip/squish.gzip.lua`""
            $squishyContent += "`nModule `"gzip.deflatelua`" `"gzip/deflatelua.lua`""
            Set-Content -Path $squishyFile -Value $squishyContent
        }

        # Run squish
        Write-Host "  Running squish with $squishyFile..." -ForegroundColor Gray
        if ($squishyFile -ne "squishy") {
            # Backup original squishy and use the variant
            Move-Item "squishy" "squishy.backup" -Force
            Copy-Item $squishyFile "squishy"
            lua squish.lua
            # Restore original squishy
            Move-Item "squishy.backup" "squishy" -Force
        } else {
            lua squish.lua
        }

        # Clean up temp squishy if created
        if ($tempSquishy) {
            Remove-Item $squishyFile -Force
        }

        # Copy files to package
        Write-Host "  Copying files..." -ForegroundColor Gray
        Copy-Item "squish" -Destination $packageDir
        Copy-Item "README.md" -Destination $packageDir
        Copy-Item "COPYRIGHT" -Destination $packageDir
        Copy-Item "CHANGES" -Destination $packageDir
        Copy-Item "dist.info" -Destination $packageDir

        # Create archive
        $archiveName = "${packageName}.zip"
        $archivePath = Join-Path $distDir $archiveName
        Write-Host "  Creating archive $archiveName..." -ForegroundColor Gray
        Compress-Archive -Path "$packageDir\*" -DestinationPath $archivePath -Force

        # Clean up package directory
        Remove-Item $packageDir -Recurse -Force

        Write-Host "  Created $archiveName" -ForegroundColor Green
    }

    Write-Host "`nBuild complete! Packages created in release/dist/" -ForegroundColor Green
    Write-Host "`nPackages:" -ForegroundColor Cyan
    Get-ChildItem $distDir -Filter "*.zip" | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }

} finally {
    Pop-Location
}
