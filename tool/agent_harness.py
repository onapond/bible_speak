#!/usr/bin/env python3
"""Shared plan, verification, handoff, and usage harness."""
from __future__ import annotations
import argparse, datetime as dt, fnmatch, hashlib, json, os, re, shlex, shutil
import socket, subprocess, sys, time, tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / ".ai-harness/config.json"
PLAN = ROOT / ".ai-harness/plan.json"
HANDOFF = ROOT / ".ai-harness/HANDOFF.md"
RANK = {"fast": 1, "standard": 2, "full": 3}
STATE_FILES = {".ai-harness/plan.json", ".ai-harness/HANDOFF.md"}
SKIP = (".git/", ".ai-harness/runtime/", ".dart_tool/", "build/", "functions/node_modules/")


class HarnessError(RuntimeError): pass


def read(path): return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temp, path)


def config(): return read(CFG)


def runtime(create=True):
    setting = config()["runtimeDir"]
    if setting.startswith("git:"):
        path = Path(git("rev-parse", "--path-format=absolute", "--git-path", setting.split(":", 1)[1]).strip())
    else:
        path = ROOT / setting
    if create:
        path.mkdir(parents=True, exist_ok=True)
        path.chmod(0o700)
    return path


def git(*args):
    result = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True)
    if result.returncode: raise HarnessError(result.stderr.strip())
    return result.stdout


def names(text): return [value for value in text.split("\0") if value]


def repo_files():
    result = set(names(git("ls-files", "-z")))
    result.update(names(git("ls-files", "--others", "--exclude-standard", "-z")))
    return sorted(name for name in result if name not in STATE_FILES
                  and not name.startswith(SKIP) and (ROOT / name).is_file())


def fingerprint():
    digest = hashlib.sha256()
    for name in repo_files():
        digest.update(name.encode() + b"\0")
        digest.update(b"x" if os.access(ROOT / name, os.X_OK) else b"-")
        digest.update((ROOT / name).read_bytes())
    plan = read(PLAN)
    plan.pop("updatedAt", None)
    for item in plan["tasks"]:
        item.pop("status", None); item.pop("owner", None)
    digest.update(json.dumps(plan, ensure_ascii=False, sort_keys=True).encode())
    return digest.hexdigest()


def directory_digest(path):
    path = Path(path)
    if not path.is_dir(): return None
    digest = hashlib.sha256()
    for item in sorted(value for value in path.rglob("*") if value.is_file()):
        digest.update(str(item.relative_to(path)).encode() + b"\0")
        digest.update(item.read_bytes())
    return digest.hexdigest()


def changed_files():
    result = set(names(git("diff", "--name-only", "-z", "HEAD")))
    result.update(names(git("diff", "--cached", "--name-only", "-z")))
    result.update(names(git("ls-files", "--others", "--exclude-standard", "-z")))
    result.difference_update(STATE_FILES)
    if not result:
        result.update(names(git("diff-tree", "--no-commit-id", "--name-only", "-r", "-z", "HEAD")))
    return sorted(name for name in result if not name.startswith(SKIP))


def route_files(files):
    routes = set()
    for name in files:
        if name in {
            "AGENTS.md", "CLAUDE.md", ".gitignore", "codemagic.yaml", "firestore.rules",
            "firestore.indexes.json", "mise.toml", ".tool-versions",
        } or name.startswith(
                (".ai-harness/", ".codex/", ".claude/", ".github/workflows/", "bin/", "tool/")):
            routes.add("harness")
        elif name.startswith("docs/") or name.endswith(".md"): routes.add("docs")
        elif name.startswith("functions/"): routes.add("functions")
        elif name.startswith(("cloudflare-worker/", "render-proxy/", "vercel-proxy/")) or name.endswith((".js", ".mjs", ".cjs")):
            routes.add("javascript")
        elif name.endswith((".sh", ".bash")): routes.add("shell")
        elif name.startswith("ios/"): routes.update(("flutter", "ios"))
        elif name.startswith("android/"): routes.update(("flutter", "android"))
        elif name.startswith("macos/"): routes.add("flutter")
        elif name.startswith("web/") or name.startswith("build_web"): routes.update(("flutter", "web"))
        elif name in {"pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "firebase.json", ".firebaserc"} or name.startswith("assets/"):
            routes.update(("flutter", "ui", "ios", "android", "web"))
        elif name.startswith(("lib/", "test/", "integration_test/")) or name.endswith(".dart"):
            routes.add("flutter")
            if name.startswith(("lib/screens/", "lib/widgets/", "lib/styles/", "lib/theme/")): routes.add("ui")
        else: routes.add("unknown")
    return routes or {"harness"}


def mise_tool_bin(name):
    executable = shutil.which("mise")
    if not executable or not (ROOT / "mise.toml").is_file(): return None
    try:
        result = subprocess.run([executable, "which", name], cwd=ROOT, text=True,
                                capture_output=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired): return None
    if result.returncode: return None
    candidate = Path(result.stdout.strip())
    return candidate if candidate.is_file() and os.access(candidate, os.X_OK) else None


def tool_bin(name):
    if managed := mise_tool_bin(name): return managed
    if name in {"npm", "npx"} and (node := mise_tool_bin("node")):
        sibling = node.parent / name
        if sibling.is_file(): return sibling
    return Path(found) if (found := shutil.which(name)) else None


def flutter_bin():
    if os.getenv("FLUTTER_BIN") and Path(os.environ["FLUTTER_BIN"]).is_file(): return Path(os.environ["FLUTTER_BIN"])
    if os.getenv("FLUTTER_ROOT") and (Path(os.environ["FLUTTER_ROOT"]) / "bin/flutter").is_file():
        return Path(os.environ["FLUTTER_ROOT"]) / "bin/flutter"
    if managed := mise_tool_bin("flutter"): return managed
    if found := shutil.which("flutter"): return Path(found)
    local = ROOT / "android/local.properties"
    if local.exists():
        for line in local.read_text().splitlines():
            if line.startswith("flutter.sdk="):
                candidate = Path(line.split("=", 1)[1].strip()) / "bin/flutter"
                if candidate.is_file(): return candidate
    return None


def first(command):
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=20)
        output = (result.stdout + result.stderr).strip()
        return output.splitlines()[0] if output else "missing"
    except (OSError, subprocess.TimeoutExpired): return "missing"


def metadata():
    for path in (CFG, PLAN, ROOT / ".codex/hooks.json", ROOT / ".claude/settings.json"): read(path)
    for path in (ROOT / ".codex/config.toml", *sorted((ROOT / ".codex/agents").glob("*.toml"))):
        with path.open("rb") as handle: tomllib.load(handle)
    with (ROOT / "mise.toml").open("rb") as handle:
        tools = tomllib.load(handle).get("tools", {})
    expected = config()["toolchain"]
    pinned = {
        "flutter": expected["flutter"],
        "node": expected["node"],
        "npm:firebase-tools": expected["firebase"],
        "java": expected["java"],
    }
    mismatches = [f"{name}={tools.get(name)!r}, expected {version!r}"
                  for name, version in pinned.items() if tools.get(name) != version]
    if mismatches: raise HarnessError("mise toolchain mismatch: " + "; ".join(mismatches))
    if not (ROOT / "CLAUDE.md").read_text().startswith("@AGENTS.md"): raise HarnessError("CLAUDE.md import missing")
    ids = [item["id"] for item in read(PLAN)["tasks"]]
    if len(ids) != len(set(ids)): raise HarnessError("duplicate task ids")


def doctor(strict=False):
    expected = config()["toolchain"]; errors, warnings = [], []
    flutter = flutter_bin()
    if flutter:
        version = first([str(flutter), "--version"]); print(f"OK flutter path={flutter} version={version}")
        if expected["flutter"] not in version: errors.append(f"expected Flutter {expected['flutter']}: {version}")
        if str(flutter).startswith(("/tmp/", "/private/tmp/")): warnings.append("Flutter SDK is ephemeral")
    else: errors.append("Flutter missing; set FLUTTER_BIN or FLUTTER_ROOT")
    node_path = tool_bin("node")
    node = first([str(node_path or "node"), "--version"]); print(f"OK node path={node_path or 'missing'} version={node}")
    major = re.search(r"v(\d+)", node)
    if not major or int(major.group(1)) != expected["functionsNodeMajor"]:
        errors.append(f"Functions expects Node {expected['functionsNodeMajor']}, found {node}")
    elif node.removeprefix("v") != expected["node"]:
        errors.append(f"expected Node {expected['node']}, found {node}")
    firebase_path = tool_bin("firebase")
    firebase = first([str(firebase_path or "firebase"), "--version"])
    print(f"{'OK' if firebase_path else 'WARN'} firebase={firebase_path or 'missing'} version={firebase}")
    if not firebase_path:
        errors.append("Firebase CLI missing; run mise install")
    elif expected["firebase"] not in firebase:
        errors.append(f"expected Firebase CLI {expected['firebase']}, found {firebase}")
    java_path = tool_bin("java")
    java = first([str(java_path or "java"), "-version"])
    print(f"{'OK' if java_path else 'WARN'} java={java_path or 'missing'} version={java}")
    java_major = re.search(r'version "(\d+)', java)
    if not java_path or not java_major or int(java_major.group(1)) < expected["emulatorsJavaMajor"]:
        errors.append(f"Firebase Emulator expects Java {expected['emulatorsJavaMajor']}+, found {java}")
    for name in ("git", "python3", "npm", "xcodebuild", "pod", "claude", "codex"):
        path = tool_bin(name)
        print(f"{'OK' if path else 'WARN'} {name}={path or 'missing'}")
    warnings.append("Riverpod codegen is deferred until analyzer dependencies are upgraded")
    for message in errors: print("ERROR " + message)
    for message in warnings: print("WARN " + message)
    return 1 if strict and errors else 0


def check(folder, check_id, command, cwd=ROOT, timeout=1800):
    log = folder / "logs" / f"{check_id}.log"; log.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy(); env.update({"CI": "true", "FLUTTER_SUPPRESS_ANALYTICS": "true", "NO_COLOR": "1"})
    managed_dirs = []
    for name in ("node", "flutter", "firebase", "java"):
        if path := mise_tool_bin(name): managed_dirs.append(str(path.parent))
    if managed_dirs: env["PATH"] = os.pathsep.join([*dict.fromkeys(managed_dirs), env.get("PATH", "")])
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        code, output = result.returncode, result.stdout
    except (OSError, subprocess.TimeoutExpired) as exc: code, output = 127, str(exc)
    log.write_text(output, encoding="utf-8")
    summary = "\n".join(output.splitlines()[-20:]) if code else ""
    return {"id": check_id, "status": "pass" if code == 0 else "fail", "exit": code,
            "durationMs": int((time.monotonic() - started) * 1000),
            "log": str(log.relative_to(ROOT)), "summary": summary}


def validation_target(explicit=None):
    if explicit: return explicit
    held = lock()
    if held:
        selected = task(read(PLAN), held["taskId"]).get("target")
        if selected in {"ios", "android", "web"}: return selected
    return config()["toolchain"]["defaultStandardTarget"]


def validation_compile_targets(lane, selected):
    if lane == "standard": return (selected,)
    if lane == "full" and selected == "ios": return ("ios", "android")
    if lane == "full" and selected == "android": return ("android",)
    return ()


def verify(lane, target=None):
    files, fp = changed_files(), fingerprint(); routes = route_files(files)
    effective = "standard" if lane == "fast" and "unknown" in routes else lane
    selected = validation_target(target)
    if effective == "full": routes.update(("flutter", "functions", "ui", selected))
    head = git("rev-parse", "--short", "HEAD").strip()
    run_id = f"{head}-{fp[:8]}-{effective}-{int(time.time())}"
    folder = runtime() / "runs" / run_id; folder.mkdir(parents=True)
    checks = []
    try: metadata(); checks.append({"id": "metadata", "status": "pass", "exit": 0, "durationMs": 0, "log": "", "summary": ""})
    except Exception as exc: checks.append({"id": "metadata", "status": "fail", "exit": 1, "durationMs": 0, "log": "", "summary": str(exc)})
    checks.append(check(folder, "harness-tests", [sys.executable, "-m", "unittest", "discover", "-s", "tool/tests", "-p", "test_agent_harness.py"]))
    checks.append(check(folder, "shell-syntax", ["bash", "-n", "bin/harness", ".claude/hooks/pre-commit-check.sh", ".claude/hooks/pre-deploy-check.sh"]))
    if "javascript" in routes:
        for path in (ROOT / name for name in files if name.endswith((".js", ".mjs", ".cjs"))):
            if path.exists(): checks.append(check(folder, "node-" + path.stem, ["node", "--check", str(path)]))
    if "shell" in routes:
        paths = [name for name in files if name.endswith((".sh", ".bash")) and (ROOT / name).exists()]
        if paths: checks.append(check(folder, "changed-shell-syntax", ["bash", "-n", *paths]))
    if "unknown" in routes:
        unknown = [name for name in files if route_files([name]) == {"unknown"}]
        checks.append({"id": "unknown-route", "status": "fail", "exit": 1, "durationMs": 0,
                       "log": "", "summary": "add a deterministic route for: " + ", ".join(unknown[:20])})
    flutter, expected = flutter_bin(), config()["toolchain"]
    if "flutter" in routes:
        dart = flutter.parent / "dart" if flutter else None
        if not flutter or not dart or not dart.is_file():
            checks.append({"id": "flutter-toolchain", "status": "fail", "exit": 127, "durationMs": 0, "log": "", "summary": "run harness doctor"})
        else:
            version = first([str(flutter), "--version"]); ok = expected["flutter"] in version or effective == "fast"
            checks.append({"id": "flutter-toolchain", "status": "pass" if ok else "fail", "exit": 0 if ok else 1, "durationMs": 0, "log": "", "summary": "" if ok else version})
            darts = [name for name in files if name.endswith(".dart") and (ROOT / name).exists()]
            if darts: checks.append(check(folder, "dart-format", [str(dart), "format", "--output=none", "--set-exit-if-changed", *darts]))
            checks.append(check(folder, "dart-analyze", [str(dart), "analyze"]))
            checks.append(check(folder, "flutter-test", [str(flutter), "test", "--no-pub", "--test-randomize-ordering-seed=0", "--concurrency=1", "--reporter", "compact"]))
            if "ui" in routes:
                ui = check(folder, "ui-check", [str(dart), "run", "scripts/ui_check.dart", "--summary"])
                if ui["status"] == "pass":
                    output = (ROOT / ui["log"]).read_text()
                    match = re.search(r"(\d+) warnings", output)
                    baseline = config()["validation"]["uiWarningBaseline"]
                    if match and int(match.group(1)) > baseline:
                        ui.update({"status": "fail", "exit": 1,
                                   "summary": f"UI warnings {match.group(1)} exceed baseline {baseline}"})
                checks.append(ui)
            builds = {"ios": [str(flutter), "build", "ios", "--simulator", "--debug", "--no-pub"],
                      "android": [str(flutter), "build", "apk", "--debug", "--no-pub"],
                      "web": [str(flutter), "build", "web", "--release", "--no-pub"]}
            for build_target in validation_compile_targets(effective, selected):
                checks.append(check(folder, build_target + "-compile", builds[build_target], timeout=3600))
            if effective == "full":
                release_builds = {
                    "android": [str(flutter), "build", "appbundle", "--release", "--no-pub"],
                    "ios": [str(flutter), "build", "ios", "--release", "--no-codesign", "--no-pub"],
                    "web": [str(ROOT / "build_web.sh"),
                            "production" if git("branch", "--show-current").strip() == "master" else "development"],
                }
                checks.append(check(folder, selected + "-release", release_builds[selected], timeout=3600))
    if "functions" in routes:
        node_path = tool_bin("node")
        node = first([str(node_path or "node"), "--version"]); major = re.search(r"v(\d+)", node)
        ok = bool(major and int(major.group(1)) == expected["functionsNodeMajor"]) or effective == "fast"
        checks.append({"id": "node-runtime", "status": "pass" if ok else "fail", "exit": 0 if ok else 1, "durationMs": 0, "log": "", "summary": "" if ok else node})
        function_scripts = {
            path for pattern in ("*.js", "*.mjs", "*.cjs")
            for path in (ROOT / "functions").glob(pattern)
        }
        for path in sorted(function_scripts):
            checks.append(check(folder, "node-" + path.stem, [str(node_path or "node"), "--check", str(path)]))
        npm_path = tool_bin("npm")
        checks.append(check(folder, "functions-unit", [str(npm_path or "npm"), "run", "test:unit", "--", "--runInBand", "--ci", "--colors=false"], cwd=ROOT / "functions"))
        checks.append(check(folder, "functions-rules", [str(npm_path or "npm"), "run", "test:rules"], cwd=ROOT / "functions"))
    status = "pass" if all(item["status"] == "pass" for item in checks) else "fail"
    failure_signature = None
    failure_attempt = 0
    if status == "fail":
        failures = [(item["id"], item["summary"]) for item in checks if item["status"] == "fail"]
        failure_signature = hashlib.sha256(json.dumps(failures).encode()).hexdigest()
        previous_path = runtime() / "latest_validation.json"
        previous = read(previous_path) if previous_path.exists() else {}
        failure_attempt = previous.get("failureAttempt", 0) + 1 if previous.get("failureSignature") == failure_signature else 1
        if failure_attempt > config()["coordination"]["maxRepairAttempts"]:
            status = "blocked"
    record = {"schemaVersion": 1, "runId": run_id, "status": status, "laneRequested": lane,
              "laneEffective": effective, "target": locals().get("selected", target), "head": head, "fingerprint": fp,
              "changedFiles": files, "routes": sorted(routes), "checks": checks,
              "failureSignature": failure_signature, "failureAttempt": failure_attempt,
              "artifacts": {"web": directory_digest(ROOT / "build/web")}
              if effective == "full" and selected == "web" else {}}
    write(folder / "run.json", record); write(runtime() / "latest_validation.json", record)
    passed = sum(item["status"] == "pass" for item in checks)
    print(f"{status.upper()} run={run_id} checks={passed}/{len(checks)} logs={folder.relative_to(ROOT)}")
    for item in checks:
        if item["status"] == "fail": print(f"FAIL {item['id']}: {item['summary'][:1600]}")
    return 0 if status == "pass" else 1


def gate(required):
    path = runtime(False) / "latest_validation.json"
    if not path.exists(): return False, f"run ./bin/harness verify --lane {required}"
    record = read(path)
    if record.get("status") != "pass" or record.get("fingerprint") != fingerprint():
        return False, f"validation failed or stale; run ./bin/harness verify --lane {required}"
    actual = record.get("laneEffective", "fast")
    if RANK.get(actual, 0) < RANK[required]: return False, f"{required} required; run verify --lane {required}"
    if required == "full" and record.get("target") == "web" and record.get("artifacts", {}).get("web") != directory_digest(ROOT / "build/web"):
        return False, "release artifact changed after validation; run verify --lane full"
    return True, "current"


def command_parts(command):
    git_push = re.search(r"\bgit\b[^\n;&|]*\bpush\b[^\n;&|]*", command)
    git_commit = re.search(r"\bgit\b[^\n;&|]*\bcommit\b[^\n;&|]*", command)
    deploy = re.search(r"\b(firebase\b[^\n;&|]*\bdeploy|vercel\b[^\n;&|]*--prod|netlify\b[^\n;&|]*\bdeploy|npm\b[^\n;&|]*\b(?:run\s+)?deploy\b)|(?:\./)?scripts/deploy_environment\.sh\b", command)
    release_build = re.search(r"(flutter\b[^\n;&|]*\bbuild\b[^\n;&|]*--release|(?:\./)?build_web\.(?:sh|ps1))", command)
    return git_push, git_commit, deploy, release_build


def required_lane(command):
    git_push, git_commit, deploy, release_build = command_parts(command)
    if deploy or release_build: return "full"
    if git_push:
        push_text = git_push.group()
        current_release_branch = git("branch", "--show-current").strip() == "master"
        explicit_release_branch = bool(re.search(r"(?:^|\s)(?:\S+:)?master(?:\s|$)", push_text))
        return "full" if current_release_branch or explicit_release_branch else "standard"
    if git_commit: return "standard"
    return None


def command_gate(command):
    git_push, git_commit, deploy, release_build = command_parts(command)
    if git_push and re.search(r"(?:--force(?:-with-lease)?|-f\b|--mirror\b|--delete\b|(?:^|\s)\+\S+)", git_push.group()): return "destructive push blocked"
    if git_commit and "--amend" in git_commit.group(): return "commit amend blocked"
    if deploy and release_build: return "build and deploy must be separate; run verify --lane full"
    required = required_lane(command)
    if required:
        ok, reason = gate(required)
        return None if ok else reason
    return None


def bash_mutates(command):
    return bool(re.search(
        r"(?:^|[;&|]\s*)(?:rm|mv|cp|touch|mkdir|chmod|chown|install|tee|truncate|apply_patch)\b"
        r"|\b(?:sed|perl)\s+-i\b|(?:^|[^<])>>?[^=]|\b(?:npm|pnpm|yarn)\s+(?:install|add|remove)\b",
        command,
    ))


def task(plan, task_id):
    for item in plan["tasks"]:
        if item["id"] == task_id: return item
    raise HarnessError("unknown task " + task_id)


def normalized_path(path):
    candidate = Path(path)
    if not candidate.is_absolute(): candidate = ROOT / candidate
    try: return str(candidate.resolve(strict=False).relative_to(ROOT))
    except ValueError: return None


def path_allowed(path, patterns):
    normalized = normalized_path(path)
    return normalized is not None and any(fnmatch.fnmatch(normalized, pattern) for pattern in patterns)


def lock_path(): return runtime(False) / "writer_lock.json"
def lock(): return read(lock_path()) if lock_path().exists() else None


def print_plan():
    value = read(PLAN); print(f"{value['project']} milestone={value['milestone']}")
    for item in value["tasks"]: print(f"{item['id']} {item['status']:<11} owner={item['owner'] or '-'} budget={item['budget']} target={item['target']} {item['title']}")


def claim(task_id, agent, force=False):
    runtime()
    value, held = read(PLAN), lock(); item = task(value, task_id)
    if held and held["agent"] == agent and held["taskId"] == task_id:
        print(f"CLAIMED task={task_id} agent={agent} already-held"); return
    if held and not force: raise HarnessError(f"lease held by {held['agent']} for {held['taskId']}")
    if item["status"] == "done": raise HarnessError("task already done")
    if held and force:
        claimed = dt.datetime.fromisoformat(held["claimedAt"])
        stale = dt.timedelta(hours=config()["coordination"]["staleLockHours"])
        if dt.datetime.now(dt.timezone.utc) - claimed < stale:
            raise HarnessError(f"live lease cannot be forced; stale after {stale}")
        previous = task(value, held["taskId"])
        if previous["status"] == "in_progress": previous.update({"status": "ready", "owner": None})
        lock_path().unlink()
    lock_data = json.dumps({"taskId": task_id, "agent": agent, "host": socket.gethostname(),
                            "claimedAt": dt.datetime.now(dt.timezone.utc).isoformat()}).encode()
    try:
        descriptor = os.open(lock_path(), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "wb") as handle: handle.write(lock_data)
    except FileExistsError:
        raise HarnessError("writer lease was claimed concurrently")
    item.update({"status": "in_progress", "owner": agent}); value["updatedAt"] = dt.date.today().isoformat()
    write(PLAN, value)
    print(f"CLAIMED task={task_id} agent={agent}")


def release(agent, force=False):
    held = lock()
    if not held: print("RELEASED no active lease"); return
    if held["agent"] != agent and not force: raise HarnessError("lease belongs to " + held["agent"])
    if held["agent"] != agent and force:
        claimed = dt.datetime.fromisoformat(held["claimedAt"])
        stale = dt.timedelta(hours=config()["coordination"]["staleLockHours"])
        if dt.datetime.now(dt.timezone.utc) - claimed < stale:
            raise HarnessError(f"live lease cannot be released; stale after {stale}")
    value = read(PLAN); item = task(value, held["taskId"])
    if item["status"] == "in_progress":
        item.update({"status": "ready", "owner": None})
        value["updatedAt"] = dt.date.today().isoformat(); write(PLAN, value)
    lock_path().unlink(); print(f"RELEASED task={held['taskId']}")


def handoff(task_id, source, target, summary, next_step, status):
    value, held = read(PLAN), lock(); item = task(value, task_id)
    if not held or held["taskId"] != task_id or held["agent"] != source: raise HarnessError("writer lease required")
    outside = [name for name in changed_files() if not path_allowed(name, item["allowedPaths"])]
    if outside: raise HarnessError("changed files outside allowedPaths: " + ", ".join(outside[:20]))
    if status != "blocked":
        ok, reason = gate(item["validationLane"])
        if not ok: raise HarnessError(reason)
        latest = read(runtime(False) / "latest_validation.json")
        if item.get("target") not in {None, "none"} and latest.get("laneEffective") != "full":
            check_id = item["target"] + "-compile"
            compiled = any(check.get("id") == check_id and check.get("status") == "pass" for check in latest.get("checks", []))
            if not compiled: raise HarnessError(f"task target {item['target']} compile evidence missing")
    item["status"] = status; value["updatedAt"] = dt.date.today().isoformat(); write(PLAN, value)
    latest = read(runtime(False) / "latest_validation.json") if (runtime(False) / "latest_validation.json").exists() else {}
    HANDOFF.write_text(f"# AI handoff\n\n- Task: {task_id} — {item['title']}\n- From/To: {source} -> {target}\n- State: {status}\n- Summary: {summary[:240]}\n- Changed: {', '.join(changed_files()[:12])}\n- Verification: {latest.get('runId', 'none')} ({latest.get('status', 'none')})\n- Next: {next_step[:240]}\n")
    lock_path().unlink(); print(f"HANDOFF task={task_id} to={target} state={status}")


def context(agent=None):
    value, held = read(PLAN), lock()
    lines = [f"BIBLE_SPEAK_HARNESS agent={agent or 'interactive'} branch={git('branch', '--show-current').strip()}",
             f"milestone={value['milestone']} fingerprint={fingerprint()[:10]}",
             f"writer={held['agent'] + ':' + held['taskId'] if held else 'none'}"]
    for item in value["tasks"]:
        if item["status"] in {"ready", "in_progress", "review", "blocked"}:
            lines.append(f"task {item['id']} status={item['status']} owner={item['owner'] or '-'} budget={item['budget']} lane={item['validationLane']} target={item['target']} title={item['title']}")
    latest_path = runtime(False) / "latest_validation.json"
    if latest_path.exists():
        latest = read(latest_path)
        lines.append(f"validation={latest.get('status')} lane={latest.get('laneEffective')} fresh={latest.get('fingerprint') == fingerprint()} run={latest.get('runId')}")
        failed = next((item for item in latest.get("checks", []) if item.get("status") == "fail"), None)
        if failed: lines.append(f"failure={failed['id']} attempt={latest.get('failureAttempt')} digest={failed.get('summary', '')[:300]}")
    return "\n".join(lines)[:config()["context"]["maxChars"]]


def hook(event, agent):
    if event == "session-start": print(context(agent)); return 0
    try: payload = json.load(sys.stdin)
    except json.JSONDecodeError: return 0
    value = payload.get("tool_input") or {}
    tool_name = payload.get("tool_name", "")
    if tool_name in {"apply_patch", "Edit", "Write"}:
        held = lock()
        if not held or held["agent"] != agent:
            print("BLOCKED: writer lease required for edits", file=sys.stderr); return 2
        item = task(read(PLAN), held["taskId"])
        paths = []
        if isinstance(value, dict):
            paths += [value[key] for key in ("file_path", "path") if isinstance(value.get(key), str)]
            patch = value.get("command", "")
            paths += re.findall(r"\*\*\* (?:Add|Update|Delete) File: (.+)", patch)
            paths += re.findall(r"\*\*\* Move to: (.+)", patch)
        for path in paths:
            relative = normalized_path(path)
            if relative is None or not path_allowed(relative, item["allowedPaths"]):
                print(f"BLOCKED: {relative} is outside task allowedPaths", file=sys.stderr); return 2
    if tool_name == "Bash" and isinstance(value, dict) and bash_mutates(value.get("command", "")):
        held = lock()
        if not held or held["agent"] != agent:
            print("BLOCKED: writer lease required for mutating Bash", file=sys.stderr); return 2
    reason = command_gate(value.get("command", "") if isinstance(value, dict) else "")
    if reason: print("BLOCKED: " + reason, file=sys.stderr); return 2
    return 0


def observed_tokens(record):
    usage = record.get("usage") or {}
    return sum(value for key in ("input_tokens", "output_tokens", "cached_input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens") if isinstance((value := usage.get(key)), int))


def dispatch(args):
    item = task(read(PLAN), args.task)
    if args.role == "implement" and (not lock() or lock()["taskId"] != args.task or lock()["agent"] != args.agent):
        raise HarnessError("implementation requires writer lease")
    prompt = Path(args.prompt_file).read_text()
    if len(prompt) > 12000: raise HarnessError("prompt exceeds 12000 characters")
    prompt = f"Task {item['id']}: {item['title']}\nFollow AGENTS.md. Return a compact result.\n\n{prompt}"
    if args.agent == "claude":
        role = config()["budgets"]["claude"]["roles"][args.role]
        command = ["claude", "-p", "--output-format", "json", "--no-session-persistence", "--model", role["model"], "--effort", role["effort"], "--max-turns", str(args.max_turns or role["maxTurns"]), "--permission-mode", "acceptEdits" if args.role == "implement" else "plan"]
    else: command = ["codex", "exec", "--json", "--ephemeral", "-C", str(ROOT), "-s", "workspace-write" if args.role == "implement" else "read-only", "-"]
    if args.dry_run: print("DRY_RUN " + shlex.join(command)); return 0
    started = time.monotonic(); result = subprocess.run(command, cwd=ROOT, text=True, input=prompt, capture_output=True, timeout=args.timeout_minutes * 60)
    run_id = f"{args.agent}-{args.task}-{int(time.time())}"; folder = runtime() / "agent-runs"; folder.mkdir(parents=True, exist_ok=True)
    raw = folder / (run_id + ".jsonl"); raw.write_text(result.stdout + result.stderr); raw.chmod(0o600)
    payloads = []
    for line in ([result.stdout] if args.agent == "claude" else result.stdout.splitlines()):
        try: payloads.append(json.loads(line))
        except json.JSONDecodeError: pass
    if args.agent == "claude":
        output = payloads[-1] if payloads else {}; usage = output.get("usage", {})
        extra = {"totalCostUsd": output.get("total_cost_usd"), "numTurns": output.get("num_turns")}
    else:
        usage, extra = {}, {}
        for output in payloads:
            if output.get("type") == "turn.completed": usage = output.get("usage", {})
    record = {"runId": run_id, "agent": args.agent, "role": args.role, "taskId": args.task, "exit": result.returncode, "usage": usage, **extra}
    ledger = runtime() / "usage.jsonl"
    with ledger.open("a") as handle: handle.write(json.dumps(record) + "\n")
    ledger.chmod(0o600)
    tokens = observed_tokens(record); warning = f" soft-limit-exceeded={args.soft_token_limit}" if args.soft_token_limit and tokens > args.soft_token_limit else ""
    print(f"{'PASS' if result.returncode == 0 else 'FAIL'} run={run_id} tokens={tokens} ms={int((time.monotonic()-started)*1000)} log={raw.relative_to(ROOT)}{warning}")
    return result.returncode


def usage():
    path = runtime(False) / "usage.jsonl"
    if not path.exists(): print("No recorded headless usage."); return
    rows = [json.loads(line) for line in path.read_text().splitlines() if line]; totals = {}
    for row in rows: totals[row["agent"]] = totals.get(row["agent"], 0) + observed_tokens(row)
    print(f"runs={len(rows)} " + " ".join(f"{key}_observed_tokens={value}" for key, value in sorted(totals.items())))


def parser():
    value = argparse.ArgumentParser(); sub = value.add_subparsers(dest="command", required=True)
    item = sub.add_parser("doctor"); item.add_argument("--strict", action="store_true")
    sub.add_parser("plan")
    item = sub.add_parser("context"); item.add_argument("--agent", choices=("codex", "claude"))
    item = sub.add_parser("claim"); item.add_argument("task"); item.add_argument("--agent", required=True, choices=("codex", "claude")); item.add_argument("--force", action="store_true")
    item = sub.add_parser("release"); item.add_argument("--agent", required=True, choices=("codex", "claude")); item.add_argument("--force", action="store_true")
    item = sub.add_parser("verify"); item.add_argument("--lane", choices=tuple(RANK), default="fast"); item.add_argument("--target", choices=("ios", "android", "web"))
    item = sub.add_parser("handoff"); item.add_argument("task"); item.add_argument("--from-agent", required=True, choices=("codex", "claude")); item.add_argument("--to", required=True, choices=("codex", "claude", "human")); item.add_argument("--summary", required=True); item.add_argument("--next", required=True, dest="next_step"); item.add_argument("--status", choices=("review", "blocked", "ready"), default="review")
    item = sub.add_parser("hook"); item.add_argument("event", choices=("session-start", "pre-tool-use")); item.add_argument("--agent", required=True, choices=("codex", "claude"))
    item = sub.add_parser("dispatch"); item.add_argument("--agent", required=True, choices=("codex", "claude")); item.add_argument("--role", required=True, choices=("explore", "review", "implement", "architecture")); item.add_argument("--task", required=True); item.add_argument("--prompt-file", required=True); item.add_argument("--max-turns", type=int); item.add_argument("--soft-token-limit", type=int); item.add_argument("--timeout-minutes", type=int, default=30); item.add_argument("--dry-run", action="store_true")
    sub.add_parser("usage"); return value


def main():
    args = parser().parse_args()
    if args.command == "doctor": return doctor(args.strict)
    if args.command == "plan": print_plan()
    elif args.command == "context": print(context(args.agent))
    elif args.command == "claim": claim(args.task, args.agent, args.force)
    elif args.command == "release": release(args.agent, args.force)
    elif args.command == "verify": return verify(args.lane, args.target)
    elif args.command == "handoff": handoff(args.task, args.from_agent, args.to, args.summary, args.next_step, args.status)
    elif args.command == "hook": return hook(args.event, args.agent)
    elif args.command == "dispatch": return dispatch(args)
    elif args.command == "usage": usage()
    return 0


if __name__ == "__main__":
    try: raise SystemExit(main())
    except HarnessError as exc: print("ERROR " + str(exc), file=sys.stderr); raise SystemExit(2)
