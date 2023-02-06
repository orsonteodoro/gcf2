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
	chown root:root "${dest}/make.conf"
	chown root:root "${dest}/package.env"
	chown -R root:root "${dest}/env"
	chmod 644 "${dest}/make.conf"
	chmod 644 "${dest}/package.env"
	chmod -R 644 "${dest}/env/"*
	chmod -R 755 "${dest}/env"
echo
echo "You need to manually update ${dest}/make.conf from"
echo "${dest}/make.conf.${ts}"
echo
}

main
