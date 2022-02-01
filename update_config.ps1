<#
.SYNOPSIS
	Script to reconfigure Matrix servers that are protected in SRM ie moved between sites in a DR scenario.
.DESCRIPTION
	The script will execute batch files stored locally on the servers that requires reconfiguration after failover,
	it will also update configuration data stored in databases.
.NOTES
	Author		: Jörgen Blom
	Version		: 1.0 
	Date		: 2013-09-28
.EXAMPLE
	update_config.ps1 site
.PARAMETER site
	The site where the servers are currently hosted after failover.
	Valid values are: dr | prod
#>
#Requires -Version 2.0

$Result = 0
$SQLServer = "server=se-sql-0035\sql0035;Database=iwm;Integrated Security=sspi"

# read param (which site to control)
$Site = $args[0]


if( ($Site -eq "DR") -or ($Site -eq "Prod") ) {
	# SE-DMFILE-0001
	$Result = Invoke-WmiMethod -Class win32_process -Computername se-dmfile-0001 -Name Create -ArgumentList "C:\DR\$Site.bat","C:\DR" | Select ReturnValue
	if( $Result.ReturnValue -ne 0) { Write-Host "failed to copy $Site config on SE-DMFILE-0001" -foregroundcolor "yellow" -backgroundcolor "red" }

	# SE-DMWEB-0001
	$Result = Invoke-WmiMethod -Class win32_process -Computername se-dmweb-0001 -Name Create -ArgumentList "C:\DR\$Site.bat","C:\DR" | Select ReturnValue
	if( $Result.ReturnValue -ne 0) { Write-Host "failed to copy $Site config on SE-DMWEB-0001" -foregroundcolor "yellow" -backgroundcolor "red" }

	# SE-DMFLOW-0001
    $Result = Invoke-WmiMethod -Class win32_process -Computername se-dmflow-0001 -Name Create -ArgumentList "C:\DR\$Site.bat","C:\DR" | Select ReturnValue
	if( $Result.ReturnValue -ne 0) { Write-Host "failed to copy $Site config on SE-DMFLOW-0001" -foregroundcolor "yellow" -backgroundcolor "red" }

	$SqlConn = New-Object System.Data.SqlClient.SqlConnection $SqlServer
	$SqlConn.Open()
	$SqlCmd = $SqlConn.CreateCommand()
			
	switch($Site) {
		"dr" {
				$SqlCmd.CommandText = "UPDATE dbo.LDAPSERVERS SET HOST = 'dr-dc-0104'"
				$Result = ($SqlCmd.ExecuteNonQuery() )
				if( $Result -ne 1) {
					Write-Host "Please verify configuration manually, expected one to row to be affected ($Result rows affected)" -foregroundcolor "yellow" -backgroundcolor "red"
				}
				$SqlCmd.CommandText ="UPDATE dbo.SERVERSETTINGS SET VALUE = 'drsmtp.sirius.local' WHERE NAME = 'SMTPServer'"
				$Result = ($SqlCmd.ExecuteNonQuery() )
				if( $Result -ne 1) {
					Write-Host "Please verify configuration manually, expected one to row to be affected ($Result rows affected)" -foregroundcolor "yellow" -backgroundcolor "red"
				}
			}
		"prod" {
				$SqlCmd.CommandText = "UPDATE dbo.LDAPSERVERS SET HOST = 'se-dc-0101'"
				$Result = ($SqlCmd.ExecuteNonQuery() )
				if( $Result -ne 1) {
					Write-Host "Please verify configuration manually, expected one to row to be affected ($Result rows affected)" -foregroundcolor "yellow" -backgroundcolor "red"
				}
				$SqlCmd.CommandText = "UPDATE dbo.SERVERSETTINGS SET VALUE = 'smtp.sirius.local' WHERE NAME = 'SMTPServer'"
				$Result = ($SqlCmd.ExecuteNonQuery() )
				if( $Result -ne 1) {
					Write-Host "Please verify configuration manually, expected one to row to be affected ($Result rows affected)" -foregroundcolor "yellow" -backgroundcolor "red"
				}
			}
	}
	$sqlConn.Close()
}
else {
	Write-Host "Must supply one parameter {DR, Prod}, for example: update_config.ps1 DR (will update to DR config)"
}
