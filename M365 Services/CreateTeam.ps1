#*******************************************************************************************************************************************
# CreateTeam.ps1
# Copyright Dave Gerrard 2020
# Create a Team with specific inputs to control SharePoint Url, group email and vanity display name.

$errorInput = $false

Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "**********************************************************************************"
Write-Host -BackgroundColor Black -ForegroundColor Cyan " Create Team using prompts                                                        "
Write-Host -BackgroundColor Black -ForegroundColor Cyan " Copyright Dave Gerrard 2020                                                      "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
Write-Host -BackgroundColor Black -ForegroundColor Cyan " Requires the following inputs:                                                   "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Tenancy prefix                                                               "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Tenancy email domain                                                         "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Teams managed path                                                           "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Team vanity name                                                             "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - SharePoint strong URL                                                        "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Group email address                                                          "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Team owner                                                                   "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Team Admin credentials (uses Teams PowerShell module)                        "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "   - Teams PowerShell module                                                      "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
Write-Host -BackgroundColor Black -ForegroundColor Cyan "**********************************************************************************"

Write-Host ""

#capture inputs and validate
try {
    #test for a rerunning script with common variables already set
    if($null -eq $tenancyPrefix -Or $null -eq $tenancyEmailDomain)
    {
        Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
        Write-Host -BackgroundColor Black -ForegroundColor Cyan " Please provide the following information                                        "
        Write-Host -BackgroundColor Black -ForegroundColor Yellow " Tenancy PharePoint.com subdomain e.g. the bit before .sharepoint.com             "
        $tenancyPrefix = Read-Host -Prompt ":"

        Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
        Write-Host -BackgroundColor Black -ForegroundColor Yellow " Tenancy email domain                                                             "
        $tenancyEmailDomain = Read-Host -Prompt ":"
    }
    else {
        Write-Host ""
        Write-Host -ForegroundColor Magenta "    "$tenancyPrefix
        Write-Host -ForegroundColor Magenta "    "$tenancyEmailDomain
        Write-Host ""
    }
    Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow " Teams managed path e.g sites or teams                                            "
    $teamsManagedPath = Read-Host -Prompt ":"

    Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
    Write-Host -BackgroundColor Black -ForegroundColor Cyan "  Please provide the following information                                        "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow " Team vanity name                                                                 "
    $teamVanityName = Read-Host -Prompt ":"
    
    Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow " SharePoint strong URL (just the site url, no spaces and must not already exist)  "
    $teamSharePointUrl = Read-Host -Prompt ":"
    
    Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow " Group email address (do not include the domain and must not exist)               "
    $teamGroupEmail = Read-Host -Prompt ":"
        
    Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow " Team owner email address (only one)                                              "
    $teamTeamOwner = Read-Host -Prompt ":"

    if($teamVanityName -eq "" -Or $teamSharePointUrl -eq "" -Or $teamGroupEmail -eq "" -Or $teamTeamOwner -eq "")
    {
        $errorInput = $true
    }
}
catch {
    if($errorInput -eq $true)
    {
        Write-Host -BackgroundColor White -ForegroundColor Red "**********************************************************************************"
        Write-Host -BackgroundColor White -ForegroundColor Red " Missing inputs                                                                   "
        Write-Host -BackgroundColor White -ForegroundColor Red "**********************************************************************************"
        break
    }
}

#validate inputs
Write-Host -BackgroundColor Black -ForegroundColor Cyan "                                                                                  "
Write-Host -BackgroundColor Black -ForegroundColor Cyan " Please confirm your inputs...                                                    "

$newSharePointUrl = "https://" + $tenancyPrefix + ".sharepoint.com/" + $teamsManagedPath + "/" + $teamSharePointUrl
$newMailNickName = $teamGroupEmail + "@" + $tenancyEmailDomain

Write-Host -ForegroundColor Cyan " Team vanity name:"
Write-Host -ForegroundColor Magenta "    "$teamVanityName
Write-Host ""

Write-Host -ForegroundColor Cyan " SharePoint strong url:"
Write-Host -ForegroundColor Magenta "    "$newSharePointurl
Write-Host ""

Write-Host -ForegroundColor Cyan " Group email address:"
Write-Host -ForegroundColor Magenta "    "$newMailNickName
Write-Host ""

Write-Host -ForegroundColor Cyan " Team owner"
Write-Host -ForegroundColor Magenta "    "$teamTeamOwner
Write-Host ""

$confirmInputs = Read-Host -Prompt "Confirm Y/n"

if($confirmInputs -eq "N" -Or $confirmInputs -eq "n")
{
    Write-Host -BackgroundColor White -ForegroundColor Red "**********************************************************************************"
    Write-Host -BackgroundColor White -ForegroundColor Red " Inputs not confirmed                                                             "
    Write-Host -BackgroundColor White -ForegroundColor Red "**********************************************************************************"
    
    Write-Host ""
    $moreError = Read-Host -Prompt "Create another Team? Y/n"
    if($moreError -eq "Y" -Or $moreError -eq "y")
    {
        & ".\CreateTeam.ps1"
    }
    else {
        Disconnect-MicrosoftTeams
        Write-Host "Disconnected from Teams for "$tenancyPrefix
        break
    }
}
else
{
    #connect to Teams
    Connect-MicrosoftTeams

    Write-Host -BackgroundColor Black -ForegroundColor Cyan "Creating team...                                                                   "
    New-Team -DisplayName $teamVanityName -MailNickName $teamGroupEmail -Visibility "Private" -Owner $teamTeamOwner
    
    Write-Host ""
    
    #get group id
    $groupId = (Get-Team -MailNickName $teamGroupEmail).GroupId
    
    Get-Team -GroupId $groupId
}

Write-Host ""
$more = Read-Host -Prompt "Create another Team? Y/n"
if($more -eq "Y" -Or $more -eq "y")
{
    & ".\CreateTeam.ps1"
}
else {
    Disconnect-MicrosoftTeams
    Write-Host "Disconnected from Teams for "$tenancyPrefix
    break
}