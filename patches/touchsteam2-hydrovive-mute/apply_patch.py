#!/usr/bin/env python3
"""Patch com.thermasol.touchsteam2 so a power-off stays silent.

Run against a PRISTINE baksmali disassembly of the installed classes2.dex:

    python3 apply_patch.py <smali-dir>

Design (see README.md for the reasoning and the rejected latch):

  OverheadLight gains two static fields
      sInShutdown : true only while ShutdownAll runs the bluetooth teardown
      sAudioGen   : bumped once per ShutdownAll, invalidates in-flight timers

  OverheadLight.unmute / setMasterVolume return early while sInShutdown.
  Utils.delayMusicVolume does not spawn while sInShutdown, and stamps the
  thread it does spawn with sAudioGen; the thread drops itself if a shutdown
  happened after it was scheduled.

Nothing survives the shutdown.  Audio restoration is untouched because
sInShutdown is false for every user-initiated call.
"""
import sys, os

OVL = "com/thermasol/touchsteam2/util/OverheadLight.smali"
UTL = "com/thermasol/touchsteam2/util/Utils.smali"
LMB = "com/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA.smali"


def load(root, rel):
    with open(os.path.join(root, rel)) as f:
        return f.read()


def save(root, rel, text):
    with open(os.path.join(root, rel), "w") as f:
        f.write(text)


def sub(text, old, new, what):
    n = text.count(old)
    if n != 1:
        sys.exit(f"FAIL: {what}: expected exactly 1 occurrence, found {n}")
    return text.replace(old, new)


def method_bounds(text, sig):
    start = text.find(".method " + sig)
    if start < 0:
        start = text.find(sig)
        if start < 0:
            sys.exit(f"FAIL: method {sig} not found")
    start = text.rfind("\n", 0, start) + 1
    end = text.find(".end method", start)
    if end < 0:
        sys.exit(f"FAIL: end of {sig} not found")
    return start, end


root = sys.argv[1] if len(sys.argv) > 1 else "."

# ---------------------------------------------------------------- OverheadLight
o = load(root, OVL)

anchor = '# annotations\n'
o = sub(o, anchor,
        "# tt-hydrovive-mute: shutdown-scoped audio suppression\n"
        ".field public static volatile sAudioGen:I\n\n"
        ".field public static volatile sInShutdown:Z\n\n\n" + anchor,
        "OverheadLight fields")

GUARD = """    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sInShutdown:Z

    if-eqz v0, :tt_hv_ok

    return-void

    :tt_hv_ok
"""

for sig in ("public static final unmute(Landroid/content/Context;)V",
            "public static final setMasterVolume(Landroid/content/Context;I)V"):
    s, e = method_bounds(o, sig)
    body = o[s:e]
    tail = "    .annotation runtime Lkotlin/jvm/JvmStatic;\n    .end annotation\n\n"
    body = sub(body, tail, tail + GUARD, f"guard in {sig}")
    o = o[:s] + body + o[e:]

save(root, OVL, o)

# ------------------------------------------------------------------------ Utils
u = load(root, UTL)

# 1. bump the generation at the very top of ShutdownAll
sig = "public static ShutdownAll(Landroid/content/Context;)V"
s, e = method_bounds(u, sig)
body = u[s:e]
tail = '        names = {\n            "context"\n        }\n    .end annotation\n\n'
body = sub(body, tail, tail +
           "    # tt-hydrovive-mute: invalidate any timer scheduled before now\n"
           "    sget v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sAudioGen:I\n\n"
           "    add-int/lit8 v0, v0, 0x1\n\n"
           "    sput v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sAudioGen:I\n\n",
           "generation bump in ShutdownAll")

# 2. bracket the bluetooth teardown with the suppression flag
old = "    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->PersistPauseAndKillBluetooth(Landroid/content/Context;)V\n"
new = """    const/4 v0, 0x1

    sput-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sInShutdown:Z

    :try_start_hv
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->PersistPauseAndKillBluetooth(Landroid/content/Context;)V
    :try_end_hv
    .catchall {:try_start_hv .. :try_end_hv} :catchall_hv

    goto :goto_hv

    :catchall_hv
    move-exception v1

    const/4 v0, 0x0

    sput-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sInShutdown:Z

    throw v1

    :goto_hv
    const/4 v0, 0x0

    sput-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sInShutdown:Z
"""
body = sub(body, old, new, "flag bracket in ShutdownAll")
u = u[:s] + body + u[e:]

# 3. delayMusicVolume: no timer during shutdown; stamp the timer otherwise
sig = "private static delayMusicVolume(Landroid/content/Context;II)V"
s, e = method_bounds(u, sig)
body = u[s:e]
body = sub(body, "    .registers 5\n", "    .registers 6\n", "delayMusicVolume registers")
body = sub(body,
           "    .line 566\n    new-instance v0, Ljava/lang/Thread;\n",
           "    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sInShutdown:Z\n\n"
           "    if-eqz v0, :tt_hv_spawn\n\n"
           "    return-void\n\n"
           "    :tt_hv_spawn\n"
           "    sget v2, Lcom/thermasol/touchsteam2/util/OverheadLight;->sAudioGen:I\n\n"
           "    .line 566\n    new-instance v0, Ljava/lang/Thread;\n",
           "delayMusicVolume guard")
body = sub(body,
           "    invoke-direct {v1, p2, p0, p1}, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;-><init>(ILandroid/content/Context;I)V\n",
           "    invoke-direct {v1, p2, p0, p1, v2}, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;-><init>(ILandroid/content/Context;II)V\n",
           "lambda construction")
u = u[:s] + body + u[e:]

# 4. the timer body: drop itself if a shutdown happened after it was scheduled
sig = "static synthetic lambda$delayMusicVolume$1(ILandroid/content/Context;I)V"
s, e = method_bounds(u, sig)
body = u[s:e]
body = body.replace("    .registers 5\n", "    .registers 6\n", 1)
body = body.replace(
    "static synthetic lambda$delayMusicVolume$1(ILandroid/content/Context;I)V",
    "static synthetic lambda$delayMusicVolume$1(ILandroid/content/Context;II)V", 1)
body = sub(body,
           "    :goto_9\n    invoke-static {p1, p2}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMasterVolume(Landroid/content/Context;I)V\n",
           "    :goto_9\n"
           "    sget v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sAudioGen:I\n\n"
           "    if-ne p3, v0, :tt_hv_wake\n\n"
           "    return-void\n\n"
           "    :tt_hv_wake\n"
           "    invoke-static {p1, p2}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMasterVolume(Landroid/content/Context;I)V\n",
           "stale-timer check")
u = u[:s] + body + u[e:]

save(root, UTL, u)

# ------------------------------------------------------------------- lambda class
l = load(root, LMB)
l = sub(l,
        ".field public final synthetic f$2:I\n",
        ".field public final synthetic f$2:I\n\n.field public final synthetic f$3:I\n",
        "lambda f$3 field")
l = sub(l,
        ".method public synthetic constructor <init>(ILandroid/content/Context;I)V\n",
        ".method public synthetic constructor <init>(ILandroid/content/Context;II)V\n",
        "lambda ctor signature")
l = sub(l, "    .registers 4\n", "    .registers 5\n", "lambda ctor registers")
l = sub(l,
        "    iput p3, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I\n",
        "    iput p3, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I\n\n"
        "    iput p4, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$3:I\n",
        "lambda ctor body")
l = sub(l, "    .registers 3\n", "    .registers 5\n", "lambda run registers")
l = sub(l,
        "    iget p0, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I\n\n"
        "    invoke-static {v0, v1, p0}, Lcom/thermasol/touchsteam2/util/Utils;->lambda$delayMusicVolume$1(ILandroid/content/Context;I)V\n",
        "    iget v2, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I\n\n"
        "    iget v3, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$3:I\n\n"
        "    invoke-static {v0, v1, v2, v3}, Lcom/thermasol/touchsteam2/util/Utils;->lambda$delayMusicVolume$1(ILandroid/content/Context;II)V\n",
        "lambda run body")
save(root, LMB, l)

print("patched: OverheadLight.smali, Utils.smali, lambda class")
