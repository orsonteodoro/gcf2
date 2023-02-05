#!/bin/bash

main() {
	local ts=$(date "+%Y%m%d-%H.%M.%S")
	./gen_package_env.sh
	local dest="${EROOT}/etc/portage"
	cp -a "${dest}/bashrc"{,.${ts}}
	cp -a "bashrc" "${dest}"
	cp -a "package.env" "${dest}"
	cp -a "${dest}/make.conf"{,.${ts}}
	cp -a "make.conf" "${dest}"
	cp -a "env" "${dest}"
	cp -a "package.cfi_ignore" "${dest}"
	cp -a "patches" "${dest}"
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
