#!/bin/bash

_gcf_verify_src() {
	local location="${1}"
	if [[ "${location}" == "ED" ]] ; then
		# Verify in ${ED} when it is not stripped
		find "${ED}" -executable
	elif [[ "${location}" == "EROOT" ]] ; then
		# Verify after strip in ${EROOT}
		cat "${EROOT}/var/db/pkg/${p}/CONTENTS" | cut -f 2 -d " "
	fi
}

gcf_verify_loading_lib() {
	local location="${1}"
	IFS=$'\n'
	local row
	for row in $(_gcf_verify_src "${location}") ; do
		local f=$(echo "${row}" | cut -f 2 -d " ")
		local md5_expected=$(echo "${row}" | cut -f 3 -d " ")
		[[ "${f}" =~ ".so" ]] || continue
		local is_so=0
		file "${f}" | grep -q -e "ELF.*shared object" && is_so=1
		if (( ${is_so} == 1 )) ; then
			# ldd is insecure.  See `man 1 ldd`
			local md5_actual=$(md5sum "${f}" | cut -f 1 -d " ")
			if [[ "${md5_expected}" == "${md5_actual}" ]] \
				&& ldd "${f}" | grep -q -e "not a dynamic executable" ; then
				echo "Found broken ${f} from ${p}"
			fi
		fi
	done
	IFS=$' \t\n'
}

main() {
	echo "Finding packages please wait"
	local F=$(find "${EROOT}/var/db/pkg" -name "CONTENTS")
	local f
	for f in ${F[@]} ; do
		local p=$(echo "${f}" | cut -f 5-6 -d "/")
		gcf_verify_loading_lib "EROOT"
	done
}

main
