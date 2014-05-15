PowerBot
========

An IRC bot in PowerShell (using SmartIrc4net)

The main bot functionality is the PowerBot.psm1 module and the UpdateCommands.ps1 script which loads hooks and commands.
Through the psd1 configuration, PowerBot allows you to expose any PowerShell commands you want to IRC users by adding them to the module manifest in the PrivateData.RolePermissions.Users array.

To install, use the [PoshCode](/PoshCode/PoshCode) module:

    Install-Module PowerBot

I've included a few commands here in the BotCommands module, but in my bot (which I host in Azure) I also use a bunch of other modules. Here are some suggested additions:

    'SQLitePSProvider', 'Strings', 'Bing', 'Math', 'WebQueries', 'FAQ', 'Credit' | % { Install-Module $_ }

You can add this to the RolePermissions.Users array:

    @{Name="Bing"}
    @{Name="Math"}
    @{Name="WebQueries"}
    @{Name="Strings"; Function = "Join-String", "Split-String", "Replace-String", "Format-Csv"}
    @{Name="FAQ"}
    @{Name="SQLiteCredit"}

I should note that FAQ and Credit, as well as the new "UserTracking" module require a "data:" drive with filter support 
such as the one provided by Jim Christopher's SqlLite module, which I packaged on Chocolatey for the PoshCode module:

   Install-Module SQLitePSProvider

In order to get them to import correctly, I had to write these modules with an ```Import-Module``` statement at the top, rather than a properly documented dependency on the module.
This is unfortunate because the "SQLitePSProvider" module name is my packaging of Jim's module, and so if he ever packages his, I'll probaly have to update all these to depend on that. 

NOTE that if you do NOT want to use the SQLitePSProvider, you need some other way of providing a data drive with compatible syntax.
Otherwise, you can simply not use those three modules, and everything should work fine (except that you won't have role-based access control).
