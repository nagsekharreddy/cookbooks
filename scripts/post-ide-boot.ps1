﻿<#
.SYNOPSIS

Complete the IDE install once the user instantiates an instance from the IDE AMI.

Requires the Web User so its called from LANSA Quick COnfig

.EXAMPLE


#>
param (
    [Parameter(Mandatory=$true)]
    [string]
    $webuser

    )

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}


try
{

    #####################################################################################
    Write-output ("$(Log-Date) Mapping licenses")
    #####################################################################################

    Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser

    #####################################################################################
	Write-output ("$(Log-Date) Allow webuser to create directory in c:\windows\temp so that LOB and BLOB processing works" )
    #####################################################################################
    
    Set-AccessControl $webuser "C:\Windows\Temp" "Modify" "ContainerInherit, ObjectInherit"

    #####################################################################################
	Write-output ("$(Log-Date) Restart Integrator JSM to reload license" )
    #####################################################################################

    $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    cmd /c "$APPA\integrator\jsmadmin\strjsm.exe" "-sstop" 
    cmd /c "$APPA\integrator\jsmadmin\strjsm.exe" "-sstart"

    Write-Output ("$(Log-Date) Installation completed successfully")
}
catch
{
	$_
    Write-Error ("$(Log-Date) Installation error")
    throw
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
