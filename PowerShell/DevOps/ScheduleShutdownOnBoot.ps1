# PowerShell script to force a system shutdown six hours after the system boots up
# and place the scheduled task in a new folder named "Saberin"

# Create a scheduled task to shut down the system six hours after boot
$action = New-ScheduledTaskAction -Execute 'shutdown.exe' -Argument '/s /f /t 21600'

# Trigger the task at system startup
$trigger = New-ScheduledTaskTrigger -AtStartup

# Create a principal to run the task with SYSTEM account privileges
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Create the "Saberin" folder in the Task Scheduler if it doesn't exist
if (-not (Test-Path "$env:SystemRoot\System32\Tasks\Saberin")) {
    New-Item -Path "$env:SystemRoot\System32\Tasks\Saberin" -ItemType Directory
}

# Register the task in the "Saberin" folder to run at startup with a six-hour delay before shutdown
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "ForceShutdownAfterBoot" -Description "Force shutdown six hours after system boots up" -TaskPath "\Saberin\"
