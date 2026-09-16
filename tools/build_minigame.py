#!/usr/bin/env python3
"""Build the WeChat mini game from this project.

Godot's own web export gives us a .pck plus the stock web runtime, which a
mini game can't load: WeChat has no DOM, no fetch, and its own audio and
file APIs. godot-minigame (MIT, github.com/godothub/godot-minigame) ships a
matching runtime as a mini game project shell -- the engine wasm, an
adapter, and a loader -- and expects us to drop our .pck into it.

So this does three things: export the .pck with the stock Godot editor,
unpack the shell for the same engine version, and stitch them together into
outputs/minigame/, a directory WeChat DevTools can open as a project.

Usage:  python tools/build_minigame.py [--skip-export]
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"C:\Users\admin\Tools\Godot\Godot_v4.3-stable_win64_console.exe"
WEB_OUT = os.path.join(ROOT, "outputs", "web")
OUT = os.path.join(ROOT, "outputs", "minigame")
CACHE = os.path.join(ROOT, "work", "mgcache")

# The shell has to match the engine that produced the .pck, or the game
# loads into a runtime that can't read its own resources.
TEMPLATE = "minigame4.3.0.3.tpz"
TEMPLATE_URL = f"https://github.com/godothub/godot-minigame/releases/download/4.3.0/{TEMPLATE}"
PCK_NAME = "game-pck.bin"


def run(args, label):
    print(f"  {label} ...")
    result = subprocess.run(args, capture_output=True, text=True, errors="replace")
    if result.returncode != 0:
        sys.exit(f"{label} failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")


def export_pck():
    os.makedirs(WEB_OUT, exist_ok=True)
    run([GODOT, "--headless", "--path", ROOT, "--import"], "importing project")
    run([GODOT, "--headless", "--path", ROOT, "--export-release", "Web"], "exporting web build")


def template_dir():
    os.makedirs(CACHE, exist_ok=True)
    archive = os.path.join(CACHE, TEMPLATE)
    if not os.path.exists(archive):
        print(f"  downloading {TEMPLATE} ...")
        urllib.request.urlretrieve(TEMPLATE_URL, archive)
    shell = os.path.join(CACHE, "shell")
    if not os.path.exists(shell):
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(shell)
    return shell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-export", action="store_true",
                    help="reuse outputs/web from a previous run")
    ap.add_argument("--appid", help="WeChat appid to stamp into the project")
    args = ap.parse_args()

    # An appid set on a previous build survives a rebuild: without this, every
    # run wipes the output directory and the appid reverts to the template's.
    previous_appid = None
    existing = os.path.join(OUT, "project.config.json")
    if os.path.exists(existing):
        with open(existing, encoding="utf-8") as fh:
            previous_appid = json.load(fh).get("appid")

    if not args.skip_export:
        export_pck()
    pck = os.path.join(WEB_OUT, "index.pck")
    if not os.path.exists(pck):
        sys.exit("no outputs/web/index.pck -- run without --skip-export")

    shell = template_dir()
    # Empty the directory rather than removing it: DevTools holds a handle on
    # the project directory while the project is open, so rmtree() fails on the
    # directory itself -- after having already deleted half the files inside.
    if os.path.exists(OUT):
        try:
            for name in os.listdir(OUT):
                victim = os.path.join(OUT, name)
                if os.path.isdir(victim):
                    shutil.rmtree(victim)
                else:
                    os.remove(victim)
        except PermissionError as err:
            sys.exit(f"cannot rebuild {OUT}: {err}\n"
                     "close the project in WeChat DevTools first "
                     "(cli.bat close --project ...), then rerun")
    os.makedirs(OUT, exist_ok=True)
    shutil.copytree(shell, OUT, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".plugincache", "*.md"))

    # The shell ships a demo pack; ours replaces it, and engine/game.js is
    # the one line that names it.
    demo = os.path.join(OUT, "engine", "demo-pck.bin")
    if os.path.exists(demo):
        os.remove(demo)
    shutil.copy2(pck, os.path.join(OUT, "engine", PCK_NAME))
    entry = os.path.join(OUT, "engine", "game.js")
    with open(entry, encoding="utf-8") as fh:
        source = fh.read()
    source = source.replace("/engine/demo-pck.bin", f"/engine/{PCK_NAME}")
    with open(entry, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(source)

    # The game is built around a 1280x720 field of view, and the HUD anchors
    # to the edges of whatever aspect it gets -- so it wants the phone held
    # sideways, not a portrait re-layout.
    game_json = os.path.join(OUT, "game.json")
    with open(game_json, encoding="utf-8") as fh:
        config = json.load(fh)
    config["deviceOrientation"] = "landscape"
    with open(game_json, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(config, fh, ensure_ascii=False, indent=4)

    project_json = os.path.join(OUT, "project.config.json")
    with open(project_json, encoding="utf-8") as fh:
        project = json.load(fh)
    project["projectname"] = "星渊幸存者"
    # DevTools rejects "touristappid" outright ("no such AppID"), so there has
    # to be a real-looking one here. Whatever was used last time wins, then
    # --appid, then the template's own -- which belongs to someone else and is
    # only good enough to run the simulator locally.
    appid = args.appid or previous_appid or project.get("appid")
    project["appid"] = appid
    with open(project_json, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(project, fh, ensure_ascii=False, indent=4)

    total = 0
    for root, _dirs, files in os.walk(OUT):
        for name in files:
            total += os.path.getsize(os.path.join(root, name))
    main_pack = total - dir_size(os.path.join(OUT, "engine"))
    print(f"wrote {OUT}")
    print(f"  main package : {main_pack / 1024:.0f} KB   (WeChat limit 4 MB)")
    print(f"  engine subpkg: {dir_size(os.path.join(OUT, 'engine')) / 1024 / 1024:.2f} MB")
    print(f"  total        : {total / 1024 / 1024:.2f} MB   (WeChat limit 30 MB)")
    print(f"  appid        : {appid}")
    if appid == "wxda5f10e2e9114855":
        print("  ^ that is the template's own appid. The local simulator runs fine with")
        print("    it, but previewing on a phone or uploading needs your own:")
        print("    python tools/build_minigame.py --appid wx<yours>")
    print("open it in WeChat DevTools: 导入项目 -> 选择这个目录 -> 小游戏")


def dir_size(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for name in files:
            total += os.path.getsize(os.path.join(root, name))
    return total


if __name__ == "__main__":
    main()
