# Project files the atom does not take fail evaluation with a message that
# names them (FY-0037): more than one configuration file of a tool at the
# root, a JavaScript configuration of prettier, a schema in the
# configuration of taplo, extends with a path and ignore-from-file in the
# configuration of yamllint, and extends and includes that start without **
# in the configuration of biome. The presets of yamllint and includes that
# start with ** are fine.
{
  facts,
  fixture,
  lib-atom,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      # The errors that the atom's own module makes for a fixture project in
      # dev/fixtures/errors: the atom gets a lib-atom whose config gives the
      # errors as the file, since builtins.tryEval loses the text of a throw.
      spied.lib = lib-atom // {
        config =
          arguments: tool:
          let
            chosen = lib-atom.config arguments tool;
          in
          chosen // { file = lib.concatStringsSep "\n" chosen.errors; };
      };
      errors =
        name:
        let
          values =
            (fixture {
              name = "errors/${name}";
              atomInputs.lib-atom = spied;
            }).allSystems.${system};
          inherit (values.treefmt.settings) formatter;
          inherit (values.pre-commit.settings) hooks;
          lines = text: lib.optionals (text != "") (lib.splitString "\n" text);
        in
        lib.concatMap lines [
          (lib.last formatter.flakeyard-prettier-data.options)
          (lib.last formatter.taplo.options)
          hooks.yamllint.settings.configPath
          (lib.last (lib.splitString " --config-path " hooks.flakeyard-biome-lint.entry))
        ];
      evaluates =
        name: output:
        (builtins.tryEval (fixture { name = "errors/${name}"; }).checks.${system}.${output}.drvPath)
        .success;
      prettiers = ".prettierrc, .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml, .prettierrc.toml";
    in
    {
      checks.test-errors = facts pkgs "test-errors" {
        # Restated: the text is the interface (FY-0035).
        "two configurations of each tool fail with their names" =
          errors "two-configs" == [
            "atom-data-formats: the project has more than one configuration of prettier: .prettierrc.json, .prettierrc.yaml; keep one."
            "atom-data-formats: the project has more than one configuration of taplo: .taplo.toml, taplo.toml; keep one."
            "atom-data-formats: the project has more than one configuration of yamllint: .yamllint, .yamllint.yaml; keep one."
            "atom-data-formats: the project has more than one configuration of biome: biome.json, .biome.json; keep one."
          ];
        "a JavaScript configuration of prettier fails with its names" =
          errors "js-config" == [
            "atom-data-formats: the atom cannot pass these configurations of prettier to it: .prettierrc.cjs, prettier.config.ts; write the configuration in one of ${prettiers} instead."
          ];
        "a schema of taplo fails" =
          errors "taplo-schema" == [
            "atom-data-formats: the atom cannot pass these configurations of taplo to it: taplo.toml (schema); write the configuration in one of .taplo.toml, taplo.toml instead."
          ];
        "a schema of a rule of taplo fails" =
          errors "taplo-rule-schema" == [
            "atom-data-formats: the atom cannot pass these configurations of taplo to it: .taplo.toml (schema); write the configuration in one of .taplo.toml, taplo.toml instead."
          ];
        "extends with a path of yamllint fails" =
          errors "yamllint-extends" == [
            "atom-data-formats: the atom cannot pass these configurations of yamllint to it: .yamllint.yaml (extends other than default or relaxed); write the configuration in one of .yamllint, .yamllint.yaml, .yamllint.yml instead."
          ];
        "ignore-from-file of yamllint fails" =
          errors "yamllint-ignore-from-file" == [
            "atom-data-formats: the atom cannot pass these configurations of yamllint to it: .yamllint (ignore-from-file); write the configuration in one of .yamllint, .yamllint.yaml, .yamllint.yml instead."
          ];
        "extends of biome fails" =
          errors "biome-extends" == [
            "atom-data-formats: the atom cannot pass these configurations of biome to it: biome.json (extends); write the configuration in one of biome.json, biome.jsonc, .biome.json, .biome.jsonc instead."
          ];
        "extends of biome in JSONC fails" =
          errors "biome-extends-jsonc" == [
            "atom-data-formats: the atom cannot pass these configurations of biome to it: biome.jsonc (extends); write the configuration in one of biome.json, biome.jsonc, .biome.json, .biome.jsonc instead."
          ];
        "includes of biome that start without ** fail with the patterns" =
          errors "biome-includes" == [
            "atom-data-formats: the atom cannot pass these configurations of biome to it: biome.json (includes that do not start with **: src/**, !dist/**, docs/*.json); write the configuration in one of biome.json, biome.jsonc, .biome.json, .biome.jsonc instead."
          ];
        "the presets of yamllint and ignore are fine" = errors "yamllint-presets" == [ ];
        "includes of biome that start with ** are fine" = errors "biome-includes-anywhere" == [ ];
        "a project without such files evaluates" = errors "../good" == [ ];
        "two configurations fail evaluation" = !evaluates "two-configs" "data-formats";
        "a JavaScript configuration fails evaluation" = !evaluates "js-config" "treefmt";
        "a schema of taplo fails evaluation" = !evaluates "taplo-schema" "data-formats";
        "extends of yamllint fails evaluation" = !evaluates "yamllint-extends" "data-formats";
        "extends of biome fails evaluation" = !evaluates "biome-extends" "data-formats";
        "the presets of yamllint evaluate" = evaluates "yamllint-presets" "data-formats";
        "includes that start with ** evaluate" = evaluates "biome-includes-anywhere" "data-formats";
      };
    };
}
