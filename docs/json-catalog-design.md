# JSON app catalog

Status: Approved for implementation.

## Requested change

Move the editable application catalog from PowerShell into a JSON file read by the installer.

## Current coupling

- Installer.psm1 defines names, WinGet IDs, default selections, and pinned versions.
- Console.psm1 assigns descriptions by array position.
- Destination.psm1 hardcodes Discord and PowerToys as default-location exceptions.
- Installer.psm1 ties the x64 argument to the presence of a pinned version.

## Confirmed catalog decisions

- Bundle a local apps.json with a format version and ordered apps array.
- Include name, id, description, selectedByDefault, optional version and architecture, and explicit custom-location support on each app.
- Validate the entire catalog before selection or installation; report actionable errors and stop on invalid input.
- Keep this catalog separate from transient user selections; do not save user selections.
- Keep the existing WinGet source and safe installation behavior fixed in code. Do not accept arbitrary commands, URLs, or installer arguments through JSON.

The user approved all four catalog proposals. apps.json sits beside install.cmd and is included in the ZIP; array order controls display order. Invalid names, duplicate IDs, missing files, malformed JSON, and incorrect field types stop execution with actionable errors. Optional notes explain package-specific choices. Changes load on the next run.

## Dry-run request

The user approved the following dry-run behavior:

- The review screen offers Dry run as the initially highlighted action.
- Dry run validates the catalog, queries WinGet for every selected package including pinned version and architecture when provided, detects existing installations, and displays planned destinations and commands.
- Failed checks block installation and identify the affected app and reason. A successful dry run offers Install, Change selection, or Exit. Changing selection or destination invalidates earlier verification.
- If WinGet is missing or unusable, report Prerequisite missing and offer an explicit Prepare WinGet and retry action. Do not silently bootstrap WinGet during dry run.
- Dry run creates no app folders or write-test files. It checks disk availability and existing paths and saves a timestamped diagnostic log. Actual destination write checks occur before installation.
- Dry run runs no app installers. WinGet queries may update their own source cache or diagnostic files; this is not an offline or zero-write mode.
- A dry run cannot prove vendor installers honor custom locations or complete successfully. Actual installs retain existing skip, retry, and logging behavior.
