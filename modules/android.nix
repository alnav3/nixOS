{pkgs, ...}:
{
  networking.nftables.enable = true;
  virtualisation.waydroid.enable = true;

  # Allow waydroid network interface through firewall
  networking.firewall = {
    trustedInterfaces = [ "waydroid0" ];
  };

  # Waydroid networking is now working with the original script
  # We removed the global IPv6 disable and use selective IPv6 disabling instead

  # Steam Deck controller key layout for Waydroid
  environment.etc = {
    "waydroid-keylayout/Vendor_28de_Product_11ff.kl" = {
      text = ''
        # Copyright (C) 2020 The Android Open Source Project
        #
        # Licensed under the Apache License, Version 2.0 (the "License");
        # you may not use this file except in compliance with the License.
        # You may obtain a copy of the License at
        #
        #      http://www.apache.org/licenses/LICENSE-2.0
        #
        # Unless required by applicable law or agreed to in writing, software
        # distributed under the License is distributed on an "AS IS" BASIS,
        # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        # See the License for the specific language governing permissions and
        # limitations under the License.

        #
        # Steam Deck Controller - USB
        #

        # Mapping according to https://developer.android.com/training/game-controllers/controller-input.html

        key 304   BUTTON_A
        key 305   BUTTON_B
        key 307   BUTTON_X
        key 308   BUTTON_Y

        key 310   BUTTON_L1
        key 311   BUTTON_R1

        # Triggers.
        axis 0x02 LTRIGGER
        axis 0x05 RTRIGGER

        # Left and right stick.
        axis 0x00 X
        axis 0x01 Y

        # Right stick / mousepad
        axis 0x03 Z
        axis 0x04 RZ

        key 317   BUTTON_THUMBL
        key 318   BUTTON_THUMBR

        # Hat.
        axis 0x10 HAT_X
        axis 0x11 HAT_Y

        # Mapping according to https://www.kernel.org/doc/Documentation/input/gamepad.txt
        # Left arrow
        key 314   BUTTON_SELECT
        # Right arrow
        key 315   BUTTON_START

        # Steam key
        key 316   BUTTON_MODE
      '';
      mode = "0644";
    };

    "waydroid-keylayout/ATV-Generic.kl" = {
      text = ''
        # Generic key layout file for Android TV with ENTER remapped to DPAD_CENTER
        # for Leanback Keyboard compatibility

        key 1     ESCAPE
        key 2     1
        key 3     2
        key 4     3
        key 5     4
        key 6     5
        key 7     6
        key 8     7
        key 9     8
        key 10    9
        key 11    0
        key 12    MINUS
        key 13    EQUALS
        key 14    DEL
        key 15    TAB
        key 16    Q
        key 17    W
        key 18    E
        key 19    R
        key 20    T
        key 21    Y
        key 22    U
        key 23    I
        key 24    O
        key 25    P
        key 26    LEFT_BRACKET
        key 27    RIGHT_BRACKET
        key 28    DPAD_CENTER
        key 29    CTRL_LEFT
        key 30    A
        key 31    S
        key 32    D
        key 33    F
        key 34    G
        key 35    H
        key 36    J
        key 37    K
        key 38    L
        key 39    SEMICOLON
        key 40    APOSTROPHE
        key 41    GRAVE
        key 42    SHIFT_LEFT
        key 43    BACKSLASH
        key 44    Z
        key 45    X
        key 46    C
        key 47    V
        key 48    B
        key 49    N
        key 50    M
        key 51    COMMA
        key 52    PERIOD
        key 53    SLASH
        key 54    SHIFT_RIGHT
        key 55    NUMPAD_MULTIPLY
        key 56    ALT_LEFT
        key 57    SPACE
        key 58    CAPS_LOCK
        key 102   MOVE_HOME
        key 103   DPAD_UP
        key 105   DPAD_LEFT
        key 106   DPAD_RIGHT
        key 108   DPAD_DOWN
        key 111   FORWARD_DEL
        key 158   BACK
        key 304   BUTTON_A
        key 305   BUTTON_B
        key 307   BUTTON_X
        key 308   BUTTON_Y
        key 310   BUTTON_L1
        key 311   BUTTON_R1
        key 314   BUTTON_SELECT
        key 315   BUTTON_START
        key 316   BUTTON_MODE
        key 317   BUTTON_THUMBL
        key 318   BUTTON_THUMBR

        # Joystick and game controller axes
        axis 0x00 X
        axis 0x01 Y
        axis 0x02 Z
        axis 0x03 RX
        axis 0x04 RY
        axis 0x05 RZ
        axis 0x10 HAT_X
        axis 0x11 HAT_Y
      '';
      mode = "0644";
    };
  };

  # Copy the key layout files to waydroid overlay on system activation
  system.activationScripts.waydroid-keylayout = ''
    mkdir -p /var/lib/waydroid/overlay/system/usr/keylayout
    
    # Copy Steam Deck controller layout
    if [ -f /etc/waydroid-keylayout/Vendor_28de_Product_11ff.kl ]; then
      cp /etc/waydroid-keylayout/Vendor_28de_Product_11ff.kl /var/lib/waydroid/overlay/system/usr/keylayout/
      chown root:root /var/lib/waydroid/overlay/system/usr/keylayout/Vendor_28de_Product_11ff.kl
      chmod 644 /var/lib/waydroid/overlay/system/usr/keylayout/Vendor_28de_Product_11ff.kl
    fi
    
    # Copy Android TV generic layout (use this if you have Android TV image)
    if [ -f /etc/waydroid-keylayout/ATV-Generic.kl ]; then
      cp /etc/waydroid-keylayout/ATV-Generic.kl /var/lib/waydroid/overlay/system/usr/keylayout/Generic.kl
      chown root:root /var/lib/waydroid/overlay/system/usr/keylayout/Generic.kl
      chmod 644 /var/lib/waydroid/overlay/system/usr/keylayout/Generic.kl
    fi
  '';

  environment.systemPackages = with pkgs; [
    scrcpy
    wlr-randr
    universal-android-debloater
    cage
    iptables-nftables-compat
    xorg.xdpyinfo
  ];
}
