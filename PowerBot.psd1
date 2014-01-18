@{

# These modules will be processed when the module manifest is loaded.
ModuleToProcess = 'PowerBot.psm1'

# This GUID is used to uniquely identify this module.
GUID = '58d14559-327c-4be5-92d3-e7be1edf35dd'

# The author of this module.
Author = 'Joel Bennett'

# The company or vendor for this module.
CompanyName = 'Http://HuddledMasses.org'

# The copyright statement for this module.
Copyright = '(c) 2014, Joel Bennett'

# The version of this module.
ModuleVersion = '3.0'

# A description of this module.
Description = 'PowerBot the PowerShell IRC Bot'

# The minimum version of PowerShell needed to use this module.
PowerShellVersion = '4.0'

# The CLR version required to use this module.
CLRVersion = '4.0'

# Functions to export from this manifest.
FunctionsToExport = 'Start-PowerBot', 'Resume-PowerBot', 'Stop-PowerBot', 'Get-PowerBotIrcClient', 'Get-Command'

# Aliases to export from this manifest.
# AliasesToExport = ''

# Variables to export from this manifest.
#VariablesToExport = ''

# Cmdlets to export from this manifest.
#CmdletsToExport = ''

# This is a list of other modules that must be loaded before this module.
RequiredModules = @('HttpRest', 'ResolveAlias')

# The script files (.ps1) that are loaded before this module.
ScriptsToProcess = @()

# The type files (.ps1xml) loaded by this module.
TypesToProcess = @()

# The format files (.ps1xml) loaded by this module.
FormatsToProcess = @()

# A list of assemblies that must be loaded before this module can work.
RequiredAssemblies = 'bin\Meebey.SmartIrc4net.dll' # Meebey.SmartIrc4net, Version=0.4.5, Culture=neutral, PublicKeyToken=null

# Module specific private data can be passed via this member.
PrivateData = @{
   # Nick = @('PowerBot')
   # RealName = ''
   # Password = ''
   Server = "chat.freenode.net"
   Port = 8001
   Channels = @('#PowerBot')
   Owner = "Jaykul!~Jaykul@geoshell/dev/Jaykul"
   CommandModules = @{Name="Bing"}, 
      @{Name="FAQ"}, 
      @{Name="PoshCode\Scripts"; Function = "Search-PoshCode"},
      @{Name="PowerBot\BotCommands"}, 
      @{Name="Microsoft.PowerShell.Utility"; Cmdlet = "Format-Wide", "Format-List", "Format-Table", "New-Alias", "Select-Object", "Sort-Object", "Get-Random", "Out-String"}
   
   #  ProxyServer = "www.mc.xerox.com"
   #  ProxyPort = "8000"
   #  ProxyUserName
   #  ProxyPassword
}

}
