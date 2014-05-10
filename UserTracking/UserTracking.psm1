param(
   $irc = $(PowerBot\Get-PowerBotIrcClient)
)

Import-Module SQLitePSProvider -ErrorAction Stop

## NOTE: These might need to be configureable per network. The values given are for FreeNode:
$NickServ = "NickServ"
$Services = "services."


# NOTE: PowerBot will create a "data:" drive if the "SQLitePSProvider" module is present.
if(!(Test-Path data:)) { return }

# So all we have to worry about is whether the UserTracking table is present
if(!(Test-Path data:\UserTracking)) {
   New-Item data:\UserTracking -Value @{ Account="TEXT UNIQUE NOT NULL"; Nick="TEXT NOT NULL"; LastMask="TEXT NOT NULL"; AcceptableMask="Text"; Roles="TEXT"; }
}

function Sync-Join {
   param($Source, $EventArgs)
   $Data = $EventArgs.Data

   $irc.SendMessage("Message", $NickServ, "info ${Nick}" )   
}

$q = [char]9787
$Script:ReceivingAbout = $Null
function Update-NickservInfo {
   if("$Message" -match "Information on") {
      $global:InfoMessage = $Message
   }

   if($Nick -eq $NickServ -and $Hostname -eq $Services) {
      if($Message -match "Information on.+\b(.+)\b.+\(account.+\b(.+)\b.*\):") {
         # Write-Host "Getting information about $($Matches[2])" -Fore Cyan
         $Script:ReceivingAbout = @{ Account = $Matches[2]; Nick = $Matches[1]; }
      }
      elseif($Script:ReceivingAbout) {
         Write-Host "NickServ about $($Script:ReceivingAbout.Account): $Message"
         if($Message -match "Last addr\s+:\s+(\S*)")
         {
            $Script:ReceivingAbout.LastMask = $Matches[1]
         }
         elseif($Message -match 'Last seen\s+:\s+(.*)')
         {
            if($Matches[1] -eq "now") {
               Write-Host "NickServ says $($Script:ReceivingAbout.Account) is online now." -fore green
               # $null = $Script:ReceivingAbout.RemoveKey('account')
               $Result = Set-Item data:\UserTracking -Filter "Account = '$($Script:ReceivingAbout.Account)'" -Value $Script:ReceivingAbout -ErrorAction SilentlyContinue -ErrorVariable Failed -Passthru
               Write-Host "Result: $Result ($([Bool]!$Failed))"
               if(!$Result) {
                  $Result = New-Item data:\UserTracking @ReceivingAbout -ErrorAction SilentlyContinue -ErrorVariable Failed
                  Write-Host "Result: $Result ($([Bool]!$Failed))"
               }
            } else {
               Write-Host "Imposter: $($Script:ReceivingAbout.Nick) is not $($Script:ReceivingAbout.Account)" -fore red
            }
         }
         elseif($Message -match "\*\*\*.*\bEnd of Info\b.*\*\*\*")
         {
            Write-Host "No more information about $($Script:ReceivingAbout.Account)" -fore darkyellow
            $Script:ReceivingAbout = $Null
         }
      }
   }
}


function Sync-Who {
   param($Source, $EventArgs)
   # $From = "{0}!{1}@{2}" -f $EventArgs.Nick, $EventArgs.Ident, $EventArgs.Host

   $irc.SendMessage("Message", $NickServ, "info $($EventArgs.Nick)" )
}


function Sync-Nick {
   param($Source, $EventArgs)

   Write-Host $("Rename from {0} to {1}" -f $EventArgs.OldNickname, $EventArgs.NewNickname)
   $irc.SendMessage("Message", $NickServ, "info $($EventArgs.NewNickname)" )   
}

function Get-PowerBotUser {
   param(
      [Parameter(Position=0)]
      [Alias("From")]
      $HostMask
   )
   if($HostMask){ $Nick, $Mask = $HostMask.Split('!', 2) }
   elseif($From) { $Nick, $Mask = $From.Split('!', 2) }

   Get-Item -Path data:\UserTracking -filter "Nick = '${Nick}' AND LastMask = '${Mask}'" | Select Account, Nick, LastMask, AcceptableMask, Roles
}

function Get-PowerBotRole {
   [CmdletBinding(DefaultParameterSetName="HostMask")]
   param(
      [Parameter(Position=0,ParameterSetName="Account",Mandatory=$True)]
      $Account,

      [Parameter(ParameterSetName="HostMask")]
      [Alias("From")]
      $HostMask
   )
   if($Account) {
      if($Roles = (Get-Item -Path data:\UserTracking -filter "Account = '${Account}'").Roles -split "\s+") { @($Roles) }
      else { @("User") }
      return
   }
   else{
      if($HostMask){ $Nick, $Mask = $HostMask.Split('!', 2) }
      elseif($From) { $Nick, $Mask = $From.Split('!', 2) }
      else { return @("User") }

      if($Roles = (Get-Item -Path data:\UserTracking -filter "Nick = '${Nick}' AND LastMask = '${Mask}'").Roles -split "\s+") {
         @($Roles)
      } else { @("User") }
   }
}

function Set-PowerBotRole {
   [CmdletBinding(DefaultParameterSetName="HostMask")]
   param(
      [Parameter(Position=0, ParameterSetName="Account", Mandatory=$True)]
      $Account,

      [Parameter(ParameterSetName="HostMask", Mandatory=$True)]
      [Alias("From")]
      $HostMask,

      [Parameter(Position=1, Mandatory=$true)]
      [ValidateScript({if($PowerBotUserRoles -contains $_){ $True } else { throw "$_ is not a valid Role. Please use one of: $PowerBotUserRoles"}})]
      [String[]]$Role
   )

   if($Account) {
      (Set-Item data:\UserTracking -Filter "account = '$Account'" -Value @{Roles = $Role -join ' '} -Passthru).Roles -split "\s+"
   } elseif($HostMask){
      $Nick, $Mask = $HostMask.Split('!', 2)
      (Set-Item data:\UserTracking -Filter "Nick = '${Nick}' AND LastMask = '${Mask}'" -Value @{Roles = $Role -join ' '} -Passthru).Roles -split "\s+"
   }
}


Set-Alias Get-Role Get-PowerBotRole
Set-Alias Roles Get-PowerBotRole