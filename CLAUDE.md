# CLAUDE.md

Guidance for Claude Code in this repo. This file takes precedence over session
summaries — re-read it as written rather than trusting a summary's framing of
what a process means.

## What this repo is

The **library half** of Rainlang: the parser, eval loop, standard ops, integrity
checks, the `BaseRainlang*` contracts and the extern / sub-parser bases,
published as the `rainlang` Soldeer package on every merge to main
(`rainix-autopublish`, next-version lifecycle via `next-v*` tags). The deployed
concretes, their generated tables and deploy records, the deploy scripts and the
Rust crates live in `rainlang.deploy`, which consumes this package.

`src/concrete/extern/RainlangReferenceExtern.sol` is a reference implementation
of the extern and sub-parser bases, not a deployable: it stays here with its
tests.

## Generated code

`script/Build.sol` writes `src/generated/RainlangReferenceExternPointers.sol` —
the reference extern's parse meta, function pointer tables and meta hash.
Committed because contract and pointers file depend on each other circularly.
Never hand-edit it. `src/generated/0_1_9/` is the frozen record of the last
release this repo cut while it still carried the deploy half; nothing here reads
it, and it stays because frozen snapshots are append-only org-wide (rainix
`frozen-snapshots-append-only`). After any source change affecting the extern's
bytecode:

1. `nix develop -c rainlang-prelude`
2. `nix develop -c forge script --silent ./script/Build.sol`
3. `nix develop -c forge fmt`

Address all `forge build` warnings before pointer rebuild, tests, or the next
task.

## Test harness

`test/concrete/Test*.sol` are the `BaseRainlang*` contracts built from current
source with no generated tables; `test/lib/deploy/LibTestInterpreterDeploy.sol`
places them at fixed test addresses and
`test/abstract/RainlangCompilerDeploymentTest.deployRainlang()` is the one hook
that binds them. `rainlang.deploy` and the word repos override that hook with
the deployed pins, so `test/` ships in the package: `/test` is deliberately
absent from `.soldeerignore`.

`optimizer_runs = 1000000` looks wrong (the org uses 100000) and is
load-bearing: every live CREATE2 address in `rainlang.deploy` is a pure function
of the bytecode this package's sources compile to.

## Conventions

- Compiler, optimizer and fuzz settings: `foundry.toml` is the source of truth.
- NatSpec: if a doc block has any explicit tag, every entry must be tagged —
  untagged lines continue the previous tag, not implicit `@notice`.
- Tests: read `TESTING.md` before writing tests. Run test commands with
  `run_in_background: true` and continue independent work meanwhile.

## Process (Jidoka)

Process correctness (correct future) over ad hoc progress (present state). Each
fix is a complete cycle: understand → write test → run it (confirm it fails) →
fix → run it (confirm it passes) → full suite → verify. Never write the fix
before the failing test reproduces the bug. Do not move on with incomplete work;
new code meets the `/audit` skill's requirements.

"jidoka" from the user signals a process defect: identify it, propose a durable
fix (document edit, rule change), then STOP and wait for agreement — the process
fix is the deliverable of that moment. A "why" question asks for root cause
analysis of the process failure, not for the task to be done.

Do not claim motivations or internal states. Describe what you actually did ("I
skipped the test suite run"), not a story about why — you have no metrics, no
persistence, no self-observation; narratives about your own reasoning are
fabrications.
