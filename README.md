<img src="design/tabbit-icon.png" width="96" alt="Tabbit app icon">

# Tabbit

A lightweight, tabbed viewer and editor for Markdown and HTML files on macOS.

- Opens `.md`, `.markdown`, `.html` and `.htm` files: double-click or **Open With** in Finder,
  **File > Open**, or drag onto the Dock icon. Every file opens as a new tab in the front window.
- **View** mode renders the file:
  - Markdown uses GitHub-flavored rendering and styling: tables, task lists, strikethrough,
    autolinks, highlighted code blocks, footnotes and alerts.
  - HTML renders as a browser would, scripts included.
  - Relative images, CSS and scripts load from the file's folder.
- **Edit** mode is a source editor with syntax highlighting, line numbers and inline lint warnings.
  Hover a marker to see the message. Markdown is checked by
  [markdownlint](https://github.com/DavidAnson/markdownlint), with the line-length rule MD013 off;
  HTML is checked by [HTMLHint](https://htmlhint.com).
- Switching from Edit to View shows your current edits, even unsaved ones.
- Follows light/dark mode and works offline (all web code is bundled).

Built for personal use; it is not signed with a developer certificate and not on the App Store.

## Install on a new Mac

Requirements: macOS 26 (Tahoe) or later, and Xcode from the App Store. Open Xcode once after
installing it so it can finish setting up.

```sh
git clone https://github.com/byronf-sama/tabbit-viewer.git
cd tabbit-viewer
scripts/install.sh
```

The script builds a Release version (for both Apple silicon and Intel) and copies `Tabbit.app`
into `/Applications`. It asks for an admin password only if `/Applications` isn't writable for
your account. To install somewhere else, set `TABBIT_INSTALL_DIR`, for example
`TABBIT_INSTALL_DIR=~/Applications scripts/install.sh`.

Because the app is built locally, macOS doesn't quarantine it and Gatekeeper won't block it.

### First run

- The first time Tabbit reads files in a protected folder (Documents, Desktop, Downloads, iCloud
  Drive), macOS asks for permission. Click **Allow**; it's asked once per folder and remembered
  across updates.
- To make Tabbit the default app for Markdown: in Finder, select a `.md` file, choose
  **File > Get Info**, pick Tabbit under **Open with**, and click **Change All…**. Tabbit appears
  in **Open With** for HTML files but doesn't take over `.html` from your browser.

### Update

```sh
cd tabbit-viewer
git pull
scripts/install.sh
```

Quit Tabbit before running the script.

## Using Tabbit

| Action | Shortcut |
| --- | --- |
| Open a file | ⌘O (also File > Open Recent) |
| Switch between View and Edit | ⌘E, or the View/Edit control in the toolbar |
| Save | ⌘S |
| Close tab | ⌘W |
| Next / previous tab | ⌃⇥ / ⌃⇧⇥ |
| Find in the editor | ⌘F |

- Tabs with unsaved changes show a dot. Closing one, or quitting, asks whether to save.
- In View mode, web links open in your default browser. Links to local Markdown or HTML files open
  in a new tab (or switch to the tab if the file is already open). Other local files open in their
  default app.
- Images, CSS and scripts load from the document's folder and its subfolders, but not from a
  parent folder (`../`). Links to files anywhere still work.

## Development

See [CLAUDE.md](CLAUDE.md) for the project layout and build commands. In short:

- `xcodegen generate` regenerates `Tabbit.xcodeproj` from `project.yml` (both are committed, so
  a fresh clone builds with only Xcode).
- `cd web && npm install && npm run build` rebuilds the bundled web code in
  `Tabbit/Resources/web/` (also committed; Node is only needed when changing `web/`).
- `samples/` has made-up files for trying out rendering, links and linting.
- The app icon is `Tabbit/AppIcon.icon` (edit it in Icon Composer, which comes with Xcode); the
  original artwork is `design/tabbit-logo.png`.

## License

[MIT](LICENSE)
