# Cross Device Resume Toggler (CDR)

<p align="center">
  <img alt="Windows 11" src="https://img.shields.io/badge/Windows-11-blue" />
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE" />
  <img alt="Single file" src="https://img.shields.io/badge/Single--file-BAT%2BPS-green" />
  <img alt="Admin" src="https://img.shields.io/badge/Admin-for%20policy-important" />
  <img alt="Install" src="https://img.shields.io/badge/Install-None-brightgreen" />
</p>

A tiny, single-file utility to **enable, disable, or check** Windows 11 *Cross Device Resume* (aka **Hand Off**). Works per-user via **HKCU**, and optionally for all users via **HKLM** policy (admin). Double‑click for a menu or script it with switches.

## ✨ Features

* **Enable/Disable/Status** for your account (HKCU)
* **Policy enforce/relax** for all users (HKLM, prompts for admin)
* **Effective state** readout that combines user pref + policy
* **One file**: hybrid BAT + PowerShell; no install, no leftovers
* **Conditional pause** only when double‑clicked
* **Predictable exit codes** (`0` ok, `1` error)

## 🧠 What “Effective” means

Windows applies both your **User** setting and any **Policy**. CDR shows the combined result so you don’t guess.

```
EffectiveEnabled = (UserAllowed == 1) AND (PolicyDisabled == 0)
```

| User (HKCU) | Policy (HKLM) | Effective |
| ----------- | ------------- | --------- |
| On (1)      | Allowed (0)   | Enabled   |
| On (1)      | Disabled (1)  | Disabled  |
| Off (0)     | Allowed (0)   | Disabled  |
| Off (0)     | Disabled (1)  | Disabled  |

## 🔑 Registry keys

* **User (no admin):**

  * `HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration\IsResumeAllowed` (DWORD) 1 = allow, 0 = block
* **Policy (admin, all users):**

  * `HKLM\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume\value` (DWORD) 0 = allow, 1 = disable

> Policy changes may require sign‑out or reboot to fully apply.

## 📚 About Cross Device Resume

* Lets you start an activity on your phone and **resume on Windows**.
* Designed for **Microsoft accounts** on consumer Windows; use the **same account** on phone and PC.
* OneDrive file flows: unlock your PC shortly after opening on phone to get a prompt for supported types (**Word/Excel/PowerPoint/OneNote/PDF**).
* New app‑to‑PC scenarios are being rolled out via Windows Insider builds (e.g., **Spotify**), surfaced with a **phone‑badged taskbar icon**. Support grows as apps adopt the **Cross Device Resume APIs**.
