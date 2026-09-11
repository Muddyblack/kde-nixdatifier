# Nixdatifier UI rewrite and KDE / Hyprland support

Prepared: 11 September 2026  
Status: implementation brief for the next implementation request. The production rewrite has not started.

## Scope and working agreement

Rebuild Nixdatifier's presentation around the reviewed HTML design, preserve its existing functionality and settings, and support KDE Plasma and Hyprland through a shared QML UI and core.

The user will ask separately to implement this plan. Until then, leave the production widget and HTML preview as they are. The latest requested menu, settings, preview-collapse, and timeline-motion refinements belong in the real implementation; they do not require another HTML revision.

- No commits, staging, tags, pushes, releases, or publishing unless the user later explicitly changes that instruction. Do not run `make tag` or `tag.sh`.
- Preserve existing user changes, including any files already staged by the user.
- Use the existing project and sibling widgets as implementation references. Do not modify the sibling projects as part of this rewrite.
- The HTML is a visual reference with sample data, not a replacement application or a specification of backend behavior. The production UI remains QML.
- New user instructions take precedence over this brief. The decisions below take precedence over omissions or contradictory details in the HTML.

## References and current state

| Reference | Purpose |
| --- | --- |
| [design-preview.html](design-preview.html) | Reviewed visual direction and illustrative interactions for both desktops. |
| [readme/demo.svg](readme/demo.svg) | Existing glow and animation reference. The requested final travel motion is described below. |
| [main.qml](package/contents/ui/main.qml) | Current state, polling, parsing, cache coordination, and system actions. |
| [FullView.qml](package/contents/ui/FullView.qml) | Existing header, menus, confirmations, cleanup, and view wiring. |
| [GenerationDelegate.qml](package/contents/ui/GenerationDelegate.qml) | Generation details, timeline behavior, and existing interactions. |
| [PackageRow.qml](package/contents/ui/components/PackageRow.qml) | Expandable package rows, icons, metadata, and source links to preserve. |
| [main.xml](package/contents/config/main.xml) and [configGeneral.qml](package/contents/ui/configGeneral.qml) | Existing settings and configuration compatibility contract. |
| [tools/sh](package/contents/tools/sh) | Existing Nix and system helpers to retain or adapt. |
| [AI Usage widget](../ai-usage-widget) and [Gitpulse](../github-notifications-widget) | Local examples of Plasma plus Hyprland/Quickshell, tray helpers, settings, and shared code. |

The preview already shows the overall design, the original flake icon, a connected timeline, colored expandable package rows, per-input actions, and simulated working states. It still has a small local marker bounce and simplified settings/menu behavior. Those are **not** the final requirements.

The preview's scripted DOM interactions and stylesheet parsing were checked. Actual browser rendering could not be verified in the assistant environment because Chrome failed under its runtime restrictions. These checks do not validate either production QML host.

## Visual direction

- Use the preview's dark graphite surfaces, restrained blue accent, clearer hierarchy, readable secondary text, and consistent spacing, borders, radii, and controls.
- Keep the existing Nixdatifier identity and useful visual character: the multicolored flake, the left timeline rail, glow, status colors, and recognizable package icons.
- Define shared theme and sizing properties rather than repeating unrelated hardcoded colors and dimensions throughout the screens.
- Support desktop theme integration and existing custom appearance settings. A new default must not overwrite a user's saved colors, font scale, transparency, or icon preference.
- Adapt to compact popups, larger windows, font scaling, and display scaling. Long kernel names, package names, and revisions must not break layouts.
- Provide keyboard focus, useful tooltips, clear loading/error/empty states, and readable status labels alongside colors.

Primary navigation: **Generations · Updates · Compare · Tools**. Existing stored view names remain compatible even if their visible labels change.

## Header, footer, and menu

### Header

Keep the original flake icon and Nixdatifier title, generation/version information, hostname, uptime, and last activation/switch time. Distinguish the running/active system, the system actually booted, and the next-boot target when they differ.

Retain pin/keep-open behavior, cleanup access, configurable quick-run command buttons, and a three-dot menu. Make these fit the new visual hierarchy without removing their functionality.

### Store information

**Keep Nix store size and reclaimable space in the footer.** The user explicitly accepted this placement after noticing it in the preview; the earlier request to duplicate it in the header was withdrawn.

Keep the fuller storage/cleanup view in Tools, including free-space information where available. Avoid treating unknown or still-loading estimates as zero.

### Three-dot menu

Restore the existing actions in the modern styling:

1. Refresh generations list.
2. Check flake for updates.
3. Configure widget…
4. KDE Store Page.
5. GitHub Repository.

Retain action availability/loading feedback and the actual project destinations. Support click-away dismissal, Escape, keyboard navigation, and focus return. Keep native Plasma settings entry points, shortcut configuration, and About access available where supplied by the host.

## Original flake icon and working animation

- Use [the existing multicolored flake SVG](package/contents/ui/nixos-logo.svg). Do not substitute the generic snowflake used in the first mockup. The package icon has a separate role and is not the same asset.
- Keep existing colored/white/black/accent icon-style choices; the original colored artwork is the reviewed default.
- Animate the flake while actual work is in progress: refreshes, flake checks, details/comparison loading, update previews, individual input updates, hashing, secrets/config inspection, cleanup, generation actions, and tracked custom commands.
- Drive this from real operation state. A launched command is not necessarily a completed command; preserve existing completion tracking and handle failures and cancellation.
- Cover the popup header and compact panel/tray/pill representation, and show working feedback in any overlay that covers the header.
- Stop the working animation when operations finish. Do not copy the HTML's fixed-duration simulation into production.
- Provide a useful operation label without inventing a completion percentage. Prevent conflicting actions while preserving harmless navigation and collapse controls.

## Generations and the left timeline

### Rail and rows

- Keep a continuous vertical rail on the **left**, with a node for each generation.
- Preserve distinct green booted, amber next-boot, and quieter purple historical markers, plus explicit labels. Do not infer these statuses from the selected row.
- Show generation number, timestamp, kernel, and NixOS version/date. Long kernel strings such as the user's CachyOS variant must remain inspectable.
- Clicking a generation expands/collapses its details and package changes against the previous generation.
- Preserve search, keyboard navigation, comparison entry points, live activation, next-boot selection, deletion, and the existing confirmation preferences.
- Keep generation details and configuration changes available even where the HTML only shows a subset.

### Final requested green animation

**The green animated marker must travel along the rail from the booted generation up to the next-boot target and back. A two-pixel bounce in place is insufficient.** This is the user's final clarification of the requested motion.

Use a glowing moving marker/ring following the real row positions, with a smooth outward and return movement. Preserve the static status labels and underlying generation state while the decoration animates.

- Calculate the full distance between the actual booted and next-boot nodes; do not hardcode a row height or an offset from the screenshot.
- Recalculate the path when rows expand/collapse, the view resizes, font scale changes, or the generation model changes.
- Keep the effect aligned with the rail when scrolling and with virtualized rows. Avoid positioning against a delegate that has been destroyed or recycled.
- If there is no distinct next-boot target, or both endpoints are not available in the displayed timeline, use a stationary glow/pulse or suspend the traveling effect rather than inventing a target.
- Integrate glow/motion preferences and reduced-motion behavior.
- Pause decorative animation when the popup is closed, the timeline is not visible, or the application is otherwise hidden. Do not keep an idle hidden render loop running.

The existing `demo.svg` supplies the character of the effect; its literal transforms are not a layout implementation for QML.

## Package changes: retain the existing interaction

Use shared package-row components in generation details, Compare, and update previews.

- Preserve green additions, red removals, and amber changes/upgrades with explicit `+`, `−`, and `~` indicators.
- Keep actual application/package icons, including recognizable icons such as Bitwarden, with a sensible package fallback.
- Show package name, version or old/new versions, and signed size delta in a compact row.
- Preserve click-to-expand behavior for the **whole package row**, including a truncated name. Expand/collapse affordances must remain visible and keyboard accessible.
- Expanded details show the full package name, versions, size delta, store path with copy action, and homepage/source or nixpkgs fallback links.
- Preserve real metadata resolution and safe external-link handling; do not replace live values with the preview's sample URLs or zero-filled store paths.
- Keep package filtering and compact/detailed modes. Preserve scroll position and useful expansion state during routine UI updates.
- Handle empty or unusual versions, very long names, missing icons/metadata, and large diffs without broken layouts or excessive work.

Compare needs clear source/target selectors, correct directional additions/removals and size changes, a sensible same-generation result, and selection prefilled when opened from a generation row. Retain configuration snapshot/diff functionality alongside package comparisons.

## Updates and collapsible previews

Each flake input keeps three distinct, immediately accessible actions:

| Action | Required behavior |
| --- | --- |
| Preview changes | Evaluate and show the package changes for that input. Show genuine loading/error state. |
| Update only this input | Update that input in the configured flake lock file. Preserve the existing command behavior; do not replace this with update-all or an automatic rebuild. |
| Open source | Open the actual upstream repository or supported revision/compare destination, using the hosting URL returned for that input rather than assuming GitHub. |

**Loaded previews must be easy to collapse and reopen.** Give each input a clear chevron/toggle and expanded state. Clicking the input's preview header or its toggle should collapse/reopen the details; clicking Update or Open source should perform only that action.

- Separate preview visibility from cached preview data. Collapsing must not discard the result or trigger another evaluation when reopened.
- Keep inputs independent; opening or collapsing one must not accidentally clear another input's cached result.
- Preserve package expansion/filter state where possible during a visibility-only toggle.
- Do not disable collapse just because unrelated work is running.
- Invalidate or refresh stale previews when the relevant revisions, flake path, or lock state change. A cached result is reusable only for the configuration/revisions it describes.
- Show errors and retry controls inline. Closing an error/preview section must not silently launch another job.

## Tools and existing system functionality

The user approved the Tools tab and its storage view. Move utilities there without narrowing what they can do:

- Secrets: deployed and source locations, detection, presence/status, timestamps, and existing agenix/sops handling. Preserve the distinction between metadata inspection and secret contents.
- Hashing: preserve **URL, Zip/Tar, GitHub, File, and Store** modes, result/error handling, and copy actions. The preview's one-field form is incomplete.
- Nix store: total size, reclaimable estimate, free space, existing cleanup variants, and the custom GC command.
- Commands: up to four configurable quick actions, optional header buttons, configured terminal, working directory, shell/alias behavior, and completion feedback.
- Keep toasts, copyable errors, notifications, refresh behavior, confirmation flows, pin/pop-out behavior, remembered size, and any other existing user-facing action discovered during the initial parity audit.

## Full settings: retain all four sections

The user explicitly requested preserving **General, Commands, Behavior, and Design**. The short settings overlay in the HTML is not sufficient and does not authorize dropping options.

Use the following inventory as a compatibility checklist. Check the current XML/QML again at implementation time for changes made since this brief.

| Section | Settings to preserve |
| --- | --- |
| General — NixOS & Flake | `flakePath`, `configRepoPath`, `enableHostDetect`, `checkInterval`, `maxGenerations` |
| General — Default view | `defaultView`, including compatibility with existing `timeline`, `updates`, `diff`, `secrets`, and `hash` values where supported |
| Commands — Quick actions | `customCommands` with labels, commands, optional colors and a maximum of four; `showCommandButtons` |
| Commands — Terminal / cleanup | `commandTerminal`, `gcCustomCommand` |
| Behavior — Permissions / generation actions | `usePkexec`, `enableLiveSwitch`, `confirmBeforeRollback`, `confirmBeforeDelete`, `showDeleteButton` |
| Behavior — Refresh / updates | `autoRefreshOnOpen`, `showFlakeSection`, `showNotifications` |
| Behavior — Secrets | `secretsPath`, `secretsSourcePath` |
| Behavior — Package differences | `diffFilterEnabled`, `showPackageIcons`, `diffViewMode` |
| Design — Colors / text | `timelineColor`, `accentColor`, `fontScale`, `useSystemTextColor`, `customTextColor` |
| Design — Background / effects | `showBg`, `bgColor`, `bgRadius`, `enableGlow`; preserve background alpha/transparency when reading and saving existing values |
| Design — Compact representation | `iconStyle`, `compactStyle` (`icon`, `number`, `both`, `pill`), `compactShowBadge` |
| Remembered geometry | `popupWidth`, `popupHeight` |

Keep meaningful labels, units, help text, valid ranges, terminal choices, and blank-path auto-detection behavior. Preserve Apply/OK/Cancel semantics where used and persist real settings across restarts.

Map renamed navigation without losing settings: `timeline` opens Generations; `diff` opens Compare; `secrets` and `hash` reach their corresponding Tools subview. Preserve user customizations when introducing new defaults or keys. Do not silently reset existing Plasma configuration or change the plasmoid ID.

Hyprland needs equivalent capabilities and persistent settings without requiring Plasma. Additional tray/pill visibility and placement controls can follow the sibling widgets' implementation patterns. Desktop-specific window/panel settings may remain separate; shared core behavior must not diverge.

## Architecture for both desktops

### Shared core and UI

Extract reusable state/parsing/actions from the current large `main.qml` and reusable presentation from the existing views. Keep one model/operation contract for generations, package changes, flake inputs, previews, secrets, hashes, storage, errors, and busy state.

Use QtQuick-compatible shared components with explicit inputs/signals and theme properties. Keep Plasma-only imports, configuration access, translation facilities, and command execution out of components that must load in Quickshell. Provide host adapters for those facilities rather than copying the entire application for each desktop.

Reuse working shell helpers and their behavior. Refactor or repair them where needed for portability, ownership of processes, error handling, and concurrency; a UI rewrite alone is not a reason to reimplement every Nix operation.

Suggested responsibilities, with exact filenames chosen during implementation:

- Shared engine/model and operation lifecycle.
- Shared theme, chrome, timeline rail/marker, generation row, package row, updates, comparisons, tools, and settings content.
- Plasma host for `PlasmoidItem`, compact/full representations, native configuration, and process integration.
- Quickshell host for its process API, persistent settings, popup/window lifecycle, IPC, and tray/pill integration.

### KDE Plasma

Retain the existing plasmoid identity and installation path, panel and desktop usage, configuration integration, keyboard/host behavior, theme support, compact styles, and persistent popup sizing. Confirm pin and pop-out behavior still work with the shared UI.

### Hyprland / Quickshell

Follow the local AI Usage and Gitpulse patterns: a standard StatusNotifier tray entry, optional floating/edge pill, popup toggle, placement, pinning, and click-away handling. Integrate with supported tray hosts such as Waybar/Caelestia through the same existing pattern.

Use a repository-root Quickshell entry point so shared imports remain inside its configuration root. Add a Nix launcher/package path for Hyprland, keeping the existing Plasma package usable. Pin required runtime tools through packaging rather than relying on a Plasma session's incidental PATH.

### Running both

Both hosts must be installable and usable on the same system, including concurrent instances. Share reusable caches appropriately and coordinate costly probes and conflicting system mutations across processes. An in-memory busy flag in one frontend is not sufficient coordination for two independently running hosts.

Keep settings ownership explicit: preserve per-instance Plasma settings, use persistent Hyprland settings, and avoid accidental overwrites between them. Equivalent features do not require forcing both desktops to use the same window placement or visual preferences.

## Performance and correctness to preserve

- Retain the existing low-idle-cost behavior: expensive store walks/GC estimates are demand-driven, rate-limited, non-overlapping, and run with the existing low-priority approach.
- Keep shared flake caching, watch-based synchronization, and a slow fallback when watching is unavailable. Do not introduce a respawn loop or duplicate probes for each open view.
- Keep package icon/homepage resolution bounded and reusable across large diffs.
- Stop hidden decorative animation and release or stop obsolete UI work as appropriate. Opening settings or changing tabs must not start duplicate backend jobs.
- Preserve proper shell argument quoting, process completion/error reporting, supported terminal detection, privilege handling, and configured confirmation behavior.
- Treat active, booted, selected, and next-boot generations as distinct state. Neither visual animation nor selection changes backend system state.

## Implementation sequence when requested

1. **Audit and establish parity.** Re-read repository instructions and the working tree; inventory all existing views, settings, helpers, actions, caches, and host behavior. Identify suitable shared code and sibling integration patterns.
2. **Extract the common core.** Establish host-neutral models, operation lifecycle/busy tracking, settings boundaries, and process adapters while preserving the existing behaviors.
3. **Build the shared visual foundation.** Implement the approved theme, original icon, header/footer/menu, navigation, responsive controls, and full settings content.
4. **Implement Generations and Compare.** Include the continuous timeline, full-distance green travel animation, real package icons, expandable package metadata, and configuration differences.
5. **Implement Updates and Tools.** Include per-input actions, independently collapsible cached previews, all hash modes, secrets, storage, cleanup, and commands.
6. **Complete both hosts.** Wire the shared components into Plasma and Quickshell, persist settings, preserve existing configuration, and implement the tray/pill/IPC and concurrency behavior.
7. **Package, verify, and document.** Update the Nix flake, development/preview commands, and README; verify both production frontends and report remaining environment limitations accurately. Leave the result uncommitted for review.

## Acceptance checks

- Both actual QML hosts load and show real data; no dependency on the HTML or its sample state.
- Both can coexist; duplicate expensive work and conflicting mutations are coordinated.
- Existing Plasma configuration is preserved, and Hyprland settings survive restart.
- All settings in the inventory and all existing functional modes remain reachable.
- The original flake animates for real tracked work and stops afterward, including when work is initiated from an overlay.
- The green traveling marker reaches the next-boot node and returns; it remains aligned after resize, filtering, expansion, scrolling, and model changes. Missing endpoints and hidden/reduced-motion cases are handled.
- Update previews collapse/reopen clearly, preserve valid cached data, and invalidate when their inputs change. Preview, update-only, and external navigation remain separate actions.
- Package rows retain icons, semantic colors, filtering, full-name expansion, versions, signed sizes, copy, and source links in all three contexts.
- The three-dot menu and full settings sections work through keyboard and pointer input.
- Store information stays in the footer, with the fuller Tools view; hostname, version/generation, uptime, and activation information remain in the header.
- Compact sizes, long strings, font scaling, missing data, large diffs, errors, and loading states remain usable.
- Run relevant QML lint/build checks and meaningful engine/host/interaction checks. Use fixtures or controlled test harnesses for privileged/destructive actions; do not switch, delete, or garbage-collect the user's real system merely to test the redesign.
- Verify behavior in actual Plasma and Quickshell environments where available. Do not claim visual or live-host validation based only on syntax checks, stubs, or the HTML preview.
- No commits, tags, pushes, releases, or unrequested publishing.

