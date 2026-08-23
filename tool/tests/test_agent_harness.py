import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / "agent_harness.py"
spec = importlib.util.spec_from_file_location("agent_harness", path)
harness = importlib.util.module_from_spec(spec); spec.loader.exec_module(harness)


class HarnessTest(unittest.TestCase):
    def test_routes(self):
        self.assertEqual(harness.route_files(["lib/screens/a.dart", "functions/index.js"]), {"flutter", "ui", "functions"})

    def test_unknown_never_skips(self):
        self.assertEqual(harness.route_files(["strange.xyz"]), {"unknown"})

    def test_force_push_blocked(self):
        self.assertIn("push", harness.command_gate("git push --force origin main"))
        self.assertIn("push", harness.command_gate("git -C repo push -f origin main"))
        self.assertIn("push", harness.command_gate("git push origin +HEAD:main"))

    def test_deploy_wrappers_require_full(self):
        self.assertEqual(harness.required_lane("npm --prefix functions run deploy"), "full")
        self.assertEqual(harness.required_lane("git push origin master"), "full")

    def test_scope_normalization(self):
        self.assertTrue(harness.path_allowed(".codex/hooks.json", [".codex/**"]))
        self.assertFalse(harness.path_allowed("lib/../pubspec.yaml", ["lib/**"]))

    def test_compound_build_deploy_is_blocked(self):
        self.assertIn("separate", harness.command_gate("./build_web.sh && firebase deploy --only hosting"))

    def test_usage(self):
        self.assertEqual(harness.observed_tokens({"usage": {"input_tokens": 10, "output_tokens": 5}}), 15)


if __name__ == "__main__": unittest.main()
