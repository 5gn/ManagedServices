<#
v0.1.1 - 6th May 2020

Datto RMM Agent deploy by Microsoft Endpoint Manager (Intune)
Adapted from a script by Jon North, Datto, March 2020

Script by Jay Antoney, 5G Networks
www.5gnetworks.com.au
GitHub: https://github.com/5gn

-- Script Aim --
Deploys the DattoRMM agent to AzureAD joined machines fully managed by Intune
Download the Agent installer, run it, wait for it to finish, delete it

-- Script Requirements --
If running the script manually, you must run it in an elevated PowerShell prompt
When creating the script deployment policy in Microsoft EndPoint Manager, the following settings must be set
> Run this script using the logged on credentials = NO
> Enforce script signature check = NO
> Run script in 64 bit PowerShell Host = NO

-- Version --
0.1.1 Write in the site ID as a parameter to the script and check to make sure the site ID is semi valid - @github/jantoney

-- Needed Improvements --
1. Choose the Agent installer based off of an Active Directory Group that the machine is a part of or another way of selecting the group automatically
#>

#set passed parameters
param($RMMSiteID = $null)

# Manual Datto RMM Site ID Allocation
$manualRMMSiteID = ""
$manualRMMSiteName = ""

# Script Parameters
$LogPath = "$env:TEMP\DattoRMMInsatll"     # NO trailing slash \
$LogFileName = "DattoRMMAgentInstall.log"

#### DO NOT CHANGE BELOW THIS LINE ####

$InstallStart=(Get-Date)
$LogFile = "$LogPath\$LogFileName"
$AgentURL="https://Syrah.centrastage.net/csm/profile/downloadAgent/$RMMSiteID"

# Check and create an event log Directory on the machine if not already created
Try {
  if( -not (test-path -Path $LogPath -ErrorAction SilentlyContinue)) {
    new-item -path $LogPath -ItemType Directory -Force -ErrorAction Continue
  }
}
Catch {
  Write-Output "We can't create that directory!"
  exit 1
}

Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Started Datto RMM Agent install script.

# Check the Site ID is present and valid
if ($RMMSiteID -eq $null) {
  Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  No site ID has been passed to the script. Checking Manual Site ID"
  If ($manualRMMSiteID -ne $null) {
  	$RMMSiteID = $manualRMMSiteID
	Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Manual Site ID used"
  } else {
  	Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  No Site ID found. Exiting"
	Write-Output "No site ID passed"
  	Exit 1
  }
}

#Check if the Site ID matches the required Regex pattern
if ($RMMSiteID -notmatch '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}') {
   Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Supplied Datto RMM Site ID ($SiteID) is in an invalid format."
   Write-Output "Datto RMM Site ID format is incorrect"
   Write-Output "ID Entered: $SiteID"
   Exit 1
}

# First check if Agent is installed and instantly exit if so
If (Get-Service CagService -ErrorAction SilentlyContinue) {
    Write-Output "Datto RMM Agent already installed on this device"
    Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Datto RMM Agent already installed on this device." -Append
    Exit 0
}

# Download the Agent
$DownloadStart=(Get-Date)
Write-Output "Starting Agent download at $(Get-Date -Format HH:mm) from $AgentURL"
Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Starting Agent download from $AgentURL." -Append
(New-Object System.Net.WebClient).DownloadFile($AgentURL, "$LogPath\DRMMSetup.exe")

# Confirm download of Agent file, exit on fail
If (Test-Path "$LogPath\DRMMSetup.exe") {
    Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Agent Downloaded." -Append
    Write-Output "Agent download completed at $(Get-Date -Format HH:mm) in $((Get-Date).Subtract($DownloadStart).Seconds) seconds `r`n`r`n"
} else {
    Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Agent Download Failed." -Append
    Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  $error" -Append
    Write-Output "Agent installer not found."
    Exit 1
}

$InstallStart=(Get-Date)
Write-Output "Starting Agent install to target site at $(Get-Date -Format HH:mm)..."
Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Start Agent Install." -Append
Start-Process "$LogPath\DRMMSetup.exe" -wait
Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Agent Install Complete in $((Get-Date).Subtract($InstallStart).Seconds) seconds." -Append
Write-Output "Agent install completed at $(Get-Date -Format HH:mm) in $((Get-Date).Subtract($InstallStart).Seconds) seconds."
Remove-Item "$LogPath\DRMMSetup.exe" -Force
Out-File -FilePath $LogFile "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss:fff')  :  Removed Agent Installer." -Append
Exit 0
    
