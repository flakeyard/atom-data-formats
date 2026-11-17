# The root module of atom-data-formats (FY-0017). It fails when the consumer
# locks treefmt-nix or git-hooks.nix a second time, imports the modules of
# both and the atom's modules. The atom's inputs and the root of the
# repository reach the other files only as function arguments (FY-0039).
atomInputs:
{
  inputs,
  lib,
  self,
  ...
}:
let
  root = ./..;
  # The functions that atoms share, of the revision the atom pins (FY-0040).
  shared = atomInputs.lib-atom.lib;
  upstream = shared.upstream {
    atom = "atom-data-formats";
    own = atomInputs;
    consumer = inputs;
  };
  # The warning of the next major version, with lib of the consumer's nixpkgs.
  warning =
    pkgsLib:
    shared.warning {
      lib = pkgsLib;
      atom = "atom-data-formats";
      inherit root;
    };
  # The configuration file that each tool gets (FY-0037).
  configs = import ./configs.nix {
    inherit lib root shared;
    project = self.outPath;
  };
in
{
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    (upstream "treefmt-nix" atomInputs.treefmt-nix.flakeModule)
    (upstream "git-hooks" atomInputs.git-hooks.flakeModule)
    (import ./formatter.nix { inherit configs; })
    (import ./hooks.nix { inherit configs; })
    (import ./checks.nix {
      inherit (atomInputs) git-hooks;
      inherit (shared) domain;
      inherit warning;
    })
    (import ./shell.nix { inherit warning; })
  ];
}
