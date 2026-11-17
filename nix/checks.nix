# checks.data-formats: the linters of the domain, as the project's
# configuration holds them, without network access (FY-0017). Built with
# lib.<system>.run of git-hooks.nix from only these hooks and the project's
# global excludes, so pre-commit selects the files by `files`, `types` and
# `excludes` as the installed hook does. Its source holds only the files
# that the `files` of the hooks match, so a change of other files keeps the
# check cached.
{
  git-hooks,
  domain,
  warning,
}:
{ self, ... }:
{
  _file = ./checks.nix;

  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit) settings;
      names = [
        "yamllint"
        "flakeyard-biome-lint"
        "flakeyard-taplo-lint"
        "flakeyard-schema-github-actions"
        "flakeyard-schema-renovate"
        "flakeyard-schema-dependabot"
        "flakeyard-schema-github-issue-forms"
        "flakeyard-schema-github-issue-config"
      ];
      # The files of the hooks, as a store path of their own (FY-0017).
      files =
        domain
          {
            inherit lib;
            project = self.outPath;
          }
          {
            name = "data-formats";
            hooks = map (name: settings.hooks.${name}) names;
          };
      # Every option of the project's hook; raw is computed from the others.
      hook = name: removeAttrs settings.hooks.${name} [ "raw" ];
    in
    {
      checks.data-formats = warning lib (
        git-hooks.lib.${system}.run {
          inherit (files) src;
          hooks = lib.genAttrs names hook;
          inherit (settings) excludes package gitPackage;
        }
      );
    };
}
