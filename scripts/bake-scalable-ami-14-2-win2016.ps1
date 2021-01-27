﻿<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"
. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-IdeMsi -VersionText '14.2 EPC142060' `
            -VersionMajor 14 `
            -VersionMinor 2 `
            -LocalDVDImageDirectory "n\a" `
            -S3DVDImageDirectory "n\a" `
            -S3VisualLANSAUpdateDirectory "n\a" `
            -S3IntegratorUpdateDirectory "n\a" `
            -AmazonAMIName "Windows_Server-2016-English-Full-SQL_2017_Express*" `
            -GitBranch "support/L4W14200_scalable"`
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $false `
            -InstallScalable $true `
            -Win2012 $false `
            -ManualWinUpd $false `
            -SkipSlowStuff $true

            # Note Skipping slow stuff skips DVD upload and Windows updates, neither of which is needed when Scalable and its a new AWS image
