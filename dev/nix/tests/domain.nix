# The source of checks.data-formats holds only the files that the `files` of
# its hooks match (FY-0017). The projects in dev/fixtures/domain have the
# same YAML and TOML files, except other-data, whose TOML differs; one and
# other-files differ in a README.md and a JSON5 file, which no hook checks,
# so their checks are the same derivation and stay cached.
{ facts, fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      check = name: (fixture { name = "domain/${name}"; }).checks.${system}.data-formats.drvPath;
    in
    {
      checks.test-domain = facts pkgs "test-domain" {
        "files outside the domain do not change the check" = check "other-files" == check "one";
        "a TOML file changes the check" = check "other-data" != check "one";
      };
    };
}
