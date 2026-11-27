# Vendor overlay

Everything that differs from the pinned base vendor image (`base/vendor.img`, `e9fd6030…`; not published, see
[#67](https://github.com/terafin/thermasol/issues/67)) lives here. `build.sh` unpacks the base, applies this
directory, installs the audio APEX built by `build-audio.sh`, and repacks; `build-framework.sh` rebuilds
`services.jar` from `framework.patch` for the system image.

- `sepolicy.cil.add` — lines appended to `/vendor/etc/selinux/vendor_sepolicy.cil`. One rule per
  line, each with the reason in `sepolicy.cil.why`.
- `sepolicy.cil.replace` — `old<TAB>new` exact-line replacements in the same file.
- `files/` — files copied into the vendor tree at the same path (`etc/init/audio-sonos.rc`).
- `labels` — `path<TAB>selinux-label` for every file in `files/`. A file without a label line is a
  build failure: an unlabeled file is denied to every domain at runtime.

The audio service is not stored here as a binary: `build-audio.sh` builds Android's reference AIDL
audio service (NXP's copy) with the Sonos module from `audio-tree.patch`, verifies the APEX, and
`build.sh` installs that APEX into the image.