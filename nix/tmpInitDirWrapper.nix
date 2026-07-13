{
  runCommandLocal,
  writeShellScriptBin,
}:

{
  emacsEnv,
  initFiles,
  earlyInitFile,
  assetsDir ? null,
  manifestFile ? null,
  manifestFileName ? "twist-manifest.json",
}:
let
  initFile = runCommandLocal "twist-init.el" { } ''
    mkdir -p "$out"
    touch "$out/init.el"
    for file in ${builtins.concatStringsSep " " initFiles}; do
      cat "$file" >> "$out/init.el"
      echo >> "$out/init.el"
    done
  '';
in
writeShellScriptBin "emacs-twist" ''
  set -eu

  initdir="$(mktemp -d "''${TMPDIR:-/tmp}/emacs-twist-XXX")"
  cleanup() {
    rm -rf "$initdir"
  }
  trap cleanup EXIT

  ln -s ${initFile}/init.el "$initdir/init.el"
  ln -s ${earlyInitFile} "$initdir/early-init.el"
  ${if assetsDir == null then "" else ''ln -s ${assetsDir} "$initdir/assets"''}
  ${if manifestFile == null then "" else ''ln -s ${manifestFile} "$initdir/${manifestFileName}"''}

  ${emacsEnv}/bin/emacs --init-directory="$initdir" "$@"
''
