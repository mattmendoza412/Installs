<#
.SYNOPSIS
	Script to shut down Matrix services prior to failover to other site.
.DESCRIPTION
	The script reads the XML file service_control.xml (located in the same directory as this script)
	and reconfigure the service startup type to 'Automatic', it will then start the listed services.
.NOTES
	Author		: Jörgen Blom
	Version		: 1.0 
	Date		: 2013-09-28
.EXAMPLE
	startup_services.ps1 site
.PARAMETER site
	The site where the services are currently running.
	Valid values are: dr | prod
#>
#Requires -Version 2.0


# read param (which site to control)
[string] $Site = $args[0]

if( ($Site -eq "dr") -or ($Site -eq "Prod") ) {

	# Get a list of services to shut down prior to failover
	[string] $ScriptLocation = split-path -parent $MyInvocation.MyCommand.Path
	[string] $XmlFilePath = "$ScriptLocation\service_control.xml"

	[xml] $XmlContent = Get-Content -Path $XmlFilePath

	[System.Xml.XmlElement] $servers = $XmlContent.get_DocumentElement()

	foreach($Server in $Servers.ChildNodes) {
		[string] $ServerName = $Server.name
		if( ($Site -eq "dr") -and ($ServerName -eq "se-dmcom-0001") ) {
			$ServerName = $ServerName.Replace("se","dr")
		}

		foreach($Service in $Server.ChildNodes) {
			[string] $SvcName = $Service.name
			[string] $SvcStartup = $Service.svc_startup
			
			$Result = (get-wmiobject win32_service -comp $ServerName -filter "name='$SvcName'" | 
					Invoke-WmiMethod -Name ChangeStartMode -ArgumentList "automatic" | Select ReturnValue)
			if($Result.ReturnValue -ne 0) {
				Write-Host("Failed to change startup type for service '{0}'" -f $SvcName,$SvcStartup) -foregroundcolor "yellow"
			}
			
			$Result = (get-wmiobject win32_service -comp $ServerName -filter "name='$SvcName'" | 
						Invoke-WmiMethod -Name StartService | Select ReturnValue)
			if($Result.ReturnValue -ne 0) {
				Write-Host("Failed to start service '{0}' on server {1}" -f $SvcName, $ServerName) -foregroundcolor "yellow" -backgroundcolor "red"
			}
		}			
	}
}
else {
	Write-Host "Usage: startup_services <param>, where param is DR or Prod";
}