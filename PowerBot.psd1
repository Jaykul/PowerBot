@{

# These modules will be processed when the module manifest is loaded.
ModuleToProcess = 'PowerBot.psm1'

# This GUID is used to uniquely identify this module.
GUID = '58d14559-327c-4be5-92d3-e7be1edf35dd'

# The author of this module.
Author = 'Joel Bennett'

# The company or vendor for this module.
CompanyName = 'http://HuddledMasses.org'

# The copyright statement for this module.
Copyright = '(c) 2014, Joel Bennett'

# The version of this module.
ModuleVersion = '3.6'

# A description of this module.
Description = 'PowerBot: the PowerShell IRC Bot'

# The minimum version of PowerShell needed to use this module.
PowerShellVersion = '4.0'

# The CLR version required to use this module.
CLRVersion = '4.0'

# Functions to export from this manifest.
FunctionsToExport = 'Start-PowerBot', 'Resume-PowerBot', 'Stop-PowerBot', 'Get-PowerBotIrcClient'

# Aliases to export from this manifest.
# AliasesToExport = ''

# Variables to export from this manifest.
#VariablesToExport = ''

# Cmdlets to export from this manifest.
#CmdletsToExport = ''

# This is a list of other modules that must be loaded before this module.
RequiredModules = @('ResolveAlias')

# The script files (.ps1) that are loaded before this module.
ScriptsToProcess = @()

# The type files (.ps1xml) loaded by this module.
TypesToProcess = @()

# The format files (.ps1xml) loaded by this module.
FormatsToProcess = @()

FileList = @(
   'PowerBot.psd1', 'PowerBot.psm1', 'ReadMe.md', 'UpdateCommands.ps1', 'LICENSE'

   'bin\JabbR.Client.dll', 'bin\log4net.dll', 'bin\Meebey.SmartIrc4net.dll', 'bin\Microsoft.AspNet.SignalR.Client.dll', 
   'bin\Newtonsoft.Json.dll', 'bin\ServiceStack.Common.dll', 'bin\ServiceStack.Interfaces.dll', 
   'bin\ServiceStack.Text.dll', 'bin\StarkSoftProxy.dll', 'bin\Twitterizer2.dll', 

   'BotHooks\BotHooks.psm1', 
   'BotCommands\BotCommands.psd1', 'BotCommands\BotCommands.psm1',
   'UserTracking\UserTracking.psm1', 'UserTracking\UserTracking.psd1'
)

# A list of assemblies that must be loaded before this module can work.
RequiredAssemblies = '.\bin\Meebey.SmartIrc4net.dll' # Meebey.SmartIrc4net, Version=0.4.5, Culture=neutral, PublicKeyToken=null

# Module specific private data can be passed via this member.
PrivateData = @{
   # Nick = @('PowerBot')
   # RealName = ''
   # Password = ''
   Server = "chat.freenode.net"
   Port = 8001
   Channels = @('#PowerBot')

   CommandPrefix = ">"

   Owner = "Jaykul!jaykul@geoshell/dev/Jaykul"
   
   Hooks = @{
      "PowerBot\BotHooks" = @{
         "Expand-Url"      = "ChannelMessage"
         "Test-Language"   = "ChannelMessage"
      }
      "PowerBot\UserTracking" = @{
         "Sync-Join"       = "Join"
         "Sync-Part"       = "Part"
         "Sync-NickChange" = "NickChange"
         "Sync-LoggedIn"   = "LoggedIn"
      }
   }

   # There are two mandatory roles: Guest and User
   #     Guest is for unauthenticated users
   #     User is the default for newly-created users
   # Normally, all users get the "User" role (in addition to any other role)
   # BEWARE: EVERYONE has access to the commands in Guest, no matter what.
   #         You must ensure there's no overlap with commands from other roles
   RolePermissions = @{
      Owner    = @{
         "PowerBot\UserTracking" = "Set-Role"
      }
      Admin    = @{
         "Microsoft.PowerShell.Utility" = "New-Alias"
      }
      User     = @{
         "Microsoft.PowerShell.Utility" = "Format-Wide", "Format-List", "Format-Table", "Select-Object", "Sort-Object", "Get-Random", "Out-String"
      }
      Guest    = @{
         "PowerBot\UserTracking" = "Get-Role"
         "PowerBot\BotCommands" = "Get-Help"
      }
   }
   
   #  ProxyServer = "www.mc.xerox.com"
   #  ProxyPort = "8000"
   #  ProxyUserName
   #  ProxyPassword
}

}
