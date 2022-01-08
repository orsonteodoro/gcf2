#!/bin/bash
N_TOTAL=0
N_CFIED=0
main() {
	echo "Getting world list please wait"
	local L=( $(emerge -pve world 2>/dev/null \
		| cut -c 18- \
		| cut -f 1 -d " " \
		| grep -e "/" \
		| sed -E -e "s/:.*//g" \
		| sort \
		| uniq) )
	local p
	echo "CFIed packages:"
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local is_cfied=0
		if [[ -e "/var/db/pkg/${p}/CONTENTS" ]] ; then
			for f in $(cat /var/db/pkg/${p}/CONTENTS | cut -f 2 -d " ") ; do
				readelf -Ws "${f}" 2>/dev/null \
					| grep -q -E -e "(__cfi_init|__cfi_check_fail)" 2>/dev/null \
					&& is_cfied=1 && break
			done
		fi
		if (( ${is_cfied} == 1 )) ; then
			echo "[cfied] ${p}"
			N_CFIED=$((${N_CFIED} + 1))
		else
			echo "[not-cfied] ${p}"
		fi
		N_TOTAL=$((${N_TOTAL} + 1))
	done
	echo "Total: ${N_TOTAL}"
	echo "# CFIed: ${N_CFIED} "$(python -c "print(${N_CFIED} / ${N_TOTAL} * 100)")" %"
	echo "# NOT CFIed: $((${N_TOTAL} - ${N_CFIED})) "$(python -c "print((${N_TOTAL} - ${N_CFIED}) / ${N_TOTAL} * 100)")" %"
}

main
