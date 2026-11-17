# The atom in a project with atom-workspace: prettier formats YAML and JSON
# and taplo formats TOML with the packages of the project's nixpkgs through
# the hook treefmt and the substitutable checks.treefmt, the hooks are
# enabled, checks.pre-commit is off, and devShells.default holds the five
# tools.
{ testing, ... }:
{
  perSystem = testing.workspace (
    {
      pkgs,
      flake,
      system,
    }:
    let
      values = flake.allSystems.${system};
      inherit (values.pre-commit.settings) hooks;
    in
    {
      formatters = {
        flakeyard-prettier-data = pkgs.prettier;
        inherit (pkgs) taplo;
      };
      packages = {
        inherit (pkgs)
          prettier
          taplo
          yamllint
          biome
          check-jsonschema
          ;
      };
      facts = {
        "prettier formats only YAML and JSON" =
          values.treefmt.settings.formatter.flakeyard-prettier-data.includes == [
            "*.yaml"
            "*.yml"
            "*.json"
            "*.jsonc"
          ];
        "taplo formats only TOML" = values.treefmt.settings.formatter.taplo.includes == [ "*.toml" ];
        "the atom leaves programs.prettier alone" = !values.treefmt.programs.prettier.enable;
        "every hook is enabled" = pkgs.lib.all (name: hooks.${name}.enable) [
          "yamllint"
          "flakeyard-biome-lint"
          "flakeyard-taplo-lint"
          "flakeyard-schema-github-actions"
          "flakeyard-schema-renovate"
          "flakeyard-schema-dependabot"
          "flakeyard-schema-github-issue-forms"
          "flakeyard-schema-github-issue-config"
        ];
        "the hooks run the project's packages" =
          hooks.yamllint.package == pkgs.yamllint
          && hooks.flakeyard-biome-lint.package == pkgs.biome
          && hooks.flakeyard-taplo-lint.package == pkgs.taplo
          && hooks.flakeyard-schema-renovate.package == pkgs.check-jsonschema;
      };
    }
  );
}
