<#
.SYNOPSIS
	Script to shut down Matrix services prior to failover to other site.
.DESCRIPTION
	The script reads the XML file service_control.xml (located in the same directory as this script)
	and shuts down the listed services and reconfigure the service startup type according to the configuration file.
.NOTES
	Author		: Jörgen Blom
	Version		: 1.0 
	Date		: 2013-09-28
.EXAMPLE
	shut_down_services.ps1 site
.PARAMETER site
	The site where the services are currently running.
	Valid values are: dr | prod
#>
#Requires -Version 2.0


# read param (which site to control)
[string] $Site = $args[0]


if( ($Site -eq "DR") -or ($Site -eq "Prod") ) {
	[string] $ScriptLocation = split-path -parent $MyInvocation.MyCommand.Path
	[string] $XmlFilePath = "$ScriptLocation\service_control.xml"
	
	# Get a list of services to shut down prior to failover
	[xml] $XmlContent = Get-Content -Path $XmlFilePath

	[System.Xml.XmlElement] $servers = $XmlContent.get_DocumentElement()

	foreach($Server in $Servers.ChildNodes) {
		[string] $ServerName = $Server.name
		if( ($Site -eq "DR") -and ($ServerName -eq "se-dmcom-0001") ) {
			$ServerName = $ServerName.Replace("se","dr")
		}

		foreach($Service in $Server.ChildNodes) {
			[string] $SvcName = $Service.name
			[string] $SvcStartup = $Service.svc_startup
			
			$Result = (get-wmiobject win32_service -comp $ServerName -filter "name='$SvcName'" | 
						Invoke-WmiMethod -Name StopService | Select ReturnValue)
		
			if($Result.ReturnValue -ne 0) {
				Write-Host("Failed to stop service '{0}' on server {1}" -f $SvcName, $ServerName) -foregroundcolor "yellow" -backgroundcolor "red"
			}
			
			$Result = (get-wmiobject win32_service -comp $ServerName -filter "name='$SvcName'" | 
					Invoke-WmiMethod -Name ChangeStartMode -ArgumentList "$SvcStartup" | Select ReturnValue)
			if($Result.ReturnValue -ne 0) {
				Write-Host("Failed to change startup type for service '{0}' (to {1})." -f $SvcName,$SvcStartup) -foregroundcolor "yellow"
			}
		}
	}
}
else {	# proceed with shut down of services
	Write-Host "Usage: shut_down_services <param>, where param is DR or Prod";
}