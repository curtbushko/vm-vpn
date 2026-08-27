{ workspace, ... }:

{
  environment.etc."vm-vpn/start.html".text = ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>${workspace.displayName}</title>
        <style>
          body { background: #${workspace.colors.background}; color: #${workspace.colors.foreground}; display: grid; font-family: sans-serif; min-height: 100vh; margin: 0; place-items: center; }
          main { border: 4px solid #${workspace.colors.accent}; border-radius: 1rem; padding: 4rem; text-align: center; }
          h1 { font-size: 4rem; margin: 0; }
          p { color: #${workspace.colors.accentText}; font-size: 2rem; }
        </style>
      </head>
      <body><main><h1>${workspace.productIcon} ${workspace.productLabel}</h1><p>${workspace.environmentIcon} ${workspace.environmentLabel}</p><strong>${workspace.vmName}</strong></main></body>
    </html>
  '';

  environment.etc."vm-vpn/wallpaper.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1200">
      <rect width="100%" height="100%" fill="#${workspace.colors.background}"/>
      <text x="50%" y="48%" text-anchor="middle" fill="#${workspace.colors.foreground}" font-family="sans-serif" font-size="96">${workspace.productLabel}</text>
      <text x="50%" y="58%" text-anchor="middle" fill="#${workspace.colors.accentText}" font-family="sans-serif" font-size="48">${workspace.environmentLabel} · ${workspace.vmName}</text>
    </svg>
  '';
}
