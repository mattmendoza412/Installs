#!ps
#
# Last modified 2017-01-11 magnus.nyberg@siriusgroup.com

Function TestServerPort([string]$H, [string]$P)
{
    if ($H -eq "") { return $false}
    if ($P -eq "") { return $false}
    $TCPobject = new-Object system.Net.Sockets.TcpClient
    $Connect = $tcpobject.BeginConnect($H,$P,$null,$null)
    $Wait = $connect.AsyncWaitHandle.WaitOne(900,$false)
    if (-Not $Wait) {
        return $false
    } else {
        $error.clear()
        $TCPobject.EndConnect($Connect) | out-Null
        if ($Error[0]) {
            return $false
        } else {
            return $true
        }
    }
}


Function GetServerInfo([string]$svr)
{
    if ($svr -eq "") { return ""}
    $Ret = $svr
    $fqdn = $svr + "." + $domain

    $ADSobj = Get-ADComputer -Server $domain -Identity $svr -properties name,operatingsystem,description
    if ($ADSobj) {
        $OSver = $ADSobj.OperatingSystem
        if ($OSver) {
            $Ret = $Ret + $delim + $OSver
        } else {
            $Ret = $Ret + $delim
        }
        $Descr = $ADSobj.Description
        if ($Descr) {
            $Ret = $Ret + $delim + $Descr
        } else {
            $Ret = $Ret + $delim
        }
    } else {
        $Ret = $Ret + $delim + $delim
    }

    $WMIobj = Get-WmiObject win32_computersystem -computername $svr -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($WMIobj) {
        $Manuf = $WMIobj.manufacturer
        if ($Manuf) {
            $Ret = $Ret + $delim + $Manuf
        } else {
            $Ret = $Ret + $delim
        }
    } else {
        $Ret = $Ret + $delim
    }

    $WMIobj = Get-WmiObject win32_operatingsystem -computername $svr -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($WMIobj) {
        $BootTimeObj = New-TimeSpan (Get-Date) ([Management.ManagementDateTimeConverter]::ToDateTime($WMIobj.LastBootUpTime))
        $Uptime = ( 0 - $BootTimeObj.Days )
        if ($Uptime -ge 0) {
            $Ret = $Ret + $delim + $Uptime
        } else {
            $Ret = $Ret + $delim
        }
    } else {
        $Ret = $Ret + $delim
    }

    return $Ret
}


#Main()
#

$domain = $env:UserDNSDomain.ToLower()
$dc1 = $($domain.split(".")[0])
$dc2 = $($domain.split(".")[1])
$sbase = "DC=$dc1,DC=$dc2"
$outputfile = ".\serverinfo.out"
echo $null > $outputfile
$port = 445
$num_avail = 0
$num_notavail = 0
$delim = ";"
echo "Searchbase = $sbase"
echo "DNS Domain = $domain"

##$servers = Get-Content ".\ServerInfo.txt"
$servers = Get-ADComputer -Server $domain -SearchBase "$sbase" -Filter { (Enabled -eq "true") -and (OperatingSystem -Like 'Windows *Server*') } -Property * | Select -Expand Name

echo ("Server" + $delim + "OperatingSystem" + $delim + "Description" + $delim + "Manufacturer"+ $delim + "Uptime (days)") >> $outputfile

foreach ($computer in $servers) {
    if ($computer -eq "" -or !$computer) {
        echo ("")
    } else {
        if (TestServerPort $computer $port) {
            echo (GetServerInfo "$computer") | Out-File -filepath ( $outputfile ) -append
            $num_avail += 1
        } else {
            echo ("Not available: $computer")
            $num_notavail += 1
        }
    }
}
 
echo "Available:     $num_avail"
echo "Not available: $num_notavail"
 
#End
#
