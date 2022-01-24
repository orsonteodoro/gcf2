#!/bin/bash
show_cfi_set() {
	local s="${1}"
	echo "Getting ${s} list please wait"
	local L=( $(emerge -pve ${s} 2>/dev/null \
		| cut -c 18- \
		| cut -f 1 -d " " \
		| grep -e "/" \
		| sed -E -e "s/:.*//g" \
		| sort \
		| uniq) )
	local p
	echo "CFIed packages:"
	local n_total=0
	local n_cfied=0
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local is_cfied=0
		if [[ -e "/var/db/pkg/${p}/CONTENTS" ]] ; then
			for f in $(cat /var/db/pkg/${p}/CONTENTS | cut -f 2 -d " ") ; do
				readelf -Ws "${f}" 2>/dev/null \
					| grep -q -E -e "(cfi_bad_type|cfi_check_fail)" 2>/dev/null \
					&& is_cfied=1 && break
			done
		fi
		if (( ${is_cfied} == 1 )) ; then
			echo "[cfied] ${p}"
			n_cfied=$((${n_cfied} + 1))
		else
			echo "[not-cfied] ${p}"
		fi
		n_total=$((${n_total} + 1))
	done
	echo "Total: ${n_total}"
	echo "# CFIed: ${n_cfied} "$(python -c "print(${n_cfied} / ${n_total} * 100)")" %"
	echo "# NOT CFIed: $((${n_total} - ${n_cfied})) "$(python -c "print((${n_total} - ${n_cfied}) / ${n_total} * 100)")" %"
}

main() {
	for s in system world ; do
		show_cfi_set "${s}"
	done
}

main
