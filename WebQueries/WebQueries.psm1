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

      # If set, return the forecast in Celsius (defaults to Fahrenheit)
      [Parameter()]
      [switch]$Celsius
   )
   $url = "http`://weather.yahooapis.com/forecastrss?p={0}{1}" -f $zip, $(if($Celsius){"&u=c"})
   $channel = ([xml](New-Object Net.WebClient).DownloadString($url)).rss.channel
   if($channel -and $channel.location.city) {
      $current = $channel.item.condition
      $f = @($channel.item.forecast)[0]
      "Current Weather at {0}: {1}: {2} {3}°{4}`nToday's Forecast: {5} {6}-{7}°{4}" -f $channel.location.city, $channel.lastBuildDate, $current.text, $current.temp, $(if($Celsius){"C"}else{"F"}), $f.text, $f.low, $f.high
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

Set-Alias duck Invoke-DuckDuckGo
function Invoke-DuckDuckGo {
   #.Synopsis
   #  Call DuckDuckGo API
   param(
      # Query to pass on to DuckDuckGo
      [Parameter(Position=0, ValueFromRemainingArguments=$true )]
      $Query = "Windows PowerShell"
   )

   $UrlQuery = [System.Net.WebUtility]::UrlEncode($Query)

   $response = invoke-restmethod "http://api.duckduckgo.com/?format=json&skip_disambig=1&no_redirect=1&no_html=1&t=PowerBot&q=${UrlQuery}"
   if($response.Answer) {
      $response.Answer
   } elseif($response.DefinitionSource) {
      "{0} - {1} - {2}" -f ($response.Definition -replace "</?(:?pre|code)>"), $response.DefinitionSource, $response.DefinitionUrl
   } elseif($response.AbstractText) {
      "{0} - {1} - {2}" -f ($response.AbstractText -replace "</?(:?pre|code)>"), $response.AbstractSource, $response.AbstractUrl
   } elseif($response.Definition) {
      $response.Definition
   }elseif($response.Type -eq "D") {
      $related = $response | % RelatedTopics | % Text
      if($related) {
         return "Too ambiguous: " + ($related -Join " -or- ")
      } else {
         return "Sorry, the response is too ambiguous"
      }
   } else {
      "I don't know anything about ${Query}"
   }
   # A (article), D (disambiguation), C (category), N (name), E (exclusive)
}

Set-Alias chuck Invoke-ChuckNorris
function Invoke-ChuckNorris {
   #.Synopsis
   #  Random Chuck Norris awesomeness
   param( [Parameter(Position=0)]$User )

   if($User -eq "me") { $User = $Nick }
   if($User) {
      (irm "http://api.icndb.com/jokes/random?exclude=[explicit]&firstName=${User}&lastName=").value.joke -replace "  "," "
   } else {
      (irm "http://api.icndb.com/jokes/random?exclude=[explicit]").value.joke
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
   # Bitly supports a lot of custom 3rd party domains
   [regex]$bitly  = "(?:https?://)?(?:bit.ly|j.mp|amzn.to)/([^?/ ]*)\b"
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
      ## Bitly requires OAuth (or an APIKey, although that's deprecated)
      $url = Replace-Matches $url $bitly.Matches($url)  {Invoke-Http GET "http`://api.bit.ly/v3/expand"               @{format="xml"; hash=$_; login=""; apiKey=""; } | Receive-Http TEXT "//long_url" }

      ## These two are AWOL and their APIs don't work (even though their links still do)
      # $url = Replace-Matches $url $supr.Matches($url)   {Invoke-Http GET "http`://su.pr/api/expand"                   @{format="xml"; hash=$_} | Receive-Http TEXT "//*[@name='longUrl']/@value" }
      # $url = Replace-Matches $url $trim.Matches($url)   {Invoke-Http GET "http`://api.tr.im/v1/trim_destination.xml"  @{trimpath=$_}   | Receive-Http Text "//trim/destination" }
      
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
   Write-Host "http`://amzn.to/1moRjaK"     ($result = Resolve-URL "http`://amzn.to/1moRjaK") ($result -eq "http`://www.amazon.com/gp/product/B005CSOE1G/ref=as_li_ss_tl?ie=UTF8&camp=1789&creative=390957&creativeASIN=B005CSOE1G&linkCode=as2&tag=huddledmasses-20" )

   # Write-Host "http`://tr.im/wsxg"          ($result = Resolve-URL "http`://tr.im/wsxg") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )
   # Write-Host "http`://su.pr/2Tqyub"        ($result = Resolve-URL "http`://su.pr/2Tqyub") ($result -eq "http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" )

   Write-Host "Multiple Url Torture" ("http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ -- This is a simple test of the Resolve-Url cmdlet http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ to see if it can resolve http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ multiple urls http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/ and such. http`://huddledmasses.org/get-web-another-round-of-wget-for-powershell/" -eq `
   (Resolve-URL "http`://xrl.us/bkhfy -- This is a simple test of the Resolve-Url cmdlet http`://is.gd/fSf to see if it can resolve http`://xrl.us/bkhfy multiple urls http`://snurl.com/28o3w and such. http`://tinyurl.com/4xuwlh"))
}

# function Resolve-Word {
#    # Find real words from an anagram (this is here to kill the fun of the !word game from geoBot).
#    [CmdletBinding(DefaultParameterSetName="NoData")]
#    param(
#       # The anagram (the scrambled word)
#       [Parameter(Position=1, ValueFromPipeline=$true)]
#       [string]$anagram
#    ,
#       # not used unless the value of anagram is "..."
#       [Parameter(Position=2,Mandatory=$false, ValueFromRemainingArguments=$true)]
#       [string]$anagram2
#    )
#    if($anagram -eq "...") { $anagram = $anagram2 }
#      Invoke-Http POST http://wordsmith.org/anagram/anagram.cgi @{anagram=$anagram; t=1 } | 
#        Receive-Http TEXT "//p[3]/text()"
# }

Export-ModuleMember -Function *-* -Cmdlet * -Alias *