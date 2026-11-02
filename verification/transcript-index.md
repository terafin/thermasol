# Transcript index

The guide in [`../docs/09-install-from-stock.md`](../docs/09-install-from-stock.md) was
reconstructed from six session transcripts covering the whole conversion. This is the map, so a
claim can be checked rather than trusted.

## Method

Every tool call and its result was extracted, in order, into a **command spine**: call number,
timestamp, tool, literal command, and a result digest (first and last output lines, status, line
count). Nothing was filtered by topic. Full results remain in the extracts and can be pulled with:

```sh
sed -n '/^\[412\] CALL/,/^\[413\] CALL/p' <session>.txt
```

## Sessions

| Session | Calls | Span | What it is |
|---|---|---|---|
| `1aff3792-9ffd-482c-9b0e-729861b60618` | 7,967 | 2026-09-12 → 10-15 | The conversion: store redirect → Termux → adb → flash → A15 bring-up |
| `3056feeb-430e-41f5-a9b8-85e1cade2568` | 4,693 | 2026-10-15 → 11-02 | Hardware defects, deployment to slots, documentation |
| `57b516a6-9d5e-4219-ae93-a6ab448290fa` | 1,321 | 2026-10-15 | A15 bring-up, run from a peer session |
| `570ccc58-bc50-4c98-9955-0204971babb4` | 570 | 2026-10-12 → 10-15 | A/B tooling, UART recovery, console diagnosis |
| `55e88202-9581-4f3b-8f88-ae86807e9877` | 248 | 2026-09-12 → 10-31 | **Not panel work** — Synology RAID on `yuna` |
| `c4daa379-4936-44f2-b5c3-4087b5eed572` | 1,340 | 2026-09-09 → 10-30 | **Not panel work** — herdr/chezmoi cockpit on `tellah` |

**16,139 calls** in total. Both non-panel sessions were confirmed out of scope by reading them,
not by keyword filtering; they are listed so nobody re-does that work.

## Coverage

Every call in every session was read, in ordered chunks, by an agent with instructions to index
each one. Coverage was verified mechanically:

```
1aff3792   total= 7967  GAPS=none
3056feeb   total= 4693  GAPS=none
55e88202   total=  248  GAPS=none
570ccc58   total=  570  GAPS=none
57b516a6   total= 1321  GAPS=none
c4daa379   total= 1340  GAPS=none

COVERAGE COMPLETE
```

Three coverage holes were found during the process and re-read: `1aff 6401–6706`,
`3056feeb 4449–4693`, `57b516a6 820–1321` (1,168 calls). They existed because chunks were
regenerated mid-run and reports had been written against the older boundaries. The check that
caught them compares each report's own declared range against the session total, rather than
trusting filenames.

## Reading the citations

Citations in the guide are call numbers within a session. A `[5914]`-style reference means:
open the session file for that chunk and use the `sed` range above. Call numbers are
**per-session**, so they only make sense alongside the session they came from.

## What the guide does not claim

- It does not claim every command in it was run in exactly the form shown; where a step was
  performed by hand on the panel's touchscreen (SSH setup in Termux), the guide says so.
- It does not claim the reconstruction is complete in the sense of explaining *why* every dead
  end was a dead end. The dead ends that taught something are in
  [`../docs/13-instruments-lie.md`](../docs/13-instruments-lie.md).
- It does not claim the panel is finished. See [`../docs/07-open-issues.md`](../docs/07-open-issues.md).
