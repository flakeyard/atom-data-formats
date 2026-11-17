# A project whose data files pass every hook and are formatted: actions,
# Renovate, Dependabot and issue templates that match their schemas, YAML
# with block scalars that keep their trailing empty lines, a long line and
# the key on, JSON with comments in a .jsonc file, TOML, and a JSON5 file
# that no tool touches.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    let
      inherit (fixture { name = "good"; }) checks;
    in
    {
      checks.test-good = checks.${system}.data-formats;
      checks.test-good-format = checks.${system}.treefmt;
    };
}
