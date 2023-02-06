## Helper script(s)

### Sorted list of completion times

If you enabled logging for bashrc in make.conf, you can get a sorted list of
ebuild completion times by doing the following:

```Shell
for f in $(ls /var/log/emerge/build-logs) ; do \
	l=$(grep  -e "Completion Time:" "/var/log/emerge/build-logs/${f}") \
		&& echo "${l} ${f}" ; \
done | sort -rV
```

### Resume list

Many times emerge is forgetful about the resume list as a result of
one shotting too many times after trying to find fixes.

Before generating the resume list, preview it to ensure that the resume
list is the actual one.  Do not resume off the 1 to a few packages
you are trying to repair.

The following script has been added to allow you to resume emerging.  It
requires `emerge -pv --resume | grep -e "^\[" > ~/resume.lst` or copy
paste the resume list and remove the header and footer only keeping the
square bracket rows.  Keep the resume.lst updated once in a while or
after emerge failure after --resume.

```Shell
#!/bin/bash
# Can be named as ~/resume-emerge-lst.
# Run as ~/resume-emerge-lst ~/resume.lst

main() {
        local list="${1}"
        echo "Resume list path: ${list}"
        if [[ ! -e "${list}" ]] ; then
                echo "Missing a resume list"
                exit 1
        fi
	local o=()
        for p in $(cat "${list}" | cut -c 18- | cut -f 1 -d " ") ; do
                o+=( "=${p}" )
        done
	# You can add sudo before the following
	emerge -1vO ${o[@]}
}

main "${1}"
```

After running the script, the `--resume` arg can be used in subsequent calls 
to `emerge`.

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

### Re-emerging new packages that were not CFIed

It is important to re-emerge these packages so some of these can be CFI
protected.  This can be achieved if logging is enabled.

1. Resolve all merge conflicts and keyword/unmasked packages before preceeding
to increase coverage.

2. Run `./gen_pkg_lists.sh`

3. Run `emerge-uncfied.sh`

Use the resume-emerge-lst script or --skipfirst to skip unmergable.

The script can be modified to add additional options for emerge.

The PACKAGE_ENV_PATH environment variable may be set to change the location of
disable-clang-cfi.conf exceptions.

### Checking for early CFI violations and missing symbols

This does a simple --help and --version check.  Add any potentially dangerous
commands in the
[exclude list](../scan-cfied-broken-binaries#L68)
inside the script.  This only tests a few code paths at start.  You may still
encounter CFI violations from event based portions or deeper in the code.

For testing some deeper code paths, add test to systemwide USE flags and systemwide
FEATURES in make.conf.  Preparation for the test USE flag should be done
(in step 3 of the [steps section](../docs/CFI-support.md#steps)
early on to increase chances of a complete atomic update from beginning to
end.

IMPORTANT:  Before running the script, save your work.  You may need to run
this outside of X to prevent crash with X.

The script is called
[scan-cfied-broken-binaries](../scan-cfied-broken-binaries).

Use `<path> --help`, `<path> --version`, or `<exe_path>` to see the violation or
missing symbol problem.

The script has several environment variables to control scanning, reporting, and
analysis and are found at the top of the script.  Example: 

`ANALYSIS=1 GEN_LOG=1 CHECK_NO_ARGS=1 CHECK_HELP=0 CHECK_VERSION=0 ./scan-cfied-broken-binaries`

To form just analysis after the required /var/log/cfi-scan.log has been produced do:

`ANALYSIS=1 GEN_LOG=0 CHECK_NO_ARGS=0 CHECK_HELP=0 CHECK_VERSION=0 ./scan-cfied-broken-binaries`

Some of the environment vararibles described with 0=off and 1=on:

* ANALYSIS -- generate condensed report mapping shared-libs and the ebuilds they come from.
* GEN_LOG -- generate output log in /var/log/cfi-scan.log
* CHECK_VERSION -- run and check stderr for `program --version`
* CHECK_HELP -- run and check stderr for `program --help`
* CHECK_NO_ARGS -- run and check stderr for `program` while starting it normally
* ALLOW_ONLY_EMERGED -- allow only emerged files to be executed
* ALLOW_MODDED_BINARIES -- allow modded binaries to be executed.  Otherwise,
allow only the executable with same md5sum (aka file fingerprint) recorded by
emerge to be executed.

The `equery b <path>` is slow.  Use `grep -l "<path>" /var/db/pkg/*/*/CONTENTS`
instead.

This tool will not detect a stall or lack of progression when executing a program.
Manual inspection is required for this kind of error.  The stall could be caused
by a missing symbol problem.

### Checking for broken stripped shared-libs

The script `find-broken-so-stripping.sh` has been provided to scan for
unloadable libs as a result of stripping.  These packages require
`no-strip.conf` if a list of libs are not able to be produced with `ldd`.
