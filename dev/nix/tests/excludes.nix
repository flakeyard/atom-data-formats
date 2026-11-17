# The project's global excludes, pre-commit.settings.excludes, apply to the
# check as to the hooks: the failing files of dev/fixtures/bad pass once
# excluded, and still fail when the excludes name other files. The manifest
# of release-please, which atom-workspace excludes as a file that a tool
# writes, passes both checks with a duplicate key and without formatting.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      excluding =
        excludes:
        (fixture {
          name = "bad";
          module.perSystem.pre-commit.settings = { inherit excludes; };
        }).checks.${system}.data-formats;
      failure = pkgs.testers.testBuildFailure (excluding [ ''^other\.yaml$'' ]);
      generated = (fixture { name = "generated"; }).checks.${system};
    in
    {
      checks = {
        test-excluded = excluding [
          ''^(lint|unformatted)\.yaml$''
          ''^(duplicate|renovate)\.json$''
          ''^conflicting\.toml$''
          ''^\.github/''
        ];
        test-not-excluded = pkgs.runCommand "test-not-excluded" { } ''
          log=${failure}/testBuildFailure.log
          cat "$log"
          grep -F '(truthy)' "$log"
          grep -F 'noDuplicateObjectKeys' "$log"
          touch $out
        '';
        test-generated = generated.data-formats;
        test-generated-format = generated.treefmt;
      };
    };
}
