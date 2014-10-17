## This script requires Meebey.SmartIrc4net.dll which you can get as part of SmartIrc4net
## http://voxel.dl.sourceforge.net/sourceforge/smartirc4net/SmartIrc4net-0.4.0.bin.tar.bz2
## And the docs are at http://smartirc4net.meebey.net/docs/0.4.0/html/
############################################################################################
## You should configure the PrivateData in the PowerBot.psd1 file
############################################################################################
## You should really configure the PrivateData in the PowerBot.psd1 file
############################################################################################
## You need to configure the PrivateData in the PowerBot.psd1 file
############################################################################################

## Set some default ParametersValues for inside PowerBot
$PSDefaultParameterValues."Out-String:Stream" = $true
$PSDefaultParameterValues."Format-Table:Auto" = $true

## Store the PSScriptRoot
$global:PowerBotScriptRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$global:PowerBotScriptRoot) {
  $global:PowerBotScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$DataDir = Join-Path $Env:ProgramData "PowerBot"
if(!(Test-Path $DataDir)) { 
   Write-Warning "No PowerBot Settings Directory. Creating '$DataDir'"
   mkdir $DataDir
}

## If Jim Christopher's SQLite module is available, we'll use it
Import-Module SQLitePSProvider -ErrorAction SilentlyContinue
if(!(Test-Path data:) -and (Microsoft.PowerShell.Core\Get-Command Mount-SQLite)) {
   $BotDataFile = Join-Path $DataDir "botdata.sqlite"
   Mount-SQLite -Name data -DataSource ${BotDataFile}
} elseif(!(Test-Path data:)) {
   Write-Warning "No data drive, UserTracking and Roles disabled"
}


function Get-PowerBotIrcClient { $script:irc }

function Get-Setting {
   #.Synopsis
   #  Read a Setting off the PrivateData
   param(
      # The setting name to retrieve
      [Parameter(Position=0, Mandatory=$true)]
      $Name
   )
   $PrivateData = $MyInvocation.MyCommand.Module.PrivateData
   foreach($Level in $Name -split '\.') {
      $PrivateData = $PrivateData.$Level
   }
   return $PrivateData
}

function Send-Message {
   #.Synopsis
   #  Sends a message to the IRC server
   [CmdletBinding()]
   param(
      # Who to send the message to (a channel or nickname)
      [Parameter(Position=0)]
      [String]$To,

      # The message to send
      [Parameter(Position=1, ValueFromPipeline=$true)]
      [String]$Message,

      # How to send the message (as a Message or a Notice)
      [ValidateSet("Message","Notice")]
      [String]$Type = "Message"
   )
   process {
      Write-Verbose "Send-Message $Message"
      if($Message.Contains("`n")) {
         $Message.Trim().Split("`n") | Send-Message -To $To -Type $Type
      } else {
         $Message = $Message.Trim()
         Write-Verbose "SendMessage( '$Type', '$To', '$Message' )"
         $irc.SendMessage($Type, $To, $Message)
      }
   }
}

function Start-PowerBot {
   #.Synopsis
   #  Start PowerBot and connect to the specified channel/network
   #.Description
   #  Starts an IRC client and hooks it up to event handlers to enable the bot functionality.
   #
   #  All of the parameters on this method use defaults from the PrivateData hashtable in the module manifest.
   [CmdletBinding()]
   param(
      # The nickname to use (usually you should provide an alternate)
      # NOTE, the FIRST nick should be associated with the password, if any
      [Parameter(Position=0)]
      [string[]]$Nick        = $(
         $Default = Get-Setting Nick
         if($Default.Length -gt 0 -and $Default[0].Length -gt 0) {
            $Default
         } else { 
            "PowerBot{0:D4}" -f (Get-Random -Maximum 9999) 
            "PowerBot{0:D4}" -f (Get-Random -Maximum 9999) 
         }),

      # The IRC channel(s) to connect to
      [string[]]$Channels    = $(Get-Setting Channels),
      
      # The nickserv password to use (will be sent in a PRIVMSG to NICKSERV to IDENTIFY)
      [string]$Password      = $(Get-Setting Password),
   
      # The server to connect to 
      [string]$Server        = $(Get-Setting Server),
   
      # The port to use for connection
      [int]$Port             = $(Get-Setting Port),
   
      # The "real name" to be returned to queries from the IRC server
      [string]$RealName      = $(
         if($Default = Get-Setting RealName) { 
            $Default 
         } else {
            "PowerBot http://github.org/Jaykul/PowerBot"
         }),
   
      # The proxy server
      [string]$ProxyServer   = $(Get-Setting ProxyServer),
   
      # The port for the proxy server
      [int]$ProxyPort        = $(Get-Setting ProxyPort),
   
      # The proxy username (if required)
      [string]$ProxyUserName = $(Get-Setting ProxyUserName),
   
      # The proxy password (if required)
      [string]$ProxyPassword = $(Get-Setting ProxyPassword),

      # Recreate the IRC client even if it already exists
      [switch]$Force
   )

   # The bot owner(s) have access to all commands
   [String[]]$Owner             = $(Get-Setting Owner)


   $script:Password = $Password

   if($Force -or !(Test-Path -Path Variable:Script:Irc)) {
      $script:irc = New-Object Meebey.SmartIrc4net.IrcClient
      
      # TODO: Expose these options to configuration
      $script:irc.AutoRejoin = $true
      $script:irc.AutoRejoinOnKick = $false
      $script:irc.AutoRelogin = $true
      $script:irc.AutoReconnect = $true
      $script:irc.AutoRetry = $true
      $script:irc.AutoRetryDelay = 60
      $script:irc.SendDelay = 400
      $script:irc.Encoding = [Text.Encoding]::UTF8
      # SmartIrc will track channels for us
      $script:irc.ActiveChannelSyncing = $true
      
      if($ProxyServer) {
         $script:irc.ProxyHost     = $ProxyServer
         $script:irc.ProxyPort     = $ProxyPort
         $script:irc.ProxyUserName = $ProxyUserName
         $script:irc.ProxyPassword = $ProxyPassword
      }

      # There are a few things I need to store for command modules
      Add-Member -Input $irc NoteProperty BotOwner $Owner
      Add-Member -Input $irc NoteProperty BotChannels $Channels
      Add-Member -Input $irc NoteProperty EventHooks @{}

      # This causes errors to show up in the console
      $script:irc.Add_OnError( {Write-Error $_.ErrorMessage} )
      # This give us the option of seeing every line as verbose output
      $script:irc.Add_OnReadLine( {Write-Verbose $_.Line} )
      

      ## UserModeChange (this happens, among other things, when we first go online)
      $script:irc.Add_OnUserModeChange( {OnUserModeChange_TrackOurselves} )

      # We handle commands on query (private) messages or on channel messages
      $script:irc.Add_OnQueryMessage( {OnQueryMessage_ProcessCommands} )
      $script:irc.Add_OnChannelMessage( {OnChannelMessage_ProcessCommands} )
   }
   
   # Connect to the server
   $script:irc.Connect($server, $port)
   # Login to the server
   if($Password) {
      $script:irc.Login(([string[]]$nick), $realname, 0, $nick[0], $password)
   } else {
      $script:irc.Login(([string[]]$nick), $realname, 0, $nick[0])
   }
   Resume-PowerBot # Shortcut so starting this thing up only takes one command
}

## Note that PowerBot stops listening if you press Q ...
## You have to run Resume-Powerbot to get him to listen again
## That's the safe way to reload all the PowerBot commands
function Resume-PowerBot {
   #.Synopsis
   #  Reimport all command modules and restart the main listening loop
   [CmdletBinding()]param([switch]$Force)

   if(!(Test-Path -Path Variable:Script:Irc)) {
      throw "You must call Start-PowerBot before you call Resume-Powerbot"
   }

   . $PowerBotScriptRoot\UpdateCommands.ps1 -Force:$Force

   # Initialize the command array (only commands in this list will be heeded)
   $Character = $Null
   while($Character -ne "Q") {
      while(!$Host.UI.RawUI.KeyAvailable) {  $irc.ListenOnce($false)  }
      $Character = $Host.UI.RawUI.ReadKey().Character
      if($Character -eq "R") {
        &(Get-Module PowerBot) { 
            . $PowerBotScriptRoot\UpdateCommands.ps1 -Force:$Force
        }
      }
   }
}


function Stop-PowerBot {
   #.Synopsis
   #  Disconnect from IRC completely, with the specified quit message
   [CmdletBinding()]
   param(
      # The message to send on quit
      [Parameter(Position=0)]
      [string]$QuitMessage = "If people listened to themselves more often, they would talk less."
   )
   
   $irc.RfcQuit($QuitMessage)
   for($i=0;$i -lt 30;$i++) { $irc.Listen($false) }
   $irc.Disconnect()
}


####################################################################################################
## Event Handlers
####################################################################################################
## Event handlers in powershell have TWO automatic variables: $This and $_
##   In the case of SmartIrc4Net:
##   $This  - usually the connection, and such ...
##   $_     - the IrcEventArgs, which just has the Data member:
##

$InternalVariables = "Channel", "From", "Hostname", "Ident", "Message", "Nick"

function Test-Command {
   [CmdletBinding()]param([Parameter(ValueFromRemainingArguments)][String]$ScriptString)

   Protect-Script -Script $ScriptString -AllowedModule PowerBotCommands -AllowedVariable $InternalVariables -WarningVariable warnings

}

function OnUserModeChange_TrackOurselves {
   #.Synopsis
   #  Handles the UserModeChange event to deal with authentication and joining channels

   # ${This} is the $irc object
   $Nick = $This.NicknameList[0]

   # If we know a password 
   if($This.Password) {
      # Manual login to nickserv:
      Send-Message -To "Nickserv" -Message "IDENTIFY $Nick $($This.Password)"
      # TODO: The "REGAIN" command may only work on freenode
      if($This.Nickname -ne $Nick) {
         Send-Message -To "Nickserv" -Message "REGAIN $Nick $($This.Password)"
      }
   }

   # Remove our hook. We don't need to track this anymore
   $irc.Remove_OnUserModeChange( {OnUserModeChange_TrackOurselves} )

   foreach($chan in $irc.BotChannels) { $irc.RfcJoin( $chan ) }
}

function OnQueryMessage_ProcessCommands { 
   # If it's not prefixed, then we don't process it, because it's not a command
   if($_.Data.Message[0] -eq $Prefix -and $_.Data.Message.Length -gt 1) { 
      Process-Message -Data $_.Data -Sender $_.Data.Nick
   }
}

function OnChannelMessage_ProcessCommands {
   # If it's not prefixed, then we don't process it, because it's not a command
   if($_.Data.Message[0] -eq $Prefix -and $_.Data.Message.Length -gt 1) { 
      Process-Message -Data $_.Data -Sender $_.Data.Channel
   }
}

$Prefix = Get-Setting CommandPrefix

function Process-Message {
   param($Data, $Sender)
   Write-Verbose ("Message: " + $Data.Message)
  
   $ScriptString = $Data.Message.SubString(1)
   $global:Channel  = $Data.Channel
   $global:From     = $Data.From
   $global:Hostname = $Data.Host
   $global:Ident    = $Data.Ident
   $global:Message  = $Data.Message
   $global:Nick     = $Data.Nick

   # The default role for users with no roles set is Guest
   # EVERYONE gets the Guest role, no matter what
   $global:Roles    = @("Guest")
   if(Microsoft.PowerShell.Core\Get-Command Get-Role) {
      $global:Roles = @(Get-Role -Nick $global:Nick | Select -Expand Roles -Unique)
   } else {
      # If there's no Access Control module loaded, then we also allow everyone the "User" role 
      # Because that's where most of the commands are ...
      $global:Roles = @("User")
   }

   # Figure out which modules the user is allowed to use.
   # Everyone gets access to the "Guest" commands
   $AllowedModule = @(
      "PowerBotGuestCommands"

      # They may get other roles ...
      foreach($Role in $global:Roles) {
         "PowerBot${Role}Commands"
      }
      # Hack to allow recognizing the owner purely by hostmask
      if($From -eq $irc.BotOwner) {
         "PowerBotOwnerCommands"
      }
   ) | Select-Object -Unique


   $AllowedCommands = (Get-Module $AllowedModule).ExportedCommands.Values | % { $_.ModuleName + '\' + $_.Name }
   $Script = Protect-Script -Script $ScriptString -AllowedModule $AllowedModule -AllowedVariable $InternalVariables -WarningVariable warnings

   if(!$Script) {
      if($Warnings) {
         Send-Message -Type Message -To "#PowerBot" -Message "WARNING [${Channel}:${Nick}]: $($warnings -join ' | ')"
         # Send-Message -Type Notice -To $Data.Nick -Message "I think you're trying to trick me into doing something I don't want to do. Please stop, or I'll scream. $($warnings -join ' | ')"
      }
      return
   }
   
   
   $local:MaxLength = 497 - $Sender.Length - $irc.Who.Mask.Length 
   if($Script) {
      Write-Verbose "SCRIPT: $Script"
      try {
         Invoke-Expression $Script | 
            Format-Csv -Width $MaxLength | 
            Select-Object -First 8 | # Hard limit to number of messages no matter what.
            Send-Message -To $Sender
      } catch {
         Send-Message -To "#PowerBot" -Message "ERROR [${Channel}:${Nick}]: $_"
         Write-Warning "EXCEPTION IN COMMAND ($Script): $_"
      }
   }

   Remove-Item Variable:Global:Channel
   Remove-Item Variable:Global:From
   Remove-Item Variable:Global:Hostname
   Remove-Item Variable:Global:Ident
   Remove-Item Variable:Global:Message
   Remove-Item Variable:Global:Nick
}


Add-Type @"
using System;
using System.Management.Automation;
using System.Collections.Generic;

[AttributeUsage(AttributeTargets.Method)]
public class PowerBotHookAttribute : Attribute
{
   // The event(s) this method handles
   public string Event { get; set; }
}
"@


# A NOTE ABOUT MESSAGE LENGTH:
   
   #IRC max length is 512, minus the CR LF and other headers ... 
   # In practice, it looks like this:
   # :Nick!Ident@Host PRIVMSG #Powershell :Your Message Here
   ###### The part that never changes is the 512-2 (for the \r\n) 
   ###### And the "PRIVMSG" and extra spaces and colons
   # So that inflexible part of the header is:
   #     1 = ":".Length
   #     9 = " PRIVMSG ".Length 
   #     2 = " :".Length
   # So therefore our hard-coded magic number is:
   #     498 = 510 - 12
   # (I take an extra one off for good luck: 510 - 13)
   
   # In a real world example with my host mask and "Shelly" as the nick and user id:
     # Host     : geoshell/dev/Jaykul
     # Ident    : ~Shelly
     # Nick     : Shelly
   # We calculate the mask in our OnWho:
     # Mask     : Shelly!~Shelly@geoshell/dev/Jaykul
   
   # So if the "$Sender" is "#PowerShell" our header is:
   #     57 = ":Shelly!~Shelly@geoshell/dev/Jaykul PRIVMSG #Powershell :".Length
     # As we said before/, 12 is constant
     #     12 = ":" + " PRIVMSG " + " :"
     # And our Who.Mask ends up as:
     #     34 = "Shelly!~Shelly@geoshell/dev/Jaykul".Length 
     # And our Sender.Length is:
     #     11 = "#Powershell".Length
     # The resulting MaxLength would be 
     #    452 = 497 - 11 - 34
     # Which is one less than the real MaxLength:
     #    453 = 512 - 2 - 57 