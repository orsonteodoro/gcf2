#!/bin/bash

main() {
	local ts=$(date "+%Y%m%d-%H.%M.%S")
	local dest="${EROOT}/etc/portage"
	if [[ -e "${dest}/bashrc" ]] ; then
		mv "${dest}/bashrc"{,.${ts}}
	fi
	cp -a "package.env" "${dest}"
	cp -a "${dest}/make.conf"{,.${ts}}
	cp -a "make.conf" "${dest}"
	cp -a "env" "${dest}"
	cp -a "patches" "${dest}"
	chown root:root "${dest}/make.conf"
	chown root:root "${dest}/package.env"
	chown -R root:root "${dest}/env"
	chmod 644 "${dest}/make.conf"
	chmod 644 "${dest}/package.env"
	chmod -R 644 "${dest}/env/"*
	chmod -R 755 "${dest}/env"

	# We do it this way assuming sensitive data (credentials) are used as a patch.
	chown root:root "${dest}/patches/sys-devel/gcc:11/0000-gcc-11.3.1_p20230120-r1-ld.mold-support.patch"
	chown root:root "${dest}/patches/sys-devel/gcc:11"
	chown root:root "${dest}/patches/sys-devel"
	chown root:root "${dest}/patches"
	chmod 644 "${dest}/patches/sys-devel/gcc:11/0000-gcc-11.3.1_p20230120-r1-ld.mold-support.patch"
	chmod 755 "${dest}/patches/sys-devel/gcc:11"
	chmod 755 "${dest}/patches/sys-devel"
	chmod 755 "${dest}/patches"

echo
echo "You need to manually update ${dest}/make.conf from"
echo "${dest}/make.conf.${ts}"
echo
}

main
