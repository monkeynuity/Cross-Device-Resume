:: file: CDR.bat
@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "PAYLOAD=%TEMP%\cdr_%~n0_%RANDOM%%RANDOM%.ps1"
set "NOEXIT="
if "%~1"=="" set "NOEXIT=-NoExit"

for /f "tokens=1 delims=:" %%A in ('findstr /n "^::#PAYLOAD$" "%SELF%"') do set "SKIP=%%A"
if not defined SKIP (
  echo [CDR] Marker ::#PAYLOAD not found in %SELF%
  pause
  exit /b 2
)
set /a SKIP+=1
more +%SKIP% "%SELF%" > "%PAYLOAD%" || (echo [CDR] Failed to extract payload.& pause & exit /b 3)

where pwsh >nul 2>&1 && set "PS=pwsh" || set "PS=powershell"
echo [CDR] Launching %PS% %NOEXIT% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PAYLOAD%" -FromBat %*
"%PS%" %NOEXIT% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PAYLOAD%" -FromBat %*
set "EC=%ERRORLEVEL%"
if exist "%PAYLOAD%" del "%PAYLOAD%" >nul 2>&1
exit /b %EC%

::#PAYLOAD
# embedded PowerShell payload (brace-safe)
[CmdletBinding()]
param(
  [switch]$Status,
  [switch]$Enable,
  [switch]$Disable,
  [switch]$PolicyEnable,   # admin
  [switch]$PolicyDisable,  # admin
  [Parameter(DontShow=$true)][switch]$FromBat
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# transcript for diagnostics
$log = Join-Path $env:TEMP ("cdr_" + [IO.Path]::GetFileNameWithoutExtension($PSCommandPath) + ".log")
$TranscriptStarted = $false
try {
  Start-Transcript -Path $log -Append -ErrorAction Stop | Out-Null
  $TranscriptStarted = $true
} catch {}

# registry constants
$KeyUser   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
$NameUser  = 'IsResumeAllowed'     # 1 allow, 0 block
$KeyPolDEF = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume'
$NamePol   = 'value'               # 0 allow, 1 disable

function Test-Elevation {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-Dword($key,$name,$default) {
  try { (Get-ItemProperty -Path $key -Name $name -ErrorAction Stop).$name }
  catch { $default }
}

function Write-Dword($key,$name,[int]$value) {
  if (-not (Test-Path $key)) { [void](New-Item -Path $key -Force) }
  New-ItemProperty -Path $key -Name $name -Value $value -PropertyType DWord -Force | Out-Null
}

function Get-ResumeState {
  $user = Read-Dword $KeyUser $NameUser 1
  $pol  = Read-Dword $KeyPolDEF $NamePol 0
  [pscustomobject]@{
    UserAllowed      = [bool]$user
    PolicyDisabled   = [bool]$pol
    EffectiveEnabled = ($user -eq 1 -and $pol -eq 0)
  }
}

function Show-Status {
  $s = Get-ResumeState
  $rows = @(
    @{K='User (HKCU)'; V= if($s.UserAllowed){'On'} else {'Off'}},
    @{K='Policy (HKLM)'; V= if($s.PolicyDisabled){'Disabled (enforced)'} else {'Allowed'}},
    @{K='Effective';     V= if($s.EffectiveEnabled){'Enabled'} else {'Disabled'}}
  )
  $w = ($rows.K | Measure-Object -Maximum -Property Length).Maximum
  foreach ($r in $rows) {
    '{0} : {1}' -f $r.K.PadRight($w), $r.V | Write-Host
  }
  return 0
}

function Do-Enable  { Write-Dword $KeyUser $NameUser 1; return 0 }
function Do-Disable { Write-Dword $KeyUser $NameUser 0; return 0 }

function Do-Policy([int]$v) {
  if (-not (Test-Elevation)) { throw 'Administrator rights are required for policy changes.' }
  Write-Dword $KeyPolDEF $NamePol $v
  return 0
}

function Refresh-UI {
  param([string]$Applied,[switch]$ShowMenu)
  Clear-Host
  if ($Applied) { Write-Host $Applied -ForegroundColor Green }
  [void](Show-Status)
  if ($ShowMenu) {
    Write-Host ''
    Write-Host '[E]nable  [D]isable  [S]tatus  [P]olicy On  [X] Policy Off  [Q]uit' -ForegroundColor Gray
  }
}

function Pause-IfNeeded {
  param([bool]$hadError,[bool]$interactive)
  if ($FromBat -and ($hadError -or $interactive)) {
    [void](Read-Host 'Press Enter to close')
  }
}

function End-Program {
  param([int]$ExitCode,[bool]$HadError,[bool]$Interactive)
  if ($TranscriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
  Pause-IfNeeded -hadError:$HadError -interactive:$Interactive
  exit $ExitCode
}

# ------------------ main ------------------
$interactive = $false
$hadError = $false
$code = 0

try {
  if ($PolicyEnable) {
    $code = Do-Policy 0
    Refresh-UI -Applied 'Applied: Policy set to ALLOW (HKLM value=0).'
  } elseif ($PolicyDisable) {
    $code = Do-Policy 1
    Refresh-UI -Applied 'Applied: Policy set to DISABLE (HKLM value=1).'
  } elseif ($Enable) {
    $code = Do-Enable
    Refresh-UI -Applied 'Applied: Enabled for current user (HKCU value=1).'
  } elseif ($Disable) {
    $code = Do-Disable
    Refresh-UI -Applied 'Applied: Disabled for current user (HKCU value=0).'
  } elseif ($Status) {
    $code = Show-Status
  } else {
    $interactive = $true
    Refresh-UI -ShowMenu
    while ($true) {
      $choice = Read-Host 'Choose'
      switch ($choice.ToUpperInvariant()) {
        'E' {
          $code = Do-Enable
          Refresh-UI -Applied 'Applied: Enabled for current user (HKCU value=1).' -ShowMenu
        }
        'D' {
          $code = Do-Disable
          Refresh-UI -Applied 'Applied: Disabled for current user (HKCU value=0).' -ShowMenu
        }
        'S' {
          [void](Refresh-UI -ShowMenu)
        }
        'P' {
          try {
            $code = Do-Policy 0
            Refresh-UI -Applied 'Applied: Policy set to ALLOW (HKLM value=0).' -ShowMenu
          } catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            $hadError = $true
          }
        }
        'X' {
          try {
            $code = Do-Policy 1
            Refresh-UI -Applied 'Applied: Policy set to DISABLE (HKLM value=1).' -ShowMenu
          } catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            $hadError = $true
          }
        }
        'Q' { exit }
        default { Write-Host 'Try E, D, S, P, X, or Q.' -ForegroundColor DarkGray }
      }
    }
  }
} catch {
  Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
  $hadError = $true
  $code = 1
}

End-Program -ExitCode $code -HadError:$hadError -Interactive:$interactive
