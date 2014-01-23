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


Export-ModuleMember -Function *-* -Cmdlet * -Alias *