# A project with one finding of each hook: checks.data-formats reports the
# warnings of yamllint, which fail with --strict, the duplicate key of biome,
# the conflicting keys of taplo and a violation of each schema;
# checks.treefmt reports the files that prettier and taplo would change.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (fixture { name = "bad"; }) checks;
      failure = check: pkgs.testers.testBuildFailure checks.${system}.${check};
    in
    {
      checks.test-bad = pkgs.runCommand "test-bad" { } ''
        log=${failure "data-formats"}/testBuildFailure.log
        cat "$log"
        grep -F 'missing starting space in comment  (comments)' "$log"
        grep -F 'truthy value should be one of [false, true]  (truthy)' "$log"
        grep -F 'lint/suspicious/noDuplicateObjectKeys' "$log"
        grep -F 'conflicting keys' "$log"
        grep -F ".github/actions/build/action.yml::\$.inputs.target: 'description' is a required property" "$log"
        grep -F "renovate.json::\$.enabled: 'yes' is not of type 'boolean'" "$log"
        grep -F ".github/dependabot.yml::\$: 'version' is a required property" "$log"
        grep -F ".github/ISSUE_TEMPLATE/bug.yml::\$: 'description' is a required property" "$log"
        grep -F ".github/ISSUE_TEMPLATE/config.yml::\$.blank_issues_enabled: 'sometimes' is not of type 'boolean'" "$log"
        # The configuration of the issue templates is not an issue form.
        if grep -F "config.yml::\$: 'name' is a required property" "$log"; then exit 1; fi
        touch $out
      '';
      checks.test-bad-format = pkgs.runCommand "test-bad-format" { } ''
        log=${failure "treefmt"}/testBuildFailure.log
        cat "$log"
        grep -F 'unformatted.yaml' "$log"
        grep -F 'unformatted.json' "$log"
        grep -F 'unformatted.toml' "$log"
        if grep -F 'lint.yaml' "$log"; then exit 1; fi
        touch $out
      '';
    };
}
