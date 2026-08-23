---
name: commit
description: Validate and create a scoped Bible Speak commit.
---

Run `./bin/harness verify --lane standard`, inspect the diff for secrets, stage explicit task files, and create a new Conventional Commit. Never amend or force-push. The shared PreToolUse gate blocks a commit when validation is missing or stale.
