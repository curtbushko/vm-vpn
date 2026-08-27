let
  identity = import ./identity.nix;
in
{
  make =
    {
      productName,
      environmentName,
      workspace,
    }:
    identity.resolve {
      inherit productName environmentName workspace;
      product = import ../products/${productName}.nix;
      environment = import ../environments/${environmentName}.nix;
    };

  registry =
    workspaces:
    let
      entries = map (workspace: {
        name = workspace.vmPath;
        value = workspace;
      }) workspaces;
      result = builtins.listToAttrs entries;
    in
    assert builtins.length workspaces == builtins.length (builtins.attrNames result);
    result;
}
