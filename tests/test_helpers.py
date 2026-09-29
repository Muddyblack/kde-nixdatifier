import json
import os
import re
import subprocess
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

HELPERS = Path(__file__).resolve().parents[1] / "package/contents/tools/sh"


class Helpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nixdatifier-test-")
        self.root = Path(self.temp.name)
        self.env = dict(
            os.environ,
            XDG_CACHE_HOME=str(self.root / "cache"),
            XDG_RUNTIME_DIR=str(self.root),
        )
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env["PATH"] = str(self.bin) + os.pathsep + os.environ["PATH"]

    def tearDown(self):
        self.temp.cleanup()

    def script(self, path, source):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + source)
        path.chmod(0o755)
        return str(path)

    def run_helper(self, name, *args):
        return subprocess.run(
            [str(HELPERS / name), *args],
            check=False,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=15,
        )

    def test_cache_is_shared_across_install_paths_and_serialized(self):
        counter = self.root / "count"
        source = f"printf 'probe\\n' >> '{counter}'\nsleep .2\nprintf 'result'\n"
        a = self.script(self.root / "plasma/diskusage", source)
        b = self.script(self.root / "hyprland/diskusage", source)
        commands = [
            [str(HELPERS / "run"), "cached", "disk", "60", "--", helper]
            for helper in (a, b)
        ]
        jobs = [
            subprocess.Popen(c, env=self.env, stdout=subprocess.PIPE, text=True)
            for c in commands
        ]
        self.assertEqual(
            [p.communicate(timeout=5)[0] for p in jobs], ["result", "result"]
        )
        self.assertEqual(counter.read_text().splitlines(), ["probe"])

    def test_failed_reads_are_not_cached(self):
        broken = self.script(self.bin / "broken", "echo partial; exit 9\n")
        result = self.run_helper("run", "cached", "test", "60", "--", broken)
        self.assertEqual(result.returncode, 9)
        self.assertEqual(list((self.root / "cache/nixdatifier").glob("*.result")), [])

    def test_homepages_are_parsed_as_one_batch(self):
        names = [f"fixture-package-{n}" for n in range(200)]
        payload = self.root / "homepages.json"
        payload.write_text(json.dumps({n: f"https://example.org/{n}" for n in names}))
        self.script(self.bin / "nix", f"cat '{payload}'\n")
        self.script(self.bin / "find", "exit 0\n")
        import shutil
        real_jq = shutil.which("jq")
        calls = self.root / "jq-calls"
        self.script(self.bin / "jq", f"echo call >> '{calls}'; exec '{real_jq}' \"$@\"\n")
        result = self.run_helper("meta", *names)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            f"{n}\thttps://example.org/{n}\tnixpkgs" for n in names
        ])
        self.assertEqual(len(calls.read_text().splitlines()), 2)

    def test_partial_flake_check_retries_without_caching_failure(self):
        counter = self.root / "probes"
        helper = self.script(self.bin / "flake-probe", f"""
if [[ ! -f '{counter}' ]]; then
    touch '{counter}'
    printf 'nixpkgs\\tunreachable\\told\\t\\t0\\turl\\n'
else
    printf 'nixpkgs\\tok\\told\\tnew\\t0\\turl\\n'
fi
""")
        args = ("cached", "flake:test", "30", "--", helper)
        first = self.run_helper("run", *args)
        self.assertIn("\tunreachable\t", first.stdout)
        self.assertEqual(list((self.root / "cache/nixdatifier").glob("*.result")), [])
        second = self.run_helper("run", *args)
        self.assertIn("\tok\t", second.stdout)
        # Previously installed versions may have left failed cached results.
        result_file = next((self.root / "cache/nixdatifier").glob("*.result"))
        result_file.write_text(first.stdout)
        self.assertIn("\tok\t", self.run_helper("run", *args).stdout)

    def test_github_probe_uses_direct_commit_and_falls_back_to_git(self):
        old, new = "a" * 40, "b" * 40
        (self.root / "flake.lock").write_text(json.dumps({"nodes": {
            "root": {"inputs": {"nixpkgs": "nixpkgs"}},
            "nixpkgs": {"original": {"type": "github", "owner": "NixOS",
                "repo": "nixpkgs", "ref": "branch/with-slash"},
                "locked": {"rev": old, "lastModified": 1}}
        }}))
        args = self.root / "curl-args"
        git_called = self.root / "git-called"
        self.script(self.bin / "curl", f"printf '%s\\n' \"$@\" > '{args}'\nprintf '{new}'\n")
        self.script(self.bin / "git", f"touch '{git_called}'; printf '{new}\\trefs/heads/test\\n'\n")
        result = self.run_helper("flake-probe", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"\tok\t{old}\t{new}\t", result.stdout)
        self.assertIn("/commits/branch%2Fwith-slash", args.read_text())
        self.assertFalse(git_called.exists())
        self.script(self.bin / "curl", "exit 22\n")
        result = self.run_helper("flake-probe", str(self.root))
        self.assertIn(f"\tok\t{old}\t{new}\t", result.stdout)
        self.assertTrue(git_called.exists())
        self.script(self.bin / "git", "exit 128\n")
        self.assertIn("\tunreachable\t", self.run_helper("flake-probe", str(self.root)).stdout)
        self.script(self.bin / "git", "echo 'Could not resolve host: github.com' >&2; exit 128\n")
        self.assertIn("DNS lookup failed", self.run_helper("flake-probe", str(self.root)).stdout)
        self.script(self.bin / "git", "exit 124\n")
        self.assertIn("timed out after 40s", self.run_helper("flake-probe", str(self.root)).stdout)

    def test_change_counts_use_closure_direction_and_reuse_cache(self):
        args = self.root / "count-args"
        self.script(
            self.bin / "nix",
            f"printf '%s\\n' \"$@\" >> '{args}'\n"
            + "printf '\\033[32mone: ∅ → 1.0, +2 KiB\\033[0m\\n'\n"
            + "printf 'two: 2.0 → ∅, -3 MiB\\nthree: 1.0 → 2.0, +1 MiB\\nfour: 3.1 -> 3.2\\n'\n",
        )
        for _ in range(2):
            result = self.run_helper(
                "run",
                "cached",
                "generation-counts",
                "604800",
                "--",
                str(HELPERS / "change-counts"),
                "/nix/store/new",
                "/nix/store/old",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(result.stdout), {"added": 1, "removed": 1, "changed": 2}
            )
        self.assertEqual(
            args.read_text().splitlines(),
            [
                "--extra-experimental-features",
                "nix-command flakes",
                "store",
                "diff-closures",
                "/nix/store/old",
                "/nix/store/new",
            ],
        )

    def test_change_count_failure_and_identical_closures(self):
        self.script(self.bin / "nix", "echo 'closure missing' >&2; exit 8\n")
        result = self.run_helper("change-counts", "/nix/store/new", "/nix/store/old")
        self.assertEqual(result.returncode, 8)
        self.assertEqual(result.stdout, "")
        result = self.run_helper("change-counts", "/nix/store/same", "/nix/store/same")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout), {"added": 0, "removed": 0, "changed": 0}
        )

    def test_conflicting_mutation_is_rejected(self):
        started = self.root / "started"
        blocker = self.script(self.bin / "blocker", f"touch '{started}'; sleep 1\n")
        job = subprocess.Popen(
            [str(HELPERS / "run"), "mutate", "--", blocker], env=self.env
        )
        try:
            for _ in range(100):
                if started.exists():
                    break
                time.sleep(0.01)
            result = self.run_helper("run", "mutate", "--", "true")
            self.assertEqual(result.returncode, 75)
        finally:
            job.wait(timeout=3)

    def test_terminal_reports_real_failure_and_preserves_quoted_workdir(self):
        work = self.root / "flake's directory"
        work.mkdir()
        user_shell = self.script(
            self.bin / "test-shell", 'exec bash --noprofile --norc -c "$2"\n'
        )
        self.script(
            self.bin / "getent", f"printf 'test:x:1:1:Test:/tmp:{user_shell}\\n'\n"
        )
        terminal = self.script(self.bin / "test-terminal", 'shift; exec "$@"\n')
        result = self.run_helper(
            "terminal", terminal, str(work), "pwd > actual-dir; exit 37"
        )
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertEqual((work / "actual-dir").read_text().strip(), str(work))

    def test_dry_preview_never_writes_lockfile(self):
        args = self.root / "nix-args"
        self.script(self.bin / "nix-store", "exit 0\n")
        self.script(self.bin / "nix", f"printf '%s\\n' \"$@\" > '{args}'\nexit 0\n")
        work = self.root / "flake directory"
        work.mkdir()
        lock = work / "flake.lock"
        lock.write_text("original")
        result = self.run_helper(
            "dry-run-preview",
            str(work),
            "nixpkgs",
            "github:NixOS/nixpkgs/revision",
            "auto",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--no-write-lock-file", args.read_text().splitlines())
        self.assertEqual(lock.read_text(), "original")

    def test_settings_agree_across_hosts(self):
        """main.xml, Settings.qml, the Hyprland adapter, the editor schema and
        the Plasma config page must declare the same keys and defaults."""
        repo = HELPERS.parents[3]
        ui = repo / "package/contents/ui"
        ns = {"k": "http://www.kde.org/standards/kcfg/1.0"}
        xml = {}
        for entry in (
            ET.parse(repo / "package/contents/config/main.xml")
            .getroot()
            .iterfind(".//k:entry", ns)
        ):
            kind, text = entry.get("type"), entry.findtext("k:default", "", ns) or ""
            xml[entry.get("name")] = (
                text == "true"
                if kind == "Bool"
                else int(text)
                if kind == "Int"
                else float(text)
                if kind == "Double"
                else text
            )

        def qml_defaults(source):
            found = {}
            for kind, name, value in re.findall(
                r"^\s*property (bool|int|real|string|color) (\w+): (.+)$", source, re.M
            ):
                found[name] = (
                    float(json.loads(value)) if kind == "real" else json.loads(value)
                )
            return found

        host_only = {"pillMode", "popupPosition", "panelEdgeOffset", "panelSideOffset"}
        settings = qml_defaults((ui / "Settings.qml").read_text())
        shell = (repo / "hyprland/NixdatifierShell.qml").read_text()
        adapter = qml_defaults(
            shell[shell.index("id: cfg") : shell.index("App.Settings")]
        )
        schema = set(
            re.findall(r'"key": "(\w+)"', (ui / "SettingsSchema.js").read_text())
        )
        aliases = set(re.findall(r"cfg_(\w+):", (ui / "configGeneral.qml").read_text()))
        for name, host in (("Settings.qml", settings), ("Hyprland adapter", adapter)):
            self.assertEqual(
                {k: v for k, v in host.items() if k not in host_only}, xml, name
            )
        self.assertEqual(schema, set(xml))
        self.assertEqual(aliases, set(xml) | {name + "Default" for name in xml})

    def test_flake_context_fingerprint_changes(self):
        flake = self.root / "flake directory"
        flake.mkdir()
        (flake / "flake.lock").write_text("old")
        old = self.run_helper("flake-context", str(flake)).stdout.splitlines()
        (flake / "flake.lock").write_text("new")
        new = self.run_helper("flake-context", str(flake)).stdout.splitlines()
        self.assertEqual(old[0], str(flake))
        self.assertNotEqual(old[1], new[1])


if __name__ == "__main__":
    unittest.main()
