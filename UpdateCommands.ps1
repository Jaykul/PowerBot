[CmdletBinding()]
param(
   [Hashtable[]]$CommandModules,
   [Hashtable[]]$AdminModules,
   [Hashtable[]]$OwnerModules
)

if( $ExecutionContext.SessionState.Module.Name -ne "PowerBot" ) {
   throw "You can only UpdateCommands from within the PowerBot Module ExecutionContext"
}

Remove-Module PowerBotCommands, PowerBotOwnerCommands, PowerBotAdminCommands -ErrorAction SilentlyContinue

#################################################################
# Commands for owners only (they also get all the commands below)
New-Module PowerBotOwnerCommands {
   param($OwnerModules)
   foreach($module in $OwnerModules) {
      Write-Host "Importing" $module.Name "for" $ExecutionContext.SessionState.Module.Name
      Import-Module @module -Force -Passthru
   }

   $script:irc = PowerBot\Get-PowerBotIrcClient

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

   function Get-OwnerCommand {
      #.SYNOPSIS
      #  Lists the commands available via the bot
      param(
         # A filter for the command name (allows wildcards)
         [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
         [String[]]$Name = "*"
      )
      process {
         @($ExecutionContext.SessionState.Module.ExportedCommands.Values | Where { $_.CommandType -ne "Alias"  -and $_.Name -like $Name } | Select -Expand Name | Sort) -join ", "
      }
   }
   Export-ModuleMember -Function * -Cmdlet * -Alias *
} -Args (,$OwnerModules) | Import-Module -Global



#################################################################
# Commands for admins only (they also get all the commands below)
New-Module PowerBotAdminCommands {
   param($AdminModules)
   foreach($module in $AdminModules) {
      Write-Host "Importing" $module.Name "for" $ExecutionContext.SessionState.Module.Name
      Import-Module @module -Force -Passthru
   }

   $script:irc = PowerBot\Get-PowerBotIrcClient

   function Update-Command {
     [CmdletBinding()]param()
     &(Get-Module PowerBot) { 
       . $PowerBotScriptRoot\UpdateCommands.ps1 $irc.CommandModules $irc.AdminModules $irc.OwnerModules
     }
   }

   function Get-AdminCommand {
      #.SYNOPSIS
      #  Lists the commands available via the bot
      param(
         # A filter for the command name (allows wildcards)
         [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
         [String[]]$Name = "*"
      )
      process {
         @($ExecutionContext.SessionState.Module.ExportedCommands.Values | Where { $_.CommandType -ne "Alias"  -and $_.Name -like $Name } | Select -Expand Name | Sort) -join ", "
      }
   }
   Export-ModuleMember -Function * -Cmdlet * -Alias *
} -Args (,$AdminModules) | Import-Module -Global



#################################################################
# Commands for everyone!
New-Module PowerBotCommands {
   param($CommandModules)
   foreach($module in $CommandModules) {
      Write-Host "Importing" $module.Name "for" $ExecutionContext.SessionState.Module.Name
      Import-Module @module -Force -Passthru
   }
   function Get-Alias {
      #.SYNOPSIS
      #  Lists the commands available via the bot
      param(
         # A filter for the command name (allows wildcards)
         [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
         [String[]]$Name = "*"
      )
      process {
         @(Microsoft.PowerShell.Utility\Get-Alias -Definition $ExecutionContext.SessionState.Module.ExportedCommands.Values.Name -ErrorAction SilentlyContinue | Select -Expand DisplayName) -join ", "
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
         @($ExecutionContext.SessionState.Module.ExportedCommands.Values | Where { $_.CommandType -ne "Alias"  -and $_.Name -like $Name } | Select -Expand Name | Sort) -join ", "
      }
   }
   Export-ModuleMember -Function * -Cmdlet * -Alias *
} -Args (,$CommandModules) | Import-Module -Global
