---
name: deploy
description: Validate a Bible Speak release candidate before an authorized deployment.
---

Run `./bin/harness verify --lane full`. Deploy only the explicitly requested target after all release builds pass, then perform a live smoke check. The gate blocks stale or incomplete validation. Never inject provider secrets into Flutter/web assets.
