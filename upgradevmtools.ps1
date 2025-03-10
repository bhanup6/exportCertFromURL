# Import PowerCLI Module
Import-Module VMware.VimAutomation.Core

# Variables
$VCServer = "YourVCenterFQDN" # Replace with your vCenter FQDN or IP
$VMListFile = "C:\Path\To\VMNames.txt" # Path to the text file containing VM names
$LogFile = "C:\Path\To\VMwareToolsUpdate.log"
$EmailRecipient = "admin@example.com" # Replace with the recipient's email address
$EmailSender = "no-reply@example.com" # Replace with the sender's email address
$SMTPServer = "smtp.example.com" # Replace with your SMTP server address
$ErrorActionPreference = 'Stop'

# Initialize Log File
Add-Content -Path $LogFile -Value "VMware Tools Update Script - $(Get-Date)"
Add-Content -Path $LogFile -Value "----------------------------------------"

# Function: Send Email Notification
function Send-EmailReport {
    param (
        [string]$Subject,
        [string]$Body,
        [string]$Attachment
    )
    try {
        Send-MailMessage -From $EmailSender -To $EmailRecipient -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Attachments $Attachment -ErrorAction Stop
        Write-Host "Email notification sent successfully."
    } catch {
        Write-Host "Failed to send email notification: $_"
    }
}

# Validate vCenter Connectivity
try {
    Write-Host "Connecting to vCenter server: $VCServer..."
    Connect-VIServer -Server $VCServer -ErrorAction Stop
    Write-Host "Successfully connected to vCenter server."
    Add-Content -Path $LogFile -Value "Connected to vCenter server: $VCServer"
} catch {
    Write-Host "Error: Unable to connect to vCenter server: $_"
    Add-Content -Path $LogFile -Value "Error: Unable to connect to vCenter server ($_)."
    Send-EmailReport -Subject "VMware Tools Update Script Failed" `
                     -Body "The script failed to connect to the vCenter server ($VCServer). Please check the connectivity or credentials." `
                     -Attachment $LogFile
    Exit
}

# Validate VM List File
if (-Not (Test-Path $VMListFile)) {
    Write-Host "Error: VM list file not found at $VMListFile."
    Add-Content -Path $LogFile -Value "Error: VM list file not found at $VMListFile."
    Send-EmailReport -Subject "VMware Tools Update Script Failed" `
                     -Body "The script failed because the VM list file was not found at the specified path ($VMListFile)." `
                     -Attachment $LogFile
    Disconnect-VIServer -Confirm:$false
    Exit
}

# Read VM Names from File
$VMNames = Get-Content $VMListFile

# Process Each VM in the List
foreach ($VMName in $VMNames) {
    try {
        # Check if the VM exists in vCenter inventory
        Write-Host "Processing VM: $VMName..."
        $VM = Get-VM -Name $VMName -ErrorAction Stop

        # Check if the VM is powered on
        if ($VM.PowerState -ne "PoweredOn") {
            Add-Content -Path $LogFile -Value "$VMName: Skipped (VM is not powered on)."
            continue
        }

        # Check VMware Tools status and OS compatibility
        $GuestInfo = Get-VMGuest -VM $VM -ErrorAction SilentlyContinue
        if (-Not $GuestInfo) {
            Add-Content -Path $LogFile -Value "$VMName: Skipped (VMware Tools not installed or inaccessible)."
            continue
        }

        # Start VMware Tools Update Task without rebooting
        Write-Host "Starting VMware Tools update for VM: $VMName..."
        $Task = Update-Tools -VM $VM -NoReboot

        # Monitor Task Progress
        Write-Host "Monitoring task for VM: $VMName..."
        while ($Task.State -eq 'Running' -or $Task.State -eq 'Queued') {
            Start-Sleep 5  # Wait for 5 seconds before checking again
            $Task = Get-Task | Where-Object {$_.Id -eq $Task.Id}
            Write-Host "$VMName: Task State is '$($Task.State)'."
        }

        # Log Task Completion Status
        if ($Task.State -eq 'Success') {
            Add-Content -Path $LogFile -Value "$VMName: Successfully updated VMware Tools."
            Write-Host "$VMName: VMware Tools update completed successfully."
        } elseif ($Task.State -eq 'Error') {
            Add-Content -Path $LogFile -Value "$VMName: Failed to update VMware Tools. Error details: $(Get-VIEvent | Where {$_.Task.Id -eq $Task.Id})."
            Write-Host "$VMName: VMware Tools update failed. Check logs for details."
        } else {
            Add-Content -Path $LogFile -Value "$VMName: Unexpected task state '$($Task.State)'."
            Write-Host "$VMName: Unexpected task state '$($Task.State)'."
        }

    } catch {
        # Log any errors encountered during processing of this VM
        Add-Content -Path $LogFile -Value "$VMName: Failed to update VMware Tools ($_)."
    }
}

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false

# Email Notification with Summary Report
try {
    # Prepare Email Body Content
    $SuccessCount = Select-String "$LogFile" 'Successfully updated' | Measure-Object | Select-Object -ExpandProperty Count
    $SkippedCount = Select-String "$LogFile" 'Skipped' | Measure-Object | Select-Object -ExpandProperty Count
    $FailedCount = Select-String "$LogFile" 'Failed' | Measure-Object | Select-Object -ExpandProperty Count

    $EmailBody = @"
Hello,

The VMware Tools update script has completed execution. Below is the summary:

Total VMs Processed: $(($SuccessCount + $SkippedCount + $FailedCount))
Successfully Updated: $SuccessCount
Skipped VMs:          $SkippedCount
Failed Updates:       $FailedCount

Please find the detailed log attached for your reference.

Best regards,
Your Automation Script.
"@

    # Send Email with Log Attachment and Summary Report
    Send-EmailReport `
        -Subject "VMware Tools Update Script Execution Summary" `
        -Body $EmailBody `
        -Attachment $LogFile

} catch {
    Write-Host "Error while sending email notification: $_"
}

Write-Host "Script execution completed. Check the log file at '$LogFile' for details."
