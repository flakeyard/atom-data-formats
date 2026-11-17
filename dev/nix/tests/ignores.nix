# The ignore files that prettier reads itself, in the hook and in the check
# alike (FY-0037): it skips the files of .prettierignore, and those of
# .gitignore also when they are named on the command line. The other tools
# of the atom read no ignore file with the defaults.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      project = fixture { name = "ignores"; };
      inherit (project.allSystems.${system}.treefmt.settings.formatter) flakeyard-prettier-data;
      # prettier as treefmt runs it, which rewrites the files named on the
      # command line.
      format = "${flakeyard-prettier-data.command} ${lib.escapeShellArgs flakeyard-prettier-data.options}";
      original = root + "/dev/fixtures/ignores/gitignored.json";
    in
    {
      checks.test-ignores = project.checks.${system}.treefmt;
      # checks.treefmt formats the tracked files only; the hook names a file
      # that is tracked although .gitignore lists it. prettier leaves it as
      # it is, and formats it without .gitignore.
      checks.test-ignores-gitignore = pkgs.runCommand "test-ignores-gitignore" { } ''
        cp -r --no-preserve=mode ${root + "/dev/fixtures/ignores"} ignores
        cd ignores
        ${format} gitignored.json
        cmp gitignored.json ${original}
        rm .gitignore
        ${format} gitignored.json
        if cmp gitignored.json ${original}; then exit 1; fi
        touch $out
      '';
    };
}
