# Wallpaper sources

## `arch-<name>.png`, `default.jpg`
From the `archlinux-wallpaper` package (1.6.1-7), `/usr/share/backgrounds/archlinux/`,
downscaled from 5120x2880 to 2560x1440. Official Arch Linux artwork.
`default.jpg` is a copy of `archbtw` — it is the hardcoded fallback in ML4W's
`wallpaper-restore.sh` and `wallpaper.sh`, so the filename cannot change. It is
excluded from the rotation draw in `wallpaper-boot.sh` to avoid a double weighting.

## `arch-f4dzn-NN.png`
https://github.com/f4dzN/archlinux-wallpapers — MIT, Copyright (c) 2025 f4dzn.
Original work, drawn in Inkscape. Downscaled from 3840x2160 to 2560x1440.
NN matches the upstream filename.
