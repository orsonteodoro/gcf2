#!/bin/bash

VERSION=3 # bump every time the format or filename changes

TOTAL_LTO_PACKAGES=0
N_LTO_AGNOSTIC=0
N_LTO_RESTRICTED=0
N_LTO_SKIP=0
N_NO_LTO=0
N_NO_LTO_DATA=0

TOTAL_CFI_PACKAGES=0
N_CFIABLE=0
N_CFIABLE_WORLD=0
N_CFIABLE_SYSTEM=0
N_NO_CFI=0
N_CFI_ICALL=0
N_CFI_SKIP=0
N_NO_CFI_DATA=0

LTO_CATS=( lto-agnostic lto-restricted lto-skip no-lto no-data )
CFI_CATS=( cfi-system cfi-world cfi-no-cfi cfi-no-data cfi-skip )

RELIABLE_FORMAT_CHECK=0

is_already_added_to_system_set() {
	for t in ${LTO_CATS[@]} ; do
		grep -q -E -e "${pp}$" "/etc/portage/emerge-system-${t}.lst" && return 0
	done
	return 1
}

check_ltoable() {
	if (( ${RELIABLE_FORMAT_CHECK} == 1 )) ; then
		# Can be slow because has to pulls many pages and access disk again (possibly
		# decrypt) for the file headers.
		file "${f}" | grep -q -e "ar archive" && has_static=1
		file "${f}" | grep -q -e "ELF.*shared object" && has_shared=1
	else
		echo "${f}" | grep -q -e "\.a$" && has_static=1
		echo "${f}" | grep -q -e "\.so[.0-9]*$" && has_shared=1
	fi
	file "${f}" | grep -q -e "ELF.*executable" && has_exe=1
}

check_static_libs() {
	local emerge_set="${1}"
	echo "Please wait.  Generating emerge list..."

	echo
	echo "Both emerge -pve @system and emerge -pve @world must have no"
	echo "conflicts or build issues for complete lists to be generated."
	echo "If no list appears, resolve the conflicts or issues first."
	echo

	local L=( $(emerge -pve ${emerge_set} 2>/dev/null \
		| cut -c 18- \
		| cut -f 1 -d " " \
		| grep -e "/" \
		| sed -E -e "s/:.*//g" \
		| sort \
		| uniq) )
	echo
	echo "[${emerge_set}] LTO package status:"
	echo
	for c in ${LTO_CATS[@]} ; do
		echo "# version ${VERSION}" > /etc/portage/emerge-${emerge_set}-${c}.lst
	done
	local p
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local has_static=0
		local has_shared=0
		local has_exe=0
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
				check_ltoable
			done
		elif [[ -e "${path2}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1.2*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path2}" | cut -f 2 -d " ") ; do
				check_ltoable
			done
		elif [[ -e "${path3}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path3}" | cut -f 2 -d " ") ; do
				check_ltoable
			done
		elif [[ -e "${path4}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			for f in $(cat "${path4}" | cut -f 2 -d " ") ; do
				check_ltoable
			done
		else
			TOTAL_LTO_PACKAGES=$(( ${TOTAL_LTO_PACKAGES} + 1 ))
			N_NO_LTO_DATA=$(( ${N_NO_LTO_DATA} + 1 ))
			echo "[no-data] ${p}"
			echo "${pp}" >> /etc/portage/emerge-${emerge_set}-no-data.lst
			continue
		fi
		if (( ${has_static} == 0 && ${has_shared} == 0 && ${has_exe} == 0 )) ; then
			TOTAL_LTO_PACKAGES=$(( ${TOTAL_LTO_PACKAGES} + 1 ))
			N_LTO_SKIP=$(( ${N_LTO_SKIP} + 1 ))
			echo "[lto-skip] ${p}"
			echo "${pp}" >> /etc/portage/emerge-${emerge_set}-lto-skip.lst
		elif (( ${has_static} == 0 )) ; then
			TOTAL_LTO_PACKAGES=$(( ${TOTAL_LTO_PACKAGES} + 1 ))
			N_LTO_AGNOSTIC=$(( ${N_LTO_AGNOSTIC} + 1 ))
			echo "[lto-agnostic] ${p}"
			echo "${pp}" >> /etc/portage/emerge-${emerge_set}-lto-agnostic.lst
		else
			TOTAL_LTO_PACKAGES=$(( ${TOTAL_LTO_PACKAGES} + 1 ))
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
echo "no-data - Data is stored in /etc/portage/emerge-${emerge_set}-no-data.lst."
echo "     Requires emerge to generate a installed files list for the package"
echo "     or manual placement."
echo
echo "no-lto - Data is stored in /etc/portage/emerge-${emerge_set}-no-lto.lst."
echo "     LTO must be disabled unless LTO compiler matches the same one used"
echo "     by libc."
echo
echo "lto-agnostic - Data is stored in /etc/portage/emerge-${emerge_set}-lto-agnostic.lst."
echo "     No IR incompatibilities with static-libs.  Any compiler will work."
echo
echo "lto-skip - Data is stored in /etc/portage/emerge-${emerge_set}-lto-skip.lst."
echo "     No LTO is required."
echo
echo "lto-restricted - Data is stored in /etc/portage/emerge-${emerge_set}-lto-restricted.lst."
echo "     LTO either must be preformed by default LTO compiler or LTO must be"
echo "     disabled.  Packages that statically link must use the same compiler;"
echo "     otherwise, the package with the static-lib must have LTO disabled."
echo
}

gen_lto_lists() {
	check_static_libs "system"
	check_static_libs "world"

	echo "Stats:"
	echo "# Total packages:  ${TOTAL_LTO_PACKAGES}"
	echo "# LTO agnostic:  ${N_LTO_AGNOSTIC} ("$(python -c "print(${N_LTO_AGNOSTIC}/${TOTAL_LTO_PACKAGES}*100)")" %)"
	echo "# LTO restricted:  ${N_LTO_RESTRICTED} ("$(python -c "print(${N_LTO_RESTRICTED}/${TOTAL_LTO_PACKAGES}*100)")" %)"
	echo "# LTO disallowed:  ${N_NO_LTO} ("$(python -c "print(${N_NO_LTO}/${TOTAL_LTO_PACKAGES}*100)")" %)"
	echo "# LTO skip:  ${N_LTO_SKIP} ("$(python -c "print(${N_LTO_SKIP}/${TOTAL_LTO_PACKAGES}*100)")" %)"
	echo "# No data:  ${N_NO_LTO_DATA} ("$(python -c "print(${N_NO_LTO_DATA}/${TOTAL_LTO_PACKAGES}*100)")" %)"
}

is_ltoable() {
	if grep -q -E -e "^${pp}$" /etc/portage/emerge-{system,world}-{lto-agnostic,lto-restricted}.lst ; then
		return 0
	fi
	return 1
}

is_lto_restricted() {
	if grep -q -E -e "^${pp}$" /etc/portage/emerge-{system,world}-lto-restricted.lst ; then
		return 0
	fi
	return 1
}

is_cfi_entry_added() {
	local c
	for c in ${CFI_CATS[@]} ; do
		if grep -q -e "^${pp}(:|$)" /etc/portage/emerge-${c}.lst ; then
			return 0
		fi
	done
	return 1
}

is_world_set() {
	local c
	for c in ${LTO_CATS[@]} ; do
		if grep -q -e "^${pp}$" /etc/portage/emerge-world-${c}.lst ; then
			return 0
		fi
	done
	return 1
}

is_system_set() {
	local c
	for c in ${LTO_CATS[@]} ; do
		if grep -q -e "^${pp}$" /etc/portage/emerge-system-${c}.lst ; then
			return 0
		fi
	done
	return 1
}

check_cfi() {
	echo "Please wait.  Generating emerge list..."

	echo
	echo "Both emerge -pve @system and emerge -pve @world must have no"
	echo "conflicts or build issues for complete lists to be generated."
	echo "If no list appears, resolve the conflicts or issues first."
	echo
	echo "[cfi] Packages categorized as follows:"
	echo

	local L=( $(emerge -pve world 2>/dev/null \
		| cut -c 18- \
		| cut -f 1 -d " " \
		| grep -e "/" \
		| sed -E -e "s/:.*//g" \
		| sort \
		| uniq) )
	echo
	echo
	echo "CFI package status:"
	echo
	for c in ${CFI_CATS[@]} ; do
		echo "# version ${VERSION}" > /etc/portage/emerge-${c}.lst
	done

	set_cfi_flags() {
		local contents_path="${1}"
		for f in $(cat "${contents_path}" | cut -f 2 -d " ") ; do
			if (( ${RELIABLE_FORMAT_CHECK} == 1 )) ; then
				if file "${f}" | grep -q -e "ar archive" ; then
					has_static="A"
					readelf -Ws "${f}" 2>/dev/null | grep -q -e "dlopen" || ncfi_icall=$((${ncfi_icall} + 1))
					nbin=$((${nbin} + 1))
				fi
				if file "${f}" | grep -q -e "ELF.*shared object" ; then
					has_shared="S"
					readelf -Ws "${f}" 2>/dev/null | grep -q -e "dlopen" || ncfi_icall=$((${ncfi_icall} + 1))
					nbin=$((${nbin} + 1))
				fi
			else
				if echo "${f}" | grep -q -e "\.a$" ; then
					has_static="A"
					readelf -Ws "${f}" 2>/dev/null | grep -q -e "dlopen" || ncfi_icall=$((${ncfi_icall} + 1))
					nbin=$((${nbin} + 1))
				fi
				if echo "${f}" | grep -q -e "\.so[.0-9]*$" ; then
					has_shared="S"
					readelf -Ws "${f}" 2>/dev/null | grep -q -e "dlopen" || ncfi_icall=$((${ncfi_icall} + 1))
					nbin=$((${nbin} + 1))
				fi
			fi
			if file "${f}" | grep -q -e "ELF.*executable" ; then
				# libdl can be static, so libdl.so check is not enough.
				readelf -Ws "${f}" 2>/dev/null | grep -q -e "dlopen" || ncfi_icall=$((${ncfi_icall} + 1))
				has_exe="X"
				nbin=$((${nbin} + 1))
			fi
		done
		if (( ${nbin} == ${ncfi_icall} && ${nbin} >= 1 )) ; then
			has_cfi_icall="I"
			N_CFI_ICALL=$((${N_CFI_ICALL} + 1))
		fi
		is_lto_restricted && has_lto_restriction="R"
	}

	local p
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local has_static=""
		local has_shared=""
		local has_exe=""
		local has_cfi_icall=""
		local has_lto_restriction=""
		local p_no_r=$(echo "${p}" | sed -E -e "s/(-r[0-9]+)+$//g")
		local pp=$(echo "${p}" | sed -E -e "s/(-r[0-9]+|_p[0-9]+)+$//g" \
			| sed -E -e "s|-[.0-9_a-z]+$||g")
		local v_mm2=$(echo "${p_no_r}" | sed -e "s|${pp}-||g" | cut -f 1-2 -d ".")
		local v_mm1=$(echo "${p_no_r}" | sed -e "s|${pp}-||g" | cut -f 1 -d ".")
		local path2=$(realpath /var/db/pkg/${pp}-${v_mm2}*/CONTENTS 2>/dev/null | head -n 1)
		local path3=$(realpath /var/db/pkg/${pp}-${v_mm1}*/CONTENTS 2>/dev/null | head -n 1)
		local path4=$(realpath /var/db/pkg/${pp}-*/CONTENTS 2>/dev/null | head -n 1)

		if is_cfi_entry_added ; then
			echo "[skipped] already added ${pp}"
			continue
		fi

		local ncfi_icall=0
		local nbin=0
		if [[ -e "/var/db/pkg/${p}/CONTENTS" ]] ; then
			set_cfi_flags "/var/db/pkg/${p}/CONTENTS"
		elif [[ -e "${path2}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1.2*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			set_cfi_flags "${path2}"
		elif [[ -e "${path3}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}-1*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			set_cfi_flags "${path3}"
		elif [[ -e "${path4}" ]] 2>/dev/null 1>/dev/null ; then
			# Fallback template:  ${PN}*
			echo "[warn] No ${p} installation found.  Using older ${pp} ebuild for inspection"
			set_cfi_flags "${path4}"
		else
			TOTAL_LTO_PACKAGES=$(( ${TOTAL_CFI_PACKAGES} + 1 ))
			N_NO_CFI_DATA=$(( ${N_NO_CFI_DATA} + 1 ))
			echo "[no-data] ${p}:"
			echo "${pp}" >> /etc/portage/emerge-cfi-no-data.lst
			continue
		fi
		local fields="${has_static}${has_shared}${has_exe}${has_cfi_icall}${has_lto_restriction}"
		if [[ "${has_static}" != "A" && "${has_shared}" != "S" && "${has_exe}" != "X" ]] ; then
			TOTAL_CFI_PACKAGES=$(( ${TOTAL_CFI_PACKAGES} + 1 ))
			N_CFI_SKIP=$(( ${N_CFI_SKIP} + 1 ))
			echo "[cfi-skip] ${p}:${fields}"
			echo "${pp}:${fields}" >> /etc/portage/emerge-cfi-skip.lst
		elif is_world_set && is_ltoable ; then
			TOTAL_CFI_PACKAGES=$(( ${TOTAL_CFI_PACKAGES} + 1 ))
			N_CFIABLE=$(( ${N_CFIABLE} + 1 ))
			N_CFIABLE_WORLD=$(( ${N_CFIABLE_WORLD} + 1 ))
			echo "[cfi-world] ${p}:${fields}"
			echo "${pp}:${fields}" >> /etc/portage/emerge-cfi-world.lst
		elif is_system_set && is_ltoable ; then
			TOTAL_CFI_PACKAGES=$(( ${TOTAL_CFI_PACKAGES} + 1 ))
			N_CFIABLE=$(( ${N_CFIABLE} + 1 ))
			N_CFIABLE_SYSTEM=$(( ${N_CFIABLE_SYSTEM} + 1 ))
			echo "[cfi-system] ${p}:${fields}"
			echo "${pp}:${fields}" >> /etc/portage/emerge-cfi-system.lst
		else
			TOTAL_CFI_PACKAGES=$(( ${TOTAL_CFI_PACKAGES} + 1 ))
			N_NO_CFI=$(( ${N_NO_CFI} + 1 ))
			echo "[no-cfi] ${p}:${fields}"
			echo "${pp}:" >> /etc/portage/emerge-cfi-no-cfi.lst
			continue
		fi

	done
echo
echo "Legend:"
echo
echo "no-data - Data is stored in /etc/portage/emerge-cfi-no-data.lst."
echo "    It requires emerge to generate a installed files list for the"
echo "    package or manual placement."
echo
echo "no-cfi - Data is stored in /etc/portage/emerge-cfi-no-cfi.lst.  Not"
echo "    allowed to be CFIed."
echo
echo "cfi-skip - Data is stored in /etc/portage/emerge-cfi-skip.lst.  Doesn't"
echo "    require being CFIed."
echo
echo "cfi-world - Data is stored in /etc/portage/emerge-cfi-world.lst."
echo "    Only allowed when CC_LTO=clang otherwise disabled for that set."
echo
echo "cfi-system - Data is stored in /etc/portage/emerge-cfi-system.lst."
echo "    Only allowed when CC_LIBC=clang otherwise CFI disabled for that set."
echo
echo "A - Package has stAtic library (.a file).  May be a candidate for Clang"
echo "    plain CFI."
echo
echo "S - Package has Shared library (.so file).  May be a candidate for Clang"
echo "    CFI Cross DSO."
echo
echo "X - Package has eXecutible.  May be a candidate for complete CFI."
echo
echo "I - Package may be a candidate for cfi-icall because missing dlopen,"
echo "    but some packages may expose runtime bugs."
echo
echo "R - The package is lto-restricted."
echo
}

gen_cfi_lists() {
	check_cfi

	echo "Stats:"
	echo "# Total packages:  ${TOTAL_CFI_PACKAGES}"
	echo "# CFIable:  ${N_CFIABLE} ("$(python -c "print(${N_CFIABLE}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "#   CFIable (world):  ${N_CFIABLE_WORLD} ("$(python -c "print(${N_CFIABLE_WORLD}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "#   CFIable (system):  ${N_CFIABLE_SYSTEM} ("$(python -c "print(${N_CFIABLE_SYSTEM}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "# cfi-icall candidates:  ${N_CFI_ICALL} ("$(python -c "print(${N_CFI_ICALL}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "# Not CFIable:  ${N_NO_CFI} ("$(python -c "print(${N_NO_CFI}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "# CFI skippable:  ${N_CFI_SKIP} ("$(python -c "print(${N_CFI_SKIP}/${TOTAL_CFI_PACKAGES}*100)")" %)"
	echo "# No Data:  ${N_NO_CFI_DATA} ("$(python -c "print(${N_NO_CFI_DATA}/${TOTAL_CFI_PACKAGES}*100)")" %)"
}

main() {
	export CC_LTO=$(grep -F -e "CC_LTO" /etc/portage/make.conf | cut -f 2 -d "=" | sed -e "s|#.*||" -e 's|"||g')
	export CC_LIBC=$(grep -F -e "CC_LIBC" /etc/portage/make.conf | cut -f 2 -d "=" | sed -e "s|#.*||" -e 's|"||g')

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

#	gen_lto_lists
	gen_cfi_lists
}

main
