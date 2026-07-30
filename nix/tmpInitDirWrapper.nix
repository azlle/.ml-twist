{
  runCommandLocal,
  writeShellScriptBin,
  coreutils,
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

  bin = "${coreutils}/bin";
in

writeShellScriptBin "emacs-twist" ''
  set -eu

  # Use a 6-X template for POSIX-compliant mkdtemp(3) portability, and pin
  # to coreutils' mktemp explicitly to avoid relying on whatever mktemp
  # implementation (e.g. BusyBox) happens to be on $PATH at runtime.
  initdir="$(${bin}/mktemp -d -p "''${TMPDIR:-/tmp}" emacs-twist-XXXXXX)"
  cleanup() {
    ${bin}/rm -rf "$initdir"
  }
  trap cleanup EXIT

  ${bin}/ln -s ${initFile}/init.el "$initdir/init.el"
  ${bin}/ln -s ${earlyInitFile} "$initdir/early-init.el"
  ${if assetsDir == null then "" else ''${bin}/ln -s ${assetsDir} "$initdir/assets"''}
  ${if manifestFile == null then "" else ''${bin}/ln -s ${manifestFile} "$initdir/${manifestFileName}"''}

  ${emacsEnv}/bin/emacs --init-directory="$initdir" "$@"
''
