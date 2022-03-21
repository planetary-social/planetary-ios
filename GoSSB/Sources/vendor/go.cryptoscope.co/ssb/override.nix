# SPDX-FileCopyrightText: 2021 The Go-SSB Authors
#
# SPDX-License-Identifier: MIT

with import <nixpkgs> { };
go-ssb.overrideDerivation (drv: { 
  name = "go-ssb-fromsrc";
  src = ./.;
  # use dep2nix to make this
  #goDeps = ./deps.nix;
})
