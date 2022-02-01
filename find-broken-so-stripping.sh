#!/bin/bash

_gcf_verify_src() {
	local location="${1}"
	if [[ "${location}" == "ED" ]] ; then
		# Verify in ${ED} when it is not stripped
		find "${ED}" -executable
	elif [[ "${location}" == "EROOT" ]] ; then
		# Verify after strip in ${EROOT}
		cat /var/db/pkg/${p}/CONTENTS | cut -f 2 -d " "
	fi
}

gcf_verify_loading_lib() {
	local location="${1}"
	local f
        for f in $(_gcf_verify_src "${location}") ; do
		[[ "${f}" =~ ".so" ]] || continue
                local is_so=0
                file "${f}" | grep -q -e "ELF.*shared object" && is_so=1
                if (( ${is_so} == 1 )) ; then
                        if ldd "${f}" | grep -q -e "not a dynamic executable" ; then
				echo "Found broken ${f} from ${p}"
                        fi
                fi
        done
}

main() {
	echo "Finding packages please wait"
	local F=$(find /var/db/pkg -name "CONTENTS")
	local f
	for f in ${F[@]} ; do
		local p=$(echo "${f}" | cut -f 5-6 -d "/")
		gcf_verify_loading_lib "EROOT"
	done
}

main
