$WinPackageName = 'Beats filebeat-oss'
$processName = 'filebeat'
$Proc = @("$processName")
$ProcActive = Get-Process -Name $Proc -ErrorAction SilentlyContinue

## Stop winlogbeat application if it is already running
if($ProcActive){
	Write-Warning "Application $processName is currently running, the service will be stopped now."
	Stop-Service $processName -Force -ErrorAction SilentlyContinue
}