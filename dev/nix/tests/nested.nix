# Configuration files below the root do not apply (FY-0037): the tools get
# the chosen file by flag, so sub/biome.json, sub/.yamllint.yaml,
# sub/.prettierrc.json and sub/taplo.toml, which would let the files next to
# them pass, change nothing. biome applies a nested biome.json only below the
# directory of its own configuration file, a store path.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (fixture { name = "nested"; }) checks;
      failure = check: pkgs.testers.testBuildFailure checks.${system}.${check};
    in
    {
      checks.test-nested = pkgs.runCommand "test-nested" { } ''
        log=${failure "data-formats"}/testBuildFailure.log
        cat "$log"
        grep -F 'sub/data.json:1:3 lint/suspicious/noDuplicateObjectKeys' "$log"
        grep -F 'truthy value should be one of [false, true]  (truthy)' "$log"
        log=${failure "treefmt"}/testBuildFailure.log
        cat "$log"
        grep -F 'sub/indented.yaml' "$log"
        grep -F 'sub/data.toml' "$log"
        touch $out
      '';
    };
}
