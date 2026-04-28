$processName = 'heartbeat'
$Proc = @("$processName")
$ProcActive = Get-Process -Name $Proc -ErrorAction SilentlyContinue

if($ProcActive){
	Write-Warning "Application $processName is currently running, the service will be stopped now."
	Stop-Service $processName -Force -ErrorAction SilentlyContinue
}