# AppPruner 
<img width="150" height="150" alt="AppPruner" src="https://github.com/user-attachments/assets/917d2b6b-5a76-4e63-8fdb-44564e1dfba1" />


Command‑line tool for managing macOS app uninstallations.

- Discover and remove app files (supports match modes)
- Run dry‑runs safely
- Generate uninstall definition manifests
- List and sync definition catalog
- Generate file removal reports

## NOTE

This is a work in progress, current status is `alpha`.

## Installation

Download and install the latest PKG under releases.

## Quick start

AppPruner should be run as sudo.

- Show help (top‑level):
```bash
AppPruner --help
```

- Uninstall by definition name:
```bash
AppPruner uninstall --definition-name "companyportal"
```

- Uninstall by manifest file path:
```bash
AppPruner uninstall --definition-path /path/to/definition.json
```

- Dry run, substring matching, silent:
```bash
AppPruner uninstall --definition-name "companyportal" --match-mode substring --dry-run --silent
```

- List available definitions:
```bash
AppPruner list-app-definitions
```

- Search available definitions:
```bash
AppPruner search-app-definitions --name "ms"
```

- Sync local catalog with remote:
```bash
AppPruner sync-definitions
```

- Generate a new definition manifest:
```bash
AppPruner generate-app-definition \
  --definition-name "companyportal" \
  --app-name "Company Portal" \
  --bundle-id "com.microsoft.CompanyPortalMac" \
  --alternative-names "Company,MS Company Portal" \
  --additional-paths "/Library/Application Support/Microsoft/Intune,~/Library/Preferences/com.microsoft.CompanyPortalMac.plist" \
  --match-mode "substring" \
  --forget-pkg \
  --unload-launch-daemons \
  --output-path ./defs
```

- Generate a report of what would be uninstalled:
```bash
AppPruner generate-file-report --definition-name "companyportal" --output-path ./
```

## CLI reference

AppPruner uses subcommands. The default subcommand is uninstall. If you run AppPruner with no required arguments, it prints help by default.

- uninstall
  - --definition-name <string> (optional if --definition-path is set)
  - --definition-path <path> (optional if --definition-name is set)
  - --match-mode <exact|prefix|substring|all> (default: all)
  - --dry-run
  - --remove-user-hive
  - --version <string>           (select a specific definition/app version if supported)
  - --silent
  - --wait-time <minutes>        (default: 5)
  - --brew-tidy                  (run `brew cleanup` post uninstall if applicable)

- list-app-definitions
  - Lists all available definitions in the local catalog.

- generate-app-definition
  - --name <string>              (definition identifier to create)
  - --app-name <string>
  - --version <string>           (definition version; default: 1)
  - --alternative-names <a,b,c>
  - --bundle-id <string>
  - --search-file-paths <a,b,c>  (override default search paths)
  - --additional-paths <a,b,c>
  - --forget-pkg
  - --unload-launch-daemons
  - --output-path <path>         (default: current directory)
  - --brew-name <string>        (Homebrew name to look up for the app. If not set app name will be used.)

- sync-definitions
  - Syncs the local catalog with the remote source.

- generate-file-report
  - --definition-name <string> (optional if --definition-path is not set)
  - --definition-path <path> (optional if --definition-name is not set)
  - --version <string>           (select a specific definition version if multiple are available. default: latest)
  - --output-path <path>        (default: current directory)

Global options
- A shared GlobalOptions group is used; if available, use --debug for verbose logging.

## Definition manifests

Generated manifests describe how to locate and remove an app. A typical shape:

```json
{
  "name": "someapp",
  "version": 1,
  "updated_at": "2025-10-16T12:34:56Z",
  "uninstall": {
    "appName": "App",
    "bundleId": "com.vendor.App",
    "alternativeNames": ["Vendor App", "App by Vendor"],
    "searchFilePaths": ["/Applications", "~/Applications"],
    "additionalPaths": ["/Library/Application Support/Vendor/App"],
    "forgetPkg": true,
    "unloadLaunchDaemons": false
  }
}
```

## Behavior notes

- Default subcommand: uninstall
- No required args → prints help and exits successfully.
- Dry runs perform discovery and logging without deleting files.
- Match modes control file discovery breadth: exact, prefix, substring, all.


## License

Apache 2.0

