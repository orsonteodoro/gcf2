#!/bin/bash
T_PKGS=()
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
					| grep -q -E -e "(cfi_bad_type|cfi_check_fail|__cfi_init)" 2>/dev/null \
					&& is_cfied=1 && break
			done
		fi
		if (( ${is_cfied} == 1 )) ; then
			echo "[cfied] ${p}"
			n_cfied=$((${n_cfied} + 1))
		else
			T_PKGS+=( "=${p}" )
			echo "[not-cfied] ${p}"
		fi
		n_total=$((${n_total} + 1))
	done
}

main() {
	if [[ ! -e "/etc/portage/emerge-cfi-skip.lst" ]] ; then
		echo "Missing emerge-cfi-skip.lst.  Run gen_pkg_lists.sh"
	fi
	if [[ ! -e "/etc/portage/emerge-cfi-no-cfi.lst" ]] ; then
		echo "Missing emerge-cfi-no-cfi.lst.  Run gen_pkg_lists.sh"
	fi
	for s in system world ; do
		show_cfi_set "${s}"
	done
	L_SKIP=($(\
		for x in $(cat /etc/portage/emerge-cfi-skip.lst /etc/portage/emerge-cfi-no-cfi.lst) ; do \
				echo "${x/:}" ; \
		done \
	))
	PKGS=()
	for p in ${T_PKGS[@]} ; do
		[[ "${p}" =~ ^"#" ]] && continue
		local can_skip=0
		for p_skip in ${L_SKIP[@]} ; do
			if [[ "${p}" =~ "${p_skip}" ]] ; then
				can_skip=1
			fi
		done
		(( ${can_skip} == 0 )) && PKGS+=( "${p}" )
	done
	emerge -1vO ${PKGS[@]}
}

main
