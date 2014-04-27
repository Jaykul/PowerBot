$Script:PowerBotCtcpData = @{}

$script:irc.Add_OnCtcpReply( {OnCtcpReply_StoreData} )

function OnCtcpReply_StoreData {
   if(!$Script:PowerBotCtcpData.ContainsKey($_.Data.Nick)) {
      $Script:PowerBotCtcpData.Add( $_.Data.Nick, @{} )
   }
   
   $Script:PowerBotCtcpData[$_.Data.Nick][$_.CtcpCommand] = $_.CtcpParameter
}
