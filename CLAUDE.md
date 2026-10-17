# Tabbit

Personal, never-distributed macOS app (macOS 26+): a tabbed viewer/editor for Markdown and HTML.
Swift + AppKit, NSDocument-based; rendering and editing happen in WKWebViews running bundled web
code. Bundle ID `io.github.byronf-sama.tabbit`. The repo is public: use only made-up sample files.

## Commands

All commands run from the repo root.

```sh
# Xcode project: generated from project.yml. Re-run after adding/removing/renaming files,
# and commit project.yml and Tabbit.xcodeproj together.
xcodegen generate

# Debug build (derived data outside the repo; see "Gotchas")
xcodebuild -project Tabbit.xcodeproj -scheme Tabbit -configuration Debug \
  -derivedDataPath ~/Library/Caches/tabbit-build build

# Run the Debug build, optionally with files
open ~/Library/Caches/tabbit-build/Build/Products/Debug/Tabbit.app
open -a ~/Library/Caches/tabbit-build/Build/Products/Debug/Tabbit.app samples/welcome.md

# Web bundle: only needed after changing web/. Commit the output in Tabbit/Resources/web/.
cd web && npm install && npm run build

# Release build + install to /Applications
scripts/install.sh
```

If `xcodebuild` says it requires Xcode but the developer directory is the Command Line Tools,
prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (install.sh
does this automatically) or run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

There are no automated tests. Verify changes by running the app against `samples/`.

## Layout

- `project.yml`: XcodeGen spec (deployment target, signing, build settings).
- `Tabbit/Info.plist`: document types (Markdown rank Default, HTML rank Alternate, role Editor).
- `Tabbit/AppIcon.icon`: app icon, an Icon Composer document (open it with Xcode > Open Developer
  Tool > Icon Composer). Orange solid fill + one rabbit layer (translucency off, so the body stays
  cream). The layer is `design/tabbit-logo.png` with the orange background keyed out.
  `design/tabbit-icon.png` (shown in the README) is rendered from it; after editing the icon run:
  `"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Tabbit/AppIcon.icon --export-image --output-file design/tabbit-icon.png --platform macOS --rendition Default --width 128 --height 128 --scale 2`
- `Tabbit/App/`: entry point, app delegate, main menu (built in code; no nib/storyboard).
- `Tabbit/Document/`: `TabbitDocument` (one NSDocument for both types; owns all file I/O),
  `TabbitDocumentController` (no untitled docs: New and the tab bar's + show the Open panel).
- `Tabbit/UI/`:
  - `DocumentWindowController`: window, native tabs, View/Edit toolbar, edited dot on tabs.
  - `DocumentViewController`: switches between the preview and editor web views.
  - `PreviewController`: View mode. `LocalFileSchemeHandler`: serves the Markdown page.
  - `EditorController`: Edit mode bridge.
  - `LinkRouter`: where links go. `PageUIDelegate`: alert/confirm/prompt/file input.
  - `TabbitWebView`: lets ⌃⇥ reach the menu.
- `web/src/markdown/`: viewer page (markdown-it, highlight.js, github-markdown-css).
- `web/src/editor/`: editor page (CodeMirror 6, markdownlint, HTMLHint).
- `web/build.mjs`: esbuild; inlines JS/CSS into `Tabbit/Resources/web/{markdown,editor}.html`.
- `samples/`: made-up test files (lint demos, relative assets, cross-links).

## How it works

- **Tabs:** windows use `tabbingMode = .preferred` and `TabbitDocument.showWindows` adds each new
  window to the frontmost Tabbit window's tab group, regardless of the system tab setting.
- **Markdown View:** `markdown.html` is served over the private `tabbit-file:` scheme at the
  document's own path (`tabbit-file:///path/to/file.md`). Relative URLs resolve against the file's
  folder and `#anchors` stay same-document. The handler serves files only from that folder.
  Swift calls `window.tabbit.render(text)`; the page stays loaded so the scroll position survives.
- **HTML View:** `loadFileURL(file, allowingReadAccessTo: folder)`. Unsaved edits use
  `loadSimulatedRequest` with the file URL, which only works after a `loadFileURL` has given
  the content process read access to the folder (tracked in `htmlFolderAccess`).
- **Links:** every main-frame navigation away from the document is cancelled and routed by
  `LinkRouter`: web links to the default browser, local .md/.html to a tab, other files to their app.
- **Edit:** `editor.html` exposes `window.tabbit.setDocument/getText/markSaved/focus` and posts
  `{type: "ready"}` / `{type: "dirty", dirty}` to the `tabbit` message handler. Swift owns the
  text: `TabbitDocument.save(to:…)` pulls the text from the editor before every save.
  `hasUndoManager` is false so WebKit's native undo steps can't touch the change count.

## Gotchas

- **Build outside the repo.** The repo may live in iCloud-synced `~/Documents`, which tags new
  files with extended attributes, and codesign then fails ("resource fork, Finder information, or
  similar detritus not allowed"). Always use `-derivedDataPath ~/Library/Caches/tabbit-build`.
- **Signing:** ad-hoc (`CODE_SIGN_IDENTITY "-"`), no team, no sandbox, no hardened runtime.
  `Tabbit/Signing.requirements` sets the designated requirement to the bundle ID so macOS privacy
  grants (Documents/Desktop/Downloads access) survive rebuilds. Keep `ENABLE_DEBUG_DYLIB: NO`,
  or the requirement would also be applied to the debug dylib and break the signature.
- **Privacy prompts:** test with copies of `samples/` outside `~/Documents`, `~/Desktop` and
  `~/Downloads` to avoid triggering "access files in your Documents folder" prompts.
- **Don't standardize URLs passed to WebKit.** `standardizedFileURL` turns `/private/tmp/…` into
  `/tmp/…`, and the file then falls outside the folder WebKit was granted. Standardize only for
  comparisons.
- **WebKit text substitutions** (smart quotes/dashes, autocorrect) are disabled through
  registered user defaults in `AppDelegate`; keep them off or source edits get mangled.
- **App icon:** XcodeGen doesn't know `.icon` documents; `options.fileTypes.icon` in project.yml
  makes it a single file in the Resources phase, and Xcode compiles it with actool
  (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`) into `Assets.car` + `AppIcon.icns`. If the
  Dock/Finder keep showing an old icon after reinstalling: `touch /Applications/Tabbit.app; killall Dock`.
- **Launch Services:** builds register themselves, so Finder's Open With can list several
  copies. `install.sh` unregisters its build output. For a Debug build, run
  `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u <path to Tabbit.app>`.
