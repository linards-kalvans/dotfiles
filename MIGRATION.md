# MIGRATION.md — moving this config to a second laptop

This fork carries a personal ML4W Hyprland configuration plus a set of fixes found
by debugging faults on the host `eleving-arch-lk`. It is **not** a general-purpose
ML4W release; read [Host-specific values](#host-specific-values-you-must-change)
before using it on another machine.

- **Base:** ML4W Dotfiles for Hyprland (STABLE) **2.9.9.5** — upstream tag `2.9.9.5`
- **Branch:** `eleving-arch-lk`, rebased onto that tag so upstream merges work
- **Verified on:** Arch Linux, Hyprland 0.56.2, waybar 0.15.0, hypridle 0.1.8,
  hyprlock 0.9.6, wlogout 1.2.2, nwg-displays 0.4.4, systemd 261

---

## Fixes carried by this branch

Each fix has a diagnosis document behind it. They are quoted in the commit messages
and in comments at the point of change.

| Fix | Files | Why |
|---|---|---|
| Monitor layout pinned by `desc:` | `.config/hypr/conf/monitors/desc-pinned.conf`, `.config/hypr/lua/monitors_pin.lua`, `.config/hypr/main.lua` | DP-MST recreates its connectors on every topology change, so `DP-5`/`DP-6` become `DP-7`/`DP-8` and a name-based layout silently stops applying |
| `hl.dsp.dpms` takes a **table** | `.config/hypr/hypridle.conf`, `.config/hypr/scripts/dpms-on.sh` | `hl.dsp.dpms("on")` returns `ok` and switches the outputs **off**. A success return proves nothing — verify with `hyprctl -j monitors \| jq '.[].dpmsStatus'` |
| `on-resume` on the suspend listener | `.config/hypr/hypridle.conf` | For a suspend hypridle requests itself, its own `before_sleep_cmd`/`after_sleep_cmd` never run |
| DPMS wake from key/mouse | `.config/hypr/conf/custom.conf`, `.config/hypr/lua/custom.lua` | Both default to `false`, so once outputs are DPMS-off nothing on the keyboard can bring them back |
| `PrepareForSleep` DPMS watcher | `.config/hypr/scripts/dpms-on-resume-watch.sh`, `.config/systemd/user/dpms-on-resume.service` | `systemd --user` has no `sleep.target`, so a user unit ordered against it never starts |
| wlogout scale arithmetic | `.config/ml4w/scripts/wlogout.sh` | Hyprland 0.56.2 prints an integral `scale` as `1`, not `1.00`; ML4W's `sed 's/\.//'` fixed-point idiom then errs by 100× and wlogout core-dumps before mapping |
| `ext/workspaces` format | `.config/waybar/modules.json` | That module matches `format-icons` by workspace **name**, unlike `hyprland/workspaces` which keys by state; the inherited icon map rendered every button empty |
| Wallpaper bring-up + rotation | `.config/hypr/scripts/wallpaper-boot.sh`, `.config/hypr/scripts/wallpaper-set.sh`, `.config/hypr/conf/custom.conf`, `.config/hypr/lua/autostart.lua`, `.config/ml4w/settings/wallpaper-automation.sh` | ML4W's autostart spawns `swww-daemon` and `wallpaper-restore.sh` back to back with no readiness check, so the daemon can exit before it binds the outputs and the desktop stays black with nothing logged. `wallpaper-boot.sh` waits for `swww query` to answer first, then runs the rotation loop itself — ML4W's `wallpaper-automation.sh` is a toggle keyed on a `~/.cache` flag that survives reboot, so from an autostart entry it turns rotation *off* every other boot. `wallpaper-set.sh` also keeps working when `waypaper` cannot start |

---

## Installing on the second laptop

Assumes ML4W 2.9.9.5 stable is **already installed** there, so `~/.config` already
holds the symlinks into `~/.mydotfiles/com.ml4w.dotfiles.stable`.

### 1. Back up what is there

```bash
mv ~/.mydotfiles/com.ml4w.dotfiles.stable ~/.mydotfiles/com.ml4w.dotfiles.stable.bak
```

### 2. Clone this branch into place

Upstream keeps the tree in a `dotfiles/` subfolder, so check out that subfolder
as the dotfiles root:

```bash
git clone --branch eleving-arch-lk git@github.com:linards-kalvans/dotfiles.git ~/src/ml4w-dotfiles
cp -a ~/src/ml4w-dotfiles/dotfiles ~/.mydotfiles/com.ml4w.dotfiles.stable
```

Keeping `~/src/ml4w-dotfiles` as the git checkout means the live tree stays a plain
directory — edit there, commit in the checkout, re-copy. If you would rather have the
live tree be the git repo, clone it directly and accept that upstream's root files
(`README.md`, `CHANGELOG.md`, the `.dotinst` manifests) land beside your config.

### 3. Verify the symlinks survived

The 27 `~/.config` entries and 4 home-level entries should still resolve:

```bash
find ~/.config -maxdepth 1 -type l -lname '*mydotfiles*' ! -exec test -e {} \; -print
find ~ -maxdepth 1 -type l -lname '*mydotfiles*' ! -exec test -e {} \; -print
```

Both should print nothing. Anything printed is a dangling link — recreate it with
`ln -sfn ~/.mydotfiles/com.ml4w.dotfiles.stable/.config/<name> ~/.config/<name>`.

> **Not carried:** `alacritty` and `dunst` point into a second tree,
> `~/.mydotfiles/com.ml4w.hyprlandstarter/`, which is **not** under version control and
> is not part of this repo. Those two links will dangle unless that tree exists on the
> target too.

### 4. Copy the files that live outside the tree

`~/.config/systemd/user` and `~/.local/bin` are not symlinked into the dotfiles tree,
so their contents are carried here but must be placed by hand:

```bash
install -Dm644 ~/.mydotfiles/com.ml4w.dotfiles.stable/.config/systemd/user/dpms-on-resume.service \
               ~/.config/systemd/user/dpms-on-resume.service
install -Dm755 ~/.mydotfiles/com.ml4w.dotfiles.stable/.local/bin/screenshot.sh    ~/.local/bin/screenshot.sh
install -Dm755 ~/.mydotfiles/com.ml4w.dotfiles.stable/.local/bin/hypr-perf-toggle ~/.local/bin/hypr-perf-toggle

for t in hypr-config-mode hypr-config-audit hypr-state-dump ml4w-variations-sync; do
    ln -sfn ~/.config/hypr/tools/$t ~/.local/bin/$t
done

systemctl --user daemon-reload
systemctl --user enable --now dpms-on-resume.service
```

### 5. Pick a config language

Hyprland reads `hyprland.lua` **once at startup**; if it exists, `hyprland.conf` is
ignored entirely. The two formats cannot be mixed in a session and `hyprctl reload`
does not switch between them — a restart is required.

```bash
hypr-config-mode lua     # or: hypr-config-mode conf
hypr-config-audit        # compares the two trees directive by directive
```

Both trees are kept in sync in this branch. If you only want one, `conf` is the
upstream-supported path.

---

## Host-specific values you **must** change

Everything below describes `eleving-arch-lk` and will be wrong elsewhere.

| What | Where | Action on the new machine |
|---|---|---|
| **Monitor identities** | `.config/hypr/conf/monitors/desc-pinned.conf`, `.config/hypr/lua/monitors_pin.lua` | Replace the two `desc:` strings (`Dell Inc. DELL P2314H J8J314CFB2YS`, `Dell Inc. DELL E2420HS DXG3X03`) with this machine's. Read them from `hyprctl monitors \| grep description`. If the new machine has no MST dock, drop both files and point `main.lua` back at `require("monitors")` |
| **Generated monitor layout** | `.config/hypr/monitors.conf`, `.config/hypr/monitors.lua` | nwg-displays output for this host's three screens. Just run `nwg-displays` on the target and let it regenerate |
| **Left-handed mouse** | `.config/hypr/conf/custom.conf`, `.config/hypr/lua/custom.lua` | `left_handed = true` is deliberate here. Remove it unless the new user is also left-handed |
| **Keyboard layout** | `.config/hypr/conf/custom.conf`, `.config/hypr/lua/custom.lua` | `kb_layout = lv`, `kb_variant = apostrophe` |
| **Autostart apps** | `.config/hypr/conf/custom.conf`, `.config/hypr/lua/autostart.lua` | Two Brave PWA `--app-id=` values, `zen-browser --profile /home/linards/.config/zen-linards`, `/opt/pcloud/pcloud-drive.AppImage`, `solaar -w hide`. All host-installed paths |
| **Wallpaper state** | `.config/waypaper/config.ini`, `.config/hypr/hyprpaper.conf` | Absolute paths to the chosen wallpaper |
| **Wallpaper rotation interval** | `.config/ml4w/settings/wallpaper-automation.sh` | `14400` (4 h) here. ML4W's stock `60` fires a full matugen retheme and a waybar + nwg-dock relaunch every minute, and rewrites the tracked colour files 1440 times a day |
| **GTK bookmarks** | — | Deliberately **not** carried; the original referenced an internal host. Gitignored |

### Username

These files hardcode `/home/linards`:

```
.bashrc
.gtkrc-2.0
.config/hypr/conf/custom.conf
.config/hypr/hyprpaper.conf
.config/hypr/lua/autostart.lua
.config/hypr/tools/hypr-state-dump
.config/waypaper/config.ini
```

If the target user is also `linards` these work unchanged — verify only. Otherwise:

```bash
grep -rl '/home/linards' ~/.mydotfiles/com.ml4w.dotfiles.stable \
  | xargs sed -i "s|/home/linards|$HOME|g"
```

---

## Merging upstream ML4W updates

The branch is rebased onto upstream tag `2.9.9.5`, so merges are real three-way merges.

```bash
cd ~/src/ml4w-dotfiles
git remote add upstream https://github.com/mylinuxforwork/dotfiles.git   # once
git fetch upstream --tags
git merge 2.9.9.6
```

A dry run of `git merge 2.9.9.6` on this branch produced **6 conflicts**: five waybar
theme files that this baseline deleted (modify/delete — take upstream's or keep the
deletion, whichever you want) and `.gtkrc-2.0`, where the conflict is the GTK theme
name. Nothing in `.config/hypr` conflicted.

**Go one tag at a time.** Upstream `main` is now **2.15.1 "ML4W OS"**, which is a
rewrite rather than an increment: its manifest references `input.lua`, `gesture.lua`,
`hyprland-gui.lua`, `conf/keybinding.lua` and `hyprsunset.conf`, none of which exist in
2.9.9.5. Merging straight to it is a migration with heavy conflicts, not an update.

Worth knowing: upstream has since moved to Lua natively, so the Lua tree in this branch
may converge with — or be superseded by — theirs.

After any merge:

```bash
hypr-config-audit     # both trees still agree?
hyprctl reload        # or restart Hyprland if the config language changed
```
