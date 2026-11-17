# The default configurations write out every value of the tools that the
# atom runs (FY-0037), so that a new version of a tool shows what to add:
# config/yamllint.yaml lists every rule of yamllint, and every parameter and
# the level of each rule it enables; config/taplo.toml every formatting
# option of taplo; config/biome.json every lint rule for JSON of biome, from
# the source of the package. A rule or option that the tool does not have
# fails too.
{ root, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
      # The module of the yamllint of the project's nixpkgs; the package of
      # the hook is an application, whose modules a Python environment does
      # not get.
      python = pkgs.python3.withPackages (packages: [
        packages.yamllint
        packages.pyyaml
      ]);
    in
    {
      checks.test-tool-configs =
        pkgs.runCommand "test-tool-configs"
          {
            nativeBuildInputs = [
              hooks.flakeyard-taplo-lint.package
              python
            ];
          }
          ''
            taplo config schema >taplo.schema.json
            python3 - ${root + "/config"} ${hooks.flakeyard-biome-lint.package.src} <<'PYTHON'
            import json, pathlib, re, sys, tomllib, yaml
            from yamllint import rules

            config, source = map(pathlib.Path, sys.argv[1:])
            problems = []

            def compare(what, expected, found):
                problems.extend(f"{what}: missing {key}" for key in sorted(set(expected) - set(found)))
                problems.extend(f"{what}: unknown {key}" for key in sorted(set(found) - set(expected)))

            yamllint = yaml.safe_load((config / "yamllint.yaml").read_text())["rules"]
            compare("yamllint rules", rules._RULES, yamllint)
            for name, rule in rules._RULES.items():
                value = yamllint.get(name)
                if isinstance(value, dict):
                    compare(f"yamllint {name}", ["level", *getattr(rule, "CONF", {})], value)
                elif value != "disable":
                    problems.append(f"yamllint {name}: neither disable nor every parameter")

            options = json.load(open("taplo.schema.json"))["definitions"]["OptionsIncomplete"]["properties"]
            taplo = tomllib.loads((config / "taplo.toml").read_text())["formatting"]
            compare("taplo formatting", options, taplo)

            def camel(name):
                return re.sub(r"_(.)", lambda match: match.group(1).upper(), name)

            lint = source / "crates/biome_json_analyze/src/lint"
            biome = json.loads((config / "biome.json").read_text())["linter"]["rules"]
            for group in sorted(path for path in lint.iterdir() if path.is_dir()):
                compare(f"biome {group.name}", [camel(rule.stem) for rule in group.glob("*.rs")], biome.get(group.name, {}))

            for problem in problems:
                print(problem, file=sys.stderr)
            sys.exit(1 if problems else 0)
            PYTHON
            touch $out
          '';
    };
}
