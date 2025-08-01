#!/bin/bash

if [ -z "$OMARCHY_BARE" ]; then
  echo "==> Installing core safe apps (ARM-friendly, no auto-launch issues)..."

  # ✅ Main safe apps for ARM
  yay -S --noconfirm --needed \
    gnome-calculator \
    gnome-keyring \
    libreoffice \
    localsend-bin

  echo "==> Skipping GUI apps that auto-launch or fail on ARM."
  # The following apps are skipped for now:
  #   signal-desktop  -> x86-only
  #   obs-studio      -> depends on svt-av1 (no ARM build)
  #   kdenlive        -> auto-opens after install & hangs script
  #   spotify         -> ARM build issues
  #   zoom            -> x86-only
  #   1password-beta  -> ARM signing issues
  #   1password-cli   -> ARM signing issues
  #   xournalpp       -> auto-opens after install

  # ✅ Optional “try later” packages (commented)
  # yay -S --noconfirm --needed signal-desktop obs-studio kdenlive \
  #     spotify zoom 1password-beta 1password-cli xournalpp obsidian-bin

  # pinta removed due to ARM issues
  # yay -S --noconfirm --needed pinta

  echo "==> Installing individual CLI-friendly extras..."
  for pkg in typora; do
    yay -S --noconfirm --needed "$pkg" || \
      echo -e "\e[31mFailed to install $pkg. Continuing without!\e[0m"
  done
fi

echo "==> Refreshing Omarchy application links/configs..."
source ~/.local/share/omarchy/bin/omarchy-refresh-applications || true

echo "==> Default app installation script complete."