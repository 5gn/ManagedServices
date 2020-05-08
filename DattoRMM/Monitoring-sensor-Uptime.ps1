# 
# A Monitoring Component for Datto RMM
# Detect the uptime of the windows computer
# Written by Michael Rogers 5th May 2020
# 
# Finds the last boot time of the computer, then calculates today's date. Then the total up time.
#
# INPUT VARIABLE: $DaysupInput = How many days uptime you want until the alert sounds.
#

# Get the date of the last boot
$wmio = Get-WmiObject win32_operatingsystem -ComputerName '127.0.0.1'

#Get today's date
$LocalTime = [management.managementDateTimeConverter]::ToDateTime($wmio.localdatetime)

#Calculate in time since last boot
$LastBootUptime = [management.managementDateTimeConverter]::ToDateTime($wmio.lastbootuptime)
$timespan = $localTime - $lastBootUptime
$daysup = $timespan.Days

# Determine if to sound the alert by comparing if the amount of days up is higher than the alert threshold
If ( $daysup -gt $daysupInput ) {
    Write-Host "<-Start Result->"
    Write-Host "Alert=The computer has been up for ($daysup) which is longer than has been set on this alert of ($daysupInput)"
    Write-Host "<-End Result->"
    Exit 1
}
