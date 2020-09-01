#################################
# This script can be used to help manage user off-boarding and decomissioning.
# It's working, but lots of error checking / confirmation / logging ins't yet included
#
# Things to add
# - Logging of all actions to %temp%\{username}.txt
# - Check for current AzureAD connection, it not prompt for login
# - Check is Azure AD module is installed
# - Add confirmation of actions for all options
# - Add in a "let's do it all" option
# - Migrate to full Microsoft Graph module's so we can include Exchange actions and editing email addresses, etc
#
# Script by Jay Antoney @ 5G Networks
# www.5gnetworks.com.au | 1300 10 11 12
#
# V0.2 - 2020/08/31
#
# Thanks to:
# function "New-SWRandomPassword" written by Simon Wåhlin, blog.simonw.se
#
#################################

function New-SWRandomPassword {
    <#
    .Synopsis
       Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .DESCRIPTION
       Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .EXAMPLE
       New-SWRandomPassword
       C&3SX6Kn

       Will generate one password with a length between 8  and 12 chars.
    .EXAMPLE
       New-SWRandomPassword -MinPasswordLength 8 -MaxPasswordLength 12 -Count 4
       7d&5cnaB
       !Bh776T"Fw
       9"C"RxKcY
       %mtM7#9LQ9h

       Will generate four passwords, each with a length of between 8 and 12 chars.
    .EXAMPLE
       New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4
       3ABa

       Generates a password with a length of 4 containing atleast one char from each InputString
    .EXAMPLE
       New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4 -FirstChar abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ
       3ABa

       Generates a password with a length of 4 containing atleast one char from each InputString that will start with a letter from 
       the string specified with the parameter FirstChar
    .OUTPUTS
       [String]
    .NOTES
       Written by Simon Wåhlin, blog.simonw.se
       I take no responsibility for any issues caused by this script.
    .FUNCTIONALITY
       Generates random passwords
    .LINK
       http://blog.simonw.se/powershell-generating-random-password-for-active-directory/
   
    #>
    [CmdletBinding(DefaultParameterSetName='FixedLength',ConfirmImpact='None')]
    [OutputType([String])]
    Param
    (
        # Specifies minimum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({$_ -gt 0})]
        [Alias('Min')] 
        [int]$MinPasswordLength = 8,
        
        # Specifies maximum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({
                if($_ -ge $MinPasswordLength){$true}
                else{Throw 'Max value cannot be lesser than min value.'}})]
        [Alias('Max')]
        [int]$MaxPasswordLength = 12,

        # Specifies a fixed password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='FixedLength')]
        [ValidateRange(1,2147483647)]
        [int]$PasswordLength = 8,
        
        # Specifies an array of strings containing charactergroups from which the password will be generated.
        # At least one char from each group (string) will be used.
        [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '23456789', '!"#%&'),

        # Specifies a string containing a character group from which the first character in the password will be generated.
        # Useful for systems which requires first char in password to be alphabetic.
        [String] $FirstChar,
        
        # Specifies number of passwords to generate.
        [ValidateRange(1,2147483647)]
        [int]$Count = 1
    )
    Begin {
        Function Get-Seed{
            # Generate a seed for randomization
            $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
            $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
            $Random.GetBytes($RandomBytes)
            [BitConverter]::ToUInt32($RandomBytes, 0)
        }
    }
    Process {
        For($iteration = 1;$iteration -le $Count; $iteration++){
            $Password = @{}
            # Create char arrays containing groups of possible chars
            [char[][]]$CharGroups = $InputStrings

            # Create char array containing all chars
            $AllChars = $CharGroups | ForEach-Object {[Char[]]$_}

            # Set password length
            if($PSCmdlet.ParameterSetName -eq 'RandomLength')
            {
                if($MinPasswordLength -eq $MaxPasswordLength) {
                    # If password length is set, use set length
                    $PasswordLength = $MinPasswordLength
                }
                else {
                    # Otherwise randomize password length
                    $PasswordLength = ((Get-Seed) % ($MaxPasswordLength + 1 - $MinPasswordLength)) + $MinPasswordLength
                }
            }

            # If FirstChar is defined, randomize first char in password from that string.
            if($PSBoundParameters.ContainsKey('FirstChar')){
                $Password.Add(0,$FirstChar[((Get-Seed) % $FirstChar.Length)])
            }
            # Randomize one char from each group
            Foreach($Group in $CharGroups) {
                if($Password.Count -lt $PasswordLength) {
                    $Index = Get-Seed
                    While ($Password.ContainsKey($Index)){
                        $Index = Get-Seed                        
                    }
                    $Password.Add($Index,$Group[((Get-Seed) % $Group.Count)])
                }
            }

            # Fill out with chars from $AllChars
            for($i=$Password.Count;$i -lt $PasswordLength;$i++) {
                $Index = Get-Seed
                While ($Password.ContainsKey($Index)){
                    $Index = Get-Seed                        
                }
                $Password.Add($Index,$AllChars[((Get-Seed) % $AllChars.Count)])
            }
            Write-Output -InputObject $(-join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value))
        }
    }
}

function Get-UserAzureAccount {
    #Regex pattern for checking an email address
    $EmailRegex = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$'
    $confirm = $false
    
    
    while($confirm -ne 'y') {
        write-host
        #Get the users UPN
        $UserUPN = Read-Host "Please enter in the users full UPN you're wanting to select"
        $UserUPN = $UserUPN.trim()
        while($UserUPN -notmatch $EmailRegex)
        {
         Write-Host "$UserUPN isn't a valid UPN. A UPN looks like an email address" -ForegroundColor Red
         $UserUPN = Read-Host "Please enter in the users full UPN you're wanting to select"
        }

        $user = get-azureaduser -ObjectId $UserUPN
        if ($user.count -eq 1) {
            clear
            write-host 
            write-host "------------- Confirm user details ----------------" -ForegroundColor Yellow
            write-host "Display Name: $($user.displayname)"
            write-host "Username: $($user.userprincipalname)"
            write-host "---------------------------------------------------" -ForegroundColor Yellow
            $confirm = Read-Host "Is this the correct user? (y/n)"
        } else {
            clear
            write-host
            Write-Host "No username found with username $UserUPN. Please try again" -ForegroundColor Yellow
            write-host
            $UserUPN = ''
        }
    }

    return $user
}

$mainLoop = $true
while ($mainLoop -eq $true) {
    clear

    $UserDetails = Get-UserAzureAccount
    $outpath = "c:\temp\$($UserDetails.givenname)-$($UserDetails.Surname)_actions.txt"

    $confirm2 = $false
    clear
    write-host
    write-host "Display Name: $($UserDetails.displayname)"
    write-host "Username: $($UserDetails.userprincipalname)"
    write-host "Account Active: $($UserDetails.AccountEnabled)"
    write-host
    write-host
    write-host "---------------------------------------------------" -ForegroundColor Yellow
    write-host "        Please don't 'Just try this script'" -ForegroundColor Yellow
    write-host "         It will actually change things" -ForegroundColor Yellow
    write-host "---------------------------------------------------" -ForegroundColor Yellow
    write-host 
    $confirm2 = Read-Host "Are you SURE you want to modify this user? Type YES"

    if ($confirm2 -ne "yes") {write-host "You've confirmed that this is NOT the correct user. Exiting script" -ForegroundColor Red; break};

    $selection = $false

    while ($selection -ne "n" -and $selection -ne "e")
    {
        clear
        write-host
        write-host "Getting user details and loading menu..." -ForegroundColor Yellow
        sleep(2)
        write-host

        #Setup text for Menu Option 3
        if ($UserDetails.displayname -match "ZZZ") {$menu3 = "[Complete]"; $menu3c = "White"} else {$menu3 = "[Requires Action]"; $menu3c = "Yellow"}
        
        #Setup text for Menu Option 6
        $usrManager = Get-AzureADUserManager -ObjectId $UserDetails.userprincipalname
        if ($usrManager.count -eq 0) {$menu6 = "[Nill assigned]"; $menu6c = "White"} else {$menu6 = "[Manager assigned - $($usrManager.DisplayName)]"; $menu6c = "Yellow"}
    
        #Setup text for Menu Option 7
        $groups = Get-AzureADUserMembership -ObjectId $UserDetails.userprincipalname | Select ObjectID, Displayname
        if ($groups.count -eq 0) {$menu7 = "[Nill assigned]"; $menu7c = "White"} else {$menu7 = "[Groups assigned]"; $menu7c = "Yellow"}

        #Setup text for Menu Option 8
        $reports = Get-AzureADUserDirectReport -ObjectId $UserDetails.userprincipalname | Select DisplayName,UserPrincipalName
        if ($reports.count -eq 0) {$menu8 = "[Nill assigned]"; $menu8c = "White"} else {$menu8 = "[Direct reports are assigned]"; $menu8c = "Yellow"}

        #Setup text for Menu Option 9
        $licenses = Get-AzureADUserLicenseDetail -ObjectId $UserDetails.userprincipalname | Select SkuPartNumber,SkuID
        if ($licenses.count -eq 0) {$menu9 = "[Nill assigned]"; $menu9c = "White"} else {$menu9 = "[Licenses assigned]"; $menu9c = "Yellow"}

        #Setup text for Menu Option 10
        $domains = get-azureaddomain | Where {$_.Name.ToLower().EndsWith("onmicrosoft.com") } | Select Name
        if ($domains.count -eq 1) {$menu10 = "@$domains.Name"} else {$menu10 = "an onmicrosoft.com domain"}

        #Display the Menu
        clear
        write-host
        write-host "Display Name: $($UserDetails.displayname)"
        write-host "Username: $($UserDetails.userprincipalname)"
        write-host "Account Active: $($UserDetails.AccountEnabled)"
        write-host "User shown in GAL: $($UserDetails.ShowInAddressList)"
        if ((Get-AzureADUserDirectReport -ObjectId $UserDetails.userprincipalname).count -gt 0){write-host "User has direct reports that will need new a new manager assigned" -ForegroundColor "Yellow"}
        write-host
        write-host
        write-host "---- MENU ----"
        write-host "1  - Change Password to Random Password"
        write-host "2  - Block user account from sign-in"
        write-host "3  - Update account name to include ZZZ_ at the start $menu3" -foregroundColor $menu3c
        write-host "4  - [not working] Hide the user from the Global Address List"
        write-host "5  - Sign user out of all Microsoft 365 services"
        write-host "6  - Remove Users Manager $menu6" -foregroundColor $menu6c
        write-host "7  - Remove the user from all Groups $menu7" -foregroundColor $menu7c
        write-host "8  - View people that this user is a manager of $menu8" -foregroundColor $menu8c
        write-host "9  - Manage User Licenses $menu9" -foregroundColor $menu9c
        Write-Host "10 - Change username to $menu10"
        write-host
        write-host "n  - New User"
        write-host "e  - Exit"
        write-host
    
        $selection = Read-Host "What action would you like to take?"

        clear
        write-host "Display Name: $($UserDetails.displayname)"
        write-host "Username: $($UserDetails.userprincipalname)"
        write-host "Account Active: $($UserDetails.AccountEnabled)"
        write-host "User shown in GAL: $($UserDetails.ShowInAddressList)"
        write-host

        switch($selection){
           1 {
                write-host "Updating user password..."
                $RndPwd = New-SWRandomPassword -PasswordLength 16
                $Pwd = (ConvertTo-SecureString -AsPlainText $RndPwd -Force)
                $error.Clear()
                try {Set-AzureADUserPassword -ObjectId $UserDetails.userprincipalname -Password $Pwd -ErrorAction SilentlyContinue}
                catch {write-host "Unable to set the users password. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                if (-not $error)
                {
                    write-host
                    write-host
                    write-host "The password for $($UserDetails.DisplayName) has been updated" -ForegroundColor Green
                    write-host
                    pause
                }
             }
           2 {
                write-host "Blocking user account from sign-in..."
                $error.Clear()
                try {Set-AzureADUser -ObjectID $UserDetails.userprincipalname -AccountEnabled $false -ErrorAction SilentlyContinue}
                catch {write-host "Unable to block the users sign-in. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                if (-not $error)
                {
                    # 100% Confirm the action was taken
                    sleep(3)
                    $UserDetails = get-azureaduser -ObjectId $UserDetails.userprincipalname
                    if ($UserDetails.AccountEnabled -eq $False) {
                        write-host
                        write-host
                        write-host "The user $($UserDetails.DisplayName) has been blocked from sign-in" -ForegroundColor Green
                        write-host
                        pause
                    } else {
                        write-host
                        write-host
                        write-host "The user $($UserDetails.DisplayName) was NOT blocked from sign-in. Please try again" -ForegroundColor Red
                        write-host
                        pause
                    }
                }
             }
           3 {
                write-host "Updating account name..."
                $NewFirstName = "ZZZ_$($UserDetails.givenname)"
                $NewSurname = "ZZZ_$($UserDetails.surname)"
                $NewDisplayName = "ZZZ_$($UserDetails.displayname)"
                $error.Clear()
                if ($UserDetails.displayname -notmatch "ZZZ") {
                    try {Set-AzureADUser -ObjectID $UserDetails.userprincipalname -DisplayName $NewDisplayName -GivenName $NewFirstName -Surname $NewSurname -Department "Off-boarded" -TelephoneNumber $null -ErrorAction SilentlyContinue}
                    catch {write-host "Unable to update users details. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                }
                if (-not $error)
                {
                    # 100% Confirm the action was taken
                    sleep(3)
                    $UserDetails = get-azureaduser -ObjectId $UserDetails.userprincipalname
                    if ($UserDetails.displayname -match "ZZZ") {
                        write-host
                        write-host
                        write-host "The user's display name has been updated to: $($UserDetails.DisplayName)" -ForegroundColor Green
                        write-host
                        pause
                    } else {
                        sleep(5)
                        $UserDetails = get-azureaduser -ObjectId $UserDetails.userprincipalname
                        if ($UserDetails.displayname -notmatch "ZZZ") {
                            write-host
                            write-host
                            write-host "The user's $($UserDetails.DisplayName) was NOT updated. Please try again" -ForegroundColor Red
                            write-host "---- ERROR IF AVAIL ----"
                            write-host $Error
                            write-host "---- END ERROR ----"
                            write-host
                            pause
                        } else {
                            write-host
                            write-host
                            write-host "The user's display name has been updated to: $($UserDetails.DisplayName)" -ForegroundColor Green
                            write-host
                            pause
                        }
                    }
                }
             }
           4 {
                write-host "Hiding the user from the Global Address List..."
                $error.Clear()
                try {Set-AzureADUser -ObjectID $UserDetails.userprincipalname -ShowInAddressList $false -ErrorAction SilentlyContinue}
                catch {write-host "Unable to hide the user from the Global Address List. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                if (-not $error)
                {
                    # 100% Confirm the action was taken
                    sleep(3)
                    $UserDetails = get-azureaduser -ObjectId $UserDetails.userprincipalname
                    if ($UserDetails.ShowInAddressList -eq $false) {
                        write-host
                        write-host
                        write-host "The user $($UserDetails.DisplayName) has been hidden from the Global Address List" -ForegroundColor Green
                        write-host
                        pause
                    } else {
                        write-host
                        write-host
                        write-host "The user $($UserDetails.DisplayName) wasn't able to be hidden from the Global Address List. Please try again" -ForegroundColor Red
                        write-host
                        pause
                    }
                }
             }
           5 {
                write-host "Signing user out of Microsoft 365 services..."
                $error.Clear()
                try {Set-AzureADUser -ObjectID $UserDetails.userprincipalname -ShowInAddressList $false -ErrorAction SilentlyContinue}
                catch {write-host "Unable to sign user out. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                if (-not $error)
                {
                    write-host
                    write-host
                    write-host "The user $($UserDetails.DisplayName) has been signed out of Microsoft 365 services" -ForegroundColor Green
                    write-host
                    pause
                }
             }
           6 {
                write-host "Removing the users assigned manager..."
                $error.Clear()
                try {Remove-AzureADUserManager -ObjectID $UserDetails.userprincipalname -ErrorAction SilentlyContinue}
                catch {write-host "Unable to remove the users assigned manager. Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                if (-not $error)
                {
                    sleep(2)
                    write-host
                    write-host
                    write-host "The assigned manager for $($UserDetails.DisplayName) has been removed" -ForegroundColor Green
                    write-host
                    pause
                }
             }
           7 {
                write-host "Removing the user from all Azure AD Groups..."
                $groups = Get-AzureADUserMembership -ObjectId $UserDetails.userprincipalname | Select ObjectID, Displayname
                Write-Output "------- AZURE AD GROUPS REMOVED FROM ---------" | Out-file $outpath -Append
                $groups | Out-file $outpath -Append
                Write-Output "----------------------------------------------" | Out-file $outpath -Append
                $error.Clear()

                Write-Host "Removing from groups:" -ForegroundColor Yellow
                foreach ($grp in $groups) {
                    Write-Host "$($grp.DisplayName)"
                    Try{Remove-AzureADGroupMember -ObjectId $grp.ObjectId -MemberId $UserDetails.ObjectId}
                    Catch{Write-Host "Unable to remove from $($grp.DisplayName)" -ForegroundColor Red}
                }
                if (-not $error)
                {
                    write-host
                    write-host
                    write-host "The user $($UserDetails.DisplayName) has been removed from all groups" -ForegroundColor Green
                    write-host
                    pause
                } else {
                    sleep(3)
                    $groups = Get-AzureADUserMembership -ObjectId $UserDetails.userprincipalname | Select ObjectID, Displayname
                    write-host
                    write-host
                    write-host "$($UserDetails.DisplayName) wasn't able to be removed from the following groups:" -ForegroundColor Red
                    $groups | Format-table
                    write-host
                    pause
                }
             }
           8 {
                $reports = Get-AzureADUserDirectReport -ObjectId $UserDetails.userprincipalname | Select DisplayName,UserPrincipalName
                if ($reports.count -ne 0) {
                    $menu8selection = $null
                    while ($menu8selection -ne 1 -and $menu8selection -ne 0) {
                        clear
                        write-host
                        write-host "$($UserDetails.DisplayName) is a manager of $($reports.count) staff" -ForegroundColor Yellow
                        $reports | format-table
                        Write-Host
                        Write-Host "1  - Assign the above users to another manager"
                        Write-Host
                        Write-Host "0  - Return to main menu"
                        write-host
                        $menu8selection = Read-Host "What action would you like to take?"
                    }

                    switch ($menu8selection) {
                        1 {
                            write-host
                            write-host
                            $getNewManager = Get-UserAzureAccount
                            $menu8confirm = $null
                            while ($menu8confirm -ne 'n' -and $menu8confirm -ne 'y') {
                                clear
                                write-host
                                write-host "You are able to update the following users manager" -ForegroundColor Yellow
                                write-host
                                $reports | format-table
                                write-host
                                write-host "NEW MANAGER WILL BE: $($getNewManager.DisplayName)" -ForegroundColor Yellow
                                write-host
                                $menu8confirm = Read-Host "Are you sure you want to update the above users manaer to $($getNewManager.DisplayName)? [y/n]"
                            }
                            if ($menu8confirm -eq 'y') {
                                clear
                                write-host
                                write-host "Updating users manager to $($getNewManager.DisplayName)" -ForegroundColor Yellow
                                foreach ($usrmanupdate in $reports) {
                                    Write-Host
                                    Write-Host $usrmanupdate.DisplayName -ForegroundColor Yellow
                                    try{Set-AzureADUserManager -ObjectId $usrmanupdate.userprincipalname -RefObjectId $getNewManager.ObjectId -ErrorAction Stop}
                                    catch{write-host "Unable to change the manager for $($usrmanupdate.userprincipalname). Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                                    if (-not $error)
                                    {
                                        write-host "OK" -ForegroundColor Green
                                    }
                                }
                                Sleep(2)
                            } else {
                                write-host
                                write-host "No changes were made" -foregroundcolor Green
                            }
                            write-host
                            pause
                        }
                        default {}
                    }
                } else {
                    Write-Host "$($UserDetails.DisplayName) isn't a manager of any staff" -ForegroundColor Green
                    write-host
                    write-host
                    pause
                }
                $getNewManager = $null
             }
           9 {
                write-host "Managing User Licenses for $($UserDetails.DisplayName)"
                write-host
                $licenses = Get-AzureADUserLicenseDetail -ObjectId $UserDetails.userprincipalname | Select SkuPartNumber,SkuID
                if ($licenses.count -eq 0) {
                    write-host "$($UserDetails.DisplayName) doesn't have any licenses assigned" -ForegroundColor Green
                    write-host
                    write-host
                    pause
                } else {
                    $licSelection = $false
                    while ($licSelection -ne '0') {
                        $licenses = Get-AzureADUserLicenseDetail -ObjectId $UserDetails.userprincipalname | Select SkuPartNumber,SkuID
                        clear
                        Write-Host
                        write-host "REMOVE User Licenses for $($UserDetails.DisplayName)" -ForegroundColor Yellow
                        Write-Host
                        Write-Host "ID    LICENSE NAME"
                        Write-Host "--    ------------"
                        $i = 0
                        foreach ($lic in $licenses) {
                            $i++
                            Write-Host "$($i)     $($lic.SkuPartNumber)"
                        }
                        Write-Host
                        Write-Host "00    -ALL LICENSES- (Not working yet)"
                        Write-Host
                        Write-Host "0     Return to main menu"
                        Write-Host
                        $Range = '(1-' + $licenses.Count + ')'
                        $licSelection = Read-Host "Select a license to remove" $Range
                    
                        if ($licSelection -ne '0') {
                            $body = @{
                                addLicenses = @()
                                removeLicenses= @($licenses[$licSelection-1].SkuId)
                            }
                            $error.Clear()
                            try{Set-AzureADUserLicense -ObjectId $UserDetails.userprincipalname -AssignedLicenses $body}
                            catch{write-host "Unable to remove the $($licenses[$licSelection-1].SkuPartNumber) license from $($UserDetails.DisplayName). Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                            if (-not $error)
                            {
                                write-host
                                write-host
                                write-host "The $($licenses[$licSelection-1].SkuPartNumber) license from $($UserDetails.DisplayName) has been removed" -ForegroundColor Green
                                $licenses = Get-AzureADUserLicenseDetail -ObjectId $UserDetails.userprincipalname | Select SkuPartNumber,SkuID
                                if ($licenses.count -eq 0) {write-host; write-host "No further licenses remain for this user" -ForegroundColor Green; $licSelection = 0}
                            }
                        }

                    }
                write-host
                write-host
                pause
                }
             }
           10 {
                write-host "Managing Username for $($UserDetails.DisplayName)"
                write-host "CURRENT USERNAME: $($UserDetails.userprincipalname)"
                write-host
                $domains = get-azureaddomain | Where {$_.Name.ToLower().EndsWith("onmicrosoft.com") } | Select Name
                if ($licenses.count -eq 1) {
                    write-host "Change the username for $($UserDetails.DisplayName)" -ForegroundColor Yellow
                    $domain = $domains.Name
                } else {
                    $domainSelection = $faluse
                    while ($domainSelection -ne '0') {
                        $domains = get-azureaddomain | Where {$_.Name.ToLower().EndsWith("onmicrosoft.com") } | Select Name
                        clear
                        Write-Host
                        write-host "Change the username for $($UserDetails.DisplayName)" -ForegroundColor Yellow
                        Write-Host "Please select the new domain name for the user"
                        Write-Host
                        Write-Host "ID    DOMAIN"
                        Write-Host "--    ------"
                        $i = 0
                        foreach ($dom in $domains) {
                            $i++
                            Write-Host "$($i)     $($dom.Name)"
                        }
                        Write-Host
                        Write-Host "0     Return to main menu"
                        Write-Host
                        $Range = '(1-' + $domains.Count + ')'
                        $domainSelection = Read-Host "Select a domain name to assign" $Range
                    
                        if ($domainSelection -ne '0') {
                            $domain = $domains[$domainSelection-1].Name
                            $error.Clear()
                            $newUPN = "ZZZ_"
                            $newUPN += $UserDetails.userprincipalname.Substring(0,$UserDetails.userprincipalname.IndexOf("@"))
                            $newUPN += "@$domain"
                            Write-Host "---------------------------------------------------"
                            Write-Host
                            Write-Host "Please confirm the new username before we change it"
                            Write-Host
                            Write-Host $newUPN -ForegroundColor Yellow
                            Write-Host
                            $menu10Confirm = Read-Host "Are you ready to change the username for $($UserDetails.DisplayName)? (y/n)"
                            if ($menu10Confirm -eq 'y') {
                                try{Set-AzureADUser -ObjectId $UserDetails.userprincipalname -UserPrincipalName $newUPN}
                                catch{write-host "Unable to change the username for $($UserDetails.DisplayName). Maybe try again?" -ForegroundColor Red; write-host;write-host "---- ERROR ----"; write-host $Error; write-host "---- END ERROR ----"; write-host; pause}
                                if (-not $error)
                                {
                                    sleep(3)
                                    $UserDetails = get-azureaduser -ObjectId $newUPN
                                    write-host
                                    write-host
                                    write-host "The username for $($UserDetails.DisplayName) has been changed to $($UserDetails.userprincipalname)" -ForegroundColor Green
                                }
                            } else {
                                write-host
                                write-host "Username not changed for $($UserDetails.DisplayName)" -ForegroundColor Green
                            }
                        }
                    write-host
                    write-host
                    pause
                    $domainSelection = 0
                    }
                
                }
             }
           e {
                clear
                write-host
                Write-Host "Thanks for using this script" -ForegroundColor Yellow
                Write-Host
                Write-Host "For bug, feedback and comments, please see the 5G Networks GitHub"
                Write-Host "https://github.com/5gn"
                Write-Host
                Write-Host "5G Networks"
                Write-Host "+61 1300 10 11 12"
                Write-Host "5gnetworks.com.au"
                write-host
                pause
                clear
                $mainLoop = $false
             }
           n {
                $UserDetails = $null
                $mainLoop = $true
             }
           default {write-host; write-host "Please enter a valid selection" -ForegroundColor Yellow; pause}
        }
    }
#Start main loop again if $mainLoop = True
}
