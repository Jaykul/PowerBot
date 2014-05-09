PowerBot
========

An IRC bot in PowerShell (using SmartIrc4net)

The main bot functionality is the PowerBot.psm1 module, but PowerBot allows you to expose any PowerShell commands you want to expose by adding them to the module manifest in the PrivateData.CommandModules.

I've included a few commands here in the BotCommands module, but in my bot (which I host in Azure) I also use a FAQ module, a Bing module, the Scripts submodule from PoshCode, etc.


To install, use the [PoshCode](/PoshCode/PoshCode) module:

    Install-Module PowerBot
