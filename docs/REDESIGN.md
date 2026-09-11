# Shared desktop UI

`package/contents/ui/Engine.qml` owns operations and models. `ApplicationView.qml`
binds it to `FullView.qml` and the shared views. Plasma's `main.qml` provides
native configuration, icons, and a `PlasmaProcess.qml` adapter. The repository-root
`shell.qml` loads `hyprland/NixdatifierShell.qml`, which provides Quickshell windows,
persistent configuration, IPC, and `ProcessAdapter.qml`. Neither host uses the
HTML preview or its sample data.

## Appearance and interaction

Monochrome UI SVGs have a white default while retaining runtime tint support.
The original `nixos-logo.svg` keeps its colors and rotates during tracked work.
The header shows the booted generation in green and, when different, an arrow to
its amber next-boot generation. The Updates tab owns the update count. Custom
commands open in a full Commands panel from the footer; the old
`showCommandButtons` setting controls its launcher. The panel matches the HTML
preview, with the original flake, back/close controls, configured labels beside
literal command text, and a configuration shortcut. Long commands wrap. Back,
close, and Escape restore the previous tab and focus; selecting a command returns
to that tab and uses the existing terminal runner and footer progress. Command
buttons are disabled while another mutation is running.

The timeline rail fades between amber next-boot, green booted, and blue-gray older
generation markers, with a soft glow and a fading tail. The green
marker travels from the booted row to the actual next-boot row and back, using
instantiated delegate positions. Its fill and glow blend from green to amber as it
approaches next boot, then return to green on the way back. It recomputes after expansion, filtering,
scrolling, and resizing without restarting on every geometry update. An endpoint
can scroll past the clipped viewport edge while the connecting path is visible.
Animation pauses when hidden, motion is disabled, the path is outside the
viewport, or a target delegate is unavailable; glow and motion can be toggled
independently. Plasma desktop mode
and expanded panel popups both activate the view.

The background retains configurable alpha and rounded corners. Native text color
is checked for contrast against the custom background so a light desktop theme
cannot make the dark widget's text black. Header and tab typography use the shared
sizes and the font-scale setting in both hosts.

Search keeps the System history count and a fading rail when no generation
matches. Compare pickers draw their own selected text, arrow, and option rows,
keeping generation numbers readable with native desktop control styles.

Expanded generation cards show Activate, Set boot, and Delete in the header,
just before the expand/collapse button. Narrow layouts use icons with tooltips.
The disclosure control uses a rotating chevron and a circular hover/focus state.
Collapsed headers show added, removed, and changed package counts (`+ / − / ~`)
against the previous generation. Visible rows request counts in a serial queue;
immutable closure pairs share a seven-day cache. Missing or failed counts stay
unknown rather than displaying zero. Dates use Today/Yesterday and short older
dates; full timestamps remain available on hover.
Kernel and NixOS badges use larger text and short readable labels; the full
kernel variant and NixOS build string remain available on hover. The existing visibility settings, confirmation preferences,
busy-state guards, and protection of booted/next-boot generations still apply;
right-click actions and Compare with remain available.

Package rows retain semantic colors, app icons, versions, size differences, full
names, source links, and compact/detailed expansion. Installed store paths resolve
on demand against the corresponding generation closure. Unbuilt preview packages
show that their store paths are not available yet.
The semantic colors are brighter, with restrained halos on change markers and
expanded-row edges that follow the Glow setting. Compare results sit directly
below the generation pickers; row style remains configurable in Settings. Tools
starts with the utility cards, without introductory text above them.

Each update input has separate preview, update-only, and source actions, with
hover/focus descriptions instead of a permanently displayed legend. Collapsing
only changes visibility; cached packages and their local filters remain available.
Changing the flake path, lock fingerprint, or input revisions invalidates obsolete
results, including results returned by an older in-flight preview. Preview evaluation
uses `--no-write-lock-file`.

Work status uses the existing footer text and a two-pixel animated bottom edge;
it does not add a row or shift the body. Store measurements return when work ends
and stay available in the footer tooltip and Tools while busy. Routine feedback
appears as a small Done/Notice indicator in the footer. Details open only on click;
errors remain dismissible and copyable. Updating an input also shows progress in
its own row, without an additional desktop success notification. Desktop
notifications for other operations and newly discovered updates still follow
`showNotifications`. Tools and update content scroll inside the clipped body,
keeping both content and feedback clear of the footer at compact sizes.

## Settings and coexistence

All original XML settings remain available under General, Commands, Behavior,
and Design. The native Plasma configuration flow remains intact. Hyprland stores
its settings in `$XDG_CONFIG_HOME/nixdatifier/hyprland.json` (default
`~/.config/nixdatifier/hyprland.json`) and edits a draft until Apply or OK; Cancel
leaves the saved configuration unchanged. It additionally supports always-visible,
edge-hover, or tray-only mode and six popup positions. Motion can be disabled
separately from glow. Existing defaults and saved values keep their keys and types;
new installations use the revised colors and geometry. The former default purple
timeline color displays as the new neutral rail; other custom rail colors remain intact.

The two hosts own their settings separately. Shared results and locks live under
`$XDG_CACHE_HOME/nixdatifier`. Expensive store measurements use a thirty-minute
cache; closure and metadata reads also reuse bounded caches. Helper identities are
independent of their install directory so Plasma and Quickshell can share results.
A cross-process lock rejects overlapping system mutations. Custom terminal commands
hold that lock until their actual exit status is reported, rather than guessing
completion from new generations. Terminal launch has a bounded handshake; running
commands have no arbitrary completion timer.

A directory watcher follows flake/cache changes with a slow polling fallback.
The tray watches a small status JSON file with `QFileSystemWatcher`; it does not
poll Quickshell for badges or continuously run backend probes. Its animation timer
runs only while work and motion are enabled.

## Running and packaging

- `make view` / `make view-h`: existing Plasma preview commands.
- `nix build path:.#default`: Plasma package with helper runtime dependencies.
- `nix run path:.#hyprland`: Quickshell host plus the Qt StatusNotifier tray helper.
- `nix build path:.#tray`: tray helper alone.
- `qs -p .`: direct development launch, without the companion tray helper.

Use `path:.` while reviewing untracked files; Git-backed flake evaluation excludes
untracked files. No staging is needed for the path form.

Quickshell IPC accepts `qs ipc -p <configuration-root> call panel <action>`, with
`toggle`, `show`, `hide`, `refresh`, `configure`, `summary`, and `quit`. Use the same
configuration root used by the running host. Pin keeps the popup open; Escape
closes settings first, then the popup. Existing Plasma keyboard-shortcut and About
pages are managed by Plasma itself.

## Verification

`tests/run.sh` uses temporary configuration/cache/runtime directories and mocked
processes. QML tests cover parsing and diff direction, stale results, collapsible
previews, real completion/error state, protected actions, actual preview-button
clicks, navigation, light-desktop contrast, footer geometry during work/notices,
and full-distance timeline motion after expansion and scrolling. Python tests
cover shared cache coalescing across install paths, failed reads, mutation locking,
quoted working directories, terminal exit codes, and preview lock-file safety.
`tests/Smoke.qml` renders the shared application and exercises all settings tabs.

During this implementation the QML suite and eight helper tests passed, the shared
view rendered offscreen, the production Plasma component compiled, the native
settings component instantiated, and the tray helper compiled with Qt 6. The flake and its
generated install shell were parsed. A complete Nix build could not run because
the workspace denies access to the Nix daemon socket. Live Plasma/Hyprland window,
tray, focus-grab, and desktop-authentication behavior still needs a desktop-session
check: the workspace also restricts desktop IPC, and Quickshell has no offscreen
PanelWindow backend. Static lint retains host-metadata and legacy qualification
advisories; it is not being represented as a clean live-host validation.

No real generations were switched or deleted, no real flake was updated, and no
store cleanup was run during tests.
