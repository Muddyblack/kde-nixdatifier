import QtQuick
import QtTest
import "../package/contents/ui" as App

Item {
    width: 600
    height: 740
    App.Settings {
        id: cfg
        showNotifications: false
        showPackageIcons: false
    }
    Component {
        id: executor
        QtObject {
            function exec(cmd, cb) {
                jobs.push({
                    cmd: cmd,
                    callback: cb
                });
            }
        }
    }
    property var jobs: []
    App.Engine {
        id: core
        settings: cfg
        executor: executor
        autoStart: false
    }
    App.UpdatesTab {
        id: updates
        width: 550
        height: 550
        activeViewMode: "updates"
        accentColor: "#91bcff"
        textColor: "white"
        fs: 1
        isCheckingFlake: false
        lastFlakeCheckTime: ""
        iconStyle: "colored"
        flakeUpdates: core.flakeUpdates
        dryRunCache: core.dryRunCache
        isDryRunning: core.isDryRunning
        onDryRunRequested: (name, ref) => core.runDryPreview(name, ref)
    }
    TestCase {
        name: "SharedEngine"
        when: windowShown
        function init() {
            jobs = [];
            core.isBusy = false;
            core.activeJobs = 0;
            core.isLoadingPairDiff = false;
            core.isLoadingDetails = false;
            core.isDryRunning = false;
            core.dryRunCache = {};
            core.flakeUpdates = [];
            core.detailsCache = {};
            core.expanded = false;
            core.countingChanges = false;
            core.countsQueue = [];
            core.generationCounts = {};
            core.pairDiffCache = {};
            core.toasts = [];
            core.flakeEpoch = 0;
            core.resolvedFlakePath = "/tmp/test flake's dir";
            core.lockFingerprint = "lock-a";
            core.iconCache = {};
            core.metaCache = {};
            updates.openPreviews = {};
            core.generations = [
                {
                    number: 661,
                    active: true,
                    booted: false
                },
                {
                    number: 660,
                    active: false,
                    booted: true
                }
            ];
            core.activeGenNum = 661;
            core.bootedGenNum = 660;
        }
        function fixtureInput() {
            return {
                input: "nixpkgs",
                oldRev: "abc",
                newRev: "def",
                revisionKey: "abc\ndef",
                overrideRef: "github:NixOS/nixpkgs/def",
                url: "https://github.com/NixOS/nixpkgs"
            };
        }
        function test_package_lookups_share_pending_work_and_retry_errors() {
            cfg.showPackageIcons = true;
            const packages = [
                {
                    name: "test-package"
                },
                {
                    name: "test-package"
                }
            ];
            core.loadIcons(packages);
            core.loadIcons(packages);
            core.loadMeta(packages);
            core.loadMeta(packages);
            compare(jobs.length, 2);
            jobs[0].callback(jobs[0].cmd, "", "failed", 1);
            jobs[1].callback(jobs[1].cmd, "", "failed", 1);
            core.loadIcons(packages);
            core.loadMeta(packages);
            compare(jobs.length, 4);
            jobs[2].callback(jobs[2].cmd, "test-package\tapp-icon", "", 0);
            jobs[3].callback(jobs[3].cmd, "test-package\thttps://example.org\tnixpkgs", "", 0);
            core.loadIcons(packages);
            core.loadMeta(packages);
            compare(jobs.length, 4);
            compare(core.iconCache["test-package"], "app-icon");
            compare(core.metaCache["test-package"].url, "https://example.org");
            compare(Object.keys(core.pendingIcons).length, 0);
            compare(Object.keys(core.pendingMeta).length, 0);
            cfg.showPackageIcons = false;
        }
        function test_flake_failure_notice_includes_reason() {
            core.parseFlakeProbe("nixpkgs\tunreachable\told\t\t0\turl\t\tDNS lookup failed", true, true);
            compare(core.toasts.length, 1);
            verify(core.toasts[0].msg.includes("nixpkgs (DNS lookup failed)"));
        }
        function test_generation_counts_deduplicate_and_reject_stale_results() {
            core.activeViewMode = "timeline";
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/new"
                },
                {
                    number: 660,
                    storePath: "/nix/store/old"
                }
            ];
            core.requestGenerationCounts(661);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 1);
            core.loadNextGenerationCounts();
            compare(jobs.length, 0, "Counts wait while the popup is closed");
            core.expanded = true;
            core.isBusy = true;
            core.loadNextGenerationCounts();
            compare(jobs.length, 0, "User mutations take priority");
            core.isBusy = false;
            core.loadNextGenerationCounts();
            compare(jobs.length, 1);
            verify(core.countingChanges);
            core.loadNextGenerationCounts();
            compare(jobs.length, 1);
            const oldJob = jobs[0];
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/replaced"
                },
                core.generations[1]];
            core.requestGenerationCounts(661);
            oldJob.callback(oldJob.cmd, '{"added":99,"removed":0,"changed":0}', "", 0);
            compare(core.generationCounts[661].status, "loading");
            core.loadNextGenerationCounts();
            const newJob = jobs[1];
            newJob.callback(newJob.cmd, '{"added":2,"removed":4,"changed":3}', "", 0);
            compare(core.generationCounts[661].added, 2);
            compare(core.generationCounts[661].removed, 4);
            compare(core.generationCounts[661].changed, 3);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 0);
            compare(core.activeJobs, 0);
            core.expanded = false;
        }
        function test_generation_count_errors_stay_unknown_and_pause_retries() {
            core.activeViewMode = "timeline";
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/new",
                    previousNumber: 660,
                    previousStorePath: "/nix/store/old"
                }
            ];
            compare(core.countPair(661).baseNum, 660, "The last displayed generation keeps its earlier baseline");
            compare(core.getPreviousGen(661), 660, "Expanded details use the same baseline as the header counts");
            core.expanded = true;
            core.requestGenerationCounts(661);
            core.loadNextGenerationCounts();
            const job = jobs[0];
            job.callback(job.cmd, '{"added":-1,"removed":0,"changed":0}', "", 0);
            compare(core.generationCounts[661].status, "error");
            verify(core.generationCounts[661].added === undefined);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 0);
            compare(core.toasts.length, 0);
            core.expanded = false;
        }
        function test_pair_diff_first_record_and_direction() {
            core.parsePairDiff(661, 660, "26.05\x1ekernel\x1eone: ∅ → 1.0, +2 KiB\ntwo: 2.0 → ∅, -3 MiB\nthree: 1.0 → 2.0, +1 MiB\x1e123");
            const diff = core.pairDiffCache["661_660"].diff;
            compare(diff.length, 3);
            compare(diff[0].name, "one");
            compare(diff[0].type, "added");
            compare(diff[1].type, "removed");
            compare(diff[2].type, "upgrade");
            compare(diff[1].storeProfile, "/nix/var/nix/profiles/system-660-link");
        }
        function test_summary_cache_still_loads_details() {
            core.detailsCache = {
                661: {
                    partial: true,
                    nixosVer: "26.05"
                }
            };
            core.loadGenDetails(661);
            verify(jobs.some(job => job.cmd.indexOf("/details'") >= 0));
            verify(core.isLoadingDetails);
        }
        function test_collapse_preserves_preview_and_does_not_relaunch() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.dryRunCache = {
                nixpkgs: {
                    status: "ok",
                    packages: []
                }
            };
            updates.togglePreview(input);
            verify(updates.openPreviews.nixpkgs);
            core.isDryRunning = true;
            updates.togglePreview(input);
            verify(!updates.openPreviews.nixpkgs);
            verify(core.dryRunCache.nixpkgs.status === "ok");
            updates.togglePreview(input);
            verify(updates.openPreviews.nixpkgs);
            compare(jobs.length, 0);
        }
        function test_preview_timeout_clears_busy_state_and_allows_retry() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 1);
            verify(jobs[0].cmd.startsWith("timeout --kill-after=5s 180s "));
            jobs[0].callback(jobs[0].cmd, "", "", 124);
            verify(!core.isDryRunning);
            verify(!core.isSpinning);
            compare(core.dryRunCache[input.input].status, "error");
            verify(core.dryRunCache[input.input].errorMsg.includes("timed out"));
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 2);
            jobs[1].callback(jobs[1].cmd, "OK: already up to date", "", 0);
            compare(core.dryRunCache[input.input].status, "ok");
        }

        function test_stale_preview_is_not_applied() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 1);
            verify(core.isSpinning);
            const job = jobs[0];
            core.flakeEpoch++;
            core.dryRunCache = {};
            job.callback(job.cmd, "fetch\tapp\t1\t2", "", 0);
            compare(Object.keys(core.dryRunCache).length, 0);
            verify(!core.isDryRunning);
            verify(!core.isSpinning);
        }
        function test_new_revisions_invalidate_only_changed_previews() {
            core.flakeUpdates = [fixtureInput()];
            core.dryRunCache = {
                nixpkgs: {
                    status: "ok",
                    packages: []
                }
            };
            core.parseFlakeProbe("nixpkgs\tok\tabc\tghi\t0\thttps://github.com/NixOS/nixpkgs\tgithub:NixOS/nixpkgs/ghi", true);
            verify(!core.dryRunCache.nixpkgs);
        }
        function test_input_update_is_quoted_and_exits() {
            core.runFlakeUpdateInput("input's name");
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf(" mutate -- bash -c ") >= 0);
            verify(core.isBusy);
            compare(core.updatingInput, "input's name");
            jobs[0].callback(jobs[0].cmd, "", "failure", 1);
            verify(!core.isBusy);
            compare(core.updatingInput, "");
            verify(core.toasts[0].err);
        }
        function test_terminal_completion_tracks_exit_not_generations() {
            core.runCustomCommand("false", "Test");
            verify(core.isBusy);
            verify(core.isSpinning);
            jobs[0].callback(jobs[0].cmd, "", "command failed", 7);
            verify(!core.isBusy);
            verify(core.toasts[0].err);
            verify(core.toasts[0].msg.indexOf("7") >= 0);
        }
        function test_protected_generations_and_disabled_live_switch() {
            core.executeAction(660, "delete");
            core.executeAction(661, "delete");
            cfg.enableLiveSwitch = false;
            core.executeAction(659, "switch");
            cfg.enableLiveSwitch = true;
            compare(jobs.length, 0);
        }
        function test_devenv_output_is_parsed() {
            const text = "dir=/p/app\nname=app\ndirenv=2.37.1\nenvrc_path=/p/app/.envrc\nenvrc_state=blocked\n" + "envrc_uses=use flake,dotenv\ncache_dir=\ncache_mtime=\ncache_size=\nfiles=flake.nix,.envrc\n" + "description=Demo\nlock_inputs=1\nlock_oldest=100\nlock_newest=100\ndevshells=ok\n" + "\x1euse flake\x1enixpkgs\tgithub\tNixOS/nixpkgs\tnixos-unstable\tabc1234\t100\t\x1edefault\nci";
            const r = core.parseDevEnv(text);
            compare(r.name, "app");
            compare(r.envrcState, "blocked");
            compare(r.envrcUses, ["use flake", "dotenv"]);
            compare(r.files, ["flake.nix", ".envrc"]);
            compare(r.cacheTime, 0);
            compare(r.inputs.length, 1);
            compare(r.inputs[0].source, "NixOS/nixpkgs");
            compare(r.inputs[0].rev, "abc1234");
            compare(r.inputs[0].modified, 100);
            compare(r.shells, ["default", "ci"]);
            verify(r.shellsKnown);
        }
        function test_devenv_probe_failure_is_an_error() {
            core.isProbingDevEnv = false;
            core.probeDevEnv("/nope");
            verify(core.isProbingDevEnv);
            jobs[0].callback(jobs[0].cmd, "", "ERROR: not a directory", 2);
            verify(core.devEnvResult.isError);
            verify(core.devEnvResult.value.indexOf("not a directory") >= 0);
            verify(!core.isProbingDevEnv);
        }
        function test_devenv_discovery_lists_projects() {
            core.discoverDevEnvs();
            jobs[0].callback(jobs[0].cmd, "/home/me/app\tallowed\n/home/me/other\tdenied\n", "", 0);
            compare(core.devEnvProjects.length, 2);
            compare(core.devEnvProjects[0].name, "app");
            compare(core.devEnvProjects[1].state, "denied");
        }
        function test_hash_error_is_not_success() {
            core.runHashProbe("url", "https://example.invalid");
            jobs[0].callback(jobs[0].cmd, "", "network error", 1);
            verify(core.hashResult.isError);
            verify(!core.isProbingHash);
        }
    }
}
