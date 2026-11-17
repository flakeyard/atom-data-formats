---
id: ADR-0001
title:
  Format and lint YAML, JSON and TOML with prettier, taplo, yamllint, biome and
  check-jsonschema
status: accepted
date: 2026-11-17
supersedes: []
superseded_by: []
related: []
affects:
  ["flake.nix", "flake.lock", "nix/**", "config/**", "dev/**", "README.md"]
review_by:
---

## Context

atom-data-formats is an atom of step 5 of [FY-0038][fy-0038]. It owns YAML, JSON
and TOML and the schemas of data files: prettier for YAML and JSON, taplo for
TOML, yamllint, biome lint for JSON, taplo lint, and check-jsonschema with the
schemas its package ships for the metadata of actions, Renovate, Dependabot and
issue templates; workflows are left to atom-workflows ([FY-0017][fy-0017]).
Decisions of flakeyard require of it:

- [FY-0017][fy-0017]: inputs are exactly the upstream flakes whose modules the
  atom imports, each checked against the consumer's input of the same name
  before the import. Upstream options are set with `lib.mkOverride 900`, lists
  that upstream defines at plain priority at plain priority, and tool packages
  come from the consumer's `pkgs`. prettier has two owners: atom-markdown for
  Markdown and this atom for YAML and JSON, each under a formatter name of its
  own and over files the other does not format, and a project's prettier
  configuration replaces the default of both. Hook ids and formatter names that
  upstream does not define start with `flakeyard-`. The domain has one check,
  built with `lib.<system>.run` of git-hooks.nix from only the domain's hooks
  and the project's global excludes, over the project's source filtered at most
  by the `files` of those hooks, without network access.
- [FY-0037][fy-0037]: every tool with a configuration gets flakeyard's default
  from `config/`, a project's file at the tool's standard path at the root
  replaces it wholly, the chosen file reaches the tool by flag as a store path
  of its own, and a project file in a form the atom cannot pass fails evaluation
  with a message that names it. Ignore files are configuration files, and a tool
  that reads discovered files despite the flag is documented and asserted by a
  fixture.
- [FY-0015][fy-0015], [FY-0024][fy-0024] and [FY-0038][fy-0038]: the files that
  tools write are excluded, which atom-workspace does with
  `workspace.generated`; releases start at `v0.1.0` with the moving tag `v0`; a
  stricter default ships first under `config/next/`; the warning of the next
  major version lives in `nix/next-major.nix`.
- [FY-0040][fy-0040]: the check of `follows`, the warning of the next major
  version, the choice of configuration files, the configuration files of
  prettier and the files of a domain are functions of lib-atom, which the atom
  pins in its own `flake.lock`, and the helpers of the tests come from its
  `internal/testing`.

Reading git-hooks.nix at `204b6977` and treefmt-nix at `0d6d739a`, and running
the tools of `nixos-26.05` at `ac588ef1` (prettier 3.8.3, taplo 0.10.0, yamllint
1.37.1, biome 2.4.15, check-jsonschema 0.37.2), showed:

- treefmt-nix defines `programs.prettier`, which atom-markdown owns, and
  `programs.taplo`, which runs `taplo format` and adds `--config` only when
  `programs.taplo.settings` is set. `settings.formatter.<name>` takes any name
  with a `command`, `options` and `includes`.
- git-hooks.nix defines the hook `yamllint` with `types = [ "file" "yaml" ]` and
  no `files`; it passes `settings.configPath` with `--config-file` when no
  inline configuration or preset is set, and `--strict` by default. Its hook
  `biome` runs `biome check`, which also formats, over JavaScript, TypeScript
  and JSON, and its hook `taplo` runs `taplo fmt`. It has no hook of
  check-jsonschema.
- prettier keeps the value of block scalars with the indicator `+`, adds
  trailing commas to `.jsonc` files, and reads `.editorconfig`,
  `.prettierignore` and `.gitignore` also with `--config`; it ignores JavaScript
  configurations with `--config`. With prettier's defaults it changes 2 of the
  177 YAML and JSON files of flakeyard's repositories, outside fixtures and
  generated files.
- yamllint with `--config-file` reads no other configuration file. It resolves
  `extends` with a path and `ignore-from-file` against the working directory.
  Without `--strict` it exits with 0 on warnings, and the default configuration
  reports `comments`, `comments-indentation`, `document-start` and `truthy` as
  warnings. With every default rule, except `line-length` and `document-start`
  off, one space before inline comments and `truthy` without keys, it reports
  nothing in the 92 YAML files of flakeyard.
- biome 2.4.15 has nine lint rules for JSON: `noBiomeFirstException`,
  `noDuplicateObjectKeys`, `noQuickfixBiome` and `useBiomeIgnoreFolder`, which
  are recommended, `noDuplicateDependencies`, and four in `nursery`.
  `biome lint` does not format, exits with 0 on warnings without
  `--error-on-warnings`, and accepts comments and trailing commas in `.jsonc`
  files but not in `.json`; setting `json.parser.allowComments` to `false`
  rejects them in `.jsonc` too. With `--config-path` outside the project, as a
  store path is, biome applies no `biome.json` of the project, at the root or
  nested; inside the project, a nested `biome.json` with `"root": false` is
  merged and one without it fails. It resolves `extends` and the patterns of
  `includes` against the directory of the configuration file: a pattern that
  does not start with `**` matches no file of the project. With the version
  control integration and the formatter off, it lints a file that `.gitignore`
  lists and ignores a broken `.editorconfig`. It reports nothing in the 85 JSON
  files of flakeyard.
- taplo with `--config` reads no other configuration file; it matches the
  patterns of `include` and `exclude` against the paths from the working
  directory. Its defaults change none of the 21 TOML files of flakeyard.
  `taplo lint --no-schema` reports syntax errors and conflicting keys without
  network access and ignores the schemas of the configuration.
- check-jsonschema ships the schemas of SchemaStore for GitHub Actions metadata,
  Dependabot, issue forms and the configuration of issue templates, and
  Renovate's schema, and validates with them offline. Its pre-commit hooks
  select files with patterns with a negative lookahead, which `builtins.match`,
  and so the `domain` of lib-atom, does not read. Its package in nixpkgs has no
  JSON5 parser and fails on `renovate.json5`. The metadata of the actions of
  workflow-release lacks descriptions of inputs that the schema requires.

## Decision

### Inputs

The public flake has the inputs `treefmt-nix` (numtide/treefmt-nix) and
`git-hooks` (cachix/git-hooks.nix), whose modules the atom imports, after
failing evaluation with the exact `follows` line when the consumer's input of
that name has another store path, through `upstream` of lib-atom. It also
declares `lib-atom`, which it pins in its own `flake.lock`; consumers neither
declare nor follow it. In the atom's own lock, `git-hooks` follows the nixpkgs
of `treefmt-nix`, so the lock holds one nixpkgs ([FY-0040][fy-0040]).

### Formatters

prettier formats `*.yaml`, `*.yml`, `*.json` and `*.jsonc` as the treefmt
formatter `flakeyard-prettier-data`, defined by the atom with `command`,
`options` and `includes` at `lib.mkOverride 900`, so that it never sets
`programs.prettier` of atom-markdown. Its options are `--write` and
`--config <file>`. JSON5 is not formatted: no formatter in nixpkgs that keeps
its comments formats it.

taplo formats `*.toml` through `programs.taplo` of treefmt-nix, enabled with
`pkgs.taplo` at `lib.mkOverride 900`. `--config <file>` is a plain definition of
`settings.formatter.taplo.options`, which treefmt-nix defines at plain priority.

The files that tools write, such as `.release-please-manifest.json`, are
excluded by atom-workspace.

### Hooks

Every hook has a `files` pattern that `builtins.match` reads, so the check takes
its source from them:

- `yamllint` of git-hooks.nix, with `pkgs.yamllint`, `files = \.ya?ml$`, the
  chosen file as `settings.configPath` and `settings.strict = true`, so warnings
  fail too;
- `flakeyard-biome-lint`:
  `biome lint --no-errors-on-unmatched --error-on-warnings --config-path <file>`
  with `pkgs.biome`, `files = \.jsonc?$` and `types = [ "text" ]`, since
  identify gives `.jsonc` no tag `json`;
- `flakeyard-taplo-lint`: `taplo lint --config <file> --no-schema` with
  `pkgs.taplo` and `files = \.toml$`;
- one `flakeyard-schema-<schema>` hook per schema, each
  `check-jsonschema --builtin-schema vendor.<schema>` with
  `pkgs.check-jsonschema`: `github-actions` for `action.yml` or `action.yaml` at
  the root and below `.github/actions/`, the files atom-workflows checks as
  actions; `renovate`, with `--regex-variant nonunicode`, for `renovate.json` at
  the root, in `.github/` or `.gitlab/`, `.renovaterc` and `.renovaterc.json`;
  `dependabot` for `.github/dependabot.yml` or `.yaml`; `github-issue-forms` for
  the YAML files of `.github/ISSUE_TEMPLATE/`, with the configuration in
  `excludes`; and `github-issue-config` for `.github/ISSUE_TEMPLATE/config.yml`
  or `.yaml`. There is no schema check of workflows, which atom-workflows owns,
  and `renovate.json5` is not checked.

The upstream hooks `biome` and `taplo` are not used: one formats, which treefmt
does, and the other is a formatter too.

### Configurations

The function `config` of lib-atom chooses each file ([FY-0040][fy-0040]):

- prettier: `.prettierrc`, `.prettierrc.json`, `.prettierrc.json5`,
  `.prettierrc.yaml`, `.prettierrc.yml` and `.prettierrc.toml`, else
  `config/prettier.json`;
- taplo: `.taplo.toml` and `taplo.toml`, else `config/taplo.toml`;
- yamllint: `.yamllint`, `.yamllint.yaml` and `.yamllint.yml`, else
  `config/yamllint.yaml`;
- biome: `biome.json`, `biome.jsonc`, `.biome.json` and `.biome.jsonc`, else
  `config/biome.json`.

The names and the unsupported forms of prettier come from the function
`prettier` of lib-atom, which atom-markdown also takes, so a project's file
replaces the defaults of both atoms. More than one file of a tool fails
evaluation. These forms fail evaluation with a message that names them:

- a JavaScript or TypeScript configuration of prettier, the key `prettier` of
  `package.json`, and overrides with a directory in `.prettierrc.json` and
  `.prettierrc.toml`, which prettier ignores or resolves against the directory
  of the chosen file with `--config`;
- a `schema` of taplo, at the top or in a `[[rule]]`, read with
  `builtins.fromTOML`, since the hook passes `--no-schema`;
- in yamllint's files, a top-level `extends` whose value on its line is not
  `default` or `relaxed`, and the key `ignore-from-file` at any depth, found by
  lines, since Nix does not read YAML;
- in biome's files, `extends`, read with `builtins.fromJSON` in the JSON forms
  and found by lines in the JSONC forms, and, in the JSON forms, patterns of
  `includes`, of any section and of `overrides`, that do not start with `**`
  after their `!`.

The defaults:

- `config/prettier.json` sets every option of prettier at its default, as
  atom-markdown's does except `proseWrap`, so that `.editorconfig` changes
  nothing under it;
- `config/taplo.toml` sets every formatting option at its default;
- `config/yamllint.yaml` extends nothing and lists every rule of yamllint's
  default configuration with its level and parameters, except
  `comments.min-spaces-from-content: 1`, which is what prettier writes,
  `document-start: disable`, `line-length: disable`, since lines that cannot be
  broken are allowed, and `truthy.check-keys: false`, for the key `on` of
  workflows;
- `config/biome.json` is a root configuration with the formatter, the assist,
  `useEditorconfig` and the version control integration off, `files.maxSize` and
  `files.ignoreUnknown` at their defaults, and every lint rule for JSON at its
  default severity, the rules of `nursery` off. The parser options are left to
  biome, which allows comments in `.jsonc` only.

### Check and shell

`checks.data-formats` is built with `lib.<system>.run` of git-hooks.nix from
only the eight hooks, with every option the project's configuration holds for
them, the project's global `pre-commit.settings.excludes` and the project's
`pre-commit` and `git` packages. Its source is `src` of the function `domain` of
lib-atom over these hooks: the files their `files` patterns match, so a change
of other files keeps the check cached. pre-commit selects the files, as the
installed hook does.

`devShells.flakeyard-data-formats` is built with `mkShellNoCC` and holds
prettier, taplo, yamllint, biome and check-jsonschema.

### Next major version

While `nix/next-major.nix` exists, `checks.data-formats` and the shell warn with
`lib.warn` of the consumer's nixpkgs, through the function `warning` of lib-atom
([FY-0016][fy-0016], [FY-0038][fy-0038]).

### Tests

`dev/flake.nix` imports the atom from the flake's own outputs called with the
dev flake's `treefmt-nix` and `git-hooks`, which is what `follows` gives a
consumer, together with atom-workspace, atom-markdown, atom-nix, atom-shell and
atom-workflows, and checks this repository with them. The dev flake fetches the
revision of lib-atom that the root `flake.lock` pins and takes the fixture
projects and the tests of `follows`, the warning and the glue of atom-workspace
from its `internal/testing`. Its checks evaluate on x86_64-linux and
aarch64-linux: a project that passes, a project with a finding of each hook and
files each formatter would change, block scalars with `+`, every standard path
of every tool, the evaluation errors, nested configuration files, the ignore
files and `.editorconfig` of prettier, the global excludes and generated files,
the source of the check, the atom next to atom-markdown, the keys of the
defaults against the installed tools, the glue of atom-workspace, the follows
error and the next-major warning.

## Constraints

- The public flake MUST declare only the inputs `treefmt-nix`, `git-hooks` and
  `lib-atom`, and MUST fail evaluation with the exact follows line when the
  consumer's `treefmt-nix` or `git-hooks` has another store path.
- The atom MUST format YAML and JSON with prettier only under the formatter name
  `flakeyard-prettier-data` and MUST NOT set `programs.prettier`.
- Every tool MUST get the chosen file by flag, and the chosen file MUST be the
  project's file at a standard path at the root when one exists, else the
  default of `config/`, as a store path of its own.
- The configuration files of prettier MUST come from `prettier` of lib-atom.
- yamllint MUST run with `--strict`, and biome with `--error-on-warnings`.
- taplo lint MUST run with `--no-schema`, and check-jsonschema only with the
  schemas its package ships.
- Every hook of the atom MUST set `files`, and `checks.data-formats` MUST take
  its source from `domain` of lib-atom over these hooks.
- More than one configuration file of a tool, and the forms listed under
  "Configurations", MUST fail evaluation with a message that names them.
- Everything listed in the "Public API" of the README is the public API
  ([FY-0017][fy-0017], [FY-0024][fy-0024]).

## Consequences

- (+) A project gets the same findings in the git hook, in `nix flake check` and
  in CI, with flakeyard's configuration or its own file.
- (+) A change outside YAML, JSON and TOML files keeps `checks.data-formats`
  cached.
- (+) One prettier configuration of the project applies to Markdown, YAML and
  JSON alike.
- (−) A configuration of biome or yamllint below the root does not apply, and
  biome's `includes` must start with `**`.
- (−) `renovate.json5` and JSON5 files are neither formatted nor validated.
- (−) The lines that detect `extends` and `ignore-from-file` of yamllint and
  `extends` of biome's JSONC miss a value on a later line or in a flow mapping.
- (−) Adopting the atom fails workflow-release until its actions describe their
  inputs.

## Alternatives considered

- **`programs.prettier` with more `includes`.** atom-markdown owns it, and two
  atoms setting one option conflict ([FY-0017][fy-0017]).
- **yamlfmt for YAML.** It rewrites the value of block scalars with `+` in some
  configurations ([FY-0017][fy-0017]).
- **The upstream hook `biome`.** It runs `biome check`, which formats JSON
  against prettier and lints JavaScript and TypeScript.
- **Formatting JSON with biome.** prettier already formats YAML and JSON in
  flakeyard; two formatters of JSON would disagree.
- **yamllint without `--strict`.** Its default configuration reports `comments`,
  `comments-indentation` and `truthy` as warnings, which would not fail.
- **taplo lint with schemas.** It fetches schemas over the network.
- **check-jsonschema with a JSON5 parser.** The package of nixpkgs has none; an
  overridden package would not be the consumer's.
- **The pre-commit hooks of check-jsonschema as published.** Their lookahead
  patterns are not read by `builtins.match`.
- **The configuration rules of prettier copied from atom-markdown.** Logic with
  two users belongs in one place ([FY-0035][fy-0035], [FY-0040][fy-0040]).

[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0040]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0040-share-code-through-lib-repositories.md
