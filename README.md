# atom-data-formats

A flake-parts module that formats YAML and JSON with prettier and TOML with
taplo, through treefmt, and lints them with yamllint, biome and taplo and the
metadata of actions, Renovate, Dependabot and issue templates with
check-jsonschema, offline, as git hooks and as the check `checks.data-formats`
([FY-0017][fy-0017], [ADR-0001][adr-0001]).

## Inputs

The atom has two inputs, `treefmt-nix` and `git-hooks`, which the project makes
it share with `follows` ([FY-0017][fy-0017]). It also pins [lib-atom][lib-atom],
the functions that atoms share, in its own `flake.lock`; the project neither
declares nor follows it ([FY-0040][fy-0040]). While the atom is `0.y.z`, only
flakeyard's own repositories use it, in the form of [FY-0016][fy-0016]:

```nix
{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=<commit>&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "git+https://github.com/numtide/treefmt-nix?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atom-data-formats = {
      url = "git+https://github.com/flakeyard/atom-data-formats?ref=v0&rev=<commit>&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-workspace.url = "git+https://github.com/flakeyard/atom-workspace?ref=v0&rev=<commit>&shallow=1";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.atom-data-formats.flakeModules.default
        inputs.atom-workspace.flakeModules.default
      ];
    };
}
```

Without a `follows` line, evaluation fails with, for example:

```text
atom-data-formats: input 'git-hooks' is locked twice; add to input atom-data-formats:
  inputs.git-hooks.follows = "git-hooks";
```

[atom-workspace][atom-workspace] joins the shell of the atom into
`devShells.default`, installs its hooks, enables the hook `treefmt`, makes
`checks.treefmt` substitutable, switches off the aggregated `checks.pre-commit`
of git-hooks.nix and excludes the files that tools write, such as
`.release-please-manifest.json`.

## Files it reads

From the project's source, which for a git flake holds only tracked files:

- the YAML, JSON and TOML files: `*.yaml`, `*.yml`, `*.json`, `*.jsonc` and
  `*.toml`. JSON5 files are neither formatted nor linted;
- the files of the schema hooks: `action.yml` or `action.yaml` at the root and
  below `.github/actions/`; `renovate.json` at the root, in `.github/` or in
  `.gitlab/`, `.renovaterc` and `.renovaterc.json`; `.github/dependabot.yml` or
  `.yaml`; the YAML files of `.github/ISSUE_TEMPLATE/`;
- the configuration files at the standard paths of the table below;
- `.editorconfig`, which prettier reads: its `max_line_length`, `indent_style`,
  `indent_size` or `tab_width` and `end_of_line` apply where the chosen
  configuration of prettier sets no `printWidth`, `useTabs`, `tabWidth` or
  `endOfLine`. The default sets all four, so `.editorconfig` applies only with a
  project's file that leaves them out. biome does not read it with the default,
  whose formatter and `useEditorconfig` are off;
- `.prettierignore` and `.gitignore` at the root, whose files prettier skips,
  also a tracked file that `.gitignore` lists. prettier reads them itself, in
  the hook and in the check alike. biome reads `.gitignore` only with
  `vcs.useIgnoreFile`, which the default leaves off.

The check `checks.data-formats` gets only the files that the `files` of its
hooks match, so it does not change when other files do. yamllint resolves
`ignore` patterns and taplo the patterns of `include` and `exclude` from the
root of the project, in the hook and in the check alike.

## Tools and configuration

Each tool gets the configuration file the project chose: the project's file at
one of the tool's standard paths at the root, else the default of the atom in
[`config/`](config). The project's file replaces the default wholly; nothing is
merged. The atom passes the chosen file by flag and never lets a tool discover
one ([FY-0037][fy-0037]). check-jsonschema has no configuration: it uses only
the schemas its package ships.

| Tool     | Standard path    | Default      | Project's file |
| -------- | ---------------- | ------------ | -------------- |
| prettier | `.prettierrc`    | [config][pr] | replaces it    |
| taplo    | `.taplo.toml`    | [config][tp] | replaces it    |
| yamllint | `.yamllint.yaml` | [config][yl] | replaces it    |
| biome    | `biome.json`     | [config][bi] | replaces it    |

- prettier also takes `.prettierrc.json`, `.prettierrc.json5`,
  `.prettierrc.yaml`, `.prettierrc.yml` and `.prettierrc.toml`, the names that
  [atom-markdown][atom-markdown] takes, and gets the chosen file with
  `--config`. A project's file replaces the defaults of both atoms
  ([FY-0017][fy-0017]). A JavaScript or TypeScript configuration, `.prettierrc`
  or `prettier.config` with the extension `js`, `cjs`, `mjs`, `ts`, `cts` or
  `mts`, fails evaluation with a message that names it, since prettier would
  ignore it. prettier also ignores the key `prettier` of `package.json` and
  resolves the patterns of `overrides` against the directory of the chosen file,
  a store path, so that a pattern with a directory matches no file.
  atom-markdown fails evaluation on both; this atom does not detect them yet.
- taplo also takes `taplo.toml` and gets the chosen file with `--config`, as the
  formatter and in the hook. The hook runs `taplo lint --no-schema`, so a
  `schema`, at the top or in a `[[rule]]`, fails evaluation.
- yamllint also takes `.yamllint` and `.yamllint.yml` and gets the chosen file
  with `--config-file` and `--strict`, so warnings fail too. It resolves
  `extends` with a path and `ignore-from-file` against the working directory,
  while the check holds only the files of the domain. The atom fails evaluation
  when a line sets `extends` at the top level to a value other than `default` or
  `relaxed`, or sets `ignore-from-file` at any depth; a value on a later line
  counts as another value, and a flow mapping is not detected.
- biome also takes `biome.jsonc`, `.biome.json` and `.biome.jsonc` and gets the
  chosen file with `--config-path`; the hook runs
  `biome lint --no-errors-on-unmatched --error-on-warnings`, so warnings fail
  too. biome resolves `extends` and the patterns of `includes` against the
  directory of the chosen file, a store path, so that a pattern that does not
  start with `**` after its `!` matches no file. `extends` fails evaluation,
  found with `builtins.fromJSON` in the JSON forms and on a line in the JSONC
  forms; such patterns of `includes` of any section and of `overrides` fail
  evaluation in the JSON forms and are not detected in the JSONC forms.
- Configuration files below the root do not apply: the tools get the chosen file
  by flag, and biome applies a nested `biome.json` only below the directory of
  its own configuration file.
- More than one file at the standard paths of one tool fails evaluation with a
  message that names them. The messages are those of lib-atom
  ([FY-0040][fy-0040]):

  ```text
  atom-data-formats: the atom cannot pass these configurations of taplo to it:
  taplo.toml (schema); write the configuration in one of .taplo.toml,
  taplo.toml instead.
  atom-data-formats: the project has more than one configuration of biome:
  biome.json, .biome.json; keep one.
  ```

  (one line each, wrapped here).

The defaults:

- [`config/prettier.json`][pr] sets every option of prettier at its default.
- [`config/taplo.toml`][tp] sets every formatting option of taplo at its
  default.
- [`config/yamllint.yaml`][yl] extends nothing and lists every rule of the
  default configuration of yamllint with its level and parameters, except: one
  space before an inline comment (`comments.min-spaces-from-content: 1`), as
  prettier writes it; `document-start` and `line-length` off; and
  `truthy.check-keys: false`, for the key `on` of workflows.
- [`config/biome.json`][bi] is a root configuration that lints only: the
  formatter, the assist, `useEditorconfig` and the version control integration
  are off. It sets every lint rule of biome for JSON at its default severity,
  the rules of `nursery` off, and `files.maxSize` at its default. Comments and
  trailing commas are allowed in `.jsonc` files only.

To replace a default, copy it from [`config/`](config) to a standard path,
commit it and edit it. Since the atom reads only tracked files, an untracked
file is seen by the tool in the working tree but not by the atom.

## Hooks

The hooks and the files they take, as `files` patterns of pre-commit:

- `yamllint`: `\.ya?ml$`;
- `flakeyard-biome-lint`: `\.jsonc?$`;
- `flakeyard-taplo-lint`: `\.toml$`;
- `flakeyard-schema-github-actions`: `action.yml` or `action.yaml` at the root
  and below `.github/actions/`;
- `flakeyard-schema-renovate`: `renovate.json` at the root, in `.github/` or in
  `.gitlab/`, `.renovaterc` and `.renovaterc.json`;
- `flakeyard-schema-dependabot`: `.github/dependabot.yml` or `.yaml`;
- `flakeyard-schema-github-issue-forms`: the YAML files of
  `.github/ISSUE_TEMPLATE/` other than `config.yml` and `config.yaml`;
- `flakeyard-schema-github-issue-config`: `.github/ISSUE_TEMPLATE/config.yml` or
  `.yaml`.

Each schema hook runs `check-jsonschema --builtin-schema vendor.<schema>`, the
Renovate one with `--regex-variant nonunicode`. There is no schema check of
workflows, which [atom-workflows][atom-workflows] owns. `renovate.json5` is not
checked: check-jsonschema of nixpkgs has no JSON5 parser.

## Options

The atom sets the formatter `flakeyard-prettier-data` and `programs.taplo` of
treefmt-nix and its hooks of git-hooks.nix with `lib.mkOverride 900`, so a plain
definition of the project, such as
`perSystem.pre-commit.settings.hooks.flakeyard-biome-lint.files = "...";`,
replaces a value of the atom without `mkForce`. The check runs the hooks'
packages, `entry` and settings, so such a definition changes it too. The check
also honours the hooks' other options and the project's global
`perSystem.pre-commit.settings.excludes`: pre-commit selects the files in the
check as the installed hooks do.

`--config <file>` of taplo is a plain definition of
`perSystem.treefmt.settings.formatter.taplo.options`, which treefmt-nix defines
at plain priority. Setting `perSystem.treefmt.programs.taplo.settings` makes
treefmt-nix pass a second `--config`; use a configuration file instead. The atom
never sets `programs.prettier`, which atom-markdown owns.

## Outputs

- `flakeModules.default`: the module. It adds to every system:
  - the formatter `flakeyard-prettier-data` of treefmt for `*.yaml`, `*.yml`,
    `*.json` and `*.jsonc`, and the formatter `taplo` for `*.toml`, with the
    packages of the project's nixpkgs;
  - the hooks of the table above, with the packages of the project's nixpkgs;
  - `checks.data-formats`: the hooks, run by pre-commit through
    `lib.<system>.run` of git-hooks.nix with the project's global excludes, over
    the files of the project that their `files` match, without network access.
    Formatting is checked by `checks.treefmt`;
  - `devShells.flakeyard-data-formats`: prettier, taplo, yamllint, biome and
    check-jsonschema, which atom-workspace joins into `devShells.default`.

Supported systems are `x86_64-linux` and `aarch64-linux`.

## Supported upstream revisions

The oldest supported revisions are those the tests run with: treefmt-nix
`0d6d739a833ba9a9c93034862e4a7b061a062a1c`, git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`, with prettier 3.8.3, taplo 0.10.0,
yamllint 1.37.1, biome 2.4.15 and check-jsonschema 0.37.2.

## Public API

Releases follow [semantic versioning][versioning] ([FY-0024][fy-0024]). The
public API is the inputs `treefmt-nix` and `git-hooks`, `flakeModules.default`,
the formatters `flakeyard-prettier-data` and `taplo` and the hooks of the table
above, the values the atom sets whose change rewrites files or fails a project
that passed before (the defaults in `config/`, the files each formatter and hook
takes, the schemas and the flags of the hooks), the files it reads, the outputs
`checks.data-formats` and `devShells.flakeyard-data-formats`, the supported
systems and the oldest supported upstream revisions. Versions of the tools and
of the schemas check-jsonschema ships come from the project's nixpkgs and are
not part of it.

The last minor release before a major one contains `nix/next-major.nix`; while
it exists, the check and the shell warn at evaluation that the next major
version is coming and where its migration guide is ([FY-0038][fy-0038]).

## Develop in the container

Open the repository in the flakeyard dev container: the editor reads
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json), and
`direnv` loads the shell of [`dev/flake.nix`](dev/flake.nix) through
[`.envrc`](.envrc) ([FY-0012][fy-0012]). [atom-workspace][atom-workspace] builds
the shell and installs the git hooks each time it starts. The container runs
`direnv allow` when it is created; run it once in every other worktree, and run
`direnv block` before you check out a branch you do not trust, since entering
the directory runs that branch's shell hook. Commit inside the container, whose
Nix store has the tools of the hooks. With Nix on the host, `direnv allow` or
`nix develop ./dev` gives the same shell.

The public [`flake.nix`](flake.nix) holds only the inputs and the module
([FY-0017][fy-0017]). [`dev/flake.nix`](dev/flake.nix), with its own lock,
imports the atom as consumers do, with atom-markdown, [atom-nix][atom-nix],
[atom-shell][atom-shell], atom-workflows and atom-workspace, and holds the
tests:

- `data-formats`, `treefmt`: the atom's checks of this repository;
- `markdown`, `nix`, `shell`, `workflows`: the checks of the other atoms of this
  repository;
- `test-good`, `test-good-format`: a fixture project in
  [`dev/fixtures`](dev/fixtures) whose files pass both checks: every kind of
  schema file, block scalars with the indicator `+`, JSONC with comments, TOML
  and a JSON5 file that no tool touches;
- `test-bad`, `test-bad-format`: a fixture project with a finding of each hook,
  warnings of yamllint among them, and a file of each formatter that would
  change;
- `test-block-scalars`: prettier formats a file with block scalars with `+` and
  keeps every value;
- `test-configs` and `test-configs-*`: the defaults and every standard path of
  every tool, each with a file that passes only with it;
- `test-errors`: the configurations that fail evaluation and their messages, and
  the forms that do not;
- `test-nested`: configuration files below the root do not apply;
- `test-ignores`, `test-ignores-gitignore`: `.prettierignore`, and `.gitignore`
  for a file named on the command line;
- `test-editorconfig`, `test-editorconfig-default`: `.editorconfig` with a
  project's configuration of prettier and with the default;
- `test-excluded`, `test-not-excluded`, `test-generated`,
  `test-generated-format`: the project's global excludes skip the failing files
  in the check, other excludes do not, and the files that tools write pass;
- `test-domain`: a file outside the domain does not change the check;
- `test-markdown`, `test-markdown-format`: the atom next to atom-markdown, with
  a project's prettier configuration for both;
- `test-prettier-options`, `test-tool-configs`: the defaults list every option
  and rule of the installed tools;
- `test-workspace`: the formatters, the hooks and the shell with atom-workspace;
- `test-follows`: the error for a missing `follows` of either input;
- `test-next-major`: the warning of the next major version.

The dev flake has no input for lib-atom: it fetches the revision that the root
[`flake.lock`](flake.lock) pins, gives it to the atom and takes the fixture
projects and the tests `test-follows`, `test-next-major` and `test-workspace`
from `internal/testing` of that revision ([FY-0040][fy-0040]).

Run the same commands as CI:

```sh
nix flake check --no-update-lock-file ./dev
nix flake check --no-update-lock-file --no-build --all-systems ./dev
```

CI runs [`test.yaml`](.github/workflows/test.yaml), which calls
[workflow-check][workflow-check] with `./dev`: it checks `dev/flake.lock`,
builds every check on x86_64 and arm64 runners, checks the pull request title
and `renovate.json`, fails on configuration files of atom tools at their
standard root paths ([FY-0037][fy-0037]), and reports `check / required`
([FY-0034][fy-0034]). Its weekly run builds the checks against the current
branches of nixpkgs, treefmt-nix, git-hooks.nix and flake-parts instead of the
locked revisions ([FY-0038][fy-0038]).
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard, and
[`release.yaml`](.github/workflows/release.yaml) releases the repository with
[workflow-release][workflow-release].

Before a pull request, also run typos and `reuse lint`; the atoms that will
provide them in this repository are not adopted yet ([FY-0038][fy-0038]).

## License

[MIT](LICENSE).

[adr-0001]:
  docs/adr/records/0001-format-and-lint-yaml-json-and-toml-with-prettier-taplo-yamllint-biome-and-check-jsonschema.md
[atom-markdown]: https://github.com/flakeyard/atom-markdown
[atom-nix]: https://github.com/flakeyard/atom-nix
[atom-shell]: https://github.com/flakeyard/atom-shell
[atom-workflows]: https://github.com/flakeyard/atom-workflows
[atom-workspace]: https://github.com/flakeyard/atom-workspace
[bi]: config/biome.json
[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0040]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0040-share-code-through-lib-repositories.md
[lib-atom]: https://github.com/flakeyard/lib-atom
[pr]: config/prettier.json
[tp]: config/taplo.toml
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
[yl]: config/yamllint.yaml
