param([string]$Type = "input")

# Read stdin JSON payload (hooks receive context as JSON on stdin)
$jsonInput = $null
$project = "Claude"
$sessionId = ""
$stdinMessage = ""

try {
    if ([Console]::In.Peek() -ge 0) {
        $raw = [Console]::In.ReadToEnd()
        if ($raw) {
            $jsonInput = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($jsonInput.cwd) {
                $project = ($jsonInput.cwd -split '[/\\]')[-1]
            }
            if ($jsonInput.session_id) {
                $sessionId = $jsonInput.session_id
            }
            if ($jsonInput.message) {
                $stdinMessage = $jsonInput.message
            }
        }
    }
} catch {
    # Manual run or no stdin - use defaults
}

# Resolve terminal number from session label file
$termNum = ""
if ($sessionId) {
    $sessDir = "$PSScriptRoot/sessions"
    if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir -Force | Out-Null }

    # Prune label files older than 12 hours so numbering resets daily
    $cutoff = (Get-Date).AddHours(-12)
    Get-ChildItem $sessDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force

    $labelFile = "$sessDir/$sessionId"
    if (Test-Path $labelFile) {
        $termNum = (Get-Content $labelFile -Raw).Trim()
    } else {
        # Next number = count of existing files + 1
        $count = @(Get-ChildItem $sessDir -File -ErrorAction SilentlyContinue).Count
        $next = $count + 1
        Set-Content -Path $labelFile -Value $next -NoNewline
        $termNum = "$next"
    }
}

# Sound - gentle for done, urgent for permission
if ($Type -eq "done") {
    [System.Media.SystemSounds]::Asterisk.Play()
} else {
    [System.Media.SystemSounds]::Exclamation.Play()
}

# Windows toast notification
[void][Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom.XmlDocument,ContentType=WindowsRuntime]

$dash = [char]0x2014  # em dash
$label = if ($termNum) { "$project #$termNum" } else { $project }

if ($Type -eq "done") {
    $title = "$label $dash klar"
    $body = "Svaret ar klart."
} else {
    $title = "$label $dash vantar"
    $body = if ($stdinMessage) { $stdinMessage } else { "Behover din input." }
}

$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$body</text></binding></visual><audio silent='true'/></toast>")
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe").Show([Windows.UI.Notifications.ToastNotification]::new($xml))
