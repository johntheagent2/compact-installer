# Compact Installer

Reinstall your essential apps after a fresh Windows installation. Select the apps, confirm, and let WinGet install them.

## Supported out of the box

- **Windows 11 x64:** Intel/AMD PCs with internet access, using the included Windows PowerShell 5.1.
- **Keyboard-driven terminal:** disk selection, app checkboxes, descriptions, destination review, colored statuses, and installation counts.
- **Destination selection:** C: uses app default directories; other local fixed disks use `Apps\<app name>` for apps marked as supporting custom locations. The picker shows disk labels and free space.
- **Dry run before installation:** checks package availability, pinned versions and architectures, installed apps, disk availability, and existing destination paths. Shows planned commands and blocks installation when checks fail.
- **WinGet preparation:** an explicit action can register or repair WinGet when it is missing or unusable.
- **Repeatable installation:** skips detected installed apps, continues after failures, and offers to retry only failed apps.
- **Diagnostics:** final failure details and a separate timestamped log for each run.
- **Editable catalog:** add, remove, reorder, or change app defaults in `apps.json` without editing PowerShell.

The current target excludes Windows 10, ARM PCs, offline installation, removable USB installation destinations, and network destinations. App configuration, startup registration, updates, moving existing apps, and restoring settings are outside the current scope. Automated checks use simulated installers; real vendor installation and fresh-Windows setup still need VM validation.

## Run

1. Extract the complete installer ZIP into a writable folder, such as Downloads or a USB drive. Keep `install.cmd`, `Install.ps1`, `apps.json`, and `src` together.
2. Double-click **install.cmd**.
3. Choose a local fixed disk (letter, label, and free space are shown). C: uses app default directories; other disks use `Apps\<app name>`. Discord and PowerToys always use their app defaults. Then use **Up/Down** to move, **Space** to toggle an app, **A** to select all, or **D** to deselect all.
4. Press **Enter** to review each planned destination, then **Enter** again to dry run. After verification passes, press **I** to install, **C** to change selection, or another key to exit. From the review screen, **Esc** returns to disk selection, where **Esc** cancels.
5. Approve Windows permission prompts when needed. Check the summary and optionally retry failed apps.

Requires Windows 11 on an Intel/AMD 64-bit PC and working internet. Uses the Windows PowerShell included with Windows; no Node.js or Python installation is needed. Launch normally in your own account; individual app installers request elevation when required.

## Workflow

```text
Launch install.cmd
  -> Validate apps.json
  -> Choose disk
  -> Select apps
  -> Review destinations
  -> Dry run (Enter)
       WinGet missing? -> P: Prepare WinGet and retry
       Check failed?  -> Show errors and return to selection
       Checks passed? -> I: Install / C: Change selection / Exit
  -> Check destination write access
  -> Install missing apps; skip detected installed apps
  -> Show results and log path
       Failures? -> Offer to retry only failed apps
```

Changing the selection or disk runs verification again. Dry run queries package metadata and existing installations; it never runs app installers. Installation starts only after a successful dry run and your **I** confirmation. If destination validation fails, the tool returns to disk selection. If one installation fails, it continues with the remaining apps.

## Included apps

| App | Purpose | Selected by default | Custom destination configured |
| --- | --- | --- | --- |
| Steam | Gaming | Yes | Yes |
| Discord | Chat | Yes | No — app default |
| Notepad++ | Text editor | Yes | Yes |
| UniKey | Vietnamese keyboard | Yes | Yes; pinned x64 build |
| 7-Zip | File archives | Yes | Yes |
| Everything | File and folder name search | No | Yes |
| VLC | Media player | No | Yes |
| PowerToys | Windows utilities | No | No — app default |

Custom destination support reflects the bundled catalog and installer metadata; actual vendor behavior can vary. Choosing a disk for Steam does not choose where its games are stored.

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

UniKey uses version **4.6.230919**, the official x64 build. Its newer **4.6.250531** build targets ARM64. Update its entry in `apps.json` if UniKey publishes a newer x64 version.

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

## Add another app

You can extend the bundled list by editing **apps.json**; no PowerShell changes are required. The app must be available in the WinGet community source used by this installer.

1. Find the app's exact package ID using WinGet:

   ```powershell
   winget search --name "Your app name" --source winget
   ```

2. Inspect the result before adding it. Replace `Publisher.Package` with the exact ID from the search:

   ```powershell
   winget show --id Publisher.Package --exact --source winget
   ```

3. Open `apps.json` beside `install.cmd` and add an object inside the existing `apps` array. This is a template: replace the example name and ID with the app you verified.

   ```json
   {
     "name": "Your App",
     "id": "Publisher.Package",
     "description": "Short description",
     "selectedByDefault": false,
     "supportsCustomLocation": false
   }
   ```

4. Put a comma between adjacent app objects. Keep `schemaVersion` set to `1`. JSON requires double quotes, lowercase `true`/`false`, no comments, and no trailing commas.
5. Save the file and restart `install.cmd`. The new app appears in the same position as its object in the array. Select it and run **Dry run** to check its package and planned installation before proceeding.

### Catalog fields

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | Yes | Display name and custom destination folder name; must be unique and valid as a Windows folder name. |
| `id` | Yes | Exact, unique WinGet package ID, not a download URL. |
| `description` | Yes | Short text displayed beside the app. |
| `selectedByDefault` | Yes | `true` checks the app on each new run; `false` makes it optional. |
| `supportsCustomLocation` | Yes | `true` allows `<disk>:\Apps\<name>` on non-C: disks; `false` leaves the location to the vendor installer. |
| `version` | No | Exact package version as a string. Omit or use `null` for WinGet's current compatible release. |
| `architecture` | No | `"x64"`, `"x86"`, or `"neutral"`. Omit or use `null` to let WinGet choose. |
| `notes` | No | Maintainer explanation, such as why a version is pinned; not an installer command or a terminal description. |

Start with `supportsCustomLocation: false` for a new app. Set it to `true` only after checking the package's installer metadata and verifying that its installer honors custom locations. Dry run checks package availability, but cannot establish this behavior. C: always uses app defaults regardless of this field.

To pin a release or architecture, add fields such as `"version": "1.2.3"` and `"architecture": "x64"` using values verified for that package. These fields are independent; pinning a version does not automatically force x64. The overall tool still targets Windows 11 Intel/AMD PCs.

Remove an app by deleting its object, or reorder objects to change display order. Edits affect future runs; removing an entry does not uninstall an app. If editing the source project for distribution, run `scripts\Build.ps1` afterward to include the updated catalog in the ZIP. Editing an already extracted copy takes effect on its next launch without rebuilding.
