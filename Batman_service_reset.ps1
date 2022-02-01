# checking if BatchManager service is running and restart it, if not running then it would start
# Author: Per Andersson

function CheckService
{
	
	Param($ServiceName)
	$arrService = Get-Service -Name $ServiceName -ComputerName $strServer

	if ($arrService.Status -ne "Running")
    {
	   Start-Service -inputobject $arrservice 
	   Write-Host $ServiceName is started on $strServer
	}
    else    
    {
	   Restart-Service -inputobject $arrservice 
	   Write-Host $ServiceName is restarted on $strServer
    }
}

$strServers=@("dr-gpi-0201","dr-gpi-0202","dr-gpi-0203","dr-gpi-0204","se-gpi-0201","se-gpi-0202","se-gpi-0203","se-gpi-0204","se-gpi-0205","se-gpi-0206","se-gpi-0207","se-gpi-0208","se-gpi-0209","se-gpi-0210")

ForEach($strServer in $strServers)
{
    CheckService -ServiceName "BatchManager" 
}