#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(dirname "$0")

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-1}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
CRYPTO_CHEAP_OPT="${CRYPTO_CHEAP_OPT:-O1.conf}"
CRYPTO_EXPENSIVE_OPT="${CRYPTO_EXPENSIVE_OPT:-O3.conf}"
CRYPTO_ASYM_OPT="${CRYPTO_ASYM_OPT:-Ofast-ts.conf}" # Based on benchmarks, expensive
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
EXPENSIVE_ALGS=(
	25519
	"curve[^0-9]*25519"
	"curve[^0-9]*448"
	dh
	dsa
	elgamal
	"ec(dsa|dh)"
	sm2

	# Add your custom list here
	# Maybe you should add the name of the algorithm when keysize > native word size
	#   or
	# number of rounds is very large
	sha3
)
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}"
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

get_path_pkg_idx() {
	local manifest_path="${1}"
	echo $(ls "${manifest_path}" | grep -o -e "/" | wc -l)
}

gen_overlay_paths() {
	local _overlay_paths=(
		${PORTAGE_DIR}
		${OILEDMACHINE_OVERLAY_DIR}
		$(find "${LAYMAN_BASEDIR}" -maxdepth 1 -type d \( -name "profiles" -o -name "metadata" \) \
			| sed -r -e "s/(metadata|profiles)//g" \
			| sed -e "s|/$||g" \
			| sort \
			| uniq)
	)
	export OVERLAY_PATHS="${_overlay_paths[@]}"
}

get_cat_p() {
	local tarball_path="${@}"
	local a=$(basename "${tarball_path}")
	local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
	echo ${A_TO_P[${hc}]}
}

has_single_dh() {
	local len=$(echo "${@}" | grep -o "," | wc -l)
	[[ -z "${len}" ]] && len=0
	(( "${len}" == 1 )) && return 0
	return 1
}

has_expensive_crypto() {
	local A=($(echo "${@}" | sed -e "s|,| |g"))
	local a
	local b
	for a in ${A[@]} ; do
		for b in ${EXPENSIVE_ALGS[@]} ; do
			[[ "${x}" =~ "${a}" ]] && return 0
		done
	done
	return 1
}

# This is very expensive to do a lookup
gen_tarball_to_p_dict() {
	unset A_TO_P
	declare -Ax A_TO_P
	local cache_path="${DIR_SCRIPT}/a_to_p.cache"
	if [[ -e "${cache_path}" ]] ; then
		local ts=$(stat -c "%W" "${cache_path}")
		local now=$(date +"%s")
		if (( ${ts} + 86400 >= ${now} )) ; then # Expire in 1 day
			echo "Using cached A_TO_P hashmap.  Delete it after emerge --sync."
			eval "$(cat ${cache_path})"
			if ! declare -p A_TO_P 2>&1 > /dev/null ; then
				echo "Failed to init A_TO_P"
				exit 1
			fi
			return
		fi
	fi
	echo "Generating archive to \${CATEGORY}/\${P} hashmap.  Please wait..."
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local path
		for path in $(find "${op}" -type f -name "Manifest") ; do
			echo "Inspecting ${path}"
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			grep -q -e "DIST" "${path}" || continue
			local a=$(grep -e "DIST" "${path}" | cut -f 2 -d " ")
			local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
			A_TO_P[${hc}]="${cat_p}"
		done
	done
	# Pickle it
	declare -p A_TO_P > "${cache_path}"
}

search() {
	gen_overlay_paths
	gen_tarball_to_p_dict
	local asym_algs=(
		25519
		"curve[^0-9]*25519"
		"curve[^0-9]*448"
		dh
		dsa
		"ec(dsa|dh|rdsa)"
		elgamal
	)
	# Entries maybe commented out if too ambiguous to reduce false positives.
	local algs=(
		"(blow|two|three)fish"
		25519
		aes
		aegis
		anubis
		arc4
		argon2
		"blake(|2|2b|2s)"
		camellia
		"cast[^0-9]*(5|6|128|256)"
		"chacha(|8|12|20)"
		"crypt(|o)"
		"curve[^0-9]*25519"
		"curve[^0-9]*448"
		des
		dh
		dsa
		"ec(dh|dsa|rdsa)"
		elgamal
		gf128
		gost
		keccak
		khazad
		"md(4|5)"
		poly1305
		rc6
		rijndael
		ripemd
		"rmd[^0-9]*(128|160|256|320)"
		rsa
		"(|x)salsa(|20)"
		seed
		"sha(1|2|3|256|512)"
		serpent
		"sm(2|3|4)"
		streebog
		"(x|)tea"
		whirlpool
		wp512
		xxhash
	)
	unset cryptlst
	unset asym_cryptlst
	declare -A cryptlst
	declare -A asym_cryptlst
	local algs_s=$(echo "${algs[@]}" | tr " " "|")
	local asym_algs_s=$(echo "${algs[@]}" | tr " " "|")
	local found=()
	local found_asym=()
	local x
	echo -n "" > package.env.t
	for x in $(find "${DISTDIR}" -maxdepth 1 -type f \( -name "*tar.*" -o -name "*.zip" \)) ; do
		echo "S1: Processing ${x}"
		if [[ "${ARCHIVES_SKIP_LARGE}" == "1" ]] \
			&& (( $(stat -c "%s" ${x} ) >= ${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE} )) ; then
			echo "[warn : search crypto] Skipped large tarball for ${x}"
			local cat_p=$(get_cat_p "${x}")
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "# skipped" "# Reason: Large tarball" >> package.env.t
			continue
		fi
		local hc="S"$(echo -n "${x}" | sha1sum | cut -f 1 -d " ")
		local paths
		[[ "${x}" =~ "zip"$ ]] && paths=($(unzip -l "${x}" | sed -r -e "s|[0-9]{2}:[0-9]{2}   |;|g" | grep ";" | cut -f 2 -d ";" 2>/dev/null))
		[[ "${x}" =~ "tar" ]] && paths=($(tar -tf "${x}" 2>/dev/null))
		if echo "${paths[@]}" \
			| grep -i -E -q -e "(${alg_s}).*(\.c|\.cpp|\.cxx|\.h|\.hxx)$"
		then
			found+=("${x}") # tarball path
			local s=""
			for a in ${algs[@]} ; do
				if echo -e "${paths[@]}" \
					| grep -i -q -e "${a}" ; then
					s+="${a}, "
				fi
			done
			s=$(echo "${s}" | sed -e 's|, $||g')
			[[ -n "${s}" ]] && cryptlst[${hc}]="${s}"
		fi
		if echo "${paths[@]}" \
			| grep -i -E -q -e "(${asym_alg_s}).*(\.c|\.cpp|\.cxx|\.h|\.hxx)$"
		then
			found_asym+=("${x}") # tarball path
			local s=""
			for a in ${asym_algs[@]} ; do
				if echo -e "${paths[@]}" \
                        		| grep -i -q -e "${a}" ; then
					s+="${a}, "
				fi
			done
			s=$(echo "${s}" | sed -e 's|, $||g')
			[[ -n "${s}" ]] && asym_cryptlst[${hc}]="${s}"
		fi
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		echo "S2: Processing ${x}"
		local cat_p=$(get_cat_p "${x}")
		local hc="S"$(echo -n "${x}" | sha1sum | cut -f 1 -d " ")
		if (( ${#asym_cryptlst[${hc}]} > 0 )) ; then
			has_single_dh && return
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "${CRYPTO_ASYM_OPT}" "# Contains ${asym_cryptlst[${hc}]} (expensive)" >> package.env.t
		elif (( ${#cryptlst[${hc}]} > 0 )) && has_expensive_crypto "${#cryptlst[${hc}]}" ; then
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "${CRYPTO_EXPENSIVE_OPT}" "# Contains ${cryptlst[${hc}]} (expensive)" >> package.env.t
		elif (( ${#cryptlst[${hc}]} > 0 )) ; then
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "${CRYPTO_CHEAP_OPT}" "# Contains ${cryptlst[${hc}]} (cheap)" >> package.env.t
		fi
	done
}

search
