## NOTE 1: Evrything you return is output to Out-String and then the channel or user.  Be careful!
## NOTE 2: 510 is the Max IRC Message Length, including the channel name etc.
##         http`://www.faqs.org/rfcs/rfc1459.html

# $script:irc = Get-PowerBotIrcClient

Set-Alias paste Get-Pastebin
function Get-Pastebin {
   #.Synopsis
   #  Get the latest new posts from the channel paste bin
   param(
      # The most recent paste that we know of
      $script:lastlink
   )

   $items = invoke-http get http://jaykul.com/feed | receive-http xml //item

   if($lastlink) {
      $new = ""
      foreach($link in $items | select-object -first 5) {
         if($link.link -eq $script:lastlink) {
           if($new){ $script:lastlink = $new }
           break
         }
         if(!$new){ $new = $link.link }
      
         "{0} just pasted {1} {2}" -f $link.creator, $link.title, $link.link
      }
   } else {
      $script:lastlink = $items[0].link
      "{0} pasted {1} on {2} {3}" -f $items[0].creator, $items[0].title, ([datetime]::parse($items[0].pubDate).ToUniversalTime().ToString("dddd \a\t H:m:s \U\T\C")), $items[0].link
   }
}

function Get-Help() {
   #.FORWARDHELPTARGETNAME Microsoft.PowerShell.Core\Get-Help
   #.FORWARDHELPCATEGORY Cmdlet
   [CmdletBinding(DefaultParameterSetName='AllUsersView')]
   param(
         [Parameter(Position=0, ValueFromPipelineByPropertyName=$true, ValueFromRemainingArguments=$true)]
         [System.String]
         ${Name},
         
         [System.String]
         ${Path},

         [System.String[]]
         ${Category},

         [System.String[]]
         ${Component},

         [System.String[]]
         ${Functionality},

         [System.String[]]
         ${Role},

         [Parameter(ParameterSetName='DetailedView')]
         [Switch]
         ${Detailed},

         [Parameter(ParameterSetName='Full')]
         [Switch]
         ${Full},

         [Parameter(ParameterSetName='Examples')]
         [Switch]
         ${Examples},

         [Parameter(ParameterSetName='Parameters')]
         [System.String]
         ${Parameter},

         [Switch]
         ${Online}
   )
   begin
   {
      if(!$Global:PowerBotHelpNames) {
         $Global:PowerBotHelpNames = Microsoft.PowerShell.Core\Get-Help * | Select-Object -Expand Name
      }

      function Write-BotHelp {
         [CmdletBinding()]
         param(
            [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
            [String]$Name,

            [Parameter(ValueFromPipeline=$true)]
            [PSObject]$Help
         )
         begin {
            $helps = @()
            Write-Verbose "Name: $Name    Help: $Help"
            if($Help) { $helps += @($Help) }
         }
         process {
            if(!$Name) {
               "Displays information about Windows PowerShell commands and concepts. To get help for a cmdlet, type: Get-Help [cmdlet-name].`nIf you want information about bot commands, try Get-Command."
            }
            Write-Verbose "PROCESS $Help"
            if($Help) { $helps += @($Help) }
         }
         end {
            Write-Verbose "END $($Helps.Count)"
            if($Name) {
               if($helps) {
                  if($helps.Count -eq 1) {
                     if($uri = $helps[0].RelatedLinks.navigationLink | Select -Expand uri) {
                        $uri = "Full help online: " + $uri
                     }
                     $syntax = ($helps[0].Syntax | Out-String -width 1000 -Stream).Trim().Split("`n",4,"RemoveEmptyEntries")
                     if($syntax.Count -gt 4){ $uri = "... and more. " + $uri } 
                     @( $helps[0].Synopsis, $syntax[0..3], $uri )
                  } else {
                     $commands = @( Microsoft.PowerShell.Core\Get-Command *$Name | Where-Object { $_.ModuleName -ne $PSCmdlet.MyInvocation.MyCommand.ModuleName } )
                     switch($commands.Count) {
                        1 {
                           $helps = @( $helps | Where-Object { $_.ModuleName -eq $commands[0].ModuleName } | Select -First 1 )
                           if($uri = $helps[0].RelatedLinks.navigationLink | Select -Expand uri) {
                              $uri = "Full help online: " + $uri
                           }
                           $syntax = ($helps[0].Syntax | Out-String -width 1000 -Stream).Trim().Split("`n",4,"RemoveEmptyEntries")
                           if($syntax.Count -gt 4){ $uri = "... and more. " + $uri } 
                           @( $helps[0].Synopsis, $syntax[0..3], $uri )
                        }
                        2 {
                           $h1,$h2 = Microsoft.PowerShell.Core\Get-Command *$Name | % { if($_.ModuleName) { "{0}\{1}" -f $_.ModuleName,$_.Name } else { $_.Name } }
                           "You're going to need to be more specific, I know about $h1 and $h2"
                        }
                        3 {
                           $h1,$h2,$h3 = Microsoft.PowerShell.Core\Get-Command *$Name | % { if($_.ModuleName) { "{0}\{1}" -f $_.ModuleName,$_.Name } else { $_.Name } }
                           "You're going to need to be more specific, I know about $h1, $h2, and $h3"
                        }
                        default {
                           $h1,$h2,$h3 = Microsoft.PowerShell.Core\Get-Command *$Name | Select-Object -First 2 -Last 1 | % { if($_.ModuleName) {  "{0}\{1}" -f $_.ModuleName,$_.Name } else { $_.Name } }
                           "You're going to need to be more specific, I know about $($helps.Count): $h1, $h2, ... and even $h3"
                        }
                     }
                  }
               } else {
                  "There was no help for '$Name', sorry.  I probably don't have the right module available."
               }
            }
         }
      }

      $outBuffer = $null
      if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer) -and $outBuffer -gt 1024)
      {
         $PSBoundParameters['OutBuffer'] = 1024
      }
      foreach($k in $PSBoundParameters.Keys) {
         Write-Host "$k : $($PSBoundParameters[$k])" -fore green
      }
      try {
         if($Name -and ($Global:PowerBotHelpNames -NotContains (Split-Path $Name -Leaf))) {
            Write-Output "I couldn't find the help file for '$Name', sorry.  I probably don't have the right module available."
            return
         }

         # $wrappedCmd = $ExecutionContext.InvokeCommand.GetCmdlet('Get-Help')
         $wrappedCmd = Microsoft.PowerShell.Core\Get-Command Microsoft.PowerShell.Core\Get-Help -Type Cmdlet
         $scriptCmd = {&$wrappedCmd @PSBoundParameters -ErrorAction Stop | Select-Object @{n="Name";e={Split-Path -Leaf $_.Name}}, Synopsis, Syntax, ModuleName, RelatedLinks | Write-BotHelp }
         $steppablePipeline = $scriptCmd.GetSteppablePipeline($MyInvocation.CommandOrigin)
      
      } catch [Microsoft.PowerShell.Commands.HelpNotFoundException],[System.Management.Automation.CommandNotFoundException] {
         Write-Host "Exception:" $_.GetType().FullName -fore cyan
         Write-Output "$($_.Message)  `n`nI probably don't have the right module available."
         break
      }

      $steppablePipeline.Begin($PSCmdlet)
   }
   process
   {
      try {
         if($Global:PowerBotHelpNames -Contains $Name) {
            $steppablePipeline.Process($_) 
         } elseif($steppablePipeline) {
            Write-Output "I couldn't find the help for '$Name', sorry.  I probably don't have the right module available."
            return
         }
      } catch [Microsoft.PowerShell.Commands.HelpNotFoundException],[System.Management.Automation.CommandNotFoundException] {
         Write-Host "Exception:" $_.GetType().FullName -fore yellow
         if($_.Message -match "ambiguous. Possible matches") {
            Write-Output "$($_.Exception.Message)"
         } else {
            Write-Output "$($_.Exception.Message)`n`nI probably don't have the right module available."
         }
         continue
      } catch {
         Write-Host $_.GetType().FullName -fore yellow
         Write-Host "I have no idea what just happened:`n`n$($_|out-string)" -Fore Red
         throw $_
      }
   }

   end
   {
      if($steppablePipeline) {
         try {
              $steppablePipeline.End()
         } catch {
            throw
         }
      }
   }
   <#
      .ForwardHelpTargetName Get-Help
      .ForwardHelpCategory Cmdlet
   #>
}


if(Import-Module "PoshCode\Scripts" -Function "Get-PoshCode" -Scope Local -EA 0 -Passthru) {
   function Get-PoshCode {
      #.Synopsis
      #  Search PoshCode.org for scripts
      [CmdletBinding(DefaultParameterSetName="Single")]
      PARAM(
         # The search terms (words to search for)
         [Parameter(Position=1, ValueFromRemainingArguments=$true, ValueFromPipeline=$true)]
         [Alias("SearchTerms","Terms")]
         [string[]]${query},

         # The number of search results to return (Defaults to 1, Max 5)
         [Parameter(ParameterSetName="Multiple")]
         [int]$count=3
      )

      if($count -gt 5) { 
         Write-Output "$query results? More than three is kinda spammy, but that's ridiculous. Did you know you can use your browser to search PoshCode.org? Let me hook you up: http://PoshCode.org/?q=$(($query|%{$_.split(' ')}|%{[System.Web.HttpUtility]::UrlEncode($_)}) -join '+')" 
         Write-Output "I'll guess I'll get you the first three anyway:"
         $count = 3
      }
         
      Scripts\Get-PoshCode -Query "$query" | select -first $count | ft id, Title, Web, Description -auto -HideTableHeaders
   }
}

function Get-Weather {
   #.Synopsis
   #  Get the current weather and today's forecast for the specified zipcode
   PARAM(
      # The zipcode or yahoo code 
      [Parameter(Position=0, ValueFromPipeline=$true)]
      $zip=14586,

      # If set, return the forecast in celcius
      [Parameter()]
      [switch]$celcius
   )
   $url = "http`://weather.yahooapis.com/forecastrss?p={0}{1}" -f $zip, $(if($celcius){"&u=c"})
   $channel = ([xml](New-Object Net.WebClient).DownloadString($url)).rss.channel
   if($channel -and $channel.location.city) {
      $current = $channel.item.condition
      $f = @($channel.item.forecast)[0]
      "Current Weather at {0}: {1}: {2} {3}°{4}`nToday's Forecast: {5} {6}-{7}°{4}" -f $channel.location.city, $channel.lastBuildDate, $current.text, $current.temp, $(if($celcius){"C"}else{"F"}), $f.text, $f.low, $f.high
   } else {
      "I can't find the weather for ${zip}, you should check this site for codes: http://www.edg3.co.uk/snippets/weather-location-codes/"
   }
}

function Search-ScriptCenter {
   #.Synopsis
   #  Search TechNet ScriptCenter for scripts
   [CmdletBinding(DefaultParameterSetName="Single")]
   PARAM(
      # The number of search results to return (Defaults to 1, Max 5)
      [Parameter(ParameterSetName="Multiple")]
      [int]$count=3,

      # The search terms (words to search for)
      [Parameter(Position=0, Mandatory=$true, ValueFromRemainingArguments=$true )]
      [Alias("SearchTerms","Terms")]
      ${query},

      # The property to sort by (defaults to date of submission).
      [Parameter(Mandatory=$false)]
      [ValidateSet("date", "rating", "ranking", "rankingLast7", "mostActive", "mostActiveLast7", "authorDesc", "authorAsc", "titleAsc", "titleDesc")]
      ${sortBy} = "date"
   )
   if($count -gt 5) { 
      Write-Output "$count results? More than three is kinda spammy, but that's ridiculous. Did you know you can use your browser to search ScriptCenter? Let me hook you up: http://gallery.technet.microsoft.com/scriptcenter/site/search?query=$(($query|%{$_.split(' ')}|%{[System.Web.HttpUtility]::UrlEncode($_)}) -join '+')" 
      Write-Output "I'll guess I'll get you the first three anyway:"
      $count = 3
   }
   Get-WebPageContent "http://gallery.technet.microsoft.com/ScriptCenter/en-us/site/feeds/search" -With @{searchText="${query}"; sortBy=${sortBy}} -XPath //item |
   Select-Object -First $count | %{ "$($_.title) $($_.link)" }
}

function Get-Definition {
   #.SYNOPSIS
   #  Gets the definition of a word from dictionary.cambridge.org
   [CmdletBinding(DefaultParameterSetName="NoData")]
   param(
      # The term you want to define
      [Parameter(Position=1)]
      [string]$word,

      # Return a specific index (by default the first result is returned (index=0), and on subsequent calls for the same word, the index is incremented)
      [int]$index,
      
      # How many to return (defaults to 1, max of 5)
      [Int]$Count = 1
   )
   begin {
      if($count -gt 5) { 
         Write-Output "$count results? More than three is kinda spammy, but that's ridiculous. Did you know you can use your browser to look up words? Let me hook you up: http://www.oxforddictionaries.com/definition/english/$word"
         Write-Output "I'll guess I'll get you the first couple of results, anyway:"
         $count = 2
      }

      if($Script:LastDefinition -ne $Word) {
         $Script:xhtmlns = @{x="http://www.w3.org/1999/xhtml"}
         $Script:LastDefinition = $Word
         $Script:LastDefinitionResults = @() 
         $Script:LastDefinitionIndex = 0
      }
      if($PSBoundParameters.ContainsKey("index")) {
         $Script:LastDefinitionIndex = $index
      }
   }
   process {

      $word = $word.ToLower()

      if(!$Script:LastDefinitionResults) {
         Write-Verbose "Definition not found for $word, looking up in oxforddictionaries"
         # Invoke-Http GET "http://dictionary.cambridge.org/learnenglish/results.asp" @{searchword="$word" } | 
         #    Receive-Http text "//span[@class='def-classification' or @class='cald-definition']"
         $Xml = Invoke-Http GET "http://www.oxforddictionaries.com/definition/english/$word" | Receive-Http XML
         $Script:LastDefinitionResults = @(Select-Xml -Xml $xml -XPath "//x:ul[@class='sense-entry']//x:li[1]//x:span[@class='definition']" -Namespace $xhtmlns | 
            ForEach-Object { $_.Node } | 
            Select-Object @{n="Definition";e={$_."#text".trim(" :")}}, 
                          @{n="partOfSpeech";e={ Select-Xml ".//ancestor::x:section/x:h3/x:span/text()" $_ -Namespace $xhtmlns }})
      }

      if($LastDefinitionIndex -gt ($Script:LastDefinitionResults.Count - 1)) {
         $Script:LastDefinitionIndex = 0
      }

      Write-Verbose "Definition: $LastDefinitionIndex of $(@($Script:LastDefinitionResults).Count) for $LastDefinition"

      while($Count--) {
         if($script:LastDefinitionResults.Count -gt $script:LastDefinitionIndex) {
            Write-Output ("{0}({3} of {4}): {1}, {2} " -f $LastDefinition, @($Script:LastDefinitionResults)[$Script:LastDefinitionIndex].partOfSpeech, @($Script:LastDefinitionResults)[$Script:LastDefinitionIndex].definition, (++$Script:LastDefinitionIndex), @($Script:LastDefinitionResults).Count)
         } else {
            Write-Output "No more definitions found for ${global:LastDefinition}"
            $script:LastDefinitionIndex = 0
            break;
         }
      }
   }
}

function Get-Acronym {
   #.Synopsis
   #  Gets the acronym definition
   [CmdletBinding(DefaultParameterSetName="NoData")]
   param(
      # The acronym
      [Parameter(Position=1, ValueFromPipeline=$true)]
      [string]$text,

      # Return a specific index (by default the first result is returned (index=0), and on subsequent calls for the same word, the index is incremented)
      [int]$index,

      [Int]$Count = 1
   )
   begin {
      if($count -gt 5) { 
         Write-Output "$count results? More than three is kinda spammy, but that's ridiculous. Did you know you can use your browser to look up acronyms? Let me hook you up: http://acronyms.thefreedictionary.com/$text" 
         Write-Output "I'll guess I'll get you the first couple of results, anyway:"
         $count = 2
      }
      if($script:LastAcronym -ne "$text") {
         $script:LastAcronym = "$text"
         $script:LastAcronymResults = @()
         $script:LastAcronymIndex = 0
      }
      if($PSBoundParameters.ContainsKey("index")) {
         $Script:LastAcronymIndex = $index
      }
   }

   process {
      if($LastAcronymIndex -gt ($Script:LastAcronymResults.Count - 1)) {
         $Script:LastAcronymIndex = 0
      }

      if(!$Script:LastAcronymResults) {
         $Script:LastAcronymResults = @(Invoke-Http GET "http://acronyms.thefreedictionary.com/$text" | Receive-Http Text "//table[@id='AcrFinder']/tr[@cat]/td[2]")
      }

      while($Count--) {
         if($script:LastAcronymResults.Count -gt $script:LastAcronymIndex) {
            Write-Output ("{3}({1} of {2}): {0}" -f ($script:LastAcronymResults[$script:LastAcronymIndex++]), ($script:LastAcronymIndex), ($script:LastAcronymResults.Count), $script:LastAcronym)
         } else {
            Write-Output "No more definitions found for ${global:LastAcronym}"
            $script:LastAcronymIndex = 0
            break;
         }
      }
   }
}

function ConvertTo-ShortUrl {
   #.SYNOPSIS
   #  Gets a short url from is.gd for a long URL.
   [CmdletBinding(DefaultParameterSetName="NoData")]
   param(
      # The url to shorten
      [Parameter(Position=1, ValueFromRemainingArguments=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("URI")]
      [string[]]$Url
   )
   begin { 
      [regex]$long = "https?://[^ ]*\b" 
      $OFS = " "
   }
   process {
      $u = "$url"
      $urls = $long.Matches($u)
      
      for($i = $urls.Count-1; $i -ge 0; $i--) {
         
         $u2 = Invoke-Http GET "http`://is.gd/create.php" @{longurl=$($urls[$i].Value) } | 
                     Receive-Http Text "//*[@id='short_url']/@value" 
         Write-Verbose "Replacing at $($urls[$i].Index) with $u2"
         $u = $u.Remove($urls[$i].Index, $urls[$i].Length).Insert($urls[$i].Index, $u2)
      }
      write-output "$u"
   }
}

###################################
## Please excuse the http`:// ... my own pastebin blocks me as a spammer otherwise
function Resolve-URL { 
   #.SYNOPSIS
   # Figure out the real url behind those shortened forms
   param(
      # The short url(s) to expand
      [string[]]$urls
   )
   [regex]$isgd   = "(?:https?://)?is.gd/([^?/ ]*)\b"
   [regex]$ffim   = "(?:https?://)?ff.im/([^?/ ]*)\b"  # note: ff.im is only FriendFeed entries
   [regex]$xrl    = "(?:https?://)?xrl.us/([^?/ ]*)\b"
   [regex]$cligs  = "(?:https?://)?cli.gs/([^?/ ]*)\b"
   [regex]$snip   = "(?:https?://)?(?:snurl|snipr|snipurl)\.com/([^?/ ]*)\b"
   [regex]$twurl  = "(?:https?://)?twurl.nl/([^?/ ]*)\b"
   [regex]$tiny   = "(?:https?://)?tinyurl.com/([^?/ ]*)\b"
   # These two require an API key (get your own)
   [regex]$bitly  = "(?:https?://)?bit.ly/([^?/ ]*)\b"
   [regex]$jmp    = "(?:https?://)?j.mp/([^?/ ]*)\b"
   # Su.pr and Tr.im don't have working API right now: 1/17/2014
   [regex]$trim   = "(?:https?://)?tr.im/([^?/ ]*)\b"
   [regex]$supr   = "(?:https?://)?su.pr/([^?/ ]*)\b"

   function Replace-Matches( $string, $matches, [scriptblock]$getBlock ) {
      for($i = $matches.Count-1; $i -ge 0; $i--) {
         $string = $string.Remove($matches[$i].Index, $matches[$i].Length).Insert($matches[$i].Index, ($matches[$i].groups[1].value | % $getBlock ))
      }
      write-output $string
   }

   foreach($url in $urls) {
      $old = $url
      $url = Replace-Matches $url $isgd.Matches($url)   {Invoke-Http GET "http`://is.gd/$_-"                                          | Receive-Http TEXT "//*[local-name() = 'a' and @class='biglink']/@href" }
      $url = Replace-Matches $url $ffim.Matches($url)   {Invoke-Http GET "http`://friendfeed-api.com/v2/short/$_"     @{format="xml"} | Receive-Http TEXT "//entry/url" }
      $url = Replace-Matches $url $twurl.Matches($url)  {Invoke-Http GET "http`://tweetburner.com/links/$_"                           | Receive-Http TEXT "//div[@class='stats-tweet-data']//a/@href" }
      $url = Replace-Matches $url $cligs.Matches($url)  {Invoke-Http GET "http`://cli.gs/api/v1/cligs/expand"         @{clig=$_}      | Receive-Http TEXT }
      $url = Replace-Matches $url $xrl.Matches($url)    {Invoke-Http GET "http`://metamark.net/api/rest/simple"       @{short_url=$_} | Receive-Http TEXT }
      $url = Replace-Matches $url $snip.Matches($url)   {Invoke-Http GET "http`://snipurl.com/resolveurl"             @{id=$_}        | Receive-Http TEXT }
      $url = Replace-Matches $url $tiny.Matches($url)   {Invoke-Http GET "http`://tinyurl.com/preview.php"            @{num=$_}       | Receive-Http TEXT "//a[@id='redirecturl']/@href" }
      ## bitly's is frustrating, because it not only requires an apiKey, it returns invalid xml
      #$url = Replace-Matches $url $bitly.Matches($url)  {Invoke-Http GET "http`://api.bit.ly/expand" @{version = "2.0.1"; login=""; apiKey=""; format="xml"; shortUrl="http://bit.ly/$_" } | Receive-Http Text |% { $_ -replace ".*longUrl\>(.*)\</longUrl.*",'$1' }}
      #$url = Replace-Matches $url $jmp.Matches($url)    {Invoke-Http GET "http`://api.bit.ly/expand" @{version = "2.0.1"; login=""; apiKey=""; format="xml"; shortUrl="http://bit.ly/$_" } | Receive-Http Text |% { $_ -replace ".*longUrl\>(.*)\</longUrl.*",'$1' }}
      
      # $url = Replace-Matches $url $supr.Matches($url)   {Invoke-Http GET "http`://su.pr/api/expand"           @{format="xml";hash=$_} | Receive-Http TEXT "//*[@name='longUrl']/@value" }
      # $url = Replace-Matches $url $trim.Matches($url)   {Invoke-Http GET "http`://api.tr.im/v1/trim_destination.xml" @{trimpath=$_}   | Receive-Http Text "//trim/destination" }
      
      if( $url -ne $old ) {
         Write-Output $url
      }
   }
}

function Test_ResolveUrl {
   Write-Host "http`://is.gd/fSf"           ($result = Resolve-URL "http`://is.gd/fSf") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://ff.im/bJnqF"         ($result = Resolve-URL "http`://ff.im/bJnqF") ($result -eq "http`://friendfeed.com/leeallgood/9a0d3d6d/who-needs-grid-atlantic-december-2009-new-fuel" )
   Write-Host "http`://twurl.nl/wqmpst"     ($result = Resolve-URL "http`://twurl.nl/wqmpst") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell" )
   Write-Host "http`://xrl.us/bkhfy"        ($result = Resolve-URL "http`://xrl.us/bkhfy") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://snurl.com/28o3w"     ($result = Resolve-URL "http`://snurl.com/28o3w") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://tinyurl.com/4xuwlh"  ($result = Resolve-URL "http`://tinyurl.com/4xuwlh") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://j.mp/3lqjMf"         ($result = Resolve-URL "http`://j.mp/3lqjMf") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://bit.ly/3lqjMf"       ($result = Resolve-URL "http`://bit.ly/3lqjMf") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )

   Write-Host "http`://tr.im/wsxg"          ($result = Resolve-URL "http`://tr.im/wsxg") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   Write-Host "http`://su.pr/2Tqyub"        ($result = Resolve-URL "http`://su.pr/2Tqyub") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )

   Write-Host "Multiple Url Torture" ("http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ -- This is a simple test of the Resolve-Url cmdlet http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ to see if it can resolve http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ multiple urls http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ and such. http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" -eq `
   (Resolve-URL "http`://xrl.us/bkhfy -- This is a simple test of the Resolve-Url cmdlet http`://is.gd/fSf to see if it can resolve http`://xrl.us/bkhfy multiple urls http`://snurl.com/28o3w and such. http`://tinyurl.com/4xuwlh"))
}

function Join-String {
   #.Synopsis
   #  Joins an array of strings together with the specified separator and options (a pipeline-enabled superset of the -join operator).
   #.Description
   #  Join-String allows you to join together an array with a specific separator and prepend or append additional items to the array. It also allows you to add a prefix or postfix to the resulting string, or to output a string with only unique items.
   #.Example
   #  Get-Command | Join-String -Separator ", " -Property ModuleName, Name -PropertySeparator "\"
   #
   #  Gets the available commands and outputs them as a comma-separated list of ModuleName\Command1, ModuleName\Command2, ModuleName\Command3, ...
   #.Example
   #  Get-Command | Select -Expand Name | Join-String ", "
   #
   #  Gets the available commands and outputs them as a comma-separated list of command names
   #.Example
   #  Get-Command | Join-String ", " Name
   #
   #  Gets the available commands and outputs them as a comma-separated list of command names
   #.Example
   #  Get-Command | Join-String -Property Name
   #
   #  Gets the available commands and outputs them as a space-separated list of command names   
   [CmdletBinding(DefaultParameterSetName="Strings")]
   param (
      # The separator to use when joining the strings together
      [Parameter(Position=1)]
      [PSDefaultValue(Help = '$ofs (defaults to a space)')]
      [string]$Separator = $(if(test-path variable:ofs){$ofs}else{" "}),

      # The properties that will be pulled from each object (and joined with property separator(s))
      [Parameter(Position=2,Mandatory=$true,ParameterSetName="Properties")]
      [string[]]$Property,

      # The properties that will be pulled from each object (and joined with property separator(s))
      [Parameter(Position=3,ParameterSetName="Properties")]
      [string]$PropertySeparator = $Separator,

      # Additional items to append to the array before joining
      [Parameter(ParameterSetName="Strings")]
      [string[]]$append, 

      # Additional items to prepend to the array before joining
      [Parameter(ParameterSetName="Strings")]
      [string[]]$prepend, 

      # A string prefix for the output
      [string]$prefix, 

      # A string postfix for the output
      [string]$postfix, 

      # Should we select unique items only from all the inputs
      [switch]$unique,

      # Should we exclude empty strings from the Input
      [switch]$nonempty,

      # Split the string into multiple strings of MaxLength
      [int]$SplitLength = $MaxLength,

      # The items to be joined
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [AllowEmptyString()]
      [PSObject[]]$InputObject
   )
   begin { 
      if($PSCmdlet.ParameterSetName -eq "Strings") {
         [PSObject[]]$items =  @($prepend | ?{$_} | %{ $_.split($separator) }) 
      } else {
         [PSObject[]]$items = @()
      }
   }
   process {
      $items += $InputObject
   }
   end { 
      if($PSCmdlet.ParameterSetName -eq "Strings") {
        $items += @($append | ?{$_} | %{ $_.split($separator) }); 
      }

      if($unique) {
         $items  = $items | Select -Unique
      }
      if($nonempty) {
         $items  = $items | ? {$_}
      }

      if($PSCmdlet.ParameterSetName -eq "Properties") {
         $Items = $(
            foreach($item in $Items) {
               $(
                  foreach($prop in $property)
                  {
                     $Item.$prop
                  }  
               ) -Join $PropertySeparator
            }
         )
      }

      $ofs = $separator; 
      if(!$SplitLength) {
         return "$prefix$($items)$postfix"
      } else {
         $Start = 0
         $Length = "$prefix$postfix".Length
         for($i=0; $i -lt $items.Count; $i++) {
            $ilen = $Items[$i].ToString().Length + $separator.Length
            if(($Length += $ilen) -gt $SplitLength) {
               Write-Verbose "SplitLength: $SplitLength | Length: $Length | iLen: $ilen"
               Write-Output "$prefix$($items[$start..($i-1)])$postfix"
               $Length = $iLen + "$prefix$postfix".Length
               $Start = $i
            }
         }
         if($i -gt $Start) {
            Write-Verbose "Trailing Length: $Length | iLen: $ilen"
            Write-Output "$prefix$($items[$start..$i])$postfix"
         }
      }
   }
}


Export-ModuleMember -Function *-* -Cmdlet * -Alias *