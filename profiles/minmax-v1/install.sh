#!/bin/bash

main() {
	local ts=$(date "+%Y%m%d-%H.%M.%S")
	local dest="${EROOT}/etc/portage"
	cp -a "${dest}/bashrc"{,.${ts}}
	cp -a "bashrc" "${dest}"
	cp -a "package.env" "${dest}"
	cp -a "${dest}/make.conf"{,.${ts}}
	cp -a "make.conf" "${dest}"
	cp -a "env" "${dest}"
	cp -a "package.cfi_ignore" "${dest}"
	cp -a "patches" "${dest}"
	find \
		"${dest}/package.cfi_ignore" \
		-type d -exec chmod 755 {} \;
	find \
		"${dest}/package.cfi_ignore" \
		-type f -exec chmod 644 {} \;
	find \
		"${dest}/package.cfi_ignore" \
		-exec chown root:root {} \;

	# We do it this way assuming sensitive data (credentials) are used as a patch.
	chown root:root "${dest}/patches/sys-apps/portage/no-stripping-cfi-symbols.patch"
	chown root:root "${dest}/patches/sys-apps/portage"
	chown root:root "${dest}/patches/sys-apps"
	chown root:root "${dest}/patches"
	chmod 644 "${dest}/patches/sys-apps/portage/no-stripping-cfi-symbols.patch"
	chmod 755 "${dest}/patches/sys-apps/portage"
	chmod 755 "${dest}/patches/sys-apps"
	chmod 755 "${dest}/patches"

	chown root:root "${dest}/make.conf"
	chown root:root "${dest}/package.env"
	chown -R root:root "${dest}/env"
	chmod 644 "${dest}/make.conf"
	chmod 644 "${dest}/package.env"
	chmod 755 "${dest}/bashrc"
	chmod -R 644 "${dest}/env/"*
	chmod -R 755 "${dest}/env"
	./gen_pkg_lists.sh
echo
echo "You need to manually update ${dest}/make.conf from"
echo "${dest}/make.conf.${ts}"
echo
echo "You need to manually update ${dest}/bashrc from"
echo "${dest}/bashrc.${ts}"
echo
}

main
