# devShells.flakeyard-data-formats: the tools of the domain for people
# (FY-0017); atom-workspace joins it into devShells.default.
{ warning }:
{
  _file = ./shell.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
    in
    {
      devShells.flakeyard-data-formats = warning pkgs.lib (
        pkgs.mkShellNoCC {
          packages = [
            # The command of flakeyard-prettier-data.
            pkgs.prettier
            config.treefmt.programs.taplo.package
            hooks.yamllint.package
            hooks.flakeyard-biome-lint.package
            hooks.flakeyard-schema-github-actions.package
          ];
        }
      );
    };
}
