# The linters of the domain as git hooks (FY-0017): yamllint of
# git-hooks.nix, and the atom's own hooks flakeyard-biome-lint for JSON,
# flakeyard-taplo-lint for TOML and one flakeyard-schema-<schema> per schema
# of check-jsonschema. The linters get the configuration that the project
# chose (FY-0037). Every hook has its `files`, which pre-commit applies and
# from which the check takes its source. Their package, entry and arguments
# are the single definition that the check also runs.
{ configs }:
{
  _file = ./hooks.nix;

  config.perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.pre-commit.settings) hooks;
      # A hook of check-jsonschema with a schema that its package ships, so
      # that it runs without network access.
      schema =
        name:
        {
          description,
          files,
          excludes ? [ ],
          flags ? [ ],
        }:
        {
          enable = lib.mkOverride 900 true;
          name = lib.mkOverride 900 "flakeyard-schema-${name}";
          description = lib.mkOverride 900 description;
          package = lib.mkOverride 900 pkgs.check-jsonschema;
          entry = lib.mkOverride 900 (
            lib.concatStringsSep " " (
              [
                (lib.getExe hooks."flakeyard-schema-${name}".package)
                "--builtin-schema"
                "vendor.${name}"
              ]
              ++ flags
            )
          );
          files = lib.mkOverride 900 files;
          excludes = lib.mkOverride 900 excludes;
        };
    in
    {
      pre-commit.settings.hooks = {
        yamllint = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.yamllint;
          files = lib.mkOverride 900 ''\.ya?ml$'';
          settings = {
            # Passed with --config-file; yamllint then reads no other file.
            configPath = lib.mkOverride 900 "${configs.yamllint.file}";
            # Warnings fail too.
            strict = lib.mkOverride 900 true;
          };
        };
        flakeyard-biome-lint = {
          enable = lib.mkOverride 900 true;
          name = lib.mkOverride 900 "flakeyard-biome-lint";
          description = lib.mkOverride 900 "Lint JSON files with biome.";
          package = lib.mkOverride 900 pkgs.biome;
          # biome lint does not format; prettier formats JSON. With a file
          # outside the project, biome applies no biome.json of the project.
          entry = lib.mkOverride 900 (
            lib.concatStringsSep " " [
              (lib.getExe hooks.flakeyard-biome-lint.package)
              "lint"
              "--no-errors-on-unmatched"
              "--error-on-warnings"
              "--config-path"
              "${configs.biome.file}"
            ]
          );
          files = lib.mkOverride 900 ''\.jsonc?$'';
          # identify gives .jsonc no tag json.
          types = lib.mkOverride 900 [ "text" ];
        };
        flakeyard-taplo-lint = {
          enable = lib.mkOverride 900 true;
          name = lib.mkOverride 900 "flakeyard-taplo-lint";
          description = lib.mkOverride 900 "Lint TOML files with taplo.";
          package = lib.mkOverride 900 pkgs.taplo;
          # Without schemas, which need network access (FY-0017).
          entry = lib.mkOverride 900 "${lib.getExe hooks.flakeyard-taplo-lint.package} lint --config ${configs.taplo.file} --no-schema";
          files = lib.mkOverride 900 ''\.toml$'';
        };
        # The metadata of actions, as atom-workflows selects them.
        flakeyard-schema-github-actions = schema "github-actions" {
          description = "Validate the metadata files of GitHub Actions.";
          files = ''^action\.ya?ml$|^\.github/actions/.*/action\.ya?ml$'';
        };
        # The JSON names of a Renovate configuration. check-jsonschema of
        # nixpkgs parses no JSON5, so renovate.json5 is not checked.
        flakeyard-schema-renovate = schema "renovate" {
          description = "Validate the Renovate configuration.";
          files = ''^renovate\.json$|^\.(github|gitlab)/renovate\.json$|^\.renovaterc(\.json)?$'';
          # The regular expressions of Renovate are not Unicode ones.
          flags = [
            "--regex-variant"
            "nonunicode"
          ];
        };
        flakeyard-schema-dependabot = schema "dependabot" {
          description = "Validate the Dependabot configuration.";
          files = ''^\.github/dependabot\.ya?ml$'';
        };
        flakeyard-schema-github-issue-forms = schema "github-issue-forms" {
          description = "Validate the GitHub issue forms.";
          files = ''^\.github/ISSUE_TEMPLATE/[^/]+\.ya?ml$'';
          excludes = [ ''^\.github/ISSUE_TEMPLATE/config\.ya?ml$'' ];
        };
        flakeyard-schema-github-issue-config = schema "github-issue-config" {
          description = "Validate the configuration of the GitHub issue templates.";
          files = ''^\.github/ISSUE_TEMPLATE/config\.ya?ml$'';
        };
      };
    };
}
