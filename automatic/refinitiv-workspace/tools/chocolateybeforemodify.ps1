$WinPackageName = 'Refinitiv Workspace'
$processName = 'RefinitivWorkspace'
$Proc = @("$processName")
$ProcActive = Get-Process -Name $Proc -ErrorAction SilentlyContinue

## Stop application if it is already running
if ($ProcActive) {
    Write-Warning "Application $processName is currently running, the service will be stopped now."
    $ProcActive | Stop-Process -Force -Confirm:$false
}
