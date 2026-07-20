<#
.SYNOPSIS
    Inventory Automation Script

.DESCRIPTION
    Collects Windows hardware and operating system information
    and exports the results to a CSV file.

.AUTHOR
    Julio César González Salgado

.VERSION
    1.0.0

.LASTUPDATED
    2026-07-20
#>

function Get-ComputerInfoData {

    $computer = Get-CimInstance Win32_ComputerSystem
    $bios     = Get-CimInstance Win32_BIOS
    $cpu      = Get-CimInstance Win32_Processor
    $os       = Get-CimInstance Win32_OperatingSystem

    [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        CurrentUser  = $env:USERNAME
        Manufacturer = $computer.Manufacturer
        Model        = $computer.Model
        SerialNumber = $bios.SerialNumber
        BIOSVersion  = $bios.SMBIOSBIOSVersion
        Processor    = $cpu.Name
        RAM_GB       = [math]::Round($computer.TotalPhysicalMemory /1GB,2)
        OperatingSystem = $os.Caption
        Version      = $os.Version
        Build        = $os.BuildNumber

    }

}

function Get-DiskInfo {

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

    [PSCustomObject]@{

        DiskSize_GB  = [math]::Round($disk.Size/1GB,2)
        FreeSpace_GB = [math]::Round($disk.FreeSpace/1GB,2)

    }

}

function Get-NetworkInfo {

    $adapter = Get-NetAdapter |
        Where-Object Status -eq "Up" |
        Select-Object -First 1

    $ip = Get-NetIPAddress `
        -InterfaceIndex $adapter.InterfaceIndex `
        -AddressFamily IPv4 |
        Where-Object IPAddress -notlike "169.*" |
        Select-Object -First 1

    [PSCustomObject]@{

        IPv4 = $ip.IPAddress
        MAC  = $adapter.MacAddress

    }

}

function Get-SecurityInfo {

    try{

        $bitlocker = Get-BitLockerVolume -MountPoint "C:"

        if($bitlocker.ProtectionStatus -eq 1){

            $BitLockerStatus = "Enabled"

        }
        else{

            $BitLockerStatus = "Disabled"

        }

    }

    catch{

        $BitLockerStatus = "Unavailable"

    }

    try{

        $Defender = (Get-MpComputerStatus).AntivirusEnabled

    }

    catch{

        $Defender = "Unavailable"

    }

    [PSCustomObject]@{

        BitLocker = $BitLockerStatus
        Defender  = $Defender

    }

}




$ComputerInfo = Get-ComputerInfoData
$DiskInfo     = Get-DiskInfo
$NetworkInfo  = Get-NetworkInfo
$SecurityInfo = Get-SecurityInfo


$Inventory = [PSCustomObject]@{

    ComputerName = $ComputerInfo.ComputerName
    CurrentUser  = $ComputerInfo.CurrentUser
    Manufacturer = $ComputerInfo.Manufacturer
    Model        = $ComputerInfo.Model
    SerialNumber = $ComputerInfo.SerialNumber
    BIOSVersion  = $ComputerInfo.BIOSVersion
    Processor    = $ComputerInfo.Processor
    RAM_GB       = $ComputerInfo.RAM_GB
    OperatingSystem = $ComputerInfo.OperatingSystem
    Version      = $ComputerInfo.Version
    Build        = $ComputerInfo.Build

    DiskSize_GB  = $DiskInfo.DiskSize_GB
    FreeSpace_GB = $DiskInfo.FreeSpace_GB

    IPv4         = $NetworkInfo.IPv4
    MAC          = $NetworkInfo.MAC

    BitLocker    = $SecurityInfo.BitLocker
    Defender     = $SecurityInfo.Defender

    InventoryDate = Get-Date

}


$Inventory | Export-Csv ".\InventoryReport.csv" -NoTypeInformation -Encoding UTF8

