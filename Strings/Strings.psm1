# #This one is v1-compatible
# function Split-String {
# Param([scriptblock]$action={$0},[regex]$split=" ")
# PROCESS {
#    if($_){
#       $0 = $split.Split($_)
#       $1,$2,$3,$4,$5,$6,$7,$8,$9,$n = $0
#       &$action
#    }
# }
# }

function Replace-String {
   #.Synopsis
   #  Replaces one substring with another in a (set of) input string(s)
   [CmdletBinding()]
   param (
      # Search text to replace
      [Parameter(Position=0,Mandatory=$true)]
      $Search,
      # New text to use as the replacement
      [Parameter(Position=1,Mandatory=$false)]
      $Replace = "",
      # When present, the old and new values can use regular expression syntax
      [Switch]$Simple,
      # The strings that you want to replace values in
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [string[]]$InputObject
   )
   process {
      if($Simple) {
         $InputObject | %{ $_.Replace($Search, $Replace) }
      } else {
         $InputObject -Replace $Search, $Replace
      }
   }
}

function Join-String {
   <#
      .Synopsis
         Joins an array of strings together with the specified separator and options (a pipeline-enabled superset of the -join operator).
      .Description
         Join-String allows you to join together an array with a specific separator and prepend or append additional items to the array. It also allows you to add a prefix or postfix to the resulting string, or to output a string with only unique items.
      .Example
         Get-Command | Join-String -Separator ", " -Property ModuleName, Name -PropertySeparator "\"
      
         Gets the available commands and outputs them as a comma-separated list of ModuleName\Command1, ModuleName\Command2, ModuleName\Command3, ...
      .Example
         Get-Command | Select -Expand Name | Join-String ", "
      
         Gets the available commands and outputs them as a comma-separated list of command names
      .Example
         Get-Command | Join-String ", " Name
      
         Gets the available commands and outputs them as a comma-separated list of command names
      .Example
         Get-Command | Join-String -Property Name
      
         Gets the available commands and outputs them as a space-separated list of command names   
   #>
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

      # Trim the whitespace off the ends of the lines
      [switch]$trim,

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
      if($Trim) {
         $items += $InputObject | % { $_.Trim() }
      } else {
         $items += $InputObject
      }
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
         Write-Output "${prefix}$($items)$postfix"
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

function Split-String {
   #.Synopsis
   #  Split a string and execute a scriptblock to give access to the pieces (a pipeline-enabled superset of the -split operator).
   #.Description
   #  Splits a string (by default, on whitespace), and assigns it to $0, and the first 20 words to $1 through $20 ... and then calls the specified scriptblock
   #.Example
   #  echo "this one is a crazy test brother-of-mine" | split {$3, $1.ToUpper(), $4, $6, "?"}
   #
   #  outputs 5 strings: is, THIS, a, test, ?  
   #
   #.Example
   #  echo "this test is far-from crazy" | split {$0[-1]}
   #
   #  outputs the last word in the string: crazy
   #
   #.Example
   #  echo "this is one test ff-ff-00 a crazy" | split | select -last 2
   #
   #  outputs the last two words in the string: a, crazy
   [CmdletBinding(DefaultParameterSetName="DefaultSplit")]
   param(
      # The regular expression to split on. By default "\s+" (any number of whitespace characters)
      [Parameter(Position=0, ParameterSetName="SpecifiedSplit")]
      [string]$pattern="\s+",
      
      # The scriptblock to execute.  By default {$0} which returns the whole split array   
      [Parameter(Position=0,ParameterSetName="DefaultSplit")]
      [Parameter(Position=1,ParameterSetName="SpecifiedSplit")]
      [ScriptBlock]$action={$0},
      
      # The string to split
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [Alias("String")]
      [string]$InputObject
   )
   begin {
      if(!$pattern){[regex]$re="\s+"}else{[regex]$re=$pattern}
   }
   process {
      $0 = $re.Split($InputObject)
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$n = $0
      &$action.GetNewClosure()
   }
}

function Get-Captures {
   <#
      .Synopsis
         Collect named capture groups from regular expression matches
      .Description
         Takes string data and a regular expression containing named captures, 
         and outputs all of the resulting captures in one (or more) hashtable(s)
      .Example
         @"
         Revoked Certificates:
             Serial Number: 011F63068E6BCD8CABF644026B80A903
                 Revocation Date: Jul  8 06:22:01 2012 GMT
             Serial Number: 01205F0018B6758D741B3DB43CFB26C2
                 Revocation Date: Feb 18 06:11:14 2013 GMT
             Serial Number: 012607175D820413ED0750E96B833A8F
         "@ | Get-Captures "(?m)Serial Number:\s+(?<SerialNumber>.*)\s*$|Revocation Date:\s+(?<RevocationDate>.*)\s*$"
   #>
   param(
      # The text to search for captures
      [Parameter(ValueFromPipeline=$true)]
      [string]$text,

      # A regular expression containing named capture groups (see examples)
      [Parameter(Position=1)]
      [regex]$re,

      # If set, each match will be returned as a single hashtable, otherwise, matches will be grouped together until a property name repeats.
      [switch]$NoGroup
   )
   begin {
      [string[]]$FullData = $text
   }
   process {
      [string[]]$FullData += $text
   }
   end {
      $text = $FullData -join "`n"
      Write-Verbose "Regex $re"
      Write-Verbose "Data $text"
      $matches = $re.Matches($text)
      $names = $re.GetGroupNames() | Where { $_ -ne 0 }
      $result = @{}
      foreach($match in $matches | where Success) {
         foreach($name in $names) {
            if($match.Groups[$name].Value) {
               if($NoGroup -or $result.ContainsKey($name)) {
               Write-Output $result
               $result = @{}
            }
            $result.$name = $match.Groups[$name].Value
         }
      }
    }
  }
}

function Get-Label {
   #.Synopsis
   #   Get labelled text using Regex
   #.Example
   #   openssl crl -in .\CSC3-2010.crl -inform DER -text | Get-Label "Serial Number:" "Revocation Date:" -AsObjects
   param(
      # Text data that has labels with values in it
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [AllowEmptyString()]
      [string]$data,

      # The labels for the values (labels and values are presumed to be on their own lines)
      [Parameter(ValueFromRemainingArguments=$true, Position = 1)]
      [string[]]$labels = ("Serial Number:","Revocation Date:"),

      [switch]$NoGroup,

      [switch]$AsObjects
   )
   begin {
      [string[]]$FullData = $data
   }
   process {
      [string[]]$FullData += $data
   }

   end {
      $data = $FullData -join "`n"

      $names = $labels -replace "\s+" -replace "\W"

      $re = "(?m)" + (@(
         for($l=0; $l -lt $labels.Count; $l++) {
            $label = $labels[$l]
            $name = $names[$l]
            "$label\s*(?<$name>.*)\s*`$"
         }) -join "|")

      write-verbose $re

      if($AsObjects) {
         foreach($hash in Get-Captures $data $re -NoGroup:$NoGroup) {
            New-Object PSObject -Property $hash
         }
      } else {
         Get-Captures $data $re -NoGroup:$NoGroup
      }
   }
}



function ConvertFrom-PropertyString {
   <#
      .SYNOPSIS
         Converts data from flat or single-level property files into PSObjects
      .DESCRIPTION
         Converts delimited string data such as .ini files, or the format-list output of PowerShell, into objects
      .EXAMPLE
         netsh http show sslcert | join-string "`n" | 
         ConvertFrom-PropertyString -ValueSeparator " +: " -AutomaticRecords |
            Format-Table Application*, IP*, Certificate*
                  
         Converts the output of netsh show into pseudo-objects, and then uses Format-Table to display them
      .EXAMPLE
         ConvertFrom-PropertyString config.ini
         
         Reads in an ini file (which has key=value pairs), using the default settings

         .EXAMPLE
         @"
         ID:3468
         Type:Developer
         StartDate:1998-02-01
         Code:SWENG3
         Name:Baraka

         ID:11234
         Type:Management
         StartDate:2005-05-21
         Code:MGR1
         Name:Jax
         "@ |ConvertFrom-PropertyString -sep ":" -RecordSeparator "\r\n\s*\r\n" | Format-Table


         Code             StartDate       Name            ID              Type           
         ----             ---------       ----            --              ----           
         SWENG3           1998-02-01      Baraka          3468            Developer      
         MGR1             2005-05-21      Jax             11234           Management     
            
         Reads records from a key:value string with records separated by blank lines.
         NOTE that in this example you could also have used -AutomaticRecords or -Count 5 instead of specifying a RecordSeparator
      .EXAMPLE
         @"
         Name=Fred
         Address=Street1
         Number=123
         Name=Janet
         Address=Street2
         Number=345 
         "@ | ConvertFrom-PropertyString -RecordSeparator "`n(?=Name=)"

         Reads records from a key=value string and uses a look-ahead record separator to start a new record whenever "Name=" is encountered
         
         NOTE that in this example you could have used -AutomaticRecords or -Count 3 instead of specifying a RecordSeparator 
      .EXAMPLE
         ConvertFrom-PropertyString data.txt -ValueSeparator ":"
         
         Reads in a property file which has key:value pairs
      .EXAMPLE
         Get-Content data.txt -RecordSeparator "`r`n`r`n" | ConvertFrom-PropertyString -ValueSeparator ";"
         
         Reads in a property file with key;value pairs, and records separated by blank lines, and converts it to objects
      .EXAMPLE
         ls *.data | ConvertFrom-PropertyString
         
         Reads in a set of *.data files which have an object per file defined with key:value pairs of properties, one-per line.
      .EXAMPLE
         ConvertFrom-PropertyString data.txt -RecordSeparator "^;(.*?)\r*\n" -ValueSeparator ";"
         
         Reads in a property file with key:value pairs, and sections with a header that starts with the comment character ';'
         
      .NOTES
         3.5   2012 July 26
               - Changed defaults so that lines which don't have a -ValueSeparator in them don't get output
               - Changed pipelining so that it works more the way I expect it to, nowadays
               - Fixed some problems with -RecordSeparator getting truncated to a single character when you use a capture group and add it as a PSName property
               Clearly I need to write some test cases around this to make sure that I'm not breaking functionality, because these changes felt like things that should have already worked...
         3.0   2010 Aug 4 
               - Renamed most of the parameters because I couldn't tell which did what from the Syntax help
               - Added a -AutomaticRecords switch which creates new output objects whenevr it encounters a duplicated property
               - Added a -SimpleOutput swicth which prevents the output of the PSChildName property
               - Added a -CountOfPropertiesPerRecord parameter which allows splitting input by count instead of regex or automatic
         2.0   2010 July 9 http://poshcode.org/get/1956
               - changes the output so that if there are multiple instances of the same key, we collect the values in an array
         1.0   2010 June 15 http://poshcode.org/get/1915
               - Initial release
      
   #>
   [CmdletBinding(DefaultParameterSetName="Data")]
   param(
      # The text to be parsed
      [Parameter(Position=99, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Data")]
      [Alias("Data","Content","IO")]
      [AllowEmptyString()]
      [string]$InputObject,
      # A file containing text to be parsed (so you can pipeline files to be processed)
      [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="File")]
      [Alias("PSPath")]
      [string]$FilePath,

      # The value separator string used between name=value pairs. Allows regular expressions.
      # Typical values are "=" or ":"
      # Defaults to "="   
      [Parameter(ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
      [Alias("VS","Separator")]
      [String]$ValueSeparator="\s*(?:=|:)\s*",
      # The property separator string used between sets of name=value pairs. Allows regular expressions.
      # Typical values are "\n" or "\n\n" or "\n\s*\n"
      # Defaults to "\n\s*\n?"    
      [Parameter(ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
      [Alias("PS","Delimiter")]
      [String]$PropertySeparator='(?:\s*\n+\s*)+',

      # The record separator string is used between records or sections in a text file.
      # Typical values are "\n\s*\n" or "\n\[(.*)\]\s*\n"
      # Defaults to "(?:\n|^)\[([^\]]+)\]\s*\n" (the correct value for ini files).
      
      # To support named sections or records, make sure to use a regular expression here that has a capture group defined.
      [Parameter(ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false)]
      [Alias("RS")]
      [String]$RecordSeparator='(?:\n|^)\[([^\]]+)\]\s*\n',
      
      # Supports guessing when a new record starts based on the repetition of a property name. You can use this whenever your input has multiple records and the properties are always in the same order.
      [Parameter(ParameterSetName="Data")]
      [Alias("MultiRecords","MR","MultipleRecords","AR","AutoRecords")]
      [Switch]$AutomaticRecords,
      
      # Separate the input into groups of a certain number of properties.
      # If your input file has no specific record separator, you can usually match the first property by using a look-ahead expression *(See Example 2)*
      # However, if the properties aren't in the same order each time or regular expressions make you queasy, and each of your records have the same number of properties on each record, you can use this to separate them by count.   
      [Parameter()]
      [int]$CountOfPropertiesPerRecord,
      
      # Prevent outputting the PSName parameter which indicates the source of the object when pipelineing file names
      [Parameter()]
      [Switch]$SimpleOutput,
      
      # Discard the first record, assuming that it is merely some lines of header introductory text
      [Parameter()]
      [Switch]$HasHeader,
      
      # Discard the last record, assuming that it is merely some lines of footer summary text
      [Parameter()]
      [Switch]$HasFooter
   )
   begin {
      function new-output {
         [CmdletBinding()]
         param(
            [Switch]$SimpleOutput
         ,
            [AllowNull()][AllowEmptyString()]
            [String]$Key
         ,
            [AllowNull()][AllowEmptyString()]
            $FilePath
         )
         end {
            if(!$SimpleOutput -and ("" -ne $Key))  { @{"PSName"=$key} }
            elseif(!$SimpleOutput -and $FilePath)  { @{"PSName"=((get-item $FilePath).PSChildName)} }
            else                                   { @{} }
         }
      }

      function out-output {
         [CmdletBinding()]
         param([Hashtable]$output)
         end {
            ## If we made arrays out of single values, unwrap those
            foreach($k in $Output.Keys | Where { @($Output.$_).Count -eq 1 } ) {
               $Output.$k = @($Output.$k)[0]
            }
            if($output.Count) {
               New-Object PSObject -Property $output
            }
         }
      }
      $OutputCount = 0
      [String]$InputString = [String]::Empty

      Write-Verbose "Setting up the regular expressions: `n`tRecord:   '$RecordSeparator'  `n`tProperty: '$PropertySeparator'  `n`tValue:    '$ValueSeparator'"
      [Regex]$ReRecordSeparator   = New-Object Regex ([System.String]"\s*$RecordSeparator\s*"),   ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      [Regex]$RePropertySeparator = New-Object Regex ([System.String]"\s*$PropertySeparator\s*"), ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      [Regex]$ReValueSeparator    = New-Object Regex ([System.String]"\s*$ValueSeparator\s*"),    ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
   }
   process {
      if($PSCmdlet.ParameterSetName -eq "File") {
         $AutomaticRecords = $true
         $InputString += $(Get-Content $FilePath -Delimiter ([char]0)) + "`n`n"
      } else {
         $InputString += "$InputObject`n"
      }
   }
   end {
      ## some kind of PowerShell bug when expecting pipeline input:   
      if(!"$ReRecordSeparator"){
         Write-Verbose "Setting up the record regex in the PROCESS block: '$RecordSeparator'"
         [Regex]$ReRecordSeparator   = New-Object Regex ([System.String]"\s*$RecordSeparator\s*"),   ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      }
      if(!"$RePropertySeparator"){
         Write-Verbose "Setting up the property regex in the PROCESS block: '$PropertySeparator'"
         [Regex]$RePropertySeparator = New-Object Regex ([System.String]"\s*$PropertySeparator\s*"), ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      }
      if(!"$ReValueSeparator") {  
         Write-Verbose "Setting up the value regex in the PROCESS block: '$ValueSeparator'"
         [Regex]$ReValueSeparator    = New-Object Regex ([System.String]"\s*$ValueSeparator\s*"),    ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      }
      Write-Verbose "ParameterSet: $($PSCmdlet.ParameterSetName)"
      Write-Verbose "ValueSeparator: $($ReValueSeparator)"
      $InputData = @{}
      if($PSCmdlet.ParameterSetName -eq "File") {
         $AutomaticRecords = $true
         $InputString = Get-Content $FilePath -Delimiter ([char]0)
      }
      
      ## Separate RecordText with the RecordSeparator if the user asked us to:
      if($PsBoundParameters.ContainsKey('RecordSeparator') -or $AutomaticRecords ) {
         $Records = $ReRecordSeparator.Split( $InputString ) # | Where-Object { $_ }
         ## Instead of using WhereObject and removing all the empty rows, allow empties AFTER record separators, but not before...
         if(!@($Records)[0]) {
            $Records = $Records[1..$($Records.Count-1)]
         }
         Write-Verbose "There are $($ReRecordSeparator.GetGroupNumbers().Count) groups and $(@($Records).Count) records!"
         if($ReRecordSeparator.GetGroupNumbers().Count -gt 1 -and @($Records).Count -gt 1) {
            if($HasHeader) {
               $Records = $Records[2..$($Records.Count -1)]
            }
            if($HasFooter) {
               $Records = $Records[0..$($Records.Count -3)]
            }
            while($Records) {
               $Key,$Value,$Records = @($Records)
               Write-Verbose "RecordSeparator with grouping: $Key = $Value"
               $InputData.$Key += @($Value)
            }
         } elseif(@($Records).Count -gt 1) {
            $InputData."" = @($Records)
            $InputString = $Records
         } else {
            $InputString = $Records
         }
      }
         
      ## Separate RecordText into properties and group them together by count if we were told a count
      if($PsBoundParameters.ContainsKey('CountOfPropertiesPerRecord')) {   
         $Properties = $RePropertySeparator.Split($InputString)
         Write-Verbose "Separating Records by Property count = $CountOfPropertiesPerRecord of $($Properties.Count)"
         for($Index = 0; $Index -lt $Properties.Count; $Index += $CountOfPropertiesPerRecord) {
            $InputData."" += @($Properties[($Index..($Index+$CountOfPropertiesPerRecord-1))] -Join ([char]0))
            Write-Verbose "Record ($Index..) $($Index/$CountOfPropertiesPerRecord) = $(@($Properties[($Index..($Index+$CountOfPropertiesPerRecord-1))] -Join ([char]0)))"
         }
         ## We have to manually set the PropertySeparator because we can't generate text from your regex pattern to match your regex pattern
         $SetPropertySeparator = $RePropertySeparator
         [Regex]$RePropertySeparator = New-Object Regex ([System.String][char]0), ([System.Text.RegularExpressions.RegexOptions]"Multiline,IgnoreCase,Compiled")
      } 
      if($InputData.Keys.Count -eq 0){
         Write-Verbose "Keyless entry enabled!"
         $InputData."" = @($InputString)
      }
      
      Write-Verbose "InputData: $($InputData.GetEnumerator() | ft -auto -wrap| out-string)"

      ## Process each Record
      foreach($key in $InputData.Keys) { foreach($record in $InputData.$Key) {
         Write-Verbose "Record($Key): $record"
         
         $output = new-output -SimpleOutput:$SimpleOutput -Key:$Key -FilePath:$FilePath
         
         foreach($Property in $RePropertySeparator.Split("$record") | ? {$_}) {
            if($ReValueSeparator.IsMatch($Property)) {
               [string[]]$data = $ReValueSeparator.split($Property,2) | foreach { $_.Trim() } | where { $_ }
               Write-Verbose "Property: $Property --> $($data -join ': ')"
               if($AutomaticRecords -and $Output.ContainsKey($Data[0])) {
                  out-output $output
                  $output = new-output -SimpleOutput:$SimpleOutput -Key:$Key -FilePath:$FilePath
               }
               switch($data.Count) {
                  1 { $output.($Data[0]) += @($null)    }
                  2 { $output.($Data[0]) += @($Data[1]) }
               }
            }
         }
         out-output $output

         
      }  }
      ## Put this back in case there's more input
      $RePropertySeparator = $SetPropertySeparator
   }
}

function Import-Delimited {
   <#
      .Synopsis
         A script to import delimited text (CSV,Tabs,Fixed Width,etc)
      .Description
         Import-Delimited's primary claim to fame is that it can import CSV files without headers
         but it can also import other formats, or multiple files at once, etc. and it's original
         reason for being was that it could coerce types while it was importing.
      
      .Parameter Delimiter
         An OPTIONAL [regex] to split the lines. By default: ", *" for CSV.
         Note that you can only use ONE of Names, Columns, or Select ... AND if you use Type, you MUST use Names or nothing
      
          Some other common options for the delimiter parameter:
             "; *"  -- semicolon delimited
             "`t+"  -- tab-delimited columns
             " + "  -- fixed width columns delimited by one or more spaces
      .Parameter Type
         A type to parse each line as. You can specify the properties to set with the Names parameter, and the contructor parameters but not with any other of the three column specifications.
      .Parameter Names
         A array of column names (strings) in order
      .Parameter Columns
         A hashtable of Name=>Type mappings for all the columns, in order
      .Parameter Select
         An array of hashtables which each represent a name=>expression mapping
      .Parameter Path
         A path to the file(s) to read for input
         It's best to just get-content on your own, but sometimes you need this.
            
      .Parameter HasHeaders
         A switch which means the first non-comment line should be ignored.  
      .Parameter DiscardErrors
         A switch to throw out lines which won't parse properly
      
      .Example
         "Sarah,76.8", "Brad,94" | Import-Delimited -Names "Name","Score"
      
         Specify column names, without worrying about types, etc.
       
      .Example
         "Sarah,76.8", "Brad,94" | Import-Delimited -Columns @{Name=[string];Score=[int]}
         
          Specify the column names and data types
           
      .Example
           "Sarah,76.8", "Brad,94" | Import-Delimited -Select @{n="Name";e={$_[0]}},
                                                              @{n="Score";e={
                                                                          switch([double]$_[1]){
                                                                             {$_-gt90}{"A";break}
                                                                             {$_-gt80}{"B";break}
                                                                             {$_-gt70}{"C";break}
                                                                             {$_-gt60}{"D";break}
                                                                             default  {"F";break}
                                                                          }}}
      
         When you need to massage the data, you can use Select-Object syntax with column indexes on the iterator variable ($_) to transform the data as you import it.
      
         That is: when you specify select, the line will be passed in as an array of elements to the select statement, so each expression should be like: $_[n] where n is the column index.
      
      .Notes
          When a line won't parse into the columns and types specified, the columns that do parse are 
             shown, and the error is written. To avoid this behavior you can specify the DiscardErrors
             switch, and these partially correct lines won't show up in your output.  This usually 
             allows you to throw out header lines when parsing type-safe columns. In either case, the
             script will set the $ImportDelimitedErrorCount variable to indicate the total error lines
             and will store those lines to $ImportDelimitedErrorLines.
   #>
   param( 
      [regex]        $delimiter =", *", 
      #   [type]         $Type      =$null,
      [string[]]     $Names     =$null,
      [hashtable]    $Columns   =$null,
      [hashtable[]]  $Select    =$null,
      [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
      [string[]]     $InputObject,
      [string]       $PsPath    ="",
      [switch]       $HasHeaders,
      [switch]       $DiscardErrors
   )

   BEGIN {
      ## You should only have ONE of: Names, Columns, Select
      ## If we weren't provided a header, but we do have column names:
      if(!$Select -and $Names) {
         $x=0; 
         $select = iex $([string]::join(",",($Names | % { "@{n=`"$_`";e={`$_[$($x;++$x)]}}" } )))
         
         # $select|ft Name,@{l="NameType";e={$_.Name.GetType()}},Value,@{l="ValueType";e={$_.Value.GetType()}} -auto|out-string|write-debug
         
      }
      ## If they are providing Select-Object hashtables, they'll probably give us more than one
      elseif(!$Select -and $Columns)
      {
         $headers = @(); 
         [int]$x = 0
         ## otherwise, this should be a Name=TYPE hashtable
         foreach($name in $Columns.Keys)  {
            ## If it is, then we will create a new Headers set
            if($name -is [string] -and (($Columns[$name] -as [type]) -ne $null)) {
               $headers += $("@{n=`"$name`";e={`[$($Columns[$name])`]`$_[$($x;++$x)]}}")
            }
            else ## otherwise, we'll die.
            {
               throw (New-Object ArgumentException "Columns takes a Name=[Type] hashtable map.")
            }
         }
         $select = iex $([string]::join(",",($headers)))
         # $select|ft Name,@{l="NameType";e={$_.Name.GetType()}},Value,@{l="ValueType";e={$_.Value.GetType()}} -auto|out-string|write-debug
      }
      if ($PsPath.Length -gt 0) { 
         if($select) {
            gc $PsPath | &($MyInvocation.InvocationName) -Delimiter:$delimiter -select:$select -HasHeaders:$HasHeaders -DiscardErrors:$DiscardErrors
         } else {
            gc $PsPath | &($MyInvocation.InvocationName) -Delimiter:$delimiter -HasHeaders:$HasHeaders -DiscardErrors:$DiscardErrors
         }
      }
      $erap = $ErrorActionPreference
      $global:ImportDelimitedErrorCount = 0
      $global:ImportDelimitedErrorLines = @()
   }

   PROCESS {
      foreach($line in $InputObject | %{ $_ -split "\r?\n" } ) {
         ## if it's not null, and it's not a comment line:
         if($line -and $line[0] -ne "#") 
         {
            if($HasHeaders){
               $HasHeaders = $false
               Write-Verbose "Skipping header line"
            # if no headers were specified, we're going to use the first line
            # and basically, we'll behave like Import-CSV
            } 
            elseif(!$select) {
               $x=0; 
               Write-Verbose "Processing Header Line with $($delimiter.Split($line).Count) columns: $line"
               $select = iex $([string]::join(",",($delimiter.Split($line) | % { "@{n=`"$_`";e={`$_[$($x;++$x)]}}" } )))
               # $select|ft Name,@{l="NameType";e={$_.Name.GetType()}},Value,@{l="ValueType";e={$_.Value.GetType()}} -auto|out-string|write-debug
            } else {
               Write-Verbose "Processing Line with $($delimiter.Split($line).Count) columns: $line"
               
               # In order to hide errors when -DiscardErrors is on ...
               # And still recover and show them when it's not ...
               $ErrorActionPreference = "Stop" # and make it not output on errors

               # this is the line that does the output
               select -input $delimiter.split($line) $select
               trap # hide errors if -DiscardErrors is on
               { 
                  # But if DiscardErrors in not on, we should try again so they can see the error
                  $ErrorActionPreference = "SilentlyContinue"
                  $global:ImportDelimitedErrorCount++
                  $global:ImportDelimitedErrorLines += $line
                  if(!$DiscardErrors){ 
                     select -input $delimiter.split($line) $select 
                  }
                  continue
               }
               $ErrorActionPreference = $erap
            }
         }
      }
   }

   END {
      if($global:ImportDelimitedErrorCount -gt 0) {
         $ErrorActionPreference = $erap
         Write-Error "`nFailed to parse $ImportDelimitedErrorCount lines. You can find them in `$ImportDelimitedErrorLines"
      }
   }
}

function Import-CmdEnvironment {
   <#
      .SYNOPSIS
         Import environment variables from cmd to PowerShell
      .DESCRIPTION
         Invoke the specified command (with parameters) in cmd.exe, and import any environment variable changes back to PowerShell
      .EXAMPLE
         Import-CmdEnvironment ${Env:VS90COMNTOOLS}\vsvars32.bat x86
         
         Imports the x86 Visual Studio 2008 Command Tools environment
      .EXAMPLE
         Import-CmdEnvironment ${Env:VS100COMNTOOLS}\vsvars32.bat x86_amd64
         
         Imports the x64 Cross Tools Visual Studio 2010 Command environment
   #>
   [CmdletBinding()]
   param(
      [Parameter(Position=0,Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")]
      [string]$Command = "echo"
   ,
      [Parameter(Position=0,Mandatory=$False,ValueFromRemainingArguments=$true,ValueFromPipelineByPropertyName=$true)]
      [string[]]$Parameters
   )
   ## If it's an actual file, then we should quote it:
	if(Test-Path $Command) { $Command = "`"$(Resolve-Path $Command)`"" }
   $setRE = new-Object System.Text.RegularExpressions.Regex '^(?<var>.*?)=(?<val>.*)$', "Compiled,ExplicitCapture,MultiLine"
   $OFS = " "
   [string]$Parameters = $Parameters
   $OFS = "`n"
	## Execute the command, with parameters.
   Write-Verbose "EXECUTING: cmd.exe /c `"$Command $Parameters > nul && set`""
	## For each line of output that matches, set the local environment variable
	foreach($match in  $setRE.Matches((cmd.exe /c "$Command $Parameters > nul && set")) | Select Groups) {
      Set-Content Env:\$($match.Groups["var"]) $match.Groups["val"] -Verbose
	}
}



function Format-Csv {
   [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113304')]
   param(
      [Parameter(Position=0)]
      [System.Object]${Property},
   
      [System.Object]${GroupBy},
   
      [string]${View},
   
      [switch]${ShowError},
   
      [switch]${DisplayError},
   
      [switch]${Force},
   
      [ValidateSet('CoreOnly','EnumOnly','Both')]
      [string]${Expand},
   
      [Parameter(ValueFromPipeline=$true)]
      [psobject]${InputObject},

      [int]${Width},

      [string]${Separator} = ", "
   )
begin {
   try {
      $outBuffer = $null
      if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
      {
         $PSBoundParameters['OutBuffer'] = 1
      }

      $PSBoundParameters['Column'] = 1
      $null = $PSBoundParameters.Remove("Width")
      $null = $PSBoundParameters.Remove("Separator")

      $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Format-Wide', [System.Management.Automation.CommandTypes]::Cmdlet)
      $wrappedString = $ExecutionContext.InvokeCommand.GetCommand('Out-String', [System.Management.Automation.CommandTypes]::Cmdlet)

      if($Width) {
         $scriptCmd = {& $wrappedCmd @PSBoundParameters | % { if($_.GetType().Name -eq 'GroupStartData'){ $_.groupingEntry = $null }; $_ } | Out-String -Stream | Join-String -Trim -NonEmpty -SplitLength:$Width -Separator:$Separator}
         $streamCmd = {& $wrappedString -Width:$Width -Stream}
      } else {
         $scriptCmd = {& $wrappedCmd @PSBoundParameters | % { if($_.GetType().Name -eq 'GroupStartData'){ $_.groupingEntry = $null }; $_ } | Out-String -Stream | Join-String -Trim -NonEmpty -Separator:$Separator}
         $streamCmd = {& $wrappedString -Stream}
      }
      $Stream = $Null
      # $begun = $false
      # if($InputObject) {
      #    Write-Verbose $InputObject.GetType().FullName
      #    if($InputObject.GetType().FullName -like "Microsoft.PowerShell.Commands.Internal.Format.*" -or $InputObject.GetType().FullName -eq "System.String") {
            $steppableStream = $streamCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppableStream.Begin($PSCmdlet)
         # } else {
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
      #    }      
      #    $begun = $true
      # }
   } catch {
      throw
   }
}

process {
   if($Stream -eq $Null) {
      $Stream = $_.GetType().FullName -like "Microsoft.PowerShell.Commands.Internal.Format.*" -or $InputObject.GetType().FullName -eq "System.String"
   }
   # if(!$begun) {
   #    Write-Verbose "Late Start"
   #    if($_.GetType().FullName -like "Microsoft.PowerShell.Commands.Internal.Format.*" -or $InputObject.GetType().FullName -eq "System.String") {
   #       $steppableStream = $streamCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   #       $steppableStream.Begin($PSCmdlet)
   #    } else {
   #       $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   #       $steppablePipeline.Begin($PSCmdlet)
   #    }      
   # }
   try {
      if($Stream) {
         $steppableStream.Process($_)
      } else {
         $steppablePipeline.Process($_)
      }
   } catch {
      throw
   }
}

end {
   try {
      if($Stream) {
         $steppableStream.End()
      } else {
         $steppablePipeline.End()
      }
   } catch {
      throw
   }
}
<#

.ForwardHelpTargetName Format-Wide
.ForwardHelpCategory Cmdlet

#>


}

New-Alias join Join-String
New-Alias split Split-String
New-Alias replace Replace-String
New-Alias fcsv Format-Csv

Export-ModuleMember -Function * -Alias *
