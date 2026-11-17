# The configuration file that each tool gets (FY-0037), chosen by config of
# lib-atom (FY-0040): the project's file at a standard path at its root, else
# the default of the atom, either one as a store path of its own. Project
# files that configure a tool in a form the atom does not pass to it fail
# evaluation with a message that names them. project is the project's
# source, which for a git flake holds only tracked files.
{
  lib,
  root,
  shared,
  project,
}:
let
  chosen = shared.config {
    inherit lib project;
    atom = "atom-data-formats";
  };
  lines = path: lib.splitString "\n" (builtins.readFile path);
  list = lib.concatStringsSep ", ";
  # yamllint resolves extends with a path and ignore-from-file against the
  # working directory, and the check of the domain holds only the files of
  # its hooks, so the hook and the check would read different files. YAML
  # is not parsed by Nix, so the atom looks at lines: a top-level extends
  # with a value other than default or relaxed on its line, and the key
  # ignore-from-file at any depth. A value on a later line counts as other.
  yamllints = [
    ".yamllint"
    ".yamllint.yaml"
    ".yamllint.yml"
  ];
  extends =
    line:
    let
      found = builtins.match ''["']?extends["']?[[:space:]]*:[[:space:]]*(.*)'' line;
      preset = builtins.match ''["']?(default|relaxed)["']?[[:space:]]*(#.*)?'' (lib.head found);
    in
    found != null && preset == null;
  ignoreFromFile =
    line:
    builtins.match ''[[:space:]]*(-[[:space:]]+)?["']?ignore-from-file["']?[[:space:]]*:.*'' line
    != null;
  # biome resolves extends and the patterns of includes against the
  # directory of the file of --config-path, a store path. A pattern that
  # does not start with ** after its ! matches no file of the project,
  # without a message. The atom reads the JSON forms; JSONC may hold
  # comments, which Nix does not parse, so there it looks for the key
  # extends on a line, and does not detect includes.
  biomes = [
    "biome.json"
    "biome.jsonc"
    ".biome.json"
    ".biome.jsonc"
  ];
  # The patterns of includes of every section and of every override.
  relative =
    configuration:
    lib.filter (pattern: !lib.hasPrefix "**" (lib.head (builtins.match "!*(.*)" pattern))) (
      lib.concatMap (section: if lib.isAttrs section then section.includes or [ ] else [ ]) (
        lib.attrValues configuration ++ configuration.overrides or [ ]
      )
    );
  biome =
    name:
    if lib.hasSuffix ".jsonc" name then
      [
        {
          inherit name;
          label = "${name} (extends)";
          when =
            path: lib.any (line: builtins.match ''.*"extends"[[:space:]]*:.*'' line != null) (lines path);
        }
      ]
    else
      let
        read = path: builtins.fromJSON (builtins.readFile path);
      in
      [
        {
          inherit name;
          label = "${name} (extends)";
          when = path: read path ? extends;
        }
        {
          inherit name;
          label = "${name} (includes that do not start with **: ${
            list (relative (read (project + "/${name}")))
          })";
          when = path: relative (read path) != [ ];
        }
      ];
  taplos = [
    ".taplo.toml"
    "taplo.toml"
  ];
in
{
  # The file of prettier replaces the defaults of this atom and of
  # atom-markdown alike (FY-0017).
  prettier = chosen (
    {
      tool = "prettier";
      default = root + "/config/prettier.json";
    }
    // shared.prettier { inherit lib project; }
  );
  taplo = chosen {
    tool = "taplo";
    default = root + "/config/taplo.toml";
    # taplo looks for these names, in this order.
    names = taplos;
    # The hook runs taplo lint with --no-schema: checks run without network
    # access (FY-0017), so a schema would be ignored without a message.
    # builtins.fromTOML reads TOML without dates and times.
    unsupported = map (name: {
      inherit name;
      label = "${name} (schema)";
      when =
        path:
        let
          configuration = builtins.fromTOML (builtins.readFile path);
        in
        configuration ? schema || lib.any (rule: rule ? schema) (configuration.rule or [ ]);
    }) taplos;
  };
  yamllint = chosen {
    tool = "yamllint";
    default = root + "/config/yamllint.yaml";
    # The files that yamllint finds in the working directory.
    names = yamllints;
    unsupported = lib.concatMap (name: [
      {
        inherit name;
        label = "${name} (extends other than default or relaxed)";
        when = path: lib.any extends (lines path);
      }
      {
        inherit name;
        label = "${name} (ignore-from-file)";
        when = path: lib.any ignoreFromFile (lines path);
      }
    ]) yamllints;
  };
  biome = chosen {
    tool = "biome";
    default = root + "/config/biome.json";
    # The files that biome finds in the working directory.
    names = biomes;
    unsupported = lib.concatMap biome biomes;
  };
}
