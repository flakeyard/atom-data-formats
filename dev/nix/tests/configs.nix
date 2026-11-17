# The configuration files (FY-0037): the project's file at each standard path
# replaces the default of the atom, and the chosen file reaches the tool by
# flag as a store path of its own. Each fixture in dev/fixtures/configs
# passes only with its project's file: prettier indents by four, taplo
# writes compact inline tables, yamllint allows the value yes, and biome
# allows a duplicate key.
{
  facts,
  fixture,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      project = name: (fixture { inherit name; }).allSystems.${system};
      check = name: check: (fixture { inherit name; }).checks.${system}.${check};
      # The store path of a file as the atom names it, as text to look for:
      # comparing paths needs no build, where reading the file would.
      # Restated: the name is the interface that prettier reads (FY-0035).
      stored =
        path:
        builtins.unsafeDiscardStringContext "${builtins.path {
          inherit path;
          name = lib.removePrefix "." (baseNameOf path);
        }}";
      # The file each tool gets in a project.
      words = text: lib.splitString " " text;
      prettier = name: lib.last (project name).treefmt.settings.formatter.flakeyard-prettier-data.options;
      taplo = name: lib.last (project name).treefmt.settings.formatter.taplo.options;
      hooks = name: (project name).pre-commit.settings.hooks;
      yamllint = name: (hooks name).yamllint.settings.configPath;
      biome = name: lib.last (words (hooks name).flakeyard-biome-lint.entry);
      # The file of taplo lint, after --config.
      taploLint =
        name:
        let
          found = words (hooks name).flakeyard-taplo-lint.entry;
        in
        lib.elemAt found (lib.lists.findFirstIndex (word: word == "--config") null found + 1);
      own = name: file: stored (root + "/dev/fixtures/configs/${name}/${file}");
      default = file: stored (root + "/config/${file}");
      # The fixtures in dev/fixtures/configs, by tool, with their files.
      formatted = {
        prettierrc = ".prettierrc";
        prettierrc-json = ".prettierrc.json";
        prettierrc-json5 = ".prettierrc.json5";
        prettierrc-yaml = ".prettierrc.yaml";
        prettierrc-yml = ".prettierrc.yml";
        prettierrc-toml = ".prettierrc.toml";
      };
      taplos = {
        taplo = "taplo.toml";
        taplo-dotted = ".taplo.toml";
      };
      yamllints = {
        yamllint = ".yamllint";
        yamllint-yaml = ".yamllint.yaml";
        yamllint-yml = ".yamllint.yml";
      };
      biomes = {
        biome-json = "biome.json";
        biome-jsonc = "biome.jsonc";
        biome-dotted-json = ".biome.json";
        biome-dotted-jsonc = ".biome.jsonc";
      };
      replaces =
        tool: get: fixtures:
        lib.mapAttrs' (
          name: file:
          lib.nameValuePair "${file} replaces the default of ${tool}" (get "configs/${name}" == own name file)
        ) fixtures;
      checksOf =
        output: fixtures:
        lib.mapAttrs' (
          name: _: lib.nameValuePair "test-configs-${name}" (check "configs/${name}" output)
        ) fixtures;
    in
    {
      checks = {
        test-configs = facts pkgs "test-configs" (
          {
            "without a file, prettier gets the default" = prettier "good" == default "prettier.json";
            "without a file, taplo gets the default" = taplo "good" == default "taplo.toml";
            "without a file, taplo lint gets the default" = taploLint "good" == default "taplo.toml";
            "without a file, yamllint gets the default" = yamllint "good" == default "yamllint.yaml";
            "without a file, biome gets the default" = biome "good" == default "biome.json";
            "prettier gets one --config" =
              lib.count (option: option == "--config")
                (project "good").treefmt.settings.formatter.flakeyard-prettier-data.options == 1;
            "taplo gets one --config" =
              lib.count (option: option == "--config") (project "good").treefmt.settings.formatter.taplo.options
              == 1;
            "taplo lint gets the project's file" = taploLint "configs/taplo" == own "taplo" "taplo.toml";
            "the check runs the chosen files" =
              lib.hasInfix (own "yamllint-yaml" ".yamllint.yaml") (
                builtins.toJSON (check "configs/yamllint-yaml" "data-formats").config.rawConfig
              )
              && lib.hasInfix (own "biome-json" "biome.json") (
                builtins.toJSON (check "configs/biome-json" "data-formats").config.rawConfig
              );
          }
          // replaces "prettier" prettier formatted
          // replaces "taplo" taplo taplos
          // replaces "yamllint" yamllint yamllints
          // replaces "biome" biome biomes
        );
      }
      // checksOf "treefmt" (formatted // taplos)
      // checksOf "data-formats" (yamllints // biomes);
    };
}
