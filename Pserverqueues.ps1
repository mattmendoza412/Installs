#!ps
#
# Last modified 2016-12-29 magnus.nyberg@siriusgroup.com

Function TestServerPort([string]$H, [string]$P)
{
    if ($H -eq "") { return $false}
    if ($P -eq "") { return $false}
    $TCPobject = new-Object system.Net.Sockets.TcpClient
    $Connect = $tcpobject.BeginConnect($H,$P,$null,$null)
    $Wait = $connect.AsyncWaitHandle.WaitOne(500,$false)
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

Function GetPServerInfo([string]$svr) {

    if ($svr -eq "") { return ""}

    $RegKeyPathPrint = "SYSTEM\CurrentControlSet\Control\Print\Printers"
    $RegKeyPathPorts = "SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports"

    $PrinterRegValueNames = ("Name","Share Name”,"Description”,"Printer Driver”,"Location","Port")
    $PortRegValueNames = ("HostName","PortNumber","Protocol","Queue")


    $Ret = $svr

    $RegObj = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $svr)

    if ($RegObj) {
        $PrinterRegKeyObj= $RegObj.OpenSubKey($RegKeyPathPrint)
        $PortsRegKeyObj= $RegObj.OpenSubKey($RegKeyPathPorts)

        if ($PrinterRegKeyObj) {
            $PrinterPortName = ""
            $PrinterSubKeys = $PrinterRegKeyObj.GetSubKeyNames()

            foreach ($PrinterSubKeyName in $PrinterSubKeys) {
                $PrinterSubKeyObj= $RegObj.OpenSubKey("$RegKeyPathPrint\$PrinterSubKeyName")
                $PrinterPortName = $PrinterSubKeyObj.GetValue("Port")

                foreach ($PrinterRegValueName in $PrinterRegValueNames) {
                    $PrinterRegValue = $PrinterSubKeyObj.GetValue($PrinterRegValueName)

                    if ($PrinterRegValue) {
                        $Ret = $Ret + $delim + $PrinterRegValue
                    } else {
                        $Ret = $Ret + $delim
                    }
                }

                if ($PortsRegKeyObj) {

                    if ($PrinterPortName -And $PrinterPortName.substring(0,3) -eq "WSD") {
                        $Ret = $Ret + $delim + $delim + $delim + $delim
                    } else {
                        $PortSubKeyObj = $RegObj.OpenSubKey("$RegKeyPathPorts\$PrinterPortName")

                        if ($PortSubKeyObj) {

                            foreach ($PortRegValueName in $PortRegValueNames) {
                                $PortRegValue = $PortSubKeyObj.GetValue($PortRegValueName)

                                if ("Protocol" -eq $PortRegValueName) {

                                    if ( 1 -eq $PortRegValue ) {
                                        $PortRegValue = "RAW"
                                    } else {
                                        $PortRegValue = "LPD"
                                    }
                                }

                                if ($PortRegValue) {
                                    $Ret = $Ret + $delim + $PortRegValue
                                } else {
                                    $Ret = $Ret + $delim
                                }
                            }
                        } else {
                            $Ret = $Ret + $delim + $delim + $delim + $delim
                        }
                    }
                }
                $Ret = $Ret + "`r`n" + $svr
            }
        }

    }
    return $Ret
}


#Main
#
$outputfile = ".\Pserverqueues.out"
echo $null > $outputfile
$port = 445
$num_avail = 0
$num_notavail = 0
$delim = ";"

$servers = Get-Content ".\Pservers.txt"
# $servers = Get-ADComputer -Filter { (Enabled -eq "true") -and (OperatingSystem -Like 'Windows *Server*') } -Property * | Select -Expand Name

#Add output file header
echo ("Server" + $delim + "Name" + $delim + "Share Name" + $delim + "Description" + $delim + "Printer Driver" + $delim + "Location" + $delim + "Port" + $delim + "HostName" + $delim + "Portnum" + $delim + "Protocol" + $delim + "Queue") >> $outputfile

#Loop trough server list and retreive info and append to output file
Foreach ($computer in $servers) {
    if ($computer -eq "" -or !$computer) {
        echo ("")
    } else {
        if (TestServerPort $computer $port) {
            echo (GetPServerInfo "$computer") | Out-File -filepath ( $outputfile ) -append
            $num_avail += 1
        } else {
            echo ("Not available: + $computer")
            $num_notavail += 1
        }
    }
}
 
echo "Available:     $num_avail"
echo "Not available: $num_notavail"
 
#End
#
#HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\*\
# "Name"
# "Share Name”
# "Description”
# "Printer Driver”
# "Location"
# "Port"
#
#HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports\*\
# “Hostname”
# “PortNumber”
# “Protocol”
# “Queue”

#Get-ChildItem "HKLM:\Software\Microsoft\KeyToQuery" -Recurse |
#ForEach-Object { Get-ItemProperty $_.pspath } |
#Where-Object {$_.ValueA -eq "True"}
