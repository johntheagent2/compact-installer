# Disk selection and terminal presentation

Status: Approved for implementation.

## Requested changes

- Let the user choose which disk applications are installed on.
- Improve the terminal presentation while retaining a terminal interface.

Existing installation-only scope, defaults, skip/retry behavior, and logging remain the starting point.

## Confirmed decisions

- Choose one destination disk per run for all selected apps that support a custom location.
- Use a guided terminal flow: choose disk, select apps, review, install, results.
- Use cyan highlights, clear spacing, short app descriptions, and green/yellow/red result statuses; adapt the layout to terminal width and retain keyboard controls.
- During installation, show compact per-app statuses and an overall count such as `Installing 2 of 5`. Save detailed command output in the log and show failure details on the final results screen.
- Choosing C: uses each app's default installation directory rather than C:\Apps. Do not pass a custom location for this choice.
- If a chosen destination is unavailable or cannot accept the destination folder, explain the issue and return to disk selection rather than silently switching disks.
- Existing applications remain skipped even when another disk is selected; do not relocate them.

- Offer local fixed disks with drive letters, including external disks classified by Windows as fixed. Exclude removable USB sticks and network drives.
- Show each disk's letter, label, and available space. Initially highlight C:.
- On disks other than C:, use <disk>:\Apps\<app name> for supported apps.
- Discord and PowerToys use their app default locations and are clearly labeled accordingly.
- Show every selected app's planned destination on the review screen before confirmation.

## Completion boundary

No open product decisions remain. Destination selection applies to new installations only. App settings, data, caches, dependencies, and Steam game libraries are outside the destination guarantee. Routine implementation choices must preserve these rules and the existing installation-only scope.

## Package research

Official WinGet manifests and client source reviewed on 2026-11-15 indicate custom-location support for Steam, Notepad++, UniKey, 7-Zip, Everything, and VLC. Discord has no custom-location switch; PowerToys support is unverified. Treat neither as guaranteed to honor a chosen disk. Actual installer behavior still requires validation.

- [WinGet location option](https://learn.microsoft.com/en-us/windows/package-manager/winget/install): conditional on installer support.
- [Default installer switches](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).
- [Portable installation flow](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/PortableFlow.cpp): location is the exact per-app target directory.

App data, caches, dependencies, and game libraries may use other locations. Existing installations remain skipped rather than moved.
