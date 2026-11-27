# Vendor overlay

Everything that differs from the known-good base vendor image (`base/vendor.img`, live slot _b on
2026-11-25) lives here and only here. `build.sh` unpacks the base, applies this directory, and
repacks. Nothing else is changed.

- `sepolicy.cil.add` — lines appended to `/vendor/etc/selinux/vendor_sepolicy.cil`. One rule per
  line, each with the reason in `sepolicy.cil.why`.
- `sepolicy.cil.replace` — `old<TAB>new` exact-line replacements in the same file.
- `files/` — files copied into the vendor tree at the same path (`etc/init/audio-sonos.rc`).
- `labels` — `path<TAB>selinux-label` for every file in `files/`. A file without a label line is a
  build failure: an unlabeled file is denied to every domain at runtime.

The audio service is not stored here as a binary: `build-audio.sh` builds Android's reference AIDL
audio service (NXP's copy) with the Sonos module from `audio-tree.patch`, verifies the APEX, and
`build.sh` installs that APEX into the image.