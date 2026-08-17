# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, GitHub Copilot, and others) when working with code in this repository. `CLAUDE.md` and `.github/copilot-instructions.md` point here so the guidance lives in one place.

## What this repository is

A vendored Perl utility library originally from mySociety (UK Citizens Online Democracy), providing RABX serialisation/RPC (`RABX.pm`, `RABX/`), `mySociety/` helper modules, and `File/` and `Geo/` utilities. It is consumed as a git submodule of [`openaustralia/openaustralia`](https://github.com/openaustralia/openaustralia), the umbrella repository for OpenAustralia.org.au, alongside the `twfy` PHP app.

Changes here are rare and there is no build step or CI; `test.pl` is the only test script. Issues for the wider project are tracked on the umbrella repository. After merging a change here, the umbrella repository's submodule pointer needs bumping before OpenAustralia.org.au picks it up.

## Contributing

This repository has no `CONTRIBUTING.md` or templates of its own; the org-wide ones in [`openaustralia/.github`](https://github.com/openaustralia/.github) apply. Fetch the current versions rather than relying on a copy:

`curl -fsSL https://raw.githubusercontent.com/openaustralia/.github/main/.github/CONTRIBUTING.md`

`curl -fsSL https://raw.githubusercontent.com/openaustralia/.github/main/AGENTS.md`

Any equivalent fetch of those URLs works (web fetch, or `gh api` if the GitHub CLI
is installed); don't assume a particular tool is present.
