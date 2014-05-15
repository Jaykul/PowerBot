[CmdletBinding()]
param(
   [Hashtable[]]$Settings = $ExecutionContext.SessionState.Module.PrivateData,
   [String]$BaseDirectory = $ExecutionContext.SessionState.Module.ModuleBase,
   [String]$FileName = $ExecutionContext.SessionState.Module.Name,
   [Switch]$Force
)

# if( $ExecutionContext.SessionState.Module.Name -ne "PowerBot" ) {
#    throw "You can only UpdateCommands from within the PowerBot Module ExecutionContext"
# }

$OldSettings = $Settings

function global:New-ProxyFunction {
   param(
      [Parameter(ValueFromPipeline=$True)]
      [ValidateScript({$_ -is [System.Management.Automation.CommandInfo]})]
      $Command
   )
   process {
      $FullName = "{0}\{1}" -f $Command.ModuleName, $Command.Name
      $Pattern  = [regex]::escape($Command.Name)

      [System.Management.Automation.ProxyCommand]::Create($Command) -replace "${Pattern}", "${FullName}"
   }
}

##########################################################################
## Remove all the old hooks
##########################################################################
## Event handlers in powershell have TWO automatic variables: $This and $_
##   In the case of SmartIrc4Net:
##   $This  - usually the connection, and such ...
##   $_     - the IrcEventArgs, which just has a Data member
$script:irc = PowerBot\Get-PowerBotIrcClient

Write-Host $($($irc | ft UserName, NickName, Address, IsConnected -auto | Out-String -Stream) -Join "`n") -Fore Green

$NewSettings = Import-LocalizedData -BaseDirectory $BaseDirectory -FileName $FileName
$NewSettings = $NewSettings.PrivateData


Remove-Module PowerBotHooks -ErrorAction SilentlyContinue

$global:PowerBotUserRoles = $NewSettings.RolePermissions.Keys
foreach($Module in @($OldSettings.RolePermissions.Values.Keys) + @($OldSettings.Hooks.Keys) | Select-Object -Unique) {
   Remove-Module $Module -ErrorAction SilentlyContinue
}
foreach($Role in $NewSettings.RolePermissions.Keys) {
   Remove-Module "PowerBot${Role}Commands" -ErrorAction SilentlyContinue
}

## This is the bit where I go all module-crazy on you....
##########################################################################

foreach($Module in @($NewSettings.RolePermissions.Values.Keys) + @($NewSettings.Hooks.Keys) | Select-Object -Unique) {
   Write-Host "Importing" $Module
   try {
      Import-Module $Module -Force:$Force -Global -ErrorAction Stop
   } catch { Write-Warning "Failed to import $Module $_" }
}

## For each role, we generate a new module, and import (nested) the modules and commands assigned to that role
## Then we import that dynamically generated module to the global scope so it can access the PowerBot module if it needs to
foreach($Role in $NewSettings.RolePermissions.Keys) {
   Write-Host "Generating $Role Role Command Module" -Fore Cyan

   New-Module "PowerBot${Role}Commands" {
      param($Role, $RoleModules, $Force)

      foreach($module in $RoleModules.Keys) {
         foreach($command in (Get-Module $module.split("\")[-1]).ExportedCommands.Values | 
            Where { 
               $_.CommandType -ne "Alias" -and 
               $(foreach($name in $RoleModules.$module) { $_.Name -like $name }) -Contains $True 
            } )
         {
            Set-Content "function:local:$($command.Name)" (New-ProxyFunction $command)
         }  
      }

      # There are a few special commands for Owners and "Everyone" (Users)
      if($Role -eq "Owner") 
      {
         $script:irc = PowerBot\Get-PowerBotIrcClient

         function Quit {
            #.Synopsis
            #  Disconnects the bot from IRC
            [CmdletBinding()]
            param(
               # The channel to join
               $message = "As ordered"
            )
            
            $irc.RfcQuit($Message)
            for($i=0;$i -lt 30;$i++) { $irc.Listen($false) }
            $irc.Disconnect()
         }

         function Join {
            #.Synopsis
            #  Joins a channel on the server
            [CmdletBinding()]
            param(
               # The channel to join
               $channel
            )
            
            if($channel) {
               $irc.RfcJoin( $channel )
            } else {
               "You have to specify a channel, duh!"
            }
         }

         function Say {
            #.Synopsis
            #  Sends a message to the IRC server
            [CmdletBinding()]
            param(
               # Who to send the message to (a channel or nickname)
               [Parameter()]
               [String]$To = $(if($Channel){$Channel}else{$From}),

               # The message to send
               [Parameter(Position=1, ValueFromPipeline=$true)]
               [String]$Message,

               # How to send the message (as a Message or a Notice)
               [ValidateSet("Message","Notice")]
               [String]$Type = "Message"
            )
            foreach($M in $Message.Trim().Split("`n")) {
               $irc.SendMessage($Type, $To, $M.Trim())
            }
         }

         function Update-Command {
           [CmdletBinding()]param([Switch]$Force)
           &(Get-Module PowerBot) { 
             . $PowerBotScriptRoot\UpdateCommands.ps1 -Force:$Force
           }
         }
      } elseif($Role -ne "User") {
         # For everyone but the "User" -- export Get-Command (everything but guest will have a prefix)
         # User will export Get-UserCommand and will alias Get-Command to it

         function Get-Command {
            #.SYNOPSIS
            #  Lists the commands available via the bot
            param(
               # A filter for the command name (allows wildcards)
               [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
               [String[]]$Name = "*"
            )
            process {
               $ExecutionContext.SessionState.Module.ExportedCommands.Values | Where { $_.CommandType -ne "Alias"  -and $_.Name -like $Name } | Sort Name
            }
         }
      } elseif($Role -eq "User") {

         function Get-Alias {
            #.SYNOPSIS
            #  Lists the commands available via the bot
            param(
               # A filter for the command name (allows wildcards)
               [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
               [String[]]$Name = "*"
            )
            process {
               Microsoft.PowerShell.Utility\Get-Alias -Definition $ExecutionContext.SessionState.Module.ExportedCommands.Values.Name -ErrorAction SilentlyContinue | Where { $_.Name -like $Name }
            }
         }

         function Get-UserCommand {
            #.SYNOPSIS
            #  Lists the commands available via the bot
            param(
               # A filter for the command name (allows wildcards)
               [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
               [String[]]$Name = "*"
            )
            process {
               @(Get-Module PowerBotGuestCommands, PowerBotUserCommands).ExportedCommands.Values | Where { $_.CommandType -ne "Alias"  -and $_.Name -like $Name  -and $_.Name -ne "Get-UserCommand"} | Sort Name
            }
         }
         Set-Alias Get-Command Get-UserCommand
         Export-ModuleMember -Function * -Alias Get-Command
      }
   } -Args ($Role,$NewSettings.RolePermissions.$Role,$Force) | Import-Module -Global -Prefix $(if($Role -notmatch "User|Guest") { $Role } else {""})
}

##########################################################################
## Create a hook module and register all the event handler hooks

Write-Host "Generating PowerBotHooks Module" -Fore Cyan

foreach($EventName in $irc.EventHooks.Keys) {
   foreach($Action in $irc.EventHooks.$EventName) {
      Write-Host "UnHook On$EventName" -Fore Cyan
      try {
         #Requires -version 4.0
         $irc."Remove_On$EventName"( $Action )
      } catch {
         Write-Error "Error unhooking the On$EventName Event"
      }
   }
}

$irc.EventHooks = @{}

foreach($HookModule in $NewSettings.Hooks.Keys) {
   Write-Host "Importing" $HookModule "for" $ExecutionContext.SessionState.Module.Name
   try {
      foreach($Hook in $NewSettings.Hooks.$HookModule.Keys) {
         $ModuleName = @($HookModule -split "\\")[-1]
         $EventName = $NewSettings.Hooks.$HookModule.$Hook
         if(Microsoft.PowerShell.Core\Get-Command -Name $Hook -ErrorAction SilentlyContinue) {
            $Action = [ScriptBlock]::Create("
               if(`$_.Data) {
                  `$global:Channel  = `$_.Data.Channel
                  `$global:Hostname = `$_.Data.Host
                  `$global:Ident    = `$_.Data.Ident
                  `$global:Message  = `$_.Data.Message
                  `$global:Nick     = `$_.Data.Nick
                  `$global:From     = `$_.Data.From
               }

               $ModuleName\$Hook `$this `$_

               Remove-Item Variable:Global:Channel
               Remove-Item Variable:Global:From
               Remove-Item Variable:Global:Hostname
               Remove-Item Variable:Global:Ident
               Remove-Item Variable:Global:Message
               Remove-Item Variable:Global:Nick
               ")

            try {
               Write-Host "Hook On${EventName} to ${Hook}"
               #Requires -version 4.0
               $irc."Add_On${EventName}"( $Action )
               $irc.EventHooks.$EventName += @( $Action )
            } catch {
               Write-Error "Error hooking the On$EventName Event to $Action"
            }
         } else {
            Write-Host "Could not find the command '$Hook'"
            Write-Host ($MoModule | Format-Table | Out-String)
         }
      }
   } catch {
      Write-Warning "Failed to import $HookModule $_"
   }
}


