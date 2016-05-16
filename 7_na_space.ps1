#Requires -Modules DataONTAP,Posh-SSH
# use Netapp Cmdlet to pull 7 Mode aggregate and volume data into .csv files
# requires DataONTAP module
#

$credfile="P:\cred.txt"
$sftp_credfile="P:\sftp_cred.txt"
$report_path="/path/prd/na_stats"
$user="domain\user"
$sftp_user="user"
$now = get-date -format MMddyy_HHmm
$credential=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user,(get-content $credfile | ConvertTo-SecureString)
$sftp_credential=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sftp_user,(get-content $sftp_credfile | ConvertTo-SecureString)
$Controllers=@("array1","array2","array3")

function sftp_file ($filename)
{
$sftp_session = New-SFTPSession -ComputerName server1 -Credential $sftp_credential
$index = $sftp_session.SessionID
Set-SFTPFile -SessionId $index -RemotePath $report_path -LocalFile $filename
Remove-SFTPSession -index $index
}

foreach ($Controller in $Controllers) 
{
$voloutput="P:\" + $Controller + "_volume_" + $now + ".csv"
$aggroutput="P:\" + $Controller + "_aggr_" + $now + ".csv" 
write-host "Connecting to controller $Controller"
Connect-NaController $Controller -Credential $credential -HTTP -Verbose
write-host "Exporting volume information..."
Get-NaVol | where-object {$_.Name -notmatch 'aggr0'} | export-csv $voloutput
write-host "SFTP file $voloutput"
sftp_file $voloutput
remove-item $voloutput
write-host "Exporting aggregate information..."
$aggrlist=Get-NaAggrSpace 
foreach ($aggr in $aggrlist | where-object {$_.Aggregate -notlike '*root*'})
{
write-host $aggr.AggregateName,$aggr.SizeUsed,$aggr.SizeFree,$aggr.SizeNominal,$aggr.VolumeCount
$aggr | select AggregateName,SizeUsed,SizeFree,SizeNominal,VolumeCount | Export-csv $aggroutput -Append
}
sftp_file $aggroutput
remove-item $aggroutput
}

