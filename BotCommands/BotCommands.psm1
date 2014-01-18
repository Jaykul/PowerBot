## NOTE 1: Evrything you return is output to Out-String and then the channel or user.  Be careful!
## NOTE 2: 510 is the Max IRC Message Length, including the channel name etc.
##         http`://www.faqs.org/rfcs/rfc1459.html

# $script:irc = Get-PowerBotIrcClient

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
                     $syntax = @(($helps[0].Syntax | Out-String -width 1000 -Stream).Trim().Split("`n",4,"RemoveEmptyEntries"))
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
                           $syntax = @(($helps[0].Syntax | Out-String -width 1000 -Stream).Trim().Split("`n",4,"RemoveEmptyEntries"))
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