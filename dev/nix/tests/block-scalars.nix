# prettier keeps the value of every block scalar, also with the indicator +,
# which keeps the trailing empty lines of the value (FY-0017): it formats
# dev/fixtures/block-scalars/data.yaml, as treefmt runs it, and the file
# changes while every value stays the same.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      inherit ((fixture { name = "good"; }).allSystems.${system}.treefmt.settings.formatter)
        flakeyard-prettier-data
        ;
      format = "${flakeyard-prettier-data.command} ${lib.escapeShellArgs flakeyard-prettier-data.options}";
      python = pkgs.python3.withPackages (packages: [ packages.pyyaml ]);
    in
    {
      checks.test-block-scalars = pkgs.runCommand "test-block-scalars" { } ''
        original=${root + "/dev/fixtures/block-scalars/data.yaml"}
        cp --no-preserve=mode "$original" data.yaml
        ${format} data.yaml
        cat data.yaml
        if cmp data.yaml "$original"; then exit 1; fi
        ${lib.getExe python} - "$original" data.yaml <<'PYTHON'
        import sys, yaml
        before, after = (yaml.safe_load(open(path)) for path in sys.argv[1:])
        print(repr(before))
        sys.exit(0 if before == after else 1)
        PYTHON
        touch $out
      '';
    };
}
