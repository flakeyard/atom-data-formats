# The atom next to atom-markdown, which owns prettier for Markdown
# (FY-0017): each formats its own files under its own formatter name, and
# the project's .prettierrc.json replaces the defaults of both, so that YAML
# indented by four passes checks.treefmt.
{
  facts,
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      flake = fixture {
        name = "markdown";
        module.imports = [ inputs.atom-markdown.flakeModules.default ];
      };
      inherit (flake.allSystems.${system}.treefmt.settings) formatter;
      own = builtins.unsafeDiscardStringContext "${builtins.path {
        path = root + "/dev/fixtures/markdown/.prettierrc.json";
        name = "prettierrc.json";
      }}";
    in
    {
      checks = {
        test-markdown = facts pkgs "test-markdown" {
          "atom-markdown formats only Markdown" = formatter.prettier.includes == [ "*.md" ];
          "the file of the project replaces the default of atom-markdown" =
            lib.last formatter.prettier.options == own;
          "the file of the project replaces the default of the atom" =
            lib.last formatter.flakeyard-prettier-data.options == own;
        };
        test-markdown-format = flake.checks.${system}.treefmt;
      };
    };
}
