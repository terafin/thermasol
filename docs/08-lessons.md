# 08 — Rules that keep the work honest

Six rules that are not procedures and not gotchas. Each one exists because breaking it cost real
time. For the tool-level traps see [13-instruments-lie.md](13-instruments-lie.md); for the flat
checklist see [10-known-pitfalls.md](10-known-pitfalls.md).

---

## 1. Never guess at live hardware

Record current state, start a passive capture, operate the **vendor app's own control**, then mirror
the exact frames it emits:

```sh
scripts/can-capture.sh 30      # passive
# tap the control on the panel
```

Never derive an opcode from a disassembly and send it. Doing that silently changed the speaker's
audio source and volume, and the state persists across reboots — the speaker keeps its own state,
and rebooting the panel does not reset it. See [05-fixes.md](05-fixes.md) §13 for the recovery
frames.

## 2. Source claims outrank observed ones

If another session, a memory note, or an earlier document asserts something about the device, check
it against an artifact before acting on it. What "was true" is a claim, not a constraint.

Corollary: **quote the owner.** A constraint with no author in the record is an inference. See
[10-known-pitfalls.md](10-known-pitfalls.md) for the two that had to be withdrawn.

## 3. Stage, verify, then commit — in that order

Any change to the device has three states: written to a staging area, verified by reading it back,
and committed to the thing that runs. Never collapse them.

- Write to the **inactive** slot or a temp path.
- Read the whole target back and compare hashes.
- Only then arm it, and only then reboot.

A change that cannot be verified before commit is a change that cannot be debugged after.
[06-procedures.md](06-procedures.md) §C is the procedure.

## 4. One variable at a time

When something changes behaviour, change **one** thing and re-measure. Two simultaneous changes
produce a result you cannot attribute — and a confident wrong conclusion is more expensive than no
conclusion.

This applies to questions to the operator too: one control at a time, one clear question —
*did this change what you hear?*

## 5. Ask, don't assume, about the person

Read what the owner has already said before asking again. If they have stated a preference, that is
a constraint, not a hypothesis to argue with.

And when you need a physical observation, say exactly what to do and what to listen for. "Does it
work now" produces noise.

## 6. Record what you did, or it did not happen

A receipt is: the command, its output, and the hash or number that proves the outcome. Prose
summaries are not evidence — three "build completed successfully" lines in this project referred to
a kernel that was six hours old.

When something is retracted, delete the claim. A superseding note leaves two contradictory
statements in the same document, and the next reader cannot tell which one is current.

---

## Appendix — hypotheses that were wrong

Kept as a single list because the same wrong ideas recur. Each is here so it is not re-proposed.

| Hypothesis | Killed by |
|---|---|
| `/data/local.prop` is a mechanism on Android 10 | the string table of the shipped `init` |
| `ALLOW_LOCAL_PROP_OVERRIDE` makes that file inert | the target property is defined nowhere |
| `service adbd` is not in the deployed config | it is, in `/system/init.usb.rc` |
| `adbd` never starts on its own | true on A10 only; A15's `usbd` starts it at ~21 s |
| a non-Termux adb path exists on A10 | true premise, wrong conclusion — access converges on Termux |
| silence on the wire proves the boot stopped before `netd` | `netd` is native and starts at `zygote-start` |
| the static logo proves the failure is before Android | `bootanim` has two possible starters |
| U-Boot netconsole is output-only | false |
| fastboot in 2019.04 is USB-only | false |
| `avc: granted` proves permissive | invalid reasoning; use `getenforce` |
| the shower dies without vendor drivers | all the drivers were already in the vendor tree |
| the display fails because CMA is exhausted | it is a **heap name** mismatch; CMA was never short |
| the codec never powers up | `dapm/bias_level` reads `Off` during working playback |
| the panel is unstable under watch | the watcher (`ps --sort=-RSS`) was the load |
