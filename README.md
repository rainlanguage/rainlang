# rainlang

Solidity docs can be generated with `nix develop --command forge doc -b`.

Rust docs with `nix develop --command cargo doc`.

## Overview

Standard libraries and interfaces defining and working with `InterpeterState`
including:

- the standard `eval` loop
- source compilation from opcodes
- state (de)serialization (more gas efficient than abi encoding)

Interpreters are designed to be highly moddable behind the `IInterpreterV4`
interface, but pretty much any interpreter that uses `InterpreterState` will
need these low level facilities verbatim. Further, these facilities (with
possible exception of debugging logic), while relatively short in terms of lines
of code, are surprisingly fragile to maintain in a gas efficient way so we don't
recommend reinventing this wheel.

## Versioning

Stability and versioning is achieved at the interface level. All interfaces and
types exposed externally by an interface are versioned.

The most obvious place this fails is when a breaking change cannot be expressed
in Solidity's type system.

For example, the ordering of "top to bottom" of a stack returned by an
interpreter, represented as a `uint256[]` was reversed between `eval` and
`eval2`. The compiler cannot protect downstream contracts from such a change,
even if we were to scream it in the code comments, so such changes are
considered dangerous and justify a version number at the method level (e.g.
`eval`, `eval2`, through to the current `eval4`).

The goal is to intentionally loudly break things at the compiler level, or at
least _reliably_ at runtime (i.e. unconditionally erroring every call to X). We
do NOT want to make silent subtle changes on the hope that nobody was relying on
the old behaviours.

### Unstable interfaces

An unstable interface MAY be used by a current implementation in this repo as
the goal is always to move unstable interfaces to stability.

The practical challenge for achieving stability is that it has to be informed by
usage, or at least attempted usage.

Stability is therefore _observed_ in some interface, based on some (subjective)
amount of usage in a concrete implementation without the kind of feedback that
necessitates a modification.

### Deprecated interfaces

Deprecated interfaces are those that were completely stable, with deployed
concrete implementations, then replaced by a new implementation of an unstable
interface.

As there are immutable concrete implementations in production of these ex-stable
interfaces, we keep the interfaces so that third party contracts can continue to
consume existing deployments.

This is important for existing deployments to leverage their "lindy", as often
the old battletested thing can be much safer than the new shiny thing.

### NO semver

We do NOT use semver because it requires us to make subjective assessments with
imperfect information about concepts like "breaking" or "bug".

## Branches

`main` includes the latest implementations of the latest interfaces, including
unstable interfaces.

While we keep deprecated interfaces around for a long time, we try to avoid
cruft of deprecated concrete implementations, libs and tests. This cruft can
really hinder the ability to move through necessary refactors, so it has to be
culled often.

As every commit is deployed to a testnet by CI, and is immutable onchain and can
be cross deployed to other chains, there's no need to try to couple what's
happening in this repo with onchain realities, other than at the interface
level.

There are some branches that were forked from `main` for historical reasons,
that MAY be of interest situationally, but otherwise should be ignored.

- `main-np`: Forked from the last commit using `eval` before `eval2` was the
  primary interface into the interpreter (now superseded by `eval4`). No longer
  actively developed.
