# 08 — Rules for working on this panel

Blunt rules, each one paid for. They are written as instructions, not as a memoir: what to do
differently, and why. See [10-known-pitfalls.md](10-known-pitfalls.md) for the flat checklist
form.

---

## 1. Do not guess at live hardware

Sending hand-derived CAN opcodes to the running ceiling speaker silently changes its **audio
source** and **volume**, and can kill audio that was working.

The state persists across reboots — the speaker keeps its own state, and rebooting the panel
does not reset it. Without a snapshot first, there is nothing to roll back to.

**Rule, now:** record current state → start a passive CAN capture → operate the *vendor app's
own control* → mirror the exact frames it emits. Never infer opcodes from a disassembly and
fire them at live hardware.

Related: the disassembly was also **incomplete**. `A5 62 7B`, which the vendor app itself
sends, does not appear anywhere in the binary's byte scan. A "complete" catalogue obtained by
static analysis was not complete.

---

## 2. Kernel debugfs can be a liar

`wm8904 dapm/bias_level` reads `Off` and regmap `06: 0000` / `0c: 0000` **during normal
working audio**. Reading those as a power indicator produces the conclusion "the codec never
powers up", which is false — and it sends the investigation in the worst possible direction.

The vendor UI's "Audio Source: Bluetooth / No Bluetooth device connected" label is the same
kind of trap — present even when audio works, and there are no A2DP bonds at all.

**Rule:** before treating a status value as evidence, observe it in a *known-good* state too.
A reading you have never seen vary is not a measurement.

---

## 3. "It worked before" is data, not nostalgia

The operator said a firmware update had fixed the hiss previously and that stock silenced it at
sleep. I treated the second as a hypothesis to argue with rather than a constraint to satisfy.
It turned out to be the single most informative fact in the whole investigation — and the
suspend test it motivated is what proved the noise is speaker-side.

**Rule:** when the operator reports a past behaviour, that is a constraint on the solution
space. Find the mechanism; don't explain it away.

---

## 4. Prove the target, not the representation

The thing you are inspecting is often not the thing that is running:

- The installed APK was **not** the build directory's APK.
- The static archive had **duplicate members** and the linker picked stale code.
- A "successful" build had not rebuilt `boot.img` at all.
- `avbab status` does not exist; the metadata read needed raw bytes.
- `grep`/`find` are shell functions here and return zero silently.

**Rule:** hash the artifact that is actually executing (`/proc/<pid>/exe`), assert on
freshly-read state, and treat "the command succeeded" and "the file is the right one" as
different claims.

---

## 5. Never suspend this panel

I suspended the SoC to test the stock-sleep hypothesis. It never woke, and the operator had to
trip the breaker. The wake-source check I did beforehand (`input70 wakeup=enabled`) was
necessary but not sufficient — the registration existed, the IRQ still did not wake it, and I
had not checked for an RTC/alarm source at all.

**Rule:** before any power-state experiment on sealed hardware, enumerate *every* wake source
that could rescue it, and assume the one you cannot verify will not work.

---

## 6. Bounded, reversible, and verified — in that order

The changes that went well all shared a shape: build it, prove it on the host, prove it on the
device against the *old* behaviour, deploy to the inactive slot only, gate every write on
freshly-read state, read the whole partition back, and keep a working fallback.

The changes that went badly were the ones where I edited live state to see what would happen.

---

## 7. Ask, don't assume, about the person

Read what the owner has already told you before asking again, and never ask someone to
observe a difference while you change four things at once. One control at a time, one clear
question: *did this change what you hear?*

---

## 8. The documentation is part of the work

The reason this repo exists is that the most valuable artifacts of the project were the
**records**, not the code: the receipt ledger, the root-cause briefs with their retracted
hypotheses still in place, and the evidence directories. Several times the only thing that
stopped a wrong conclusion from shipping was an older note saying "this was already tried and
it does not work."

---

## The rules that kept the project honest

Distilled from the artifact trail. Each of these caught a real error.

1. **Every claim is bound to a boot instance.** Trial scripts assert `sys.boot_completed`, the
   slot, the vbmeta digest, and a boot id **different** from the pre-reboot one. If the boot id
   did not change, nothing was tested.
2. **Building, writing and arming are three separately witnessed states.** Receipts carry
   `deployed: false` and `armed: false` until a later, separate step flips them.
3. **A killed or crashed test run is not a RED.** Only a controlled assertion failure counts.
   Two "RED" results were discarded on exactly this basis.
4. **The device measurement outranks every derived number.** An agent's arithmetic (−13.55 dB)
   was overruled by the on-device `getStreamVolumeDb` readback (−14.45 dB).
5. **An empty log is not a failed build.** A reviewer inferred "these tests never compiled"
   from an empty log; the deployed executable plus a fresh run was the evidence that settled it.
6. **Do not carry a model's report as artifact proof.** A whole review was adjudicated as
   decoding errors and produced no device change.
7. **Name the runner and the level** in every test claim — host vs device, and which command.
   There is no aggregate test command here.
8. **Scope every completion claim to the gate actually passed.** "Startup crash fixed over two
   boots" is not "Bluetooth works."

## Two inferences that were laundered into requirements

Worth recording because both cost time and both were mine:

- **"The user rejects permanent polling."** Not something the operator ever said. It was an
  agent inference, repeated across handoffs until it looked like a constraint, and had to be
  formally withdrawn.
- **"A shared physical CHG/WDOG wire."** Inferred from two DT mux entries with no hardware
  evidence, and retracted when the evidence did not support it.

The rule: quote the transcript, or label it as inference.

## Appendix — hypotheses that were wrong

Collected in one place, because this is where someone comes looking for what *not* to try.
Each of these was argued, acted on, and then disproved by evidence.

| Hypothesis | Why it was believed | How it was disproved |
|---|---|---|
| "The shower driver layer needs porting to A15" | Assumed vendor specificity | The CAN/display/audio drivers are already in the Variscite BSP; only four ThermaSol devices needed carrying over |
| "CMA exhaustion is why the display is blank" | Plausible given 2 GiB | CMA was fine; the real fault was a **heap name mismatch** (`linux,cma` vs `reserved`) |
| "The codec never powers up" | `dapm/bias_level=Off`, regmap `06/0c = 0000` | Those read identically **during normal playback**; the values are not a power indicator |
| "Audio is routed over Android Bluetooth A2DP" | Vendor Music screen said "Audio Source: Bluetooth" | No A2DP device is ever bonded, and that label is present while audio works |
| "The speaker's standby command stops the hiss" | It is named `slsr_request_sls_standby` | `slsr_is_active = 0` — the legacy SLSR device does not exist on this unit; the command is a no-op |
| "A userspace poll loop will fix touch" | Stock A10 driver polls | It duplicated and fought the kernel driver; the fix is driver-owned polling |
| "Suspend will reproduce stock's silent sleep" | Operator reported stock slept quietly | `echo mem` never wakes; no RTC/alarm source; recovered only by breaker — **and the hiss was unchanged anyway** |
| "A newer speaker firmware exists to install" | A firmware update had fixed it once before | The vendor publishes exactly one image, dated 2021; the panel already runs 7.0.0 |
| "The DSV-4000 controller firmware is the fix" | It is the only recently-updated image on the endpoint | `esv_get_is_dongle_present = false` — that hardware is not on this shower |
| "Hand-derived CAN opcodes can be tested live" | The opcode catalogue looked complete from disassembly | It was incomplete (`A5 62 7B` is absent from the binary), and guessing **destroyed working audio** |
