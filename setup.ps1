# Kill switch to make sure we run powershell v3 or above. (default: Win7 SP1 and above)
if (-Not $PSScriptRoot) {
	Write-Host "ERROR: Powershell version needs to be 3.0 or above, exiting."
	exit $LASTEXITCODE
}

# Declaring some variables
$appdata = $env:LOCALAPPDATA
$current = $PSScriptRoot

$script = "DiskUsage.ps1"
$currentScript = Join-Path $current $script
$appdataScript = Join-Path $appdata $script

$config = "diskusageconfig.xml"
$currentConfig = Join-Path $current $config
$appdataConfig = Join-Path $appdata $config

$html = "storageWarning.html"
$currentHtml = Join-Path $current $html
$appdataHtml = Join-Path $appdata $html


# Create lists with the absolute paths in them so we can check what exists and what not.
$currentPaths = $currentScript, $currentConfig, $currentHtml
$appdataPaths = $appdataScript, $appdataConfig, $appdataHtml


# Make sure the needed files exist
foreach ($path in $currentPaths) {
	if ((Test-Path $path -PathType Leaf) -ne $true) {
		Write-Host "ERROR: File ($path) not found, exiting."
		exit $LASTEXITCODE
	}
}

# Check if the files already exist in localappdata
foreach ($path in $appdataPaths) {
	if ((Test-Path $path -PathType Leaf) -ne $false) {
		Write-Host "WARN: File ($path) already exist, this file will get overwritten if you continue to install the script!"
	}
}


############### General installation 

# Install the script?
while($true) {
	Write-Host ""
	try {
		[string]$installDU = Read-Host -Prompt 'Install DiskUsage? (y/n)'
		$installDU = $installDU.ToLower()
	} catch {
		Write-Host "`nType (y)es or (n)o"
		continue
	}
	break
}

if ($installDU -eq "y" -Or $installDU -eq "yes" -Or $installDU -eq "j" -Or $installDU -eq "ja") {
	foreach ($path in $currentPaths) {
		try {
			Copy-Item $path -Destination $appdata
		} catch {
			Write-Host "ERROR: could not copy $path to $appdata, exiting."
			exit $LASTEXITCODE
		}
	}
	Write-Host "Done."
} else {
	Write-Host "Aborting."
	exit 1
}



################## Task registration

# SerializeTime :: Make sure we get the correct DateTime format.
function SerializeTime($time) {
	switch($time) {
		0 {[DateTime]$newTime = "00:00"}
		1 {[DateTime]$newTime = "01:00"}
		2 {[DateTime]$newTime = "02:00"}
		3 {[DateTime]$newTime = "03:00"}
		4 {[DateTime]$newTime = "04:00"}
		5 {[DateTime]$newTime = "05:00"}
		6 {[DateTime]$newTime = "06:00"}
		7 {[DateTime]$newTime = "07:00"}
		8 {[DateTime]$newTime = "08:00"}
		9 {[DateTime]$newTime = "09:00"}
		10 {[DateTime]$newTime = "10:00"}
		11 {[DateTime]$newTime = "11:00"}
		12 {[DateTime]$newTime = "12:00"}
		13 {[DateTime]$newTime = "13:00"}
		14 {[DateTime]$newTime = "14:00"}
		15 {[DateTime]$newTime = "15:00"}
		16 {[DateTime]$newTime = "16:00"}
		17 {[DateTime]$newTime = "17:00"}
		18 {[DateTime]$newTime = "18:00"}
		19 {[DateTime]$newTime = "19:00"}
		20 {[DateTime]$newTime = "20:00"}
		21 {[DateTime]$newTime = "21:00"}
		22 {[DateTime]$newTime = "22:00"}
		23 {[DateTime]$newTime = "23:00"}
		24 {[DateTime]$newTime = "00:00"}
	}
	return $newTime
}

# MapDayOfWeek :: Map the day of the week to the correct datatype.
function MapDayOfWeek($dayOfWeek) {
	switch($dayOfWeek){
        1 {[DayOfWeek]$day = "Monday"}            
        2 {[DayOfWeek]$day = "Tuesday"}            
        3 {[DayOfWeek]$day = "Wednesday"}            
        4 {[DayOfWeek]$day = "Thursday"}            
        5 {[DayOfWeek]$day = "Friday"}            
        6 {[DayOfWeek]$day = "Saturday"}            
        7 {[DayOfWeek]$day = "Sunday"}           
    } 
	return $day
}
	
# RegisterTask :: Register the task with the passed time.
function RegisterTask([int]$time, [int]$interval, [int]$dayOfWeek) {
	# Create the arguments and the action for the task.
	$args = "-NonInteractive -NoLogo -NoProfile -File $appdataScript"
	$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument $args
	$ExecTime = SerializeTime $time	

	# Check what type of task/trigger we want (Daily/Weekly).
	if ($interval -eq 2) {
		$Day = MapDayOfWeek $dayOfWeek
		$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $ExecTime
	} else {
		$Trigger = New-ScheduledTaskTrigger -Daily -At $ExecTime
	}
	
	# We don't need special settings but it's a requirement so we run with defaults.
	$Settings = New-ScheduledTaskSettingsSet
	# Build the task.
	$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings
	
	# What user is executing the script?
	Write-Host "`nWhat User is going to execute the script? (make sure you got the right priviliges for the task)"
	[string]$Username = Read-Host -Prompt "Username"
	[string]$Password = Read-Host -Prompt "Password"
	
	# Create the schedule.
	Register-ScheduledTask -TaskName "DiskUsage" -InputObject $Task -User $Username -Password $Password | out-null
}


# Wanna create a task too?
while($true) {
	
	try{
		Write-Host ""
		[string]$createTask = Read-Host -Prompt "Create Task? (y/n)"
		$createTask = $createTask.ToLower()
	} catch {
		Write-Host "Type (y)es or (n)o"
		continue
	}
	
	if ($createTask -eq "y" -Or $createTask -eq "yes" -Or $createTask -eq "j" -Or $createTask -eq "ja") {
		try {
			[int]$time = Read-Host -Prompt "When should we run the task? (eg. 1 => 1am; 14 => 2pm)"
		} catch {
			Write-Host "`nPlease enter a number"
			continue
		}
		# Check if we don't exceed 24 hours
		if ($time -gt 24 -Or $time -lt 0) {
			Write-Host "`nWe only have 24 hours in a day... Try again."
			continue
		}
		
		# Do we want to execute it daily or weekly?
		try {
			[int]$interval = Read-Host -Prompt "How often do you want to run it? (1 = Daily ; 2 = Weekly)"
		} catch {
			Write-Host "`nPlease enter a number"
			continue
		}
		
		if ($interval -gt 2 -Or $interval -le 0 ) {
			Write-Host "`Please use (1) for Daily or (2) for Weekly execution"
			continue
		}
		
		# On what day of the week should we execute the script?
		if ($interval -eq 2) {
			try {
				[int]$dayOfWeek = Read-Host -Prompt "On what day should we execute? (1 = Monday ; 2 = Tuesday ; 3 = Wednesday ; 4 = Thursday ; 5 = Friday ; 6 = Saturday ; 7 = Sunday)"
			} catch {
				Write-Host "`nPlease enter a number"
				continue
			}
			if ($dayOfWeek -lt 1 -Or $dayOfWeek -gt 7) {
				Write-Host "`Please use 1-to-7 to select a day of execution"
				continue
			}
		} else {
			$dayOfWeek = 0
		}
		
		# Create the task.
		RegisterTask $time $interval $dayOfWeek
		Write-Host "`nDone."
	}
	
	break
}

Write-Host "`nDiskUsage is now ready to be used."

# Wanna edit the config file?
while($true) {
	try{
		Write-Host ""
		[string]$editConfig = Read-Host -Prompt "Edit the config file? (y/n)"
		$editConfig = $editConfig.ToLower()
	} catch {
		Write-Host "Type (y)es or (n)o"
		continue
	}
	if ($editConfig -eq "y" -Or $editConfig -eq "yes" -Or $editConfig -eq "j" -Or $editConfig -eq "ja") {
		Invoke-Item $appdataConfig
	}
	break
}

exit 0