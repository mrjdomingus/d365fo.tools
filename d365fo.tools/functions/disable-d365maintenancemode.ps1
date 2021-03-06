﻿
<#
    .SYNOPSIS
        Sets the environment back into operating state
        
    .DESCRIPTION
        Sets the Dynamics 365 environment back into operating / running state after been in maintenance mode
        
    .PARAMETER MetaDataDir
        The path to the meta data directory for the environment
        
        Default path is the same as the aos service PackagesLocalDirectory
        
    .PARAMETER BinDir
        The path to the bin directory for the environment
        
        Default path is the same as the aos service PackagesLocalDirectory\bin
        
    .PARAMETER DatabaseServer
        The name of the database server
        
        If on-premises or classic SQL Server, use either short name og Fully Qualified Domain Name (FQDN).
        
        If Azure use the full address to the database server, e.g. server.database.windows.net
        
    .PARAMETER DatabaseName
        The name of the database
        
    .PARAMETER SqlUser
        The login name for the SQL Server instance
        
    .PARAMETER SqlPwd
        The password for the SQL Server user
        
    .PARAMETER ShowOriginalProgress
        Instruct the cmdlet to show the standard output in the console
        
        Default is $false which will silence the standard output
        
    .PARAMETER OutputCommandOnly
        Instruct the cmdlet to only output the command that you would have to execute by hand
        
        Will include full path to the executable and the needed parameters based on your selection
        
    .EXAMPLE
        PS C:\> Disable-D365MaintenanceMode
        
        This will execute the Microsoft.Dynamics.AX.Deployment.Setup.exe with the default values that was pulled from the environment and put the environment into the operate / running state.
        
    .EXAMPLE
        PS C:\> Disable-D365MaintenanceMode -ShowOriginalProgress
        
        This will execute the Microsoft.Dynamics.AX.Deployment.Setup.exe with the default values that was pulled from the environment and put the environment into the operate / running state.
        The output from stopping the services will be written to the console / host.
        The output from the "deployment" process will be written to the console / host.
        The output from starting the services will be written to the console / host.
        
    .NOTES
        Tags: MaintenanceMode, Maintenance, License, Configuration, Servicing
        
        Author: Mötz Jensen (@splaxi)
        Author: Tommy Skaue (@skaue)
        
        With administrator privileges:
        The cmdlet wraps the execution of Microsoft.Dynamics.AX.Deployment.Setup.exe and parses the parameters needed.
        
        Without administrator privileges:
        Will stop all services, execute a Sql script and start all services.
        
    .LINK
        Enable-D365MaintenanceMode
        
    .LINK
        Get-D365MaintenanceMode
        
#>
function Disable-D365MaintenanceMode {
    [CmdletBinding()]
    param (
        [string] $MetaDataDir = "$Script:MetaDataDir",

        [string] $BinDir = "$Script:BinDir",

        [string] $DatabaseServer = $Script:DatabaseServer,

        [string] $DatabaseName = $Script:DatabaseName,

        [string] $SqlUser = $Script:DatabaseUserName,

        [string] $SqlPwd = $Script:DatabaseUserPassword,

        [switch] $ShowOriginalProgress,

        [switch] $OutputCommandOnly

    )
    
    if ((Get-Process -Name "devenv" -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-PSFMessage -Level Host -Message "It seems that you have a <c='em'>Visual Studio</c> running. Please <c='em'>exit</c> Visual Studio and run the cmdlet again."
        Stop-PSFFunction -Message "Stopping because of running Visual Studio."
        return
    }

    if (-not $OutputCommandOnly) {
        Stop-D365Environment -All -ShowOriginalProgress:$ShowOriginalProgress | Format-Table
    }

    if (-not ($Script:IsAdminRuntime)) {
        Write-PSFMessage -Level Verbose -Message "Setting Maintenance Mode without using executable (which requires local admin)."
        
        $UseTrustedConnection = Test-TrustedConnection $PSBoundParameters

        $Params = @{
            DatabaseServer = $DatabaseServer
            DatabaseName   = $DatabaseName
            SqlUser        = $SqlUser
            SqlPwd         = $SqlPwd
        }

        if ($OutputCommandOnly) {
            $scriptContent = Get-content -Path $("$script:ModuleRoot\internal\sql\disable-maintenancemode.sql") -Raw
            Write-PSFMessage -Level Host -Message "It seems that you're want the command, but you're running in a non-elevated console. Will output the SQL script that is avaiable."
            Write-PSFMessage -Level Host -Message "$scriptContent"
        }
        else {
            Invoke-D365SqlScript @Params -FilePath $("$script:ModuleRoot\internal\sql\disable-maintenancemode.sql") -TrustedConnection $UseTrustedConnection
        }
    }
    else {
        Write-PSFMessage -Level Verbose -Message "Setting Maintenance Mode using executable."

        $executable = Join-Path $BinDir "bin\Microsoft.Dynamics.AX.Deployment.Setup.exe"

        if (-not (Test-PathExists -Path $MetaDataDir, $BinDir -Type Container)) { return }
        if (-not (Test-PathExists -Path $executable -Type Leaf)) { return }

        $params = @("-isemulated", "true",
            "-sqluser", "$SqlUser",
            "-sqlpwd", "$SqlPwd",
            "-sqlserver", "$DatabaseServer",
            "-sqldatabase", "$DatabaseName",
            "-metadatadir", "$MetaDataDir",
            "-bindir", "$BinDir",
            "-setupmode", "maintenancemode",
            "-isinmaintenancemode", "false")

        Invoke-Process -Executable $executable -Params $params -ShowOriginalProgress:$ShowOriginalProgress -OutputCommandOnly:$OutputCommandOnly
    }

    if ($OutputCommandOnly) { return }

    Start-D365Environment -All -ShowOriginalProgress:$ShowOriginalProgress | Format-Table

}