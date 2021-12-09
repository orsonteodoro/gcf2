#!/bin/bash

TOTAL_PACKAGES=0
N_LTO_AGNOSTIC=0
N_LTO_RESTRICTED=0
N_NO_LTO=0
N_NO_DATA=0

is_already_added_to_system_set() {
	for t in no-data no-lto lto-agnostic lto-restricted ; do
		grep -q -E -e "${pp}$" "/etc/portage/emerge-system-${t}.lst" && return 0
	done
	return 1
}

check_static_libs() {
	local emerge_set="${1}"
	echo "Please wait.  Generating emerge list..."
	local L=( $(emerge -pve ${emerge_set} 2>/dev/null \
		| cut -c 18- \
		| cut -f 1 -d " " \
		| grep -e "/" \
		| sed -E -e "s/:.*//g" \
		| sort \
		| uniq) )
	echo
	echo "[${emerge_set}] Packages without static-libs:"
	echo
	echo "" > /etc/portage/emerge-${emerge_set}-lto-agnostic.lst
	echo "" > /etc/portage/emerge-${emerge_set}-lto-restricted.lst
	echo "" > /etc/portage/emerge-${emerge_set}-no-lto.lst
	echo "" > /etc/portage/emerge-${emerge_set}-no-data.lst
	local p
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local has_static=0
		local has_data=0
		local p_no_r=$(echo "${p}" | sed -E -e "s/(-r[0-9]+)+$//g")
		local pp=$(echo "${p}" | sed -E -e "s/(-r[0-9]+|_p[0-9]+)+$//g" \
			| sed -E -e "s|-[.0-9_a-z]+$||g")
		local v_mm2=$(echo "${p_no_r}" | sed -e "s|${pp}-||g" | cut -f 1-2 -d ".")
		local v_mm1=$(echo "${p_no_r}" | sed -e "s|${pp}-||g" | cut -f 1 -d ".")
		local path2=$(realpath /var/db/pkg/${pp}-${v_mm2}*/CONTENTS 2>/dev/null | head -n 1)
		local path3=$(realpath /var/db/pkg/${pp}-${v_mm1}*/CONTENTS 2>/dev/null | head -n 1)
		local path4=$(realpath /var/db/pkg/${pp}-*/CONTENTS 2>/dev/null | head -n 1)

		if is_already_added_to_system_set ; then
			echo "[skipped] already added ${pp}"
			continue
		fi

		if [[ -e "/var/db/pkg/${p}/CONTENTS" ]] ; then
			for f in $(cat /var/db/pkg/${p}/CONTENTS | cut -f 2 -d " ") ; do
				echo "${f}" | grep -q -e "\.a$" && has_static=1
			done
		elif [[ -e "${path2}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1.2*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path2}" | cut -f 2 -d " ") ; do
				echo "${f}" | grep -q -e "\.a$" && has_static=1
			done
		elif [[ -e "${path3}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path3}" | cut -f 2 -d " ") ; do
				echo "${f}" | grep -q -e "\.a$" && has_static=1
			done
		elif [[ -e "${path4}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path4}" | cut -f 2 -d " ") ; do
				echo "${f}" | grep -q -e "\.a$" && has_static=1
			done
		else
			TOTAL_PACKAGES=$(( ${TOTAL_PACKAGES} + 1 ))
			N_NO_DATA=$(( ${N_NO_DATA} + 1 ))
			echo "[no-data] ${p}"
			echo "${pp}" >> /etc/portage/emerge-${emerge_set}-no-data.lst
			continue
		fi
		if (( ${has_static} == 0 )) ; then
			TOTAL_PACKAGES=$(( ${TOTAL_PACKAGES} + 1 ))
			N_LTO_AGNOSTIC=$(( ${N_LTO_AGNOSTIC} + 1 ))
			echo "[lto-agnostic] ${p}"
			echo "${pp}" >> /etc/portage/emerge-${emerge_set}-lto-agnostic.lst
		else
			TOTAL_PACKAGES=$(( ${TOTAL_PACKAGES} + 1 ))
			if [[ "${emerge_set}" == "system" && "${CC_LTO}" != "${CC_LIBC}" ]] ; then
				N_NO_LTO=$(( ${N_NO_LTO} + 1 ))
				echo "[no-lto] ${p}"
				echo "${pp}" >> /etc/portage/emerge-${emerge_set}-no-lto.lst
			elif [[ "${emerge_set}" == "system" && "${CC_LTO}" == "${CC_LIBC}" ]] ; then
				N_LTO_RESTRICTED=$(( ${N_LTO_RESTRICTED} + 1 ))
				echo "[lto-restricted] ${p}"
				echo "${pp}" >> /etc/portage/emerge-${emerge_set}-no-restricted.lst
			else
				N_LTO_RESTRICTED=$(( ${N_LTO_RESTRICTED} + 1 ))
				echo "[lto-restricted] ${p}"
				echo "${pp}" >> /etc/portage/emerge-${emerge_set}-lto-restricted.lst
			fi
		fi
	done

	echo
	echo "Legend:"
	echo
	echo "no-data - Data is stored in /etc/portage/emerge-${emerge_set}-no-data.lst.  Requires emerge to generate this list or manual placement." | fold -s -w 80
	echo
	echo "no-lto - Data is stored in /etc/portage/emerge-${emerge_set}-no-lto.lst.  LTO must be disabled unless LTO compiler matches the same one used by libc." | fold -s -w 80
	echo
	echo "lto-agnostic - Data is stored in /etc/portage/emerge-${emerge_set}-lto-agnostic.lst.  No IR incompatibilities.  Any compiler will work." | fold -s -w 80
	echo
	echo "lto-restricted - Data is stored in /etc/portage/emerge-${emerge_set}-lto-restricted.lst.  LTO either must be preformed by default LTO compiler or LTO must be disabled." | fold -s -w 80
	echo
}

main() {
	export CC_LTO=$(grep -r -e "CC_LTO" /etc/portage/make.conf | cut -f 2 -d "=" | sed -e "s|#.*||" -e 's|"||g')
	export CC_LIBC=$(grep -r -e "CC_LIBC" /etc/portage/make.conf | cut -f 2 -d "=" | sed -e "s|#.*||" -e 's|"||g')

	if [[ -z "${CC_LTO}" ]] ; then
		echo "Missing CC_LTO in /etc/portage/make.conf.  Valid values clang, gcc."
		exit 1
	fi

	if [[ -z "${CC_LIBC}" ]] ; then
		echo "Missing CC_LIBC in /etc/portage/make.conf.  Valid values clang, gcc."
		exit 1
	fi

	echo
	echo "Current compilers:"
	echo
	echo "CC_LTO=${CC_LTO} (current LTO compiler)"
	echo "CC_LIBC=${CC_LIBC} (current libc compiler)"
	echo

	echo
	echo "Both emerge -pve @system and emerge -pve @world must have no"
	echo "conflicts or build issues for complete lists to be generated."
	echo

	check_static_libs "system"
	check_static_libs "world"

	echo "Stats:"
	echo "# Total packages:  ${TOTAL_PACKAGES}"
	echo "# LTO agnostic:  ${N_LTO_AGNOSTIC} ("$(python -c "print(${N_LTO_AGNOSTIC}/${TOTAL_PACKAGES}*100)")" %)"
	echo "# LTO restricted:  ${N_LTO_RESTRICTED} ("$(python -c "print(${N_LTO_RESTRICTED}/${TOTAL_PACKAGES}*100)")" %)"
	echo "# LTO disallowed:  ${N_NO_LTO} ("$(python -c "print(${N_NO_LTO}/${TOTAL_PACKAGES}*100)")" %)"
	echo "# No data:  ${N_NO_DATA} ("$(python -c "print(${N_NO_DATA}/${TOTAL_PACKAGES}*100)")" %)"
}

main
