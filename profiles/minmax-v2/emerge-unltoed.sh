#!/bin/bash
T_PKGS=()
PACKAGE_ENV_PATH=${PACKAGE_ENV_PATH:-"${EROOT}/etc/portage/package.env"}
show_lto_set() {
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
	echo "LTOed packages:"
	local n_total=0
	local n_ltoed=0
	for p in ${L[@]} ; do
		p=$(echo "${p}" | sed -e "s|:.*||g" | sed -e "s|^<||g")
		local is_ltoed=0
		if [[ -e "${EROOT}/var/db/pkg/${p}/environment.bz2" ]] \
			&& bzcat "${EROOT}/var/db/pkg/${p}/environment.bz2" \
			| grep -q -e "declare.*CFLAGS.*flto" ; then
			is_ltoed=1
		fi
		if [[ -e "${EROOT}/var/db/pkg/${p}/USE" ]] \
			&& grep -q -e "lto" "${EROOT}/var/db/pkg/${p}/USE" ; then
			is_ltoed=1
		fi
		if (( ${is_ltoed} == 1 )) ; then
			echo "[ltoed] ${p}"
			n_ltoed=$((${n_ltoed} + 1))
		else
			T_PKGS+=( "=${p}" )
			echo "[not-ltoed] ${p}"
		fi
		n_total=$((${n_total} + 1))
	done
}

main() {
	for x in world system ; do
		if [[ ! -e "${EROOT}/etc/portage/emerge-${x}-lto-skip.lst" ]] ; then
			echo "[warn] Missing emerge-${x}-lto-skip.lst.  Run gen_pkg_lists.sh"
		fi
		if [[ ! -e "${EROOT}/etc/portage/emerge-${x}-no-lto.lst" ]] ; then
			echo "[warn] Missing emerge-${x}-no-lto.lst.  Run gen_pkg_lists.sh"
		fi
	done
	local exclude_pkgs=()
	if [[ -e "${PACKAGE_ENV_PATH}" ]] ; then
		if grep -q -E -e "(^[^#]).*remove-lto.conf" "${PACKAGE_ENV_PATH}" ; then
			exclude_pkgs=($(grep -E -e "(^[^#]).*remove-lto.conf" "${PACKAGE_ENV_PATH}" | cut -f 1 -d " "))
		else
			echo "[warn] Did not find package.env rules with remove-lto.conf.  Set PACKAGE_ENV_PATH path to the path containing remove-lto.conf rules."
		fi
	fi
	for s in system world ; do
		show_lto_set "${s}"
	done
	L_SKIP=($(\
		for x in $(cat \
			"${EROOT}/etc/portage/emerge-system-lto-skip.lst" \
			"${EROOT}/etc/portage/emerge-world-lto-skip.lst" \
			"${EROOT}/etc/portage/emerge-system-no-lto.lst" \
			"${EROOT}/etc/portage/emerge-world-no-lto.lst" \
		) ; do \
			echo "${x/:}" ; \
		done \
	))
	PKGS=()
	for p in ${T_PKGS[@]} ; do
		[[ "${p}" =~ ^"#" ]] && continue
		local can_skip=0
		for p_skip in ${L_SKIP[@]} ${exclude_pkgs[@]} ; do
			if [[ "${p}" =~ "${p_skip}" ]] ; then
				can_skip=1
			fi
		done
		(( ${can_skip} == 0 )) && PKGS+=( "${p}" )
	done
	emerge -1vO ${PKGS[@]}
}

main
