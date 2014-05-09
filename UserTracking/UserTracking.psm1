param(
   $irc = $(PowerBot\Get-PowerBotIrcClient)
)

## NOTE: These might need to be configureable per network. The values given are for FreeNode:
$NickServ = "NickServ"
$Services = "services."


# NOTE: PowerBot will create a "data:" drive if the "SQLitePSProvider" module is present.
# So all we have to worry about is whether 
if(!(Test-Path data:\Users)) {
   New-Item data:\Users -Value @{ Account="TEXT UNIQUE NOT NULL"; Nick="TEXT NOT NULL"; LastMask="TEXT NOT NULL"; Role="TEXT"; }
}

function Sync-Join {
   param($this, $eventArgs)
   $Data = $eventArgs.Data
   # $user = Get-Item -Path data:\Users -filter "lastmask = '${Ident}@${Host}'"
   # if(@($user).Count -gt 1) {
   #    $user = $user | Where { $_.nick -eq $Nick }
   # }
   # if(@($user).Count -eq 1) {
   #
   # }

   Write-Host "${Nick} : ${Ident}@${Hostname} Joined ${Channel}"
   Write-Host "$($args[1].Data | fl | out-string)"

   Write-Host "Channel:  ${global:Channel}   ${Channel}   $($Data.Channel)"
   Write-Host "Hostname: ${global:Hostname}  ${Hostname}  $($Data.Host)"
   Write-Host "Ident:    ${global:Ident}     ${Ident}     $($Data.Ident)"
   Write-Host "Message:  ${global:Message}   ${Message}   $($Data.Message)"
   Write-Host "Nick:     ${global:Nick}      ${Nick}      $($Data.Nick)"
   Write-Host "From:     ${global:From}      ${From}      $($Data.From)"


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
               $Result = Set-Item data:\Users -Filter "account = '$($Script:ReceivingAbout.Account)'" -Value $Script:ReceivingAbout -ErrorAction SilentlyContinue -ErrorVariable Failed -Passthru
               Write-Host "Result: $Result ($([Bool]!$Failed))"
               if(!$Result) {
                  $Result = New-Item data:\Users @ReceivingAbout -ErrorAction SilentlyContinue -ErrorVariable Failed
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

