## The gen_pkg_lists.sh generator

The script exists to avoid IR incompatibility proactively before it happens.

The `gen_pkg_lists.sh` script is provided to generate LTO blacklist and
whitelists.  Before running the list generator, both `CC_LTO` and `CC_LIBC` in
the generator script should be set to either clang or gcc in make.conf.  The
list generator can be run by doing `bash gen_pkg_lists.sh`.

The following files are generated for LTO flags:

* /etc/portage/emerge-system-lto-agnostic.lst -- Packages in this list are allowed any compiler for LTO for @system and @world
* /etc/portage/emerge-system-lto-restricted.lst -- Packages in this list are only allowed the default compiler for @system.  If no static-libs are linked, you can use LTO.  Otherwise, LTO must be disabled for the package with static-libs.
* /etc/portage/emerge-system-lto-skip.lst -- Packages in this do not require LTO for @system set due to lack of binaries
* /etc/portage/emerge-system-no-data.lst -- Packages are missing the emerged file list for @system
* /etc/portage/emerge-system-no-lto.lst -- Packages in this are disallowed LTO for @system and @world
* /etc/portage/emerge-world-lto-agnostic.lst -- Packages in this list are allowed any compiler for LTO for @world
* /etc/portage/emerge-world-lto-restricted.lst -- Packages in this list are only allowed the systemwide LTO compiler for @world.  If no static-libs are linked, you can use LTO.  Otherwise, LTO must be disabled for the package with static-libs.
* /etc/portage/emerge-world-lto-skip.lst -- Packages in this do not require LTO for @world set due to lack of binaries
* /etc/portage/emerge-world-no-data.lst -- Packages are missing the emerged file list for @world
* /etc/portage/emerge-world-no-lto.lst -- Packages in this list are disallowed LTO for @world
* /etc/portage/emerge-requirements-not-met.lst -- Generated by bashrc if LTO requirements are not met.  List can be re-emerged after fixing the LTO requirements.

When a static-libs USE flag is enabled in the future, the package with the
changed USE flag must be manually moved from the lto-agnostic into either a
no-lto or a lto-restricted list.

The bashrc will process these lists.  They should be re-generated before a
`emerge -ev @system` or `emerge -ev @world` is performed.  It cannot be
gathered ahead of time due to lack of ebuild metadata or hints.

The packages in either `emerge-*-no-lto.lst` and `emerge-*-lto-restricted.lst`
contain static-libs which may have compiler specific IR (Intermediate
Representation) which may not be compatible.  To maximize compatibility
when linking static-libs, LTO is disabled or uses the same IR as the chosen
default systemwide LTO used for @world.

If LTO was never applied due to it previously placed in no-data list or
was a new package, but placed later in the lto-agnostic lists after
running `gen_pkg_lists.sh`, you may re-enable the lto USE flag and
re-emerge those packages afterwards with LTO.  If it was later placed in
lto-restricted, you can only enable LTO for that particular package if
there is no hard dependence on CC_LIBC compiler for packages that use
it as a static-libs dependency.

If the package is temporarly LTO blocked or a new install, you may try to
manually move the package from no-data to lto-agnostic and in the emerge*.lst
files in order to bypass the pre IR compatibility check only if static-libs will
be not built or will have static-libs disabled or will have its LTO disabled.

## Helper script(s)

### Re-emerging new packages that were not LTOed

It is important to re-emerge these packages so some of these can be CFI
protected.  This can be achieved if logging is enabled.

1. Resolve all merge conflicts and keyword/unmasked packages before preceeding
to increase coverage.

2. Run `./gen_pkg_lists.sh`

3. Run `emerge-unltoed.sh`

Use the resume-emerge-lst script or --skipfirst to skip unmergable.

The script can be modified to add additional options for emerge.

The PACKAGE_ENV_PATH environment variable may be set to change the location of
remove-lto.conf exceptions.