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

    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    $computer = Get-CimInstance Win32_ComputerSystem -CimSession $CimSession
    $bios     = Get-CimInstance Win32_BIOS -CimSession $CimSession
    $cpu      = Get-CimInstance Win32_Processor -CimSession $CimSession
    $os       = Get-CimInstance Win32_OperatingSystem -CimSession $CimSession

    [PSCustomObject]@{

        ComputerName = $computer.Name
        CurrentUser = $computer.UserName
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        SerialNumber = $bios.SerialNumber
        BIOSVersion = $bios.SMBIOSBIOSVersion
        Processor = $cpu.Name
        RAM_GB = [math]::Round($computer.TotalPhysicalMemory /1GB,2)
        OperatingSystem = $os.Caption
        Version = $os.Version
        Build = $os.BuildNumber

    }

}


function Get-DiskInfo {

    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    $disk = Get-CimInstance `
        Win32_LogicalDisk `
        -CimSession $CimSession `
        -Filter "DeviceID='C:'"

    [PSCustomObject]@{

        DiskSize_GB = [math]::Round($disk.Size/1GB,2)

        FreeSpace_GB = [math]::Round($disk.FreeSpace/1GB,2)

        UsedSpace_GB = [math]::Round(($disk.Size-$disk.FreeSpace)/1GB,2)

        FreePercent = [math]::Round(($disk.FreeSpace/$disk.Size)*100,2)

    }

}

function Get-NetworkInfo {

    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    $adapter = Get-CimInstance `
        Win32_NetworkAdapterConfiguration `
        -CimSession $CimSession |
        Where-Object IPEnabled |
        Select-Object -First 1

    [PSCustomObject]@{

        IPv4 = ($adapter.IPAddress |
            Where-Object {$_ -match '^\d+\.'} |
            Select-Object -First 1)

        MAC = $adapter.MACAddress

        DHCP = $adapter.DHCPEnabled

        Gateway = ($adapter.DefaultIPGateway -join ",")

        DNS = ($adapter.DNSServerSearchOrder -join ",")

    }

}


function Get-SecurityInfo {

    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    $Computer = $CimSession.ComputerName

    $BitLocker = Invoke-Command -ComputerName $Computer {

        try{

            (Get-BitLockerVolume -MountPoint "C:").ProtectionStatus

        }
        catch{

            $null

        }

    }

    $Defender = Invoke-Command -ComputerName $Computer {

        try{

            (Get-MpComputerStatus).AntivirusEnabled

        }
        catch{

            $null

        }

    }

    [PSCustomObject]@{

        BitLocker = $BitLocker

        Defender = $Defender

    }

}




function Get-ComputerInventory {

    <#
    .SYNOPSIS
        Collects complete inventory information from a computer.

    .DESCRIPTION
        Combines hardware, disk, network and security information
        into a single PowerShell object.

    .PARAMETER CimSession
        Active CIM Session.

    .OUTPUTS
        PSCustomObject
    #>

    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession
    )

    $Computer = Get-ComputerInfoData -CimSession $CimSession
    $Disk     = Get-DiskInfo -CimSession $CimSession
    $Network  = Get-NetworkInfo -CimSession $CimSession
    $Security = Get-SecurityInfo -CimSession $CimSession

    [PSCustomObject]@{

        # Computer Information
        ComputerName    = $Computer.ComputerName
        CurrentUser     = $Computer.CurrentUser
        Manufacturer    = $Computer.Manufacturer
        Model           = $Computer.Model
        SerialNumber    = $Computer.SerialNumber
        BIOSVersion     = $Computer.BIOSVersion
        Processor       = $Computer.Processor
        RAM_GB          = $Computer.RAM_GB
        OperatingSystem = $Computer.OperatingSystem
        Version         = $Computer.Version
        Build           = $Computer.Build

        # Disk Information
        DiskSize_GB     = $Disk.DiskSize_GB
        UsedSpace_GB    = $Disk.UsedSpace_GB
        FreeSpace_GB    = $Disk.FreeSpace_GB
        FreePercent     = $Disk.FreePercent

        # Network Information
        IPv4            = $Network.IPv4
        MAC             = $Network.MAC
        DHCP            = $Network.DHCP
        Gateway         = $Network.Gateway
        DNS             = $Network.DNS

        # Security Information
        BitLocker       = $Security.BitLocker
        Defender        = $Security.Defender

        # Inventory Information
        InventoryDate   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    }

}


$OnlineComputers = @(
    $env:COMPUTERNAME
)


$Results = @()

foreach ($Computer in $OnlineComputers) {

    $Session = $null

    try {

        $Session = New-CimSession -ComputerName $Computer

        $Results += Get-ComputerInventory -CimSession $Session

        Write-Host "[OK] $Computer" -ForegroundColor Green

    }
    catch {

       Write-Warning "[ERROR] $Computer : $($_.Exception.Message)"

        Add-Content `
        ".\Reports\Errors.log" `
        "$(Get-Date) - $Computer - $($_.Exception.Message)"
        

    }
    finally {

        if ($Session) {
            Remove-CimSession $Session
        }

    }

}


if (!(Test-Path ".\Reports")) {

    New-Item `
        -ItemType Directory `
        -Path ".\Reports" | Out-Null

}

$Results | Export-Csv `
    ".\Reports\Inventory.csv" `
    -NoTypeInformation `
    -Encoding UTF8

    
