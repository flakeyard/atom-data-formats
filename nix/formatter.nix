# The formatters of the domain in treefmt (FY-0017): prettier for YAML and
# JSON under the formatter name flakeyard-prettier-data, since atom-markdown
# owns programs.prettier for Markdown, and taplo for TOML. Each gets the
# configuration that the project chose by --config (FY-0037). prettier
# still reads .editorconfig, whose values the chosen file overrides,
# .prettierignore and .gitignore. JSON5 is not formatted.
{ configs }:
{ lib, ... }:
{
  _file = ./formatter.nix;

  config.perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        settings.formatter.flakeyard-prettier-data = {
          command = lib.mkOverride 900 (lib.getExe pkgs.prettier);
          options = lib.mkOverride 900 [
            "--write"
            "--config"
            "${configs.prettier.file}"
          ];
          includes = lib.mkOverride 900 [
            "*.yaml"
            "*.yml"
            "*.json"
            "*.jsonc"
          ];
        };
        programs.taplo = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.taplo;
          includes = lib.mkOverride 900 [ "*.toml" ];
        };
        # A plain definition, since treefmt-nix defines the list at plain
        # priority (FY-0017); it follows the word format of treefmt-nix.
        # treefmt-nix adds a --config of its own only when
        # programs.taplo.settings is set.
        settings.formatter.taplo.options = [
          "--config"
          "${configs.taplo.file}"
        ];
      };
    };
}
