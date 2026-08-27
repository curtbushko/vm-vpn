{
  resolve =
    {
      productName,
      environmentName,
      product,
      environment,
      workspace,
    }:
    assert builtins.match "[a-z0-9]+(-[a-z0-9]+)*" productName != null;
    assert builtins.match "[a-z0-9]+(-[a-z0-9]+)*" environmentName != null;
    assert product != null;
    assert environment != null;
    let
      vmName = "${productName}-${environmentName}";
      vmPath = "${productName}/${environmentName}";
      colors = product.colors // environment.colors // (workspace.colors or { });
    in
    {
      product = productName;
      environment = environmentName;
      inherit vmName vmPath colors;
      displayName = workspace.displayName or "${product.label} - ${environment.label}";
      productLabel = product.label;
      productIcon = product.icon;
      environmentLabel = environment.label;
      environmentIcon = environment.icon;
      statusText = "${product.icon} ${productName} / ${environment.icon} ${environmentName}";
    };
}
