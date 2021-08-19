# Change the $DEBUG value to $false if deployed in production
$DEBUG = $false

# Print :: Print's the given $msg if $DEBUG mode is enabled
function Print($msg) {
	if ($DEBUG) {
		Write-Host $msg
	}
}

# SendMail :: Construct and send the mail.
#			  Only invoked if the disk space is smaller (or equal) to the defined limit.
#
function SendMail {	
	# Define some variables for futher usag and make it more readable.
    $MailFrom = $configXml.config.mail.from
    $MailTo = $configXml.config.mail.to
	$CustomerName = $configXml.config.customer.name
	$CustomerServer = $configXml.config.customer.server
    $Username = $configXml.config.mail.credentials.username
    $Password = $configXml.config.mail.credentials.password
    $SmtpServer = $configXml.config.mail.server
    $SmtpPort = $configXml.config.mail.port

	# Debug output
	Print("`nMail information")
	Print("From: $MailFrom")
	Print("To: $MailTo")
	Print("Customer: $CustomerName")
	Print("Server: $CustomerServer")
	Print("Username: $Username")
	Print("SmtpServer: $SmtpServer : $SmtpPort")

    # Create the message and stuff
    $Message = New-Object System.Net.Mail.MailMessage $MailFrom,$MailTo
    $Message.Subject = "Storage warning for: $CustomerName ($CustomerServer)"
	
	# Check if we render a html template or simple plain text.
	if ($configXml.config.mail.useHtml -eq "true") {
		try {
			$templatePath = $env:LOCALAPPDATA +"\"+ $configXml.config.mail.htmlTemplate
			[string]$htmlData = Get-Content -Path $templatePath -ErrorAction 'Stop'
		} catch {
			Write-Host "Could not parse html template ($templatePath). Make sure the file exists and you have the right permission to read it." -ForegroundColor red -BackgroundColor black
			exit $LASTEXITCODE 
		}
		
		# Modify the $htmlData with the generated data from the script.
		$htmlData = $htmlData.replace("C_TITLE", "Storage warning")
		$htmlData = $htmlData.replace("C_HEADER", "Storage warning for: $CustomerName ($CustomerServer)")
		$htmlData = $htmlData.replace("C_DATA", "Storage issue detected.<br>Server $CustomerName ($CustomerServer) is running low on space.<br><br>Free space on disk " +$configXml.config.drive+ ": "+[math]::Round($diskFree,2)+"GB")
		
		$Message.IsBodyHTML = $true
		$Message.Body = $htmlData
		Print("Content: HTML")
	} else {
		$Message.IsBodyHTML = $false
		$Message.Body = "Storage issue detected.`nServer $CustomerName ($CustomerServer) is running low on space.`n`n`nFree space on disk " +$configXml.config.drive+ ": " +[math]::Round($diskFree,2)+ "GB"
		Print("Content: TEXT")
	}

    # Construct the SMTP client object, credentials, and send
    $Smtp = New-Object Net.Mail.SmtpClient($SmtpServer,$SmtpPort)
    $Smtp.EnableSsl = $true
    $Smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
	$Smtp.Send($Message)
}

# Construct the config path and try to load the configuration file
$configPath = $env:LOCALAPPDATA + "\diskusageconfig.xml"
try {
	[XML] $configXml = Get-Content -Path $configPath -ErrorAction 'Stop'
} catch {
	Write-Host "Could not parse config file ($configPath). Make sure the file exists and you have the right permission to read it." -ForegroundColor red -BackgroundColor black
	exit $LASTEXITCODE 
}

# Get the current disk usage from C: drive
$disk = Get-PSDrive $configXml.config.drive | Select-Object Used,Free
Print("Drive letter: " + $configXml.config.drive)

# Format the disk information for better readability
$diskUsage = $disk.Used / 1GB
$diskFree = $disk.Free / 1GB

Print("Used: " + [math]::Round($diskUsage,2) + "GB")
Print("Free: " + [math]::Round($diskFree,2) + "GB")

# Make sure we have enough free space left
if ($diskFree -le $configXml.config.limit) {
    SendMail
}

