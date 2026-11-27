# Vendor overlay

Everything that differs from the base vendor image, the published v1.2 `vendor.img` (`8b4ab623…`, fetched
by `pull-base.sh`), lives here. `build.sh` unpacks the base, applies this directory and the `sonos` module
of `audio-policy.patch` to `etc/audio_policy_configuration.xml`, installs the audio APEX built by
`build-audio.sh`, and repacks; `build-framework.sh` rebuilds `services.jar` from `framework.patch` for the
system image. `remove` deletes v1.2's precompiled SELinux policy so init compiles the patched one.

- `sepolicy.cil.add` — lines appended to `/vendor/etc/selinux/vendor_sepolicy.cil`. One rule per
  line, each with the reason in `sepolicy.cil.why`.
- `sepolicy.cil.replace` — `old<TAB>new` exact-line replacements in the same file.
- `files/` — files copied into the vendor tree at the same path (`etc/init/audio-sonos.rc`).
- `labels` — `path<TAB>selinux-label` for every file in `files/`. A file without a label line is a
  build failure: an unlabeled file is denied to every domain at runtime.

The audio service is not stored here as a binary: `build-audio.sh` builds Android's reference AIDL
audio service (NXP's copy) with the Sonos module from `audio-tree.patch`, verifies the APEX, and
`build.sh` installs that APEX into the image.