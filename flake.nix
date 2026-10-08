{
  description = "❄️ Emacs configuration with enhanced reproducibility using Twist.nix.";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };

  inputs = {
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    # emacs-overlay 自身がビルド・キャッシュに使っている nixpkgs へ合わせる。
    # 独立したピンのままだと同じコミットになる保証がなく、emacsPackage が
    # nix-community.cachix.org でキャッシュヒットしない。
    nixpkgs.follows = "emacs-overlay/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    twist.url = "github:emacs-twist/twist.nix";
    org-babel.url = "github:emacs-twist/org-babel";

    elpa = {
      url = "github:elpa-mirrors/elpa";
      flake = false;
    };

    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };

    nongnu = {
      url = "github:elpa-mirrors/nongnu";
      flake = false;
    };

    epkgs = {
      url = "github:emacsmirror/epkgs";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, flake-parts, emacs-overlay, ... }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem =
        { system, lib, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              emacs-overlay.overlays.default
              inputs.org-babel.overlays.default
            ];
          };

          lockDir = ./lock;
          earlyInitFile = pkgs.tangleOrgBabelFile "early-init.el" ./early-init.org { };
          initFiles = [ (pkgs.tangleOrgBabelFile "init.el" ./emacs-config.org { }) ];

          mkPackage =
            emacsPackage:
            inputs.twist.lib.makeEnv {
              inherit pkgs emacsPackage lockDir initFiles;
              exportManifest = true;

              # use-package ではなく setup.el を使うので、パッケージの抽出も
              # (:package NAME) を読むパーサに切り替える
              initParser = inputs.twist.lib.parseSetup { inherit lib; } { };

              # setup 自身は setup で宣言できないため明示的に足す
              extraPackages = [ "setup" ];

              registries = import ./nix/registries.nix {
                inherit inputs emacsPackage;
              } ++ [ ];
            };

          package = mkPackage pkgs.emacs-git-pgtk;
          # GUIの要らないホスト (NAS機等) 向け。home-manager側 (.ml-nix) が
          # host typeに応じてdefault/noxを出し分ける。native-compも切って
          # ビルドをbyte-compileのみにし、libgccjit/binutilsも実行時
          # クロージャから外す (NASでのElisp実行速度低下は許容)。
          packageNox = mkPackage (pkgs.emacs-git-nox.override { withNativeCompilation = false; });

          defaultWrapper = pkgs.callPackage ./nix/tmpInitDirWrapper.nix { } {
            emacsEnv = package;
            inherit initFiles earlyInitFile;
            assetsDir = ./assets;
            manifestFile = package.emacsWrapper.elispManifestPath;
          };
        in
        {
          packages.default = package;
          packages.nox = packageNox;
          # home-manager モジュール側から拾えるように earlyInitFile も出力しておく
          packages.earlyInitFile = earlyInitFile;

          apps = package.makeApps { lockDirName = "lock"; } // {
            default = {
              type = "app";
              program = "${defaultWrapper}/bin/emacs-twist";
            };
          };
        };

      flake = {
        homeModules.twist = { lib, pkgs, ... }: {
          imports = [
            inputs.twist.homeModules.emacs-twist
          ];

          programs.emacs-twist = {
            config = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
            earlyInitFile = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.earlyInitFile;
            createManifestFile = lib.mkDefault true;
          };

          home.file = {
            ".config/emacs/assets/".source = ./assets;
          };

          home.packages =
            with pkgs;
            [
              adwaita-icon-theme
              adwaita-icon-theme-legacy
              ffmpeg-headless
              gcc
              skkDictionaries.l
              vips
              wl-clipboard
            ];
        };
      };
    };
}
