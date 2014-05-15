param(
   $irc = $(PowerBot\Get-PowerBotIrcClient)
)

Import-Module SQLitePSProvider -ErrorAction Stop

## NOTE: These might need to be configureable per network. The values given are for FreeNode:
$NickServ = "NickServ"
$Services = "services."

${ActiveUsers} = @{}
${PendingUsers} = @()

# NOTE: PowerBot will create a "data:" drive if the "SQLite" module is present.
if(!(Test-Path data:)) { 
   Write-Warning "No data drive, UserTracking and Roles disabled"
   return
}

# So all we have to worry about is whether the Roles table is present
if(!(Test-Path data:\Roles)) {
   New-Item data:\Roles -Value @{ Account="TEXT UNIQUE NOT NULL"; Roles="TEXT"; }
}

################################################################################
##  These five functions serve as Authentication for FreeNode
##  They are based on the fact that the user must be registered
function Sync-Join {
   param($Source, $EventArgs)
   Write-Host "Sync Join: " $Nick
   if($irc.Nicknames -notcontains $Nick) {
      $irc.rfcWhoIs($Nick)
   }
}

function Sync-Part {
   param($Source, $EventArgs)
   Write-Host $EventArgs.Who "just parted" $EventArgs.Channel "saying" $EventArgs.PartMessage -fore DarkCyan
   if(${ActiveUsers}.ContainsKey($Nick)) {
      $null = ${ActiveUsers}.Remove($Nick)
   }
}

# function Sync-Who {
#    param($Source, $EventArgs)
#    Write-Host "Sync Who: " $EventArgs.Nick -fore DarkCyan
#    $irc.rfcWhoIs($EventArgs.Nick)
# }

function Sync-NickChange {
   param($Source, $EventArgs)
   # $irc.rfcWhoIs($Nick)
   Write-Host $EventArgs.OldNickname "is now" $EventArgs.NewNickname -fore DarkCyan
   if(${ActiveUsers}.ContainsKey($EventArgs.OldNickname)) {
      ${ActiveUsers}.($EventArgs.NewNickname) = ${ActiveUsers}.($EventArgs.OldNickname)
      $null = ${ActiveUsers}.Remove($EventArgs.OldNickname)
   }
}

# function Sync-Names {
#    param($Source, $EventArgs)
#    Write-Host "Sync Names: " $($EventArgs.UserList -join ' ') -fore DarkCyan
#    $Script:PendingUsers += @($EventArgs.UserList)

#    $Count = [Math]::Min(10, $Script:PendingUsers.Length)
#    foreach($i in 1..$Count) {
#       $Next, $Script:PendingUsers = $Script:PendingUsers
#       Write-Host "NAMES: WHOIS $Next + $($Script:PendingUsers.Length)"
#       $irc.rfcWhoIs($Next)
#    }
# }

function Sync-LoggedIn {
   # .Synopsis
   #    Track the nicknames of logged-in users
   # .Description
   #    For dancer (the IRCD for FreeNode) 
   #    As part of the WHOIS response, we get a Reply with ID 330
   #    Which maps the nick to the account name it's logged in as
   param($Source, $EventArgs)

   Write-Host ("'" + $EventArgs.Nick + "' is logged in as '" + $EventArgs.Account + "'") -fore DarkCyan
   ${ActiveUsers}.($EventArgs.Nick) = $EventArgs.Account

   Write-Host (${ActiveUsers} | Format-Table | Out-String)
}

################################################################################
##  These functions map accounts to one or more roles 
##  And allow management of role-based access
function Get-Role {
   #.Synopsis
   #  Get the role(s) for a user account
   #.Description
   #  Get the role(s) for the user. If the user doesn't have specified roles,
   #  returns "User" for authenticated users, and "Guest" otherwise
   [CmdletBinding(DefaultParameterSetName="Nickname")]
   param(
      # The (Nickserv) account to fetch roles for
      [Parameter(Position=0, Mandatory=$True, ParameterSetName="Account")]
      $Account,
      # The current nickname
      [Parameter(Position=0, ParameterSetName="Nickname")]
      $Nick
   )

   if($Nick) {
      if(${ActiveUsers}.ContainsKey($Nick)) {
         $Account = ${ActiveUsers}.$Nick
      } else {
         Write-Host "Unknown User"
         $irc.rfcWhoIs($Nick)
      }
   }
   if($Account) {
      if($Roles = (Get-Item -Path data:\Roles -filter "Account = '${Account}'").Roles -split "\s+") { 
         @($Roles) 
      } else {
         @("User")
      }
   } else { @("Guest") }
}

function Set-Role {
   [CmdletBinding(DefaultParameterSetName="Nickname")]
   param(
      # The (Nickserv) account to fetch roles for
      [Parameter(Position=0, Mandatory=$True, ParameterSetName="Account")]
      $Account,

      # The role(s) to assign (
      [Parameter(Position=1, Mandatory=$true)]
      [ValidateScript({if($PowerBotUserRoles -contains $_){ $True } else { throw "$_ is not a valid Role. Please use one of: $PowerBotUserRoles"}})]
      [String[]]$Role
   )
   if($Role -notcontains "User") {
      Write-Warning "The 'User' role was not included -- this user will not have access to default commands"
   }

   $Result = Set-Item data:\Roles -Filter "account = '$Account'" -Value @{Roles = $Role -join ' '} -Passthru -ErrorAction SilentlyContinue
   if(!$Result) {
      $Result = New-Item data:\Roles -Account $Account -Roles $($Role -join ' ') -ErrorAction SilentlyContinue
   }

   if($Result) {
      $Result.Roles -split "\s+"
   }
}
