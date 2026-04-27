#Requires -RunAsAdministrator
Param(
	[Parameter(Mandatory, HelpMessage="Please provide an alias for 127.0.0.1")][string] $LoopbackAlias,
	[string] $Action = "install"
)

# Global variables as requested by maintainers
$sysdir = [Environment]::SystemDirectory
$hostsFile = "$sysdir\drivers\etc\hosts"

# Adds an alias for 127.0.0.1 to the hosts file
function Add-AliasToHost {
    param ([string]$LoopbackAlias)
    $aliasLine = "127.0.0.1 $LoopbackAlias"

    if (Test-Path $hostsFile) {
        $content = @(Get-Content $hostsFile)
        foreach ($line in $content) {
            if ($null -ne $line -and $line.Trim() -eq $aliasLine) {
                return # Already exists
            }
        }
        
        # Safe append using temporary file strategy
        $content += $aliasLine
        $content | Set-Content "$hostsFile.tmp" -Encoding ascii
        Move-Item "$hostsFile.tmp" $hostsFile -Force
    }
}

# Removes an alias for 127.0.0.1 from the hosts file
function Remove-AliasFromHost {
    param ([string]$LoopbackAlias)
    $aliasLine = "127.0.0.1 $LoopbackAlias"

    if (Test-Path $hostsFile) {
        $content = @(Get-Content $hostsFile)
        # The .Trim() here is the fix to ensure the line is found and removed
        $newContent = @($content | Where-Object { $null -ne $_ -and $_.Trim() -ne $aliasLine })

        if ($content.Count -gt $newContent.Count) {
            $newContent | Set-Content "$hostsFile.tmp" -Encoding ascii
            Move-Item "$hostsFile.tmp" $hostsFile -Force
        }
    }
}

# Sets in the registry the webclient file size limit to the maximum value
function Set-WebDAVFileSizeLimit {
    $RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\WebClient\Parameters'
    $Name         = 'FileSizeLimitInBytes'
    $Value        = '0xffffffff'

    If (-NOT (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force | Out-Null
}

# Changes the network provider order such that the builtin Windows webclient is always first
function Edit-ProviderOrder {
    $RegistryPath    = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\HwOrder'
    $Name            = 'ProviderOrder'
    $WebClientString = 'webclient'

    $CurrentOrder = (Get-ItemProperty $RegistryPath $Name).$Name
    $OrderWithoutWebclientArray = $CurrentOrder -split ',' | Where-Object {$_ -ne $WebClientString}
    $WebClientArray = @($WebClientString)

    $UpdatedOrder = ($WebClientArray + $OrderWithoutWebclientArray) -join ","
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $UpdatedOrder -PropertyType String -Force | Out-Null
}

# Execution Logic with strict validation
if ($Action -eq "uninstall") {
    Remove-AliasFromHost $LoopbackAlias
    Write-Output 'Ensured alias removed from hosts file'
} elseif ($Action -eq "install") {
    Add-AliasToHost $LoopbackAlias
    Write-Output 'Ensured alias exists in hosts file'

    Set-WebDAVFileSizeLimit
    Write-Output 'Set WebDAV file size limit'

    Edit-ProviderOrder
    Write-Output 'Ensured correct provider order'
} else {
    Write-Error "Invalid action: $Action. Only 'install' or 'uninstall' are supported."
    exit 1
}

exit 0
