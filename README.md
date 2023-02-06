# gcf2

Formerly my gentoo-cflags.  gcf2 is a collection of personal cflags profiles
for the portage build system.

## Precautions

* Backup make.conf, env/* before using gcf2.  These will be clobbered when
restoring a profile.  This can be done with `--save-profile=name`.
* It is assumed that you will make additional changes to make.conf to work with
your personal setup.
* It is a hard requirement to have a Rescue CD/USB especially with CFI ON.
([SystemRescue|https://www.system-rescue.org/] can be used.)

## Running

`./gcf2 --help` - Gets help
`./gcf2 --save-profile=name` - Saves profile as name
`./gcf2 --restores-profile=name` - Restores profile from profiles/name

### Environment variables

EROOT - The absolute path to the root of an existing installation.
(It can be unset or be empty if CHOST == CBUILD.)

## Prebuilt profiles

### Production

* gaming - optimizes for install time while maintaining decent runtime
performance while sacrificing security.  Anti premature optimization.
Anti security.  (Development is active)
* minmax-2018 - Hardened GCC with systemwide Retpoline with -O3.  No LTO.
* minmax-v1 - LTO based profile which can be configured for CFI.  It comes with
an blacklist/whitelist LTO generator to prevent IR incompatibilities.
(Development is End of Life [EOL])

### Development / pre-alpha

* minmax-v2 - LTO based profile with dynamically generated profiles with O(1)
MLOC estimator to auto tag packages needing Ccache or -O1, auto tag -O3 or
-Ofast based on matching keyword ebuild scans, auto disables fast-math
sub-options with violations to minimize ffast-math related bugs.  Includes
minmax-v1 LTO generators.  (Development is on ice)

## Notes

Refer to profiles/<name>/README.md or profiles/<name>/docs for more information.

Initially, it was decided to unify all profiles with minmax-v2 but at the same
time have the capability to switch between cflag profiles for seasonal reasons
like summer for gaming and winter for security.  gcf2 is created as a result.
