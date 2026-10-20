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

### Or copy it from a Mac that has it

This needs no Xcode on the other Mac, which still needs macOS 26 or later (Apple silicon or
Intel).

1. On the Mac with Tabbit installed, zip the app. `ditto` keeps the app bundle and its
   signature intact:

   ```sh
   ditto -c -k --keepParent /Applications/Tabbit.app ~/Desktop/Tabbit.zip
   ```

2. Move `Tabbit.zip` to the other Mac any way you like (AirDrop, cloud storage, a USB drive),
   unzip it, and drag `Tabbit.app` into `/Applications`.
3. Remove the quarantine mark. macOS marks apps that arrive by AirDrop, download or a message
   as quarantined, and Gatekeeper then blocks Tabbit ("Apple could not verify…") because it has
   no developer certificate:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Tabbit.app
   ```

   Or skip Terminal: try to open Tabbit, then click **Open Anyway** in **System Settings >
   Privacy & Security**.
4. Open Tabbit once so Finder lists it under **Open With**.

On a company-managed Mac, security software may block apps without a developer certificate
however you install them. If Tabbit still won't open after step 3, that's the likely cause.

### First run

- The first time Tabbit reads files in a protected folder (Documents, Desktop, Downloads, iCloud
  Drive), macOS asks for permission. Click **Allow**; it's asked once per folder and remembered
  across updates.
- **Reveal in Finder** works with Finder's tabs (see [Using Tabbit](#using-tabbit)). For that,
  the first time you use it macOS asks two things:
  - "Tabbit wants to control Finder": click **Allow**.
  - "Tabbit would like to control this computer using accessibility features": click **Open
    System Settings** and turn on Tabbit. Apps can't ask Finder for a tab, so Tabbit presses
    Finder's **File > New Tab**.

  Until both are allowed, Reveal in Finder may open a new Finder window instead of a tab. Both
  settings live under
  **System Settings > Privacy & Security** (Automation and Accessibility) and survive updates.
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

On a Mac where you copied Tabbit instead, quit Tabbit there and repeat the copy steps with the
updated app. Permissions you've already granted carry over.

## Using Tabbit

| Action | Shortcut |
| --- | --- |
| Open a file | ⌘O (also File > Open Recent) |
| Switch between View and Edit | ⌘E, or the View/Edit control in the toolbar |
| Save | ⌘S |
| Refresh the current file from disk | ⌘R (also File > Refresh) |
| Close tab | ⌘W |
| Next / previous tab | ⌃⇥ / ⌃⇧⇥ |
| Find in the editor | ⌘F |
| Reveal the file in Finder | ⌥⌘R, or right-click the tab > Reveal in Finder |
| Show/hide each tab's file path | ⌥⌘P (View > Show File Path) |

- Reveal in Finder selects the file in Finder and scrolls to it. If a Finder tab already shows
  the file's folder, it switches to that tab. Otherwise it opens the folder in a new tab of the
  front Finder window, or in a new window if no Finder window is open.
- Tabs with unsaved changes show a dot. Closing one, or quitting, asks whether to save.
- Refresh reloads the current file in both View and Edit mode. If the tab has unsaved edits,
  it asks before discarding them.
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
