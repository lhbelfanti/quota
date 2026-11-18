import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TOOL = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
developer = os.environ.get("DEVELOPER_DIR")
with open(os.environ["BUILD_TEST_LOG"], "a") as log:
    log.write(json.dumps({"tool": name, "args": args, "developer": developer,
                          "path": sys.argv[0]}) + "\\n")
if name == "xcode-select":
    print(os.environ["BUILD_TEST_DEFAULT_DEVELOPER"])
elif name == "xcrun":
    if args == ["--sdk", "macosx", "--find", "swiftc"]:
        print(Path(developer) / "usr/bin/swiftc")
    elif args == ["--sdk", "macosx", "--show-sdk-path"]:
        print(Path(developer) / "SDKs/MacOSX.sdk")
    else:
        sys.exit(90)
elif name == "swiftc":
    if Path(sys.argv[0]).parent == Path(os.environ["BUILD_TEST_BIN"]):
        sys.exit("Unexpected compiler from PATH")
    if "-typecheck" in args:
        source = sys.stdin.read()
        if "import SwiftUI" not in source or "import WidgetKit" not in source:
            sys.exit("Missing framework imports")
        error = os.environ.get("BUILD_TEST_ERROR")
        if error:
            sys.exit(error)
    else:
        Path(args[args.index("-o") + 1]).touch()
elif name == "codesign":
    sys.exit(73)
else:
    sys.exit(91)
'''


class BuildAppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(ROOT / "scripts/build-app.sh", self.root / "scripts")
        (self.root / "Sources/QuotaCore/Resources/ProviderLogos").mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("xcrun", "xcode-select", "swiftc", "codesign"):
            self.write_tool(self.bin / name)
        self.default = self.root / "Command Line Tools"
        self.override = self.root / "Custom Xcode.app/Contents/Developer"
        for developer in (self.default, self.override):
            compiler = developer / "usr/bin/swiftc"
            compiler.parent.mkdir(parents=True)
            self.write_tool(compiler)
        self.log = self.root / "tools.jsonl"
        self.env = os.environ.copy()
        self.env.pop("DEVELOPER_DIR", None)
        self.env.update(
            PATH=f"{self.bin}{os.pathsep}{self.env['PATH']}",
            BUILD_TEST_LOG=str(self.log),
            BUILD_TEST_DEFAULT_DEVELOPER=str(self.default),
            BUILD_TEST_BIN=str(self.bin),
        )

    def write_tool(self, path):
        path.write_text(TOOL)
        path.chmod(0o755)

    def run_build(self):
        result = subprocess.run(
            ["bash", str(self.root / "scripts/build-app.sh")],
            env=self.env, capture_output=True, text=True, timeout=30,
        )
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return result, calls

    def assert_compilation(self, developer):
        result, calls = self.run_build()
        self.assertEqual(result.returncode, 73, result.stderr)
        compiles = [call for call in calls if call["tool"] == "swiftc"]
        self.assertEqual(len(compiles), 3)
        for call in compiles:
            self.assertEqual(call["path"], str(developer / "usr/bin/swiftc"))
            self.assertEqual(call["developer"], str(developer))
            args = call["args"]
            self.assertEqual(args[args.index("-sdk") + 1], str(developer / "SDKs/MacOSX.sdk"))
        self.assertIn("-typecheck", compiles[0]["args"])
        app = self.root / "build/AIQuota.app/Contents"
        self.assertTrue((app / "MacOS/AIQuotaApp").exists())
        self.assertTrue((app / "PlugIns/AIQuotaWidgetExtension.appex/Contents/MacOS/AIQuotaWidgetExtension").exists())
        return calls

    def test_default_selection_ignores_compiler_on_path(self):
        self.assert_compilation(self.default)

    def test_developer_override_selects_both_compiler_and_sdk(self):
        self.env["DEVELOPER_DIR"] = str(self.override)
        calls = self.assert_compilation(self.override)
        self.assertFalse(any(call["tool"] == "xcode-select" for call in calls))

    def test_incompatible_sdk_preserves_existing_bundle_and_explains_fix(self):
        bundle = self.root / "build/AIQuota.app"
        bundle.mkdir(parents=True)
        sentinel = bundle / "previous-build"
        sentinel.write_text("keep")
        self.env["BUILD_TEST_ERROR"] = "This SDK is not supported by the compiler"
        result, calls = self.run_build()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(sentinel.read_text(), "keep")
        self.assertIn(self.env["BUILD_TEST_ERROR"], result.stderr)
        self.assertIn(str(self.default / "usr/bin/swiftc"), result.stderr)
        self.assertIn(str(self.default / "SDKs/MacOSX.sdk"), result.stderr)
        self.assertIn("DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-app.sh", result.stderr)
        self.assertEqual(sum(call["tool"] == "swiftc" for call in calls), 1)
        self.assertFalse(any(call["tool"] == "codesign" for call in calls))

    def test_other_preflight_errors_keep_original_diagnostic(self):
        self.env["BUILD_TEST_ERROR"] = "error: no such module 'SwiftUI'"
        result, _ = self.run_build()
        self.assertEqual(result.returncode, 1)
        self.assertIn(self.env["BUILD_TEST_ERROR"], result.stderr)
        self.assertFalse((self.root / "build").exists())


if __name__ == "__main__":
    unittest.main()
