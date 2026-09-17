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
# 星渊幸存者's own mini game account (registered 2026-09-16, personal subject).
APPID = "wx2f6726f8ef158442"
# Every API on WeChat's 用户信息类型 table (read from the MP privacy page,
# 2026-09-17). Any of these in the package forces a personal-info declaration.
PRIVACY_APIS = [
    "getUserInfo", "getUserProfile", "createUserInfoButton", "scope.userLocation",
    "getLocation", "getFuzzyLocation", "scope.werun", "getWeRunData", "getPhoneNumber",
    "chooseImage", "chooseMedia", "chooseMessageFile", "scope.record", "startRecord",
    "RecorderManager", "joinVoIPChat", "scope.camera", "createVKSession", "createCamera",
    "openBluetoothAdapter", "createBLEPeripheralServer", "scope.writePhotosAlbum",
    "saveImageToPhotosAlbum", "getFriendCloudStorage", "getGroupCloudStorage", "getGroupInfo",
    "getPotentialFriendList", "getUserCloudStorageKeys", "getFriendsStateData",
    "getUserInteractiveStorage", "getGameClubData", "getChannelsLiveInfo",
    "startAccelerometer", "stopAccelerometer", "onAccelerometerChange", "offAccelerometerChange",
    "startCompass", "stopCompass", "onCompassChange", "offCompassChange",
    "startDeviceMotionListening", "stopDeviceMotionListening", "onDeviceMotionChange",
    "offDeviceMotionChange", "startGyroscope", "stopGyroscope", "onGyroscopeChange",
    "offGyroscopeChange", "setClipboardData", "getClipboardData", "getRelationFriendList",
]
PRIVACY_SCRUB = {
    os.path.join("engine", "godot-sdk.js"): [
        ("wx.startAccelerometer", "wx.xinNoAccelStart"),
        ("wx.stopAccelerometer", "wx.xinNoAccelStop"),
        ("wx.onAccelerometerChange", "wx.xinNoAccelChange"),
        # The SDK's own wrapper methods carry the same names. Nothing in the
        # engine calls them (godot.js has no accelerometer reference at all).
        ("startAccelerometer(", "xinNoAccelStart("),
        ("stopAccelerometer(", "xinNoAccelStop("),
    ],
    "weapp-adapter.js": [("wx.getLocation", "a location API")],
}
SHARE_MARKER = "// xin: share menu"
SHARE_SNIPPET = """
// xin: share menu
wx.showShareMenu({ menus: ['shareAppMessage', 'shareTimeline'] });
const xinShareCard = () => ({
    title: '和星灵伙伴一起闯星渊、修好大灯塔！',
    imageUrl: 'images/share.png',
    query: 'from=menu',
});
wx.onShareAppMessage(xinShareCard);
if (wx.onShareTimeline) {
    wx.onShareTimeline(() => ({ title: '星渊幸存者', imageUrl: 'images/share.png', query: 'from=timeline' }));
}
"""


def run(args, label):
    print(f"  {label} ...")
    result = subprocess.run(args, capture_output=True, text=True, errors="replace")
    if result.returncode != 0:
        sys.exit(f"{label} failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")


def export_pck():
    os.makedirs(WEB_OUT, exist_ok=True)
    # The shipped font only holds the characters the project uses, so any new
    # line of text is a row of boxes until it's rebuilt. Rebuilding every time
    # is cheap (sources are cached) and means nobody has to remember.
    run([sys.executable, os.path.join(ROOT, "tools", "build_font.py")], "rebuilding font subset")
    # outputs/ sits inside the Godot project. Without this, the editor imports
    # every png the build drops there and litters them with .import files.
    open(os.path.join(ROOT, "outputs", ".gdignore"), "a").close()
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
    ap.add_argument("--appid", help="build under a different WeChat appid")
    args = ap.parse_args()


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
                    ignore=shutil.ignore_patterns(".plugincache", "*.md", "*.import"))

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

    # WeChat scans uploaded code for APIs on its privacy list and, on a hit,
    # makes the game declare that it collects personal information. The engine
    # shell wraps the accelerometer (for Godot's tilt input, which this game
    # never reads) and the adapter mentions wx.getLocation in a comment -- both
    # enough to trip the scan. Point them at names that don't exist: the shell
    # already guards each call with `wx.x && wx.x(...)`, so they become no-ops.
    for relative, swaps in PRIVACY_SCRUB.items():
        path = os.path.join(OUT, relative)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for old_name, new_name in swaps:
            text = text.replace(old_name, new_name)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
    leaks = privacy_api_hits(OUT)
    if leaks:
        sys.exit("privacy-scoped wx APIs still in the package: " + ", ".join(leaks))

    # Passive sharing -- the "..." menu's forward and moments entries -- needs a
    # listener that *returns* the share card. A GDScript callback can't return
    # a value to JS, so this lives in the shell's own game.js instead of the
    # game. The card image ships in the main package so it's there before the
    # engine subpackage finishes loading.
    shutil.copy2(os.path.join(ROOT, "tools", "minigame_assets", "share.png"),
                 os.path.join(OUT, "images", "share.png"))
    shell_entry = os.path.join(OUT, "game.js")
    with open(shell_entry, encoding="utf-8") as fh:
        shell_source = fh.read()
    if SHARE_MARKER not in shell_source:
        shell_source += SHARE_SNIPPET
        with open(shell_entry, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(shell_source)

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
    # DevTools rejects "touristappid" outright ("no such AppID"). The game has
    # its own registered appid now; --appid is only for building under another.
    appid = args.appid or APPID
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
    print("open it in WeChat DevTools: 导入项目 -> 选择这个目录 -> 小游戏")


def privacy_api_hits(root):
    hits = set()
    for folder, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".js"):
                continue
            with open(os.path.join(folder, name), encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
            hits.update(api for api in PRIVACY_APIS if api in text)
    return sorted(hits)


def dir_size(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for name in files:
            total += os.path.getsize(os.path.join(root, name))
    return total


if __name__ == "__main__":
    main()
