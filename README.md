# Compact Installer

Reinstall your essential apps after a fresh Windows installation. Select the apps, confirm, and let WinGet install them.

## Run

1. Extract the complete installer ZIP into a writable folder, such as Downloads or a USB drive. Keep `install.cmd`, `Install.ps1`, and `src` together.
2. Double-click **install.cmd**.
3. Choose a local fixed disk (letter, label, and free space are shown). C: uses app default directories; other disks use `Apps\<app name>`. Discord and PowerToys always use their app defaults. Then use **Up/Down** to move, **Space** to toggle an app, **A** to select all, or **D** to deselect all.
4. Press **Enter** to review each planned destination, then **Enter** to dry run. After verification passes, press **I** to install, **C** to change selection, or another key to exit. Any other key returns to selection; **Esc** returns to disk selection, where **Esc** cancels.
5. Approve Windows permission prompts when needed. Check the summary and optionally retry failed apps.

Requires Windows 11 on an Intel/AMD 64-bit PC and working internet. Uses the Windows PowerShell included with Windows; no Node.js or Python installation is needed. Launch normally in your own account; individual app installers request elevation when required.

## Apps

| Selected by default | Optional, unchecked |
| --- | --- |
| Steam | Everything |
| Discord | VLC |
| Notepad++ | PowerToys |
| UniKey | |
| 7-Zip | |

Every run starts with these defaults. Selections are not saved. The tool does not configure apps, restore settings, sign into accounts, or set up startup entries.

Existing apps detected by WinGet are skipped, with `--no-upgrade` also used during installation. Apps that were manually extracted as portable files may not be detectable by WinGet. A failed detection query is treated as an error rather than a reason to reinstall an app.

Disk selection applies to new app installations, not moving existing apps, app data, caches, dependencies, or Steam game libraries. Removable USB sticks and network drives are excluded. If the chosen destination is unavailable or its parent cannot be written, the tool returns to disk selection. Custom paths depend on each vendor installer honoring WinGet's location option. The terminal displays compact installation counts and colored statuses; detailed command output remains in the log.

## Results and logs

The terminal lists installed, skipped, and failed apps. Failed app names, exit codes, and captured error output appear at the end. Retrying runs only the failed apps and updates the summary; earlier errors remain in the same log.

Each run writes a separate UTF-8 file in `logs` beside the launcher, for example `logs/install-20261115-210000-123-a1b2c3d4.log`. The summary shows its full path. Logs are retained until you delete them. Exit code `0` means completion without unresolved failures or cancellation before installation; `1` means unresolved failures or a fatal setup error. The launcher pauses so double-click users can read the results.

The tool does not request an automatic restart. When WinGet reports that a restart is needed to finish an installation, the summary says so.

## WinGet preparation

After you confirm the app selection, the installer checks for WinGet 1.9 or newer. If unavailable and you explicitly choose **P: Prepare WinGet and retry**, it attempts App Installer registration, then Microsoft's documented repair route using `Microsoft.WinGet.Client` from PowerShell Gallery in current-user scope. This can also install the NuGet package provider. Failed setup stops the run and gives a recovery message. The main installer stays in your account's context.

Confirming installation accepts the selected packages' license agreements and the WinGet source terms. Downloads come through the `winget` source; hash verification stays enabled. `install.cmd` applies PowerShell's execution-policy bypass only to its child process, without changing the machine's saved execution policy.

UniKey uses version **4.6.230919**, the official x64 build. Its newer **4.6.250531** build targets ARM64. Update the catalog in `src/Installer.psm1` if UniKey publishes a newer x64 version.

References: [WinGet installation and registration](https://learn.microsoft.com/en-us/windows/package-manager/winget/), [Microsoft's repair instructions](https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting), [WinGet install options](https://learn.microsoft.com/en-us/windows/package-manager/winget/install), [UniKey downloads](https://www.unikey.org/download.html).

## Development

Run tests from Windows PowerShell 5.1 using Pester 3.4 or 4.x:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Test.ps1
```

The runner checks PowerShell syntax and executes tests using a compiled fake WinGet process and mocked Windows prerequisite commands. It never installs the catalog apps. This checks command arguments, exit-code handling, skipping, continuation, retries, failure summaries, logs, and bootstrap failures. Live app installs and fresh-Windows bootstrap still need validation in a disposable Windows 11 VM.

Build a portable distribution:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Build.ps1
```

Output: `dist/compact-installer.zip`. No logs, tests, Git files, or saved selections are included.

## JSON catalog and dry run
Edit apps.json beside install.cmd. schemaVersion is 1; apps is an ordered nonempty array. Required fields: name (a valid Windows folder name), id (WinGet package ID), description, selectedByDefault (boolean), supportsCustomLocation (boolean). Optional version, architecture (x64/x86/neutral), and notes may be omitted or null. Omit version for the current compatible release. Duplicate IDs/names and invalid fields stop execution. Changes load on the next run; selections are never saved.
Dry run checks package versions/architectures, installed apps, disk availability, and existing paths; logs planned commands; and blocks installation if verification fails. It creates no app folders or write-test files. It writes a diagnostic log, and WinGet queries may update source caches and their own logs. Destination write checks happen before installation. Real vendor behavior still requires actual install validation.
