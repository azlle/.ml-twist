{
  inputs,
  emacsPackage
}:

[
  {
    name = "local";
    type = "melpa";
    path = ../recipes;
  }

  {
    name = "gnu";
    type = "elpa";
    path = inputs.elpa.outPath + "/elpa-packages";
    core-src = emacsPackage.src;
    auto-sync-only = true;
    exclude = [
      "lv" # hydraでなにもかも終わってしまう
    ];
  }

  {
    name = "melpa";
    type = "melpa";
    path = inputs.melpa.outPath + "/recipes";
  }

  {
    type = "elpa";
    path = inputs.nongnu.outPath + "/elpa-packages";
  }

  {
    name = "emacsmirror";
    type = "gitmodules";
    path = inputs.epkgs.outPath + "/.gitmodules";
  }
]
