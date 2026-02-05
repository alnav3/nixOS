{ pkgs, fetchurl, glibc, glib, udev, nss, nspr, atk, libX11, libxcb, dbus, gdk-pixbuf, gtk3, pango, cairo, libXcomposite, libXdamage, libXext, libXfixes, libXrandr, expat, libdrm, libxkbcommon, mesa, alsa-lib, cups, at-spi2-core, at-spi2-atk }:

pkgs.appimageTools.wrapType2 {
  pname = "thorium";
  version = "1.6.0";

  src = fetchurl {
    url = "https://github.com/edrlab/thorium-reader/releases/download/v1.6.0/Thorium-1.6.0.AppImage";
    sha256 = "ce2888673573ac6ba1e9d7b8540724ec83c95f9696c4bcd50fe65b6f459f31e3";
  };

  extraPkgs = pkgs: with pkgs; [
    glibc
    glib
    udev
    nss
    nspr
    atk
    dbus
    gdk-pixbuf
    gtk3
    pango
    cairo
    expat
    libdrm
    libxkbcommon
    mesa
    alsa-lib
    cups
    at-spi2-core
    at-spi2-atk
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
  ];
}
