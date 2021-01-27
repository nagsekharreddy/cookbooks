﻿<#
.SYNOPSIS

Manage the life cycle of a LANSA MSI.

First written to be called when deploying or re-deploying an Azure ARM Template which instantiates a LANSA scalable stack.

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules.
E.g. The password is sufficiently complex and the userid is not duplicated in the password.
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE

For Docker
1. docker run -d -p 1436:1433 -e sa_password=Pcxuser@122robg -e ACCEPT_EULA=Y -v h:/temp/:c:/temp/  -v C:/Users/Robert.SYD/Documents/GitHub/cookbooks/scripts/:c:/scripts/ --isolation=hyperv microsoft/mssql-server-windows
2. docker exec -it <id> powershell
3. Place msi in hosts h:\temp or equivalent directory, say h:\temp\AWAMAPP_v14.1.2_en-us.msi (Could map IDE package directory to container's c:\temp)
5. Change server_name to the ip address of the container in this command line and run it. Presumes that server is on port 1433 and is using the default instance name of MSSQLSERVER:
C:\scripts\azure-custom-script.ps1 -server_name "172.29.146.164" -dbname "lansa" -dbuser "sa" -dbpassword "Pcxuser@122robg" -webuser "PCXUSER2" -webpassword "Pcxuser@122robg" -MSIuri "c:\temp\AWAMAPP_v14.1.2_en-us.msi"

#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$maxconnections = '20',
[String]$wait,
[String]$userscripthook,
[Parameter(Mandatory=$false)]
[String]$DBUT='MSSQLS',
[String]$MSIuri,
[String]$trace = 'N',
[String]$traceSettings = "ITRO:Y ITRL:4 ITRM:9999999999",
[String]$installMSI = 1,
[String]$updateMSI = 0,
[String]$triggerWebConfig = 1,
[String]$UninstallMSI = 0,
[String]$fixLicense = 0
)

function StopWebJobs{
   Param (
	   [string]$APPA
   )
    Write-Verbose ("APPA = $APPA") | Out-Default | Write-Host

    # If apps not installed just return

    Write-Verbose ("Stopping Listener...") | Out-Default | Write-Host
    if ( (Test-Path "$APPA\connect64\lcolist.exe") ) {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstop" -Wait | Out-Default | Write-Host
    } else {
        throw
    }

    Write-Verbose ("Stopping all web jobs...") | Out-Default | Write-Host
    if ( (Test-Path "$APPA\X_Win95\X_Lansa\Execute\w3_p2200.exe") ) {
        Start-Process -FilePath "$APPA\X_Win95\X_Lansa\Execute\w3_p2200.exe" -ArgumentList "*FORINSTALL" -Wait | Out-Default | Write-Host
    } else {
        throw
    }

    Write-Verbose ("Stopping iis...") | Out-Default | Write-Host
    iisreset /stop /noforce | Out-Default | Write-Host
}

function ResetWebServer{
   Param (
	   [string]$APPA
   )
    Write-Verbose ("APPA = $APPA") | Out-Default | Write-Host

    try {
        StopWebJobs -APPA $APPA
    }
    catch {
        return
    }

    Write-Verbose ("Resetting iis...") | Out-Default | Write-Host
    iis-reset | Out-Default | Write-Host

    Write-Verbose ("Starting Listener...") | Out-Default | Write-Host
    Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstart" -Wait | Out-Default | Write-Host
}

Set-StrictMode -Version Latest | Out-Default | Write-Host

$VerbosePreference = "Continue"

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not (Test-Path variable:script:IncludeDir) )
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path | Out-Default | Write-Host
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1" | Out-Default | Write-Host
	. "$script:IncludeDir\Init-Baking-Includes.ps1" | Out-Default | Write-Host
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}


# Put first output on a new line in log file
Write-Host ("`r`n")

Write-Verbose ("maxconnections = $maxconnections") | Out-Default | Write-Host
Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host
Write-Verbose ("updateMSI = $updateMSI") | Out-Default | Write-Host
Write-Verbose ("triggerWebConfig = $triggerWebConfig") | Out-Default | Write-Host
Write-Verbose ("UninstallMSI = $UninstallMSI") | Out-Default | Write-Host
Write-Verbose ("trace = $trace") | Out-Default | Write-Host
Write-Verbose ("fixLicense = $fixLicense") | Out-Default | Write-Host
Write-Verbose ("Password = $dbpassword") | Out-Default | Write-Host

try
{
    # Make sure we are using the normal file system, not SQLSERVER:\ or some such else.
    cd "c:" | Out-Default | Write-Host
    cmd /c exit 0              # Ensure $LASTEXITCODE is cleared

    if ( $f32bit -eq 'true' -or $f32bit -eq '1')
    {
        $f32bit_bool = $true
    }
    else
    {
        $f32bit_bool = $false
    }

    if ( $UPGD -eq 'true' -or $UPGD -eq '1')
    {
        $UPGD_bool = $true
    }
    else
    {
        $UPGD_bool = $false
    }

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\LANSA"
    }

    # Flag to anyone who needs to know that we are installing. Particularly the Load Balancer probe

    Set-ItemProperty -Path "HKLM:\Software\lansa" -Name "Installing" -Value 1 | Out-Default | Write-Host

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    Write-Verbose ("$(Log-Date) Running on $Cloud")

    Write-Host ("$(Log-Date) Test if this is the first install")
    $installer = "MyApp.msi"
    $installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
    $Installed = $false
    if (-not (Test-Path $installer_file) ) {
        if ( $installMSI -eq "0" -and $triggerWebConfig -eq "0" -and $uninstallMSI -eq "0" ) {
            Write-Host ("$(Log-Date) There is no installation file and no other options specified, so defaulting to install the MSI and setup Web Configuration")
            # Note that an Uninstall might be being done for all instances where some maybe installed and others not, so we don't want to be installing then
            # The idea is that if an explicit option is set, then honour that, no defaulting.
            $installMSI = "1"
            $triggerWebConfig = "1"
            Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host
            Write-Verbose ("triggerWebConfig = $triggerWebConfig") | Out-Default | Write-Host
        }
    } else {
        $Installed = $true
    }

    Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host

    if ( $Installed ) {
        Write-Host ("$(Log-Date) Wait for Load Balancer to get the message from the Probe that we are offline")
        Write-Verbose ("$(Log-Date) The probe is currently set to a 31 second timeout. Allow another 9 seconds for current transactions to complete") | Out-Default | Write-Host
        Start-Sleep -s 40 | Out-Default | Write-Host
    }
    Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host

    # The docker operator can easily set command line variables when creating the container, so get out of the way!
    if ( $Cloud -ne 'Docker') {
        Write-Host ("$(Log-Date) Setup tracing for both this process and its children and any processes started after the installation has completed.")

        if ($trace -eq "Y") {
            Write-Host ("$(Log-Date) Set tracing on" )
            [Environment]::SetEnvironmentVariable("X_RUN", $traceSettings, "Machine") | Out-Default | Write-Host
            $env:X_RUN = $traceSettings
        } else {
            Write-Host ("$(Log-Date) Set tracing off" )
            [Environment]::SetEnvironmentVariable("X_RUN", $null, "Machine") | Out-Default | Write-Host
            $env:X_RUN = ''
        }
    }
    Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host

    Write-Host ("$(Log-Date) Restart web server if not already planned to be done by a later script, so that tracing is on")

    if ( $Installed -and $installMSI -eq "0" -and $updateMSI -eq "0" -and $triggerWebConfig -eq "0" ) {
        ResetWebServer -APPA $APPA
    }
    Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host

    if ( $uninstallMSI -eq "1" ) {
        [bool] $Success = $true
        if ( $Installed ) {
            Write-Host ("$(Log-Date) Uninstalling...")

            # Make sure LANSA is absolutely not executing anything
            try {
                StopWebJobs -APPA $APPA
            }
            catch {
                $Success = $false
                Write-Host ("$(Log-Date) Skipping uninstaller as it seems LANSA is not actually installed...")
            }

            if ( $Success ) {
                Write-Host ("$(Log-Date) Starting the uninstaller...")
                $install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "MyAppUninstall.log" )
                [String[]] $Arguments = @( "/x $installer_file ", "/quiet", "/lv*x $install_log")
                $p = Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait -PassThru
                if ( $p.ExitCode -ne 0 ) {
                    # Set LASTEXITCODE
                    cmd /c exit $p.ExitCode
                    throw
                }
            }

            Write-Host ("$(Log-Date) Deleting installer file $installer_file...")
            Remove-Item $installer_file -Force -ErrorAction Continue | Out-Default | Write-Host
         } else {
            Write-Host ("$(Log-Date) Uninstall requested but app is not installed...")
         }
    }

    if ( $LASTEXITCODE -ne 0 ) {
        throw
    }

    if ( $installMSI -eq "1" ) {
        Write-Host ("$(Log-Date) Installing...")
        .$script:IncludeDir\install-lansa-msi.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser "$dbuser" -dbpassword "$dbpassword" -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD "0" -MSIuri $MSIuri -trace $trace -tracesettings $traceSettings -maxconnections $maxconnections
    } elseif ( $updateMSI -eq "1" ) {
        Write-Host ("$(Log-Date) Updating...")
        .$script:IncludeDir\install-lansa-msi.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD "1" -MSIuri $MSIuri -trace $trace -tracesettings $traceSettings -maxconnections $maxconnections
    }

    if ( $LASTEXITCODE -ne 0 ) {
        throw
    }

    if ( $triggerWebConfig -eq "1" ) {
        Write-Host ("$(Log-Date) Configuring Web Server...")
        .$script:IncludeDir\webconfig.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -maxconnections $maxconnections
    }

    if ( $LASTEXITCODE -ne 0 ) {
        throw
    }

    if ( $fixLicense -eq "1" ) {
        Write-Host ("$(Log-Date) Fixing licenses...")
	    Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" $webuser | Out-Default | Write-Host
	    Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" $webuser | Out-Default | Write-Host
	    Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser | Out-Default | Write-Host
        ResetWebServer -APPA $APPA
    }

    if ( $LASTEXITCODE -ne 0 ) {
        throw
    }
}
catch
{
    Write-Error ("azure-custom-script failed")

    # If $LASTEXITCODE not already set, make sure it has a value so caller terminates the deployment.
    if ( $LASTEXITCODE -eq 0 ) {
        cmd /c exit 3
    }

    if ( ($installMSI -eq "1") -and (Test-Path $installer_file) ) {
        Write-Host ("$(Log-Date) Deleting $installer_file so that an install will occur by default next time...")
        Remove-Item $installer_file -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host
    }

    return
}
finally
{
    # Repeat the basic request params as Azure truncates the log file
    Write-Verbose ("maxconnections = $maxconnections") | Out-Default | Write-Host
    Write-Verbose ("installMSI = $installMSI") | Out-Default | Write-Host
    Write-Verbose ("updateMSI = $updateMSI") | Out-Default | Write-Host
    Write-Verbose ("triggerWebConfig = $triggerWebConfig") | Out-Default | Write-Host
    Write-Verbose ("UninstallMSI = $UninstallMSI") | Out-Default | Write-Host
    Write-Verbose ("trace = $trace") | Out-Default | Write-Host
    Write-Verbose ("fixLicense = $fixLicense") | Out-Default | Write-Host
}

Write-Verbose ("$(Log-Date) Only switch off Installing flag when successful. Thus LB Probe will continue to fail if this script fails and indicate to the LB that it should not be used.")
Set-ItemProperty -Path "HKLM:\Software\lansa" -Name "Installing" -Value 0 | Out-Default | Write-Host

cmd /c exit 0
