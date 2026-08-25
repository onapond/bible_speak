import importlib.util
import json
from pathlib import Path
import tomllib
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / "agent_harness.py"
spec = importlib.util.spec_from_file_location("agent_harness", path)
harness = importlib.util.module_from_spec(spec); spec.loader.exec_module(harness)


class HarnessTest(unittest.TestCase):
    def test_routes(self):
        self.assertEqual(harness.route_files(["lib/screens/a.dart", "functions/index.js"]), {"flutter", "ui", "functions"})

    def test_unknown_never_skips(self):
        self.assertEqual(harness.route_files(["strange.xyz"]), {"unknown"})

    def test_environment_files_are_routed(self):
        self.assertEqual(harness.route_files([".github/workflows/verify.yml"]), {"harness"})
        self.assertEqual(harness.route_files(["firestore.rules"]), {"harness"})
        self.assertEqual(harness.route_files(["firestore.indexes.json"]), {"harness"})
        self.assertEqual(harness.route_files(["mise.toml"]), {"harness"})
        self.assertEqual(harness.route_files(["analysis_options.yaml"]), {"flutter", "ui", "ios", "android", "web"})
        self.assertEqual(harness.route_files(["macos/Podfile"]), {"flutter"})

    def test_mise_versions_match_harness_config(self):
        root = Path(harness.__file__).parents[1]
        config = json.loads((root / ".ai-harness/config.json").read_text())["toolchain"]
        with (root / "mise.toml").open("rb") as handle:
            tools = tomllib.load(handle)["tools"]
        self.assertEqual(tools["flutter"], config["flutter"])
        self.assertEqual(tools["node"], config["node"])
        self.assertEqual(tools["npm:firebase-tools"], config["firebase"])
        self.assertEqual(tools["java"], config["java"])

    def test_force_push_blocked(self):
        self.assertIn("push", harness.command_gate("git push --force origin main"))
        self.assertIn("push", harness.command_gate("git -C repo push -f origin main"))
        self.assertIn("push", harness.command_gate("git push origin +HEAD:main"))

    def test_deploy_wrappers_require_full(self):
        self.assertEqual(harness.required_lane("npm --prefix functions run deploy"), "full")
        self.assertEqual(harness.required_lane("./scripts/deploy_environment.sh dev hosting"), "full")
        self.assertEqual(harness.required_lane("git push origin master"), "full")

    def test_deploy_wrapper_parses_firebaserc_as_json(self):
        source = (Path(harness.__file__).parents[1] / "scripts" / "deploy_environment.sh").read_text()
        self.assertIn("JSON.parse(fs.readFileSync", source)
        self.assertNotIn("c=require(process.argv[1])", source)

    def test_full_web_build_uses_environment_wrapper(self):
        source = Path(harness.__file__).read_text()
        self.assertIn('str(ROOT / "build_web.sh")', source)
        self.assertIn('"production" if git("branch", "--show-current")', source)

    def test_full_gate_only_tracks_web_artifact_for_web_target(self):
        source = Path(harness.__file__).read_text()
        self.assertIn('effective == "full" and selected == "web"', source)
        self.assertIn('record.get("target") == "web"', source)

    def test_active_task_target_is_the_default_validation_target(self):
        plan = {"tasks": [{"id": "DATA-RULES-001", "target": "web"}]}
        with patch.object(harness, "lock", return_value={"taskId": "DATA-RULES-001"}), \
                patch.object(harness, "read", return_value=plan):
            self.assertEqual(harness.validation_target(), "web")
            self.assertEqual(harness.validation_target("android"), "android")

    def test_analysis_does_not_trigger_flutter_platform_migrations(self):
        source = Path(harness.__file__).read_text()
        self.assertIn('"dart-analyze", [str(dart), "analyze"', source)
        self.assertNotIn('"flutter-analyze", [str(flutter), "analyze"', source)

    def test_functions_unit_and_rules_commands_are_separate(self):
        source = Path(harness.__file__).read_text()
        self.assertIn('"functions-unit"', source)
        self.assertIn('"functions-rules"', source)
        self.assertNotIn('"functions-test"', source)

    def test_scope_normalization(self):
        self.assertTrue(harness.path_allowed(".codex/hooks.json", [".codex/**"]))
        self.assertFalse(harness.path_allowed("lib/../pubspec.yaml", ["lib/**"]))

    def test_compound_build_deploy_is_blocked(self):
        self.assertIn("separate", harness.command_gate("./build_web.sh && firebase deploy --only hosting"))
        self.assertIn("separate", harness.command_gate("./build_web.sh dev && ./scripts/deploy_environment.sh dev hosting"))

    def test_usage(self):
        self.assertEqual(harness.observed_tokens({"usage": {"input_tokens": 10, "output_tokens": 5}}), 15)


if __name__ == "__main__": unittest.main()
