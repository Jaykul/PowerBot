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

## Force some default ParametersValues
$PSDefaultParameterValues."Out-String:Stream" = $true
$PSDefaultParameterValues."Format-Table:Auto" = $true

$PowerBotScriptRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PowerBotScriptRoot) {
  $PowerBotScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

if((Get-Command Mount-SQLite) -and -not (Test-Path data:)) {
   $BotDataFile = (Join-Path $PowerBotScriptRoot "botdata.sqlite")
   Write-Host "Bot Data: $BotDataFile"
   Mount-SQLite -Name data -DataSource $BotDataFile
}

$PSDefaultParameterValues

function Get-PowerBotIrcClient { $script:irc }

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
      # The IRC channel(s) to connect to
      [Parameter(Position=0)]
      [string[]]$Channels    = $(Get-Setting Channels),
   
      # The nickname to use (usually you should provide an alternate)
      # NOTE, the FIRST nick should be associated with the password, if any
      [Parameter(Position=1)]
      [string[]]$Nick        = $(Get-Setting Nick),
      
      # The nickserv password to use (will be sent in a PRIVMSG to NICKSERV to IDENTIFY)
      [Parameter(Position=2)]
      [string]$Password      = $(Get-Setting Password),
   
      # The server to connect to 
      [Parameter(Position=5)]
      [string]$Server        = $(Get-Setting Server),
   
      # The port to use for connection
      [Parameter(Position=6)]
      [int]$Port             = $(Get-Setting Port),
   
      # The "real name" to be returned to queries from the IRC server
      [string]$RealName      = $(Get-Setting RealName),
   
      # The proxy server
      [string]$ProxyServer   = $(Get-Setting ProxyServer),
   
      # The port for the proxy server
      [int]$ProxyPort        = $(Get-Setting ProxyPort),
   
      # The proxy username (if required)
      [string]$ProxyUserName = $(Get-Setting ProxyUserName),
   
      # The proxy password (if required)
      [string]$ProxyPassword = $(Get-Setting ProxyPassword),

      # Recreate the IRC client even if it already exists
      [switch]$Force,

      # The bot owner(s) have access to all commands
      [String[]]$Owner = $(Get-Setting Owner),
      # The bot admin(s) have access to admin and regular commands
      [String[]]$Admin = $(Get-Setting Admin),

      [Hashtable[]]$CommandModules = $(Get-Setting CommandModules),
      [Hashtable[]]$AdminModules = $(Get-Setting AdminModules),
      [Hashtable[]]$OwnerModules = $(Get-Setting OwnerModules)
   )

   if($Nick.Length -lt 1 -or $Nick[0].Length -lt 1) {
      throw "At least one nickname is required. Please pass -Nick or set it in PrivateData"
   }
   if(!$realname) {
      throw "The RealName parameter is required. Please pass -RealName or set it in PrivateData"
   }   
   if(!$password) {
      throw "The Password parameter is required. Please pass -Password or set it in PrivateData"
   }

   if($Force -or !(Test-Path -Path Variable:Script:Irc)) {
      $script:irc = New-Object Meebey.SmartIrc4net.IrcClient
      
      # TODO: Expose these options to the psd1
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

      Add-Member -Input $irc NoteProperty BotOwner $Owner
      Add-Member -Input $irc NoteProperty BotAdmin $Admin
      Add-Member -Input $irc NoteProperty CommandModules $CommandModules
      Add-Member -Input $irc NoteProperty AdminModules $AdminModules
      Add-Member -Input $irc NoteProperty OwnerModules $OwnerModules
      Add-Member -Input $irc NoteProperty BotChannels $Channels

      # This should show errors 
      $script:irc.Add_OnError( {Write-Error $_.ErrorMessage} )
      # And give us the option of seeing the raw output in verbose
      $script:irc.Add_OnReadLine( {Write-Verbose $_.Line} )
      
      ## Hook up event handlers for messages we handle
      ##########################################################################
      ## Event handlers in powershell have TWO automatic variables: $This and $_
      ##   In the case of SmartIrc4Net:
      ##   $This  - usually the connection, and such ...
      ##   $_     - the IrcEventArgs, which just has a Data member

      ## UserModeChange (this happens, among other things, when we first go online)
      $script:irc.Add_OnUserModeChange( {
         # We only need to go through this the first time we see this message:
         if(!$irc.Who) {
            $Nick = $This.NicknameList[0]

            # Manual login to nickserv:
            Send-Message -To "Nickserv" -Message "IDENTIFY $Nick $($This.Password)"
            # TODO: The "REGAIN" command may only work on freenode
            if($This.Nickname -ne $Nick) {
               Send-Message -To "Nickserv" -Message "REGAIN $Nick $($This.Password)"
            }

            # Trigger WHO so we can figure out our own hostmask etc.
            $irc.RfcWho($Nick)
         }        
      } )

      ## Who sends us the information about who we are, and gives us a chance to (re)join channels
      $script:irc.Add_OnWho({OnWho_UserData})

      # We hook our command syntax natively
      $script:irc.Add_OnQueryMessage( {OnQueryMessage_ProcessCommands} )
      $script:irc.Add_OnChannelMessage( {OnChannelMessage_ProcessCommands} )
   }
   
   # Connect to the server
   $script:irc.Connect($server, $port)
   # Login to the server
   $script:irc.Login(([string[]]$nick), $realname, 0, $nick[0], $password)
   Resume-PowerBot # Shortcut so starting this thing up only takes one command
}

function OnWho_UserData {
   # The first time we see this a WHO, it is about us, so...
   if(!$irc.Who) {
      Add-Member -Input $irc NoteProperty Who (Select-Object Host, Ident, Nick, Realname, @{n="Mask";e={$_.Nick +"!"+ $_.Ident +"@"+ $_.Host}} -Input $_)

      if(!$irc.JoinedChannels) {
         foreach($chan in $irc.BotChannels) { $irc.RfcJoin( $chan ) }
      }
   }
} 
## Note that PowerBot stops listening if you press Q ...
## You have to run Resume-Powerbot to get him to listen again
## That's the safe way to reload all the PowerBot commands
function Resume-PowerBot {
   #.Synopsis
   #  Reimport all command modules and restart the main listening loop
   [CmdletBinding()]param()

   if(!(Test-Path -Path Variable:Script:Irc)) {
      throw "You must call Start-PowerBot before you call Resume-Powerbot"
   }

   Update-CommandModule

   # Initialize the command array (only commands in this list will be heeded)
   while($Host.UI.RawUI.ReadKey().Character -ne "Q") {
      while(!$Host.UI.RawUI.KeyAvailable) { 
         $irc.ListenOnce($false) 
      }
   }
   Stop-PowerBot
}

function Update-CommandModule {
   . $PowerBotScriptRoot\UpdateCommands.ps1
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

function OnQueryMessage_ProcessCommands { 
   Process-Message -Data $_.Data -Sender $_.Data.Nick
}

function OnChannelMessage_ProcessCommands {
   Process-Message -Data $_.Data -Sender $_.Data.Channel
}

function Process-Message {
   param($Data, $Sender)
   Write-Verbose ("Message: " + $Data.Message)

   $Prefix = Get-Setting CommandPrefix


   # If it's not prefixed, then it's not a command
   if($Data.Message[0] -ne $Prefix -or $Data.Message.Length -eq 1) { return }
   
   $ScriptString = $Data.Message.SubString(1)
   $From     = $Data.From
   
   $AllowedModule = @("PowerBotCommands")
   if(($irc.BotOwner | %{ $From -like $_ }) -Contains $True) {
      $AllowedModule += "OwnerCommands", "PowerBotOwnerCommands", "PowerBotAdminCommands"
   } 
   elseif(($irc.BotAdmin | %{ $From -like $_ }) -Contains $True) {
      $AllowedModule += "OwnerCommands", "PowerBotAdminCommands"
   }
   
   $global:Channel  = $Data.Channel
   $global:Hostname = $Data.Host
   $global:Ident    = $Data.Ident
   $global:Message  = $Data.Message
   $global:Nick     = $Data.Nick
   
   Write-Verbose "Protect-Script -Script $ScriptString -AllowedModule PowerBotCommands -AllowedVariable $($InternalVariables -join ', ') -WarningVariable warnings"
   $Script = Protect-Script -Script $ScriptString -AllowedModule $AllowedModule -AllowedVariable $InternalVariables -WarningVariable warnings
   if(!$Script) {
      if($Warnings) {
         Send-Message -Type Message -To "#PowerBot" -Message "WARNING [${Channel}:${Nick}]: $($warnings -join ' | ')"
         # Send-Message -Type Notice -To $Data.Nick -Message "I think you're trying to trick me into doing something I don't want to do. Please stop, or I'll scream. $($warnings -join ' | ')"
      }
      return
   }
   
   
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
   
   # In a real world example with my host and "Shelly" as the nick:
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
   
   $global:MaxLength = 497 - $Sender.Length - $irc.Who.Mask.Length 
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
}

function Get-Setting {
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
