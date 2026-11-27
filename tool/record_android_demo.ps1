[CmdletBinding()]
param(
    [ValidateSet('Device', 'Rules')]
    [string]$Mode = 'Device',
    [string]$AdbPath,
    [string]$Serial,
    [ValidateRange(0, 180)]
    [int]$VideoSeconds = 30,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $OutputDirectory) {
    $runId = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $OutputDirectory = Join-Path $repoRoot "build\demo-evidence\$runId"
}
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)

if ($Mode -eq 'Rules') {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Push-Location $repoRoot
    try {
        $log = Join-Path $OutputDirectory 'firestore-rules.txt'
        'Scope: local Firestore emulator. This run does not exercise the Android UI or the shared deployment.' | Set-Content $log
        cmd.exe /d /c 'npm.cmd test --prefix tool/firestore_tests 2>&1' |
            Tee-Object -FilePath $log -Append
        $testExit = $LASTEXITCODE
        Write-Host "Test output: $log"
        exit $testExit
    } finally {
        Pop-Location
    }
}

if (-not $AdbPath) {
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $AdbPath = $adbCommand.Source
    } else {
        $sdkRoot = $env:ANDROID_HOME
        if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
        if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
        $AdbPath = Join-Path $sdkRoot 'platform-tools\adb.exe'
    }
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'ADB is unavailable. Pass -AdbPath with the path to platform-tools\adb.exe.'
}

$devices = & $AdbPath devices
if ($LASTEXITCODE -ne 0) { throw 'ADB could not list connected devices.' }
$ready = @($devices | ForEach-Object {
    if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] }
})
if (!$Serial -and $ready.Count -eq 1) { $Serial = $ready[0] }
if (!$Serial -or $Serial -notin $ready) {
    throw 'Connect and unlock the phone, enable USB debugging, and accept its prompt. If multiple devices are connected, pass -Serial.'
}

function Invoke-PhoneAdb {
    param([string[]]$Arguments)
    & $AdbPath -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB command failed: $($Arguments[0])." }
}

$packageId = 'cr.ac.ucr.campusfix'
$installed = Invoke-PhoneAdb -Arguments @('shell', 'pm', 'path', $packageId)
if (-not ($installed -match '^package:')) { throw 'Install the CampusFix release APK on this phone first.' }
$model = (Invoke-PhoneAdb -Arguments @('shell', 'getprop', 'ro.product.model') | Out-String).Trim()
$android = (Invoke-PhoneAdb -Arguments @('shell', 'getprop', 'ro.build.version.release') | Out-String).Trim()
$versionLines = Invoke-PhoneAdb -Arguments @('shell', 'dumpsys', 'package', $packageId)
$versionMatch = $versionLines | Select-String '^\s+versionName=(.+)$' | Select-Object -First 1
if (-not $versionMatch) { throw 'The installed CampusFix version could not be read.' }
$version = $versionMatch.Matches[0].Groups[1].Value.Trim()
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$log = Join-Path $OutputDirectory 'device-demo.csv'
$title = 'TEST - CampusFix Android {0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
$steps = @(
    @{ Id = '01-reported'; Action = "Sign in as reporter, create a fictional incident titled '$title', then show its detail with the incident number." },
    @{ Id = '02-assigned'; Action = 'Sign in as administrator, classify that incident and assign an active test technician. Show the assigned state in its detail.' },
    @{ Id = '03-resolved'; Action = 'Sign in as the assigned technician, start work, add text progress and resolve the same incident. Show its final state in the detail.' },
    @{ Id = '04-web'; Action = 'Open https://campus-fix-ucr.web.app/ in the phone browser as an authorized user. Find the same incident and show its number and resolution.' }
)

function Save-PhoneCapture {
    param([string]$StepId, [string]$Extension, [string[]]$Command)
    $filename = "$StepId.$Extension"
    $destination = Join-Path $OutputDirectory $filename
    if (Test-Path -LiteralPath $destination) { throw "Evidence file already exists: $destination" }
    $remotePath = '/sdcard/campusfix-demo-' + [guid]::NewGuid().ToString('N') + ".$Extension"
    try {
        Invoke-PhoneAdb -Arguments (@('shell') + $Command + @($remotePath)) | Out-Null
        Invoke-PhoneAdb -Arguments @('pull', $remotePath, $destination) | Out-Null
        if ((Get-Item -LiteralPath $destination).Length -eq 0) { throw "Empty capture: $destination" }
    } finally {
        & $AdbPath -s $Serial shell rm -f $remotePath | Out-Null
    }
    return $filename
}

Write-Host "Device: $model | Android $android | CampusFix $version"
Write-Host "Evidence folder: $OutputDirectory"
Write-Host 'Use your existing test accounts. The recorder never enters credentials or changes incidents.'
Write-Host 'Sign in before each clip. Keep passwords, messages and unrelated reports outside the recording.'

foreach ($step in $steps) {
    Write-Host "`n$($step.Action)"
    $video = ''
    $screenshot = ''
    if ($VideoSeconds -gt 0) {
        $start = Read-Host "Press Enter to record for $VideoSeconds seconds, or type N to skip video"
        if ($start -eq '') {
            $video = Save-PhoneCapture -StepId $step.Id -Extension 'mp4' -Command @(
                'screenrecord', '--time-limit', "$VideoSeconds", '--size', '720x1560'
            )
        }
    }
    $outcome = Read-Host 'Show the result, then type what actually happened. Leave blank to skip the screenshot'
    if (-not [string]::IsNullOrWhiteSpace($outcome)) {
        $screenshot = Save-PhoneCapture -StepId $step.Id -Extension 'png' -Command @('screencap', '-p')
    }
    [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        device = $model
        android = $android
        appVersion = $version
        testTitle = $title
        step = $step.Id
        observed = $outcome
        screenshot = $screenshot
        video = $video
    } | Export-Csv -LiteralPath $log -Append -NoTypeInformation -Encoding UTF8
}

Write-Host "`nEvidence saved to $OutputDirectory"
