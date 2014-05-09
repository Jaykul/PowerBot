[CmdletBinding()]
param(
   [Hashtable[]]$Settings = $ExecutionContext.SessionState.Module.PrivateData
)

if( $ExecutionContext.SessionState.Module.Name -ne "PowerBot" ) {
   throw "You can only UpdateCommands from within the PowerBot Module ExecutionContext"
}

$OldSettings = $Settings

##########################################################################
## Remove all the old hooks and recreate them
##########################################################################
## Event handlers in powershell have TWO automatic variables: $This and $_
##   In the case of SmartIrc4Net:
##   $This  - usually the connection, and such ...
##   $_     - the IrcEventArgs, which just has a Data member
$script:irc = PowerBot\Get-PowerBotIrcClient

Write-Host $($($irc | ft UserName, NickName, Address, IsConnected -auto | Out-String -Stream) -Join "`n") -Fore Green

$NewSettings = Import-LocalizedData -BaseDirectory $ExecutionContext.SessionState.Module.ModuleBase -FileName $ExecutionContext.SessionState.Module.Name
$NewSettings = $NewSettings.PrivateData

[Hashtable[]]$Hooks    = $NewSettings.Hooks

Remove-Module PowerBotHooks -ErrorAction SilentlyContinue

New-Module PowerBotHooks {
   param($Irc, $Hooks)
   foreach($module in $Hooks.Keys) {
      Write-Host "Importing" $module "for" $ExecutionContext.SessionState.Module.Name
      Import-Module $module -Force -Passthru -Args $Irc
   }

   function ByHookOrCrook { 
      $MyInvocation.MyCommand.Module.OnRemove = { 
         foreach($HookModule in $Hooks.Keys) {
            foreach($Hook in $Hooks.$HookModule.Keys) {
               $ModuleName = @($HookModule -split "\\")[-1]
               $EventName = $Hooks.$HookModule.$Hook
               #$Action = [ScriptBlock]::Create("{$ModuleName\$Hook}")
               $Action = [ScriptBlock]::Create("{Write-Host `"${Hook}: `$_`"; $ModuleName\$Hook}")

               Write-Host "UnHook On$EventName to $Action"
               try {
                  #Requires -version 4.0
                  $irc."Remove_On$EventName"( $Action )
               } catch {
                  Write-Error "Error unhooking the On$EventName Event"
               }
            }
         }
      }
      Remove-Item Function:ByHookOrCrook
   }

   foreach($HookModule in $Hooks.Keys) {
      foreach($Hook in $Hooks.$HookModule.Keys) {
         $ModuleName = @($HookModule -split "\\")[-1]
         $EventName = $Hooks.$HookModule.$Hook
         $Action = [ScriptBlock]::Create("
            if(`$_.Data) {
               `$global:Channel  = `$_.Data.Channel
               `$global:Hostname = `$_.Data.Host
               `$global:Ident    = `$_.Data.Ident
               `$global:Message  = `$_.Data.Message
               `$global:Nick     = `$_.Data.Nick
               `$global:From     = `$_.Data.From
            }

            PowerBotHooks\$Hook `$this `$_

            Remove-Item Variable:Global:Channel
            Remove-Item Variable:Global:From
            Remove-Item Variable:Global:Hostname
            Remove-Item Variable:Global:Ident
            Remove-Item Variable:Global:Message
            Remove-Item Variable:Global:Nick
            ")
         Write-Host "Hook On$EventName to $Hook"
         try {
            #Requires -version 4.0
            $irc."Add_On$EventName"( $Action )
         } catch {
            Write-Error "Error hooking the On$EventName Event to $Action"
         }
      }
   }

   ByHookOrCrook

   Export-ModuleMember -Function * -Cmdlet * -Alias *
} -Args ($Irc,$Hooks) | Import-Module -Global

##########################################################################
## Command Modules, one per role
$global:PowerBotUserRoles = $NewSettings.RolePermissions.Keys
foreach($Role in $NewSettings.RolePermissions.Keys) {
   Remove-Module "PowerBot${Role}Commands" -ErrorAction SilentlyContinue
}

## This is the bit where I go all module-crazy on you....
## For each role, we generate a new module, and import (nested) the modules and commands assigned to that role
## Then we import that dynamically generated module to the global scope so it can access the PowerBot module if it needs to
foreach($Role in $NewSettings.RolePermissions.Keys) {

   New-Module "PowerBot${Role}Commands" {
      param($Role, $RoleModules)
      foreach($module in $RoleModules) {
         Write-Host "Importing" $module.Name "for" $ExecutionContext.SessionState.Module.Name
         Import-Module @module -Force -Passthru
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
           [CmdletBinding()]param()
           &(Get-Module PowerBot) { 
             . $PowerBotScriptRoot\UpdateCommands.ps1
           }
         }         
      }
      elseif($Role -eq "User") 
      {
         function Get-Alias {
            #.SYNOPSIS
            #  Lists the commands available via the bot
            param(
               # A filter for the command name (allows wildcards)
               [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
               [String[]]$Name = "*"
            )
            process {
               Microsoft.PowerShell.Utility\Get-Alias -Definition $ExecutionContext.SessionState.Module.ExportedCommands.Values.Name -ErrorAction SilentlyContinue
            }
         }


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
      }

      Set-Content "function:Get-${Role}Command" {
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

      Export-ModuleMember -Function * -Cmdlet * -Alias *
   } -Args ($Role,$NewSettings.RolePermissions.$Role) | Import-Module -Global

}
