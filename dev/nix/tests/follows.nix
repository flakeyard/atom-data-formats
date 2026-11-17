# A consumer that locks treefmt-nix or git-hooks.nix a second time fails at
# evaluation with the follows line to add (FY-0017).
{ testing, ... }:
{
  perSystem = testing.follows {
    output = [
      "checks"
      "data-formats"
    ];
    # Restated: the text is the interface (FY-0035).
    messages = {
      treefmt-nix = ''
        atom-data-formats: input 'treefmt-nix' is locked twice; add to input atom-data-formats:
          inputs.treefmt-nix.follows = "treefmt-nix";'';
      git-hooks = ''
        atom-data-formats: input 'git-hooks' is locked twice; add to input atom-data-formats:
          inputs.git-hooks.follows = "git-hooks";'';
    };
  };
}
