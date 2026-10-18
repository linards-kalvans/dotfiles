#!/usr/bin/env python3
"""Remember and restore a monitor layout per dock, keyed by monitor description.

WHAT IT DOES

Each distinct set of connected monitors -- office dock, home dock, undocked, or a
partial hookup -- is a *profile*. The layout you last left in place for a profile is
remembered and restored the next time that set of monitors appears.

  * restore: on Hyprland start, and after every monitoradded/monitorremoved burst
    (i.e. dock connect and disconnect).
  * save: once the layout has been quiet for QUIET_SECONDS and differs from what is
    stored. Arrange displays in nwg-displays, walk away, and it is remembered.
  * cold start: a profile that has never been seen falls back to the hand-written
    baseline in ~/.config/hypr/monitor-pins.conf, which is then learned as its
    first profile.

WHY THE LAYOUT IS NOT IN THE HYPRLAND CONFIG

nwg-displays runs no command on Hyprland -- it writes the generated monitors file
and relies on Hyprland's auto-reload (see nwg_displays/main.py:1110). Anything
sourced after that generated file is re-applied by the same reload and clobbers the
GUI change within a second. Pushing the layout imperatively from here is what lets
an nwg-displays change stick until the next dock event.

PROFILE KEY

The sorted descriptions of every connected output, joined with " | ". Descriptions
survive re-enumeration; connector names do not (MST recreates DP-5/DP-6 as
DP-7/DP-8, and evdi numbers DisplayLink's DVI-I-N in probe order). The dock's USB ID
is recorded alongside for diagnostics only -- it is not part of the key, so a
partial hookup gets its own remembered layout instead of overwriting the full one.

USAGE

    monitor-pin.py watch     # restore now, then on every dock event; auto-save (autostart)
    monitor-pin.py apply     # restore the current profile once and exit
    monitor-pin.py save      # capture the current layout for the current profile
    monitor-pin.py show      # print the current key, the live layout and the store

ENVIRONMENT SEAMS (testing only; unset in normal use)

    MONITOR_PIN_STORE     alternative profile store path
    MONITOR_PIN_SOCKET2   stand-in socket2 path, so the event path can be driven
                          without a physical dock (hyprctl still talks to the real
                          compositor). Keep it short: AF_UNIX caps paths at 108
                          bytes. Never fake HYPRLAND_INSTANCE_SIGNATURE instead --
                          hyprctl reads it too and every call then fails.
    MONITOR_PIN_QUIET     seconds of quiet before an auto-save
"""

import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone

HYPR_DIR = os.path.expanduser("~/.config/hypr")
BASELINE_FILE = os.path.join(HYPR_DIR, "monitor-pins.conf")

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "hypr")
STORE_FILE = os.environ.get("MONITOR_PIN_STORE",
                            os.path.join(STATE_DIR, "monitor-profiles.json"))

# Hyprland discards an exec-once child's stderr: it reaches neither the compositor
# log nor the journal, so a watcher that only printed left no record of what any
# restore did. Keep a file copy, rotated at ROTATE_BYTES so it cannot grow forever.
LOG_FILE = os.environ.get("MONITOR_PIN_LOG", os.path.join(STATE_DIR, "monitor-pin.log"))
ROTATE_BYTES = 1 << 20

# Monitor events arrive one per output, so a dock carrying three panels produces a
# burst. Coalesce them and restore once the burst goes quiet.
DEBOUNCE_SECONDS = 1.0

# Hyprland keeps re-probing DisplayLink/MST outputs for a moment after the event;
# applying into that window is accepted but can be undone by the tail of the
# compositor's own hotplug handling.
SETTLE_SECONDS = 0.5

# How long the layout must hold still before it is learned. Long enough that a
# mid-drag intermediate state in nwg-displays is never what gets saved.
QUIET_SECONDS = float(os.environ.get("MONITOR_PIN_QUIET", "20"))

# A layout identical to nwg-displays' generated file is ambiguous: it is either a
# change you just made in that GUI, or the side effect of an unrelated `hyprctl
# reload` re-applying the same file. The generated file's mtime separates them --
# only a real GUI change rewrites it. Within this window, learn; outside it, treat
# the layout as a reload artifact and put the stored profile back.
NWG_RECENT_SECONDS = 60.0

# How often to re-read the live layout. nwg-displays changes emit no monitor event
# at all, so polling is the only way to notice them.
POLL_SECONDS = 5.0

# Abandon the session after roughly a minute of failed reconnects; see watch().
MAX_RECONNECTS = 12

MONITOR_EVENTS = ("monitoradded", "monitoraddedv2",
                  "monitorremoved", "monitorremovedv2")

# A config reload re-applies nwg-displays' generated monitors file, which at the
# *other* site names connectors that are absent here -- so only the eDP-1 rule lands
# and every external drops to Hyprland's default append placement. Nothing is added
# or removed, so no monitor event fires; matugen rewriting the colour file on a
# wallpaper change is enough to do it. Treat a reload as a restore trigger.
# (Confirmed 2026-10-02: lua/colors.lua rewritten 12:50:25, layout reset, learner
# adopted it at 12:50:48.)
RELOAD_EVENTS = ("configreloaded",)

# Moving a whole workspace to another monitor does NOT make Hyprland emit
# wlr-foreign-toplevel output_enter/output_leave for the windows it carries, so
# waybar's wlr/taskbar keeps showing them on the bar of the monitor they left
# (Waybar #2993). Moving a single window does emit them, so only these events --
# and the profile restore below, which reassigns workspaces in bulk -- need the
# resync. A SIGUSR2 reload makes waybar re-enumerate the toplevels.
WORKSPACE_MOVE_EVENTS = ("moveworkspace", "moveworkspacev2")

# Workspace moves arrive one per workspace when a profile is restored. Coalesce.
WAYBAR_RESYNC_DEBOUNCE = 2.0

# Docks seen on this host. Diagnostics only -- never part of the profile key.
# The office dock is identified by the DisplayLink bridge itself; the UGREEN dock by
# the Fresco billboard it exposes unconditionally. The GenesysLogic hub pair
# (05e3:0626/05e3:0610) fronts BOTH docks and so identifies neither.
DOCK_IDS = {"17e9:601e": "office HP USB-C/A Universal Dock G2 (DisplayLink)",
            "1d5c:7102": "home UGREEN USB-C dock (DP alt mode + MST)"}

# Extra `key,value` pairs a hyprlang monitor line may carry, mapped to their
# MonitorSpec field. Anything else is dropped with a warning.
EXTRA_KEYS = {"vrr": "vrr", "transform": "transform", "bitdepth": "bitdepth",
              "mirror": "mirror"}


def log(msg):
    """Print to stderr and append a timestamped copy to LOG_FILE.

    Without the file half, a profile learned from Hyprland's own hotplug placement
    cannot be told apart from a restore that ran and was undone -- the two leave an
    identical store. Logging must never be able to take the watcher down, so every
    filesystem error here is swallowed.
    """
    line = f"[monitor-pin] {msg}"
    print(line, file=sys.stderr, flush=True)
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        if os.path.exists(LOG_FILE) and os.path.getsize(LOG_FILE) > ROTATE_BYTES:
            os.replace(LOG_FILE, LOG_FILE + ".1")
        stamp = datetime.now().astimezone().isoformat(timespec="seconds")
        with open(LOG_FILE, "a", encoding="utf-8") as fh:
            fh.write(f"{stamp} {line}\n")
    except OSError:
        pass


# --------------------------------------------------------------------------- #
# Talking to Hyprland
# --------------------------------------------------------------------------- #

def hyprctl(args):
    return subprocess.run(["hyprctl"] + args, capture_output=True, text=True,
                          timeout=10)


def resync_waybar():
    """Make waybar re-read which output every toplevel is on.

    SIGUSR2 is waybar's reload: it tears the bars down and rebinds the
    foreign-toplevel manager, so each bar's taskbar is rebuilt from the
    compositor's current truth. Verified to fix a stale taskbar without
    restarting waybar; a restart would also drop the bars for ~1s.
    """
    try:
        done = subprocess.run(["killall", "-SIGUSR2", "waybar"],
                              capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as exc:
        log(f"waybar resync failed: {exc}")
        return
    if done.returncode == 0:
        log("waybar taskbar resynced (SIGUSR2)")
    else:
        log("waybar not running -- nothing to resync")


def config_language():
    """Return 'lua' or 'conf' -- the language of the RUNNING session.

    Matters because under a Lua config `hyprctl keyword` is rejected ("use eval"),
    and under hyprlang `hyprctl eval` is not the entry point.
    """
    try:
        out = subprocess.run(["hypr-config-mode", "status"],
                             capture_output=True, text=True, timeout=5).stdout
        m = re.search(r"current-session:\s*(\w+)", out)
        if m and m.group(1) in ("lua", "conf"):
            return m.group(1)
    except (OSError, subprocess.SubprocessError):
        pass
    return "lua"


def fmt_scale(value):
    """1.0 -> '1', 1.25 -> '1.25'. Hyprland 0.56 prints an integral scale bare."""
    if float(value) == int(float(value)):
        return str(int(float(value)))
    return f"{float(value):.6f}".rstrip("0").rstrip(".")


def live_layout():
    """Return {description: {mode, position, scale, transform, vrr}} for enabled outputs."""
    res = hyprctl(["monitors", "-j"])
    if res.returncode != 0:
        log(f"cannot read monitors: {res.stderr.strip()}")
        return None
    layout = {}
    for m in json.loads(res.stdout):
        desc = m["description"]
        if desc in layout:
            # Two outputs sharing a description cannot be addressed separately by
            # `desc:`, so neither remembering nor restoring them is meaningful.
            log(f"duplicate description {desc!r} -- layout not addressable, skipping")
            return None
        layout[desc] = {
            "mode": f'{m["width"]}x{m["height"]}@{round(m["refreshRate"], 1)}',
            "position": f'{m["x"]}x{m["y"]}',
            "scale": fmt_scale(m["scale"]),
            "transform": m.get("transform", 0),
            "vrr": 1 if m.get("vrr") else 0,
        }
    return layout


def generated_file():
    """nwg-displays' output for the LIVE config language.

    Only the live language's tree is read by Hyprland -- under a Lua session
    monitors.conf is an inert mirror -- so comparing against the wrong one would
    never match.
    """
    name = "monitors.lua" if config_language() == "lua" else "monitors.conf"
    return os.path.join(HYPR_DIR, name)


def parse_generated():
    """Return {connector_name: {position, scale}} from nwg-displays' output.

    Keyed by connector NAME, because that is what nwg-displays writes -- the
    comparison in is_reload_artifact() maps it onto the live outputs.
    """
    path = generated_file()
    try:
        text = io_open_text(path)
    except OSError:
        return {}
    entries = {}
    if path.endswith(".lua"):
        for block in re.findall(r"hl\.monitor\(\s*\{(.*?)\}\s*\)", text, re.S):
            fields = dict(re.findall(r'(\w+)\s*=\s*"?([^",\n]+)"?', block))
            if "output" in fields:
                entries[fields["output"].strip()] = {
                    "position": fields.get("position", "").strip(),
                    "scale": fmt_scale(fields.get("scale", "1").strip()),
                }
    else:
        for line in text.splitlines():
            m = re.match(r"^\s*monitor\s*=\s*(.+)$", line.split("#", 1)[0])
            if not m:
                continue
            f = [x.strip() for x in m.group(1).split(",")]
            if len(f) >= 4:
                entries[f[0]] = {"position": f[2], "scale": fmt_scale(f[3])}
    return entries


def io_open_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def is_reload_artifact():
    """True if the live layout is nwg-displays' output but that file is not fresh.

    Meaning: an unrelated config reload re-applied the generated file. A genuine
    nwg-displays change rewrites the file first, so its mtime is recent.
    """
    entries = parse_generated()
    if not entries:
        return False
    res = hyprctl(["monitors", "-j"])
    if res.returncode != 0:
        return False
    monitors = json.loads(res.stdout)
    for m in monitors:
        want = entries.get(m["name"])
        # An output nwg-displays does not mention proves nothing either way: at the
        # other site's generated file it is simply absent, and on a reload it lands
        # wherever Hyprland's own fallback puts it. Bailing out here was what let a
        # reload-induced reset be learned as a deliberate arrangement -- judge the
        # question on the outputs the file *does* name.
        if want is None:
            continue
        if want["position"] != f'{m["x"]}x{m["y"]}':
            return False
        if want["scale"] != fmt_scale(m["scale"]):
            return False
    try:
        age = time.time() - os.stat(generated_file()).st_mtime
    except OSError:
        return False
    return age > NWG_RECENT_SECONDS


def profile_key(layout):
    return " | ".join(sorted(layout))


def detect_dock():
    """Best-effort dock name for the record. Never used to choose a profile."""
    try:
        out = subprocess.run(["lsusb"], capture_output=True, text=True,
                             timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    for usb_id, name in DOCK_IDS.items():
        if usb_id in out:
            return f"{usb_id} {name}"
    return None


def apply_spec(desc, spec):
    """Push one output's geometry. An absent output returns ok and moves nothing."""
    output = f"desc:{desc}"
    if config_language() == "lua":
        parts = [f'output = "{output}"', f'mode = "{spec["mode"]}"',
                 f'position = "{spec["position"]}"', f'scale = {spec["scale"]}']
        if spec.get("transform"):
            parts.append(f'transform = {spec["transform"]}')
        parts.append(f'vrr = {spec.get("vrr", 0)}')
        res = hyprctl(["eval", "hl.monitor({ " + ", ".join(parts) + " })"])
    else:
        fields = [output, spec["mode"], spec["position"], str(spec["scale"])]
        if spec.get("transform"):
            fields += ["transform", str(spec["transform"])]
        fields += ["vrr", str(spec.get("vrr", 0))]
        res = hyprctl(["keyword", "monitor", ",".join(fields)])
    out = (res.stdout or "").strip()
    # hyprctl answers ok whether or not a rule matched anything, so this proves the
    # rule was accepted -- not that a monitor moved. Confirm with `hyprctl -j monitors`.
    if res.returncode != 0 or (out and out != "ok"):
        log(f"FAILED {desc}: rc={res.returncode} {out or res.stderr.strip()}")
        return False
    return True


# --------------------------------------------------------------------------- #
# The baseline, used only for a profile that has never been seen
# --------------------------------------------------------------------------- #

def read_baseline():
    """Parse monitor-pins.conf into {output_string: spec}.

    Outputs are written as they appear there -- `desc:...` or a bare connector name
    -- and applied verbatim, so the baseline can still pin eDP-1 by name.
    """
    pins = {}
    try:
        with open(BASELINE_FILE, encoding="utf-8") as fh:
            for raw in fh:
                line = raw.split("#", 1)[0].strip()
                m = re.match(r"^monitor\s*=\s*(.+)$", line) if line else None
                if not m:
                    continue
                fields = [f.strip() for f in m.group(1).split(",")]
                if len(fields) < 4:
                    log(f"skipping malformed baseline pin: {m.group(1)!r}")
                    continue
                spec = {"mode": fields[1], "position": fields[2],
                        "scale": fields[3], "transform": 0, "vrr": 0}
                rest = fields[4:]
                for i in range(0, len(rest) - 1, 2):
                    key, value = rest[i].lower(), rest[i + 1]
                    if key in EXTRA_KEYS:
                        spec[EXTRA_KEYS[key]] = value
                    else:
                        log(f"ignoring unknown baseline arg {key!r} for {fields[0]!r}")
                pins[fields[0]] = spec
    except FileNotFoundError:
        log(f"no baseline at {BASELINE_FILE}")
    return pins


def apply_baseline():
    pins = read_baseline()
    if not pins:
        return 0
    lang = config_language()
    applied = 0
    for output, spec in pins.items():
        if lang == "lua":
            parts = [f'output = "{output}"', f'mode = "{spec["mode"]}"',
                     f'position = "{spec["position"]}"', f'scale = {spec["scale"]}']
            if spec.get("transform"):
                parts.append(f'transform = {spec["transform"]}')
            res = hyprctl(["eval", "hl.monitor({ " + ", ".join(parts) + " })"])
        else:
            res = hyprctl(["keyword", "monitor",
                           f'{output},{spec["mode"]},{spec["position"]},{spec["scale"]}'])
        out = (res.stdout or "").strip()
        if res.returncode != 0 or (out and out != "ok"):
            log(f"FAILED baseline {output}: rc={res.returncode} {out or res.stderr.strip()}")
        else:
            applied += 1
    log(f"applied baseline: {applied}/{len(pins)} pins ({lang})")
    return applied


# --------------------------------------------------------------------------- #
# Profile store
# --------------------------------------------------------------------------- #

def load_store():
    try:
        with open(STORE_FILE, encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return {"version": 1, "profiles": {}}
    except (OSError, ValueError) as exc:
        log(f"store unreadable ({exc}); starting a fresh one")
        return {"version": 1, "profiles": {}}
    data.setdefault("version", 1)
    data.setdefault("profiles", {})
    return data


def save_store(data):
    os.makedirs(os.path.dirname(STORE_FILE), exist_ok=True)
    tmp = STORE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, STORE_FILE)       # atomic; a crash never leaves a half-written store


def save_profile(layout=None, reason="manual"):
    layout = layout if layout is not None else live_layout()
    if not layout:
        return False
    key = profile_key(layout)
    data = load_store()
    existing = data["profiles"].get(key, {}).get("outputs")
    if existing == layout:
        return False
    data["profiles"][key] = {
        "saved": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "reason": reason,
        "dock": detect_dock(),
        "outputs": layout,
    }
    save_store(data)
    log(f"saved profile ({reason}, {len(layout)} outputs): {key}")
    return True


def restore_profile():
    """Restore the stored layout for the live monitor set, else the baseline."""
    layout = live_layout()
    if not layout:
        return False
    key = profile_key(layout)
    profile = load_store()["profiles"].get(key)
    if not profile:
        log(f"no profile for {len(layout)} outputs -- using baseline. key: {key}")
        apply_baseline()
        # Learn whatever the baseline produced, so this dock has a profile from now
        # on. Re-read rather than assuming the baseline covered every output.
        time.sleep(SETTLE_SECONDS)
        save_profile(reason="baseline")
        return True
    applied = sum(1 for desc, spec in profile["outputs"].items()
                  if desc in layout and apply_spec(desc, spec))
    missing = [d for d in layout if d not in profile["outputs"]]
    if missing:
        # An output present now but absent from the profile: leave Hyprland's own
        # placement rather than guessing, and let the auto-save learn the result.
        log(f"profile has no entry for: {', '.join(missing)}")
    log(f"restored profile ({applied}/{len(profile['outputs'])} outputs, "
        f"saved {profile.get('saved', '?')})")
    return True


# --------------------------------------------------------------------------- #
# watch
# --------------------------------------------------------------------------- #

class Watcher:
    def __init__(self):
        self._lock = threading.Lock()
        self._timer = None
        self._waybar_timer = None
        self._last_layout = None
        self._changed_at = 0.0

    # -- dock events ------------------------------------------------------- #

    def on_monitor_event(self):
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
            self._timer = threading.Timer(DEBOUNCE_SECONDS, self._restore)
            self._timer.daemon = True
            self._timer.start()

    def on_workspace_move(self):
        with self._lock:
            if self._waybar_timer is not None:
                self._waybar_timer.cancel()
            self._waybar_timer = threading.Timer(WAYBAR_RESYNC_DEBOUNCE,
                                                 resync_waybar)
            self._waybar_timer.daemon = True
            self._waybar_timer.start()

    def _restore(self):
        time.sleep(SETTLE_SECONDS)
        restore_profile()
        # The restore just reassigned workspaces to monitors in bulk; waybar's
        # taskbar cannot see that on its own.
        resync_waybar()
        with self._lock:
            # Re-baseline the poller so the restore itself is not mistaken for a
            # user change and immediately re-saved.
            self._last_layout = live_layout()
            self._changed_at = 0.0

    # -- learning ---------------------------------------------------------- #

    def poll(self):
        """Notice layout changes and learn them once they hold still.

        Polling rather than reacting to events, because an nwg-displays change
        produces no monitor event at all -- it writes the generated config and
        Hyprland auto-reloads.
        """
        while True:
            time.sleep(POLL_SECONDS)
            current = live_layout()
            if current is None:
                continue
            with self._lock:
                if current != self._last_layout:
                    self._last_layout = current
                    self._changed_at = time.monotonic()
                    continue
                if not (self._changed_at
                        and time.monotonic() - self._changed_at >= QUIET_SECONDS):
                    continue
                self._changed_at = 0.0
                stored = load_store()["profiles"].get(profile_key(current), {})
                if stored.get("outputs") == current:
                    continue
                if is_reload_artifact():
                    # Not a deliberate arrangement -- a config reload re-applied
                    # nwg-displays' file. Put the remembered layout back instead of
                    # learning the reset.
                    log("layout matches a stale generated file -- reload artifact, "
                        "restoring stored profile instead of learning it")
                    restore_profile()
                    self._last_layout = live_layout()
                    continue
                save_profile(current, reason="auto")


def socket2_path():
    override = os.environ.get("MONITOR_PIN_SOCKET2")
    if override:
        return override
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not sig:
        return None
    return os.path.join(runtime, "hypr", sig, ".socket2.sock")


def watch():
    path = socket2_path()
    if not path:
        log("HYPRLAND_INSTANCE_SIGNATURE unset -- not inside a Hyprland session")
        return 1

    watcher = Watcher()
    restore_profile()                 # Hyprland-start half of the contract.
    watcher._last_layout = live_layout()
    threading.Thread(target=watcher.poll, daemon=True).start()

    failures = 0
    while True:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(path)
        except OSError as exc:
            failures += 1
            # The instance signature changes when Hyprland restarts, so this socket
            # never comes back. Give up rather than spinning on a dead path while
            # autostart spawns a fresh watcher for the new instance.
            if failures > MAX_RECONNECTS:
                log(f"socket2 gone after {failures} attempts -- exiting")
                return 0
            log(f"socket2 connect failed ({exc}); retrying in 5s")
            time.sleep(5)
            continue
        failures = 0
        log(f"listening on {path}")
        buf = b""
        with sock:
            while True:
                try:
                    chunk = sock.recv(4096)
                except OSError as exc:
                    log(f"socket2 read error: {exc}")
                    break
                if not chunk:
                    log("socket2 closed by compositor")
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    event = line.decode("utf-8", "replace").split(">>", 1)[0]
                    if event in MONITOR_EVENTS or event in RELOAD_EVENTS:
                        log(f"event {event} -- scheduling restore")
                        watcher.on_monitor_event()
                    elif event in WORKSPACE_MOVE_EVENTS:
                        log(f"event {event} -- scheduling waybar resync")
                        watcher.on_workspace_move()
        time.sleep(2)


def show():
    layout = live_layout()
    if not layout:
        return 1
    key = profile_key(layout)
    store = load_store()
    print(f"store:  {STORE_FILE}")
    print(f"dock:   {detect_dock() or 'none detected'}")
    print(f"key:    {key}")
    print(f"known:  {'yes' if key in store['profiles'] else 'no -- baseline would apply'}")
    print("\nlive layout:")
    for desc, spec in sorted(layout.items()):
        print(f"  {desc:38} {spec['position']:>12}  {spec['mode']}  scale {spec['scale']}")
    print(f"\nstored profiles ({len(store['profiles'])}):")
    for k, profile in sorted(store["profiles"].items()):
        mark = "*" if k == key else " "
        print(f" {mark} [{profile.get('saved', '?')}] {len(profile['outputs'])} outputs"
              f"  dock={profile.get('dock') or '-'}")
        for desc, spec in sorted(profile["outputs"].items()):
            print(f"      {desc:38} {spec['position']:>12}  {spec['mode']}"
                  f"  scale {spec['scale']}")
    return 0


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "apply"
    if mode == "apply":
        return 0 if restore_profile() else 1
    if mode == "save":
        return 0 if save_profile(reason="manual") else 0
    if mode == "show":
        return show()
    if mode == "watch":
        return watch()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
