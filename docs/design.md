# Essential App Installer Design

Status: Scope approved for implementation.

## Confirmed scope

- Personal use on Windows 11 x64 (Intel/AMD).
- Working internet is required; applications are downloaded when the installer runs.
- The user can select and deselect applications before installation.
- Selected by default: Steam, Discord, Notepad++, UniKey, and 7-Zip.
- Available but unchecked by default: Everything, VLC, and PowerToys.
- The first version installs applications. Account sign-ins, settings restoration, and Windows customization are outside its scope.
- Do not offer app configuration or startup registration, including for UniKey. Users handle their own post-install setup separately.

## Confirmed interaction and installation behavior

- Distribute a downloadable folder containing `install.cmd`, which opens a PowerShell CLI and uses WinGet to install applications.
- Use arrow keys to navigate, Space to toggle selections, and Enter to review choices before confirming installation.
- Include select-all and deselect-all shortcuts.
- Skip applications that are already installed; app updates are outside the first version's scope.
- Continue installing the remaining applications when an installation fails.
- Offer to retry failed installations at the end.
- Finish with an installed/skipped/failed summary. Explicitly list failed applications and their error details at the end, and retain a troubleshooting log.
- Do not save selections between runs. Start each run with the agreed default selection.
- Check WinGet availability before installing applications. If it is missing, attempt to set it up automatically, allowing Windows permission prompts when required. If setup fails, explain the failure and stop.
- Save a timestamped log for each run in a `logs` folder beside the launcher. Show the log location in the final terminal summary alongside failed applications and their error details.

## Scope boundary

No open product decisions remain from the design interview. Routine implementation details will follow this scope. The installer does not configure installed apps, restore settings, register startup entries, or update apps that are already installed.
