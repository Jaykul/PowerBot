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

$Script:PowerBotCtcpData = @{}
## Force some default ParametersValues
$PSDefaultParameterValues."Out-String:Stream" = $true
$PSDefaultParameterValues."Format-Table:Auto" = $true

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
      [string[]]$Channels    = $ExecutionContext.SessionState.Module.PrivateData.Channels,
   
      # The nickname to use (usually you should provide an alternate)
      # NOTE, the FIRST nick should be associated with the password, if any
      [Parameter(Position=1)]
      [string[]]$nick        = $ExecutionContext.SessionState.Module.PrivateData.Nick,
      
      # The nickserv password to use (will be sent in a PRIVMSG to NICKSERV to IDENTIFY)
      [Parameter(Position=2)]
      [string]$password      = $ExecutionContext.SessionState.Module.PrivateData.Password,
   
      # The server to connect to 
      [Parameter(Position=5)]
      [string]$server        = $ExecutionContext.SessionState.Module.PrivateData.Server,
   
      # The port to use for connection
      [Parameter(Position=6)]
      [int]$port             = $ExecutionContext.SessionState.Module.PrivateData.Port,
   
      # The "real name" to be returned to queries from the IRC server
      [string]$realname      = $ExecutionContext.SessionState.Module.PrivateData.RealName,
   
      # A hostmask for the owner (supports wildcards), like: "Jaykul!~Jaykul@geoshell/dev/Jaykul"
      [string]$owner         = $ExecutionContext.SessionState.Module.PrivateData.Owner,

      # The proxy server
      [string]$ProxyServer   = $ExecutionContext.SessionState.Module.PrivateData.ProxyServer,
   
      # The port for the proxy server
      [int]$ProxyPort        = $ExecutionContext.SessionState.Module.PrivateData.ProxyPort,
   
      # The proxy username (if required)
      [string]$ProxyUserName = $ExecutionContext.SessionState.Module.PrivateData.ProxyUserName,
   
      # The proxy password (if required)
      [string]$ProxyPassword = $ExecutionContext.SessionState.Module.PrivateData.ProxyPassword,

      # Recreate the IRC client even if it already exists
      [switch]$Force
   )

   Write-Verbose "PrivateData Defaults:`n`n$( $ExecutionContext.SessionState.Module.PrivateData | Out-String )"

   if($Force -or !(Test-Path -Path Variable:Script:Irc)) {
      $script:irc = New-Object Meebey.SmartIrc4net.IrcClient
      
      # TODO: Expose these options to the psd1
      $script:irc.AutoRejoin = $true
      $script:irc.AutoRejoinOnKick = $true
      $script:irc.AutoRelogin = $true
      $script:irc.AutoReconnect = $true
      $script:irc.AutoRetry = $true
      $script:irc.AutoRetryDelay = 60
      $script:irc.SendDelay = 400
      # SmartIrc will track channels for us
      $script:irc.ActiveChannelSyncing = $true
      
      if($ProxyServer) {
         $script:irc.ProxyHost     = $ProxyServer
         $script:irc.ProxyPort     = $ProxyPort
         $script:irc.ProxyUserName = $ProxyUserName
         $script:irc.ProxyPassword = $ProxyPassword
      }

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
      $script:irc.Add_OnQueryMessage( {OnQueryMessage_ProcessCommands} )
      $script:irc.Add_OnChannelMessage( {OnChannelMessage_ProcessCommands} )
      $script:irc.Add_OnChannelMessage( {OnChannelMessage_ResolveUrls} )
      $script:irc.Add_OnCtcpReply( {OnCtcpReply_StoreData} )

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
      $script:irc.Add_OnWho( {
         # We only deal with this stuff the first time we see this message:
         if(!$irc.Who) {
            $_ | Add-Member NoteProperty Mask $($_.Nick +"!"+ $_.Ident +"@"+ $_.Host)
            Add-Member -Input $irc NoteProperty Who (Select-Object Host, Ident, Nick, Realname, Mask -Input $_)

            if(!$irc.JoinedChannels) {
               foreach($chan in $channels) { $irc.RfcJoin( $chan ) }
            }
         }
      } )
   }
   
   # Connect to the server
   $script:irc.Connect($server, $port)
   # Login to the server
   $script:irc.Login(([string[]]$nick), $realname, 0, $nick[0], $password)
   Resume-PowerBot # Shortcut so starting this thing up only takes one command
}

## Note that PowerBot stops listening if you press Q ...
## You have to run Resume-Powerbot to get him to listen again
## That's the safe way to reload all the PowerBot commands
function Resume-PowerBot {
   #.Synopsis
   #  Reimport all command modules and restart the main listening loop
   [CmdletBinding()]param()

   Update-CommandModule

   # Initialize the command array (only commands in this list will be heeded)
   while($Host.UI.RawUI.ReadKey().Character -ne "Q") {
      while(!$Host.UI.RawUI.KeyAvailable) { 
         $irc.ListenOnce() 
      }
      Write-Host "PowerBot is running, press Q to quit"
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


function Update-CommandModule {
   [CmdletBinding()]param()

   Write-Host "Module: " $ExecutionContext.SessionState.Module
   Remove-Module PowerBotCommands -ErrorAction SilentlyContinue
   New-Module PowerBotCommands {
      param($CommandModules)
      foreach($module in $CommandModules) {
         Write-Host "Importing " $Module.Name
         Import-Module @module -Force -Passthru
      }
   } -Args (,$ExecutionContext.SessionState.Module.PrivateData.CommandModules) | Import-Module -Global
}

function Get-Command {
   #.SYNOPSIS
   #  Lists the commands available via the bot
   param(
      # A filter for the command name (allows wildcards)
      [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [String[]]$Name = "*",

      [ValidateSet("Alias","All","Application","Cmdlet","ExternalScript","Filter","Function","Script","Workflow")]
      [String[]]$CommandType = @("Function", "Cmdlet", "Alias")
   )
   process {
      Microsoft.PowerShell.Core\Get-Command @PSBoundParameters -Module PowerBotCommands
      if("Get-Command" -like $Name) {
         Microsoft.PowerShell.Core\Get-Command "Get-Command" -Module PowerBot -Type Function, Cmdlet, Alias
      }
   }
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

function Process-Command {
  param($Data, $Sender)
  Write-Verbose ("Message: " + $Data.Message)
  if($Data.Message[0] -ne "!" -or $Data.Message.Length -eq 1) { return }

  $ScriptString = $Data.Message.SubString(1)

  Write-Verbose "Protect-Script -Script $ScriptString -AllowedModule PowerBotCommands -AllowedCommand 'PowerBot\Get-Command','PowerBot\Update-CommandModule' -AllowedVariable $($InternalVariables -join ', ') -WarningVariable warnings"
  $Script = Protect-Script -Script $ScriptString -AllowedModule PowerBotCommands -AllowedCommand "PowerBot\Get-Command", "PowerBot\Update-CommandModule" -AllowedVariable $InternalVariables -WarningVariable warnings
  if(!$Script) {
    Send-Message -Type Notice -To $Data.Nick -Message "I think you're trying to trick me into doing something I don't want to do. Please stop, or I'll scream. $($warnings -join ' | ')"
    return
  }

  $Channel  = $Data.Channel
  $From     = $Data.From
  $Hostname = $Data.Host
  $Ident    = $Data.Ident
  $Message  = $Data.Message
  $Nick     = $Data.Nick

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
    Invoke-Expression $Script | 
        Format-Table -Auto |
        Out-String -width $MaxLength -Stream | 
        Select-Object -First 8 | # Hard limit to number of messages no matter what.
        Send-Message -To $Sender
  }
}


function OnQueryMessage_ProcessCommands { 
  Process-Command -Data $_.Data -Sender $_.Data.Nick
}



function OnChannelMessage_ProcessCommands {
  Process-Command -Data $_.Data -Sender $_.Data.Channel
}

function OnChannelMessage_ResolveUrls {
   $c = $_.Data.Channel
   $n = $_.Data.Nick
   $m = $_.Data.Message
   Resolve-URL $m | % { $irc.SendMessage("Message", $c, "<$($n)> $_" ) }
}

function OnCtcpReply_StoreData {
   if(!$Script:PowerBotCtcpData.ContainsKey($_.Data.Nick)) {
      $Script:PowerBotCtcpData.Add( $_.Data.Nick, @{} )
   }
   
   $Script:PowerBotCtcpData[$_.Data.Nick][$_.CtcpCommand] = $_.CtcpParameter
}
