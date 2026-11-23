{
  lib,
  jq,
  nodejs,
}:

{
  app,
  web,
  nodeModules,
  platform,
}:

{
  nativeBuildInputs = [
    jq
    nodejs
  ]
  ++ nodeModules.nativeBuildInputs or [ ];
  buildInputs = nodeModules.buildInputs or [ ];

  # leaves the shell in the app's native project directory
  prepare = ''
    export HOME="$TMPDIR"
    ${nodeModules.install}

    cd ${lib.escapeShellArg app}
    cap="$(dirname "$(node -p 'require.resolve("@capacitor/cli/package.json")')")/bin/capacitor"
    webDir=$(node "$cap" config --json | jq -r .app.webDir)
    rm -rf "$webDir"
    cp -r --no-preserve=mode ${web} "$webDir"
    node "$cap" sync ${platform}
    cd ${platform}
  '';
}
