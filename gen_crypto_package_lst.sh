#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(realpath $(dirname "$0"))

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-0}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
CACHE_DURATION="${CACHE_DURATION:-86400}"
CRYPTO_CHEAP_OPT="${CRYPTO_CHEAP_OPT:-O1.conf}"
CRYPTO_EXPENSIVE_OPT="${CRYPTO_EXPENSIVE_OPT:-O3.conf}"
CRYPTO_ASYM_OPT="${CRYPTO_ASYM_OPT:-Ofast-ts.conf}" # Based on benchmarks, expensive
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
EXPENSIVE_ALGS=(
	"25519"
	"curve[_-]*(448|25519)"
	"dh"
	"dsa"
	"ec(dsa|dh)"
	"ed[_-]*25519"
	"elgamal"
	"sm[_-]*2"

	# Add your custom list here
	# Maybe you should add the name of the algorithm when keysize > native word size
	#   or
	# number of rounds is very large
)
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}" # with ebuilds
PORTAGE_ETC="${PORTAGE_DIR:-/etc/portage}" # with package.accept_keywords ; can be ${DIR_SCRIPT}
VAR_PATH="${VAR_PATH:-/var/cache/gen_crypto_package}" # can be $(realpath $(pwd))
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

ASYM_ALGS=(
	"25519"
	"curve[_-]*(448|25519)"
	"dh"
	"dsa"
	"ec(dsa|dh|rdsa)"
	"ed[_-]*25519"
	"elgamal"
	"sm[_-]*2"
)
# Entries maybe commented out if too ambiguous to reduce false positives.
# Some regexes need to be decomposed in order for EXPENSIVE_ALGS
# to target a specific variation.
ALL_ALGS=(
	"(blow|two|three)fish"
	"25519"
	"aria"
	"aes"
	"aegis"
	"anubis"
	"arc(4|four)"
	"argon2"
	"bear"
	"blake[_-]*(|2|2b|2s)"
	"camellia"
	"cast[_-]*(5|6|128|256)"
	"chacha[_-]*(|8|12|20)"
	"cipher"
	"crypt(|o)"
	"curve[_-]*(448|25519)"
	"(triple)?[_-]?des"
	"dh"
	"dsa"
	"ec(dh|dsa|rdsa)"
	"ed[_-]*25519"
	"elgamal"
	"gf[_-]*128"
	"gost"
	"idea"
	"kasumi"
	"keccak"
	"khazad"
	"lion"
	"md(2|4|5)"
	"noekeon"
	"poly1305"
	"rc6"
	"rfc2268"
	"rijndael"
	"ripemd[_-]*(160)?"
	"rmd[_-]*(128|160|256|320)"
	"rsa"
	"(|x)salsa(|20)"
	"seed"
	"serpent"
	"sha[_-]*(1|2|3|256|512)"
	"shacal[_-]*[12]?"
	"sm[_-]*2"
	"sm[_-]*(3|4)"
	"shake[_-]*(128|256)"
	"skipjack"
	"streebog"
	"tiger"
	"(x|)tea"
	"whirlpool"
	"wp512"
	"xxhash"
)

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

get_cat_pn() {
	local tarball_path="${@}"
	local a=$(basename "${tarball_path}")
	local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
	echo ${A_TO_P[${hc}]}
}

has_asym_alg() {
	local args="${@}"
	local a
	for a in ${ASYM_ALGS[@]} ; do
		if echo "${args}" | grep -q -F -e "${a}" ; then
			return 0
		fi
	done
	return 1
}

has_expensive_crypto() {
	local args="${@}"
	local a
	for a in ${EXPENSIVE_ALGS[@]} ; do
		if echo "${args}" | grep -q -F -e "${a}" ; then
			return 0
		fi
	done
	return 1
}

# This is very expensive to do a lookup
gen_tarball_to_p_dict() {
	unset A_TO_P
	declare -Ag A_TO_P
	local cache_path="${VAR_PATH}/a_to_p.cache"
	if [[ -e "${cache_path}" ]] ; then
		local ts=$(stat -c "%W" "${cache_path}")
		local now=$(date +"%s")
		if (( ${ts} + ${CACHE_DURATION} >= ${now} )) ; then # Expire in 1 day
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
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			grep -q -e "DIST" "${path}" || continue
			local line
			for line in $(grep -e "DIST" "${path}") ; do
				local a=$(echo "${line}" | cut -f 2 -d " ")
				local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
				A_TO_P[${hc}]="${cat_pn}"
			done
		done
	done

	mkdir -p "${VAR_PATH}"
	chmod 0755 "${VAR_PATH}"

	# Serialized data
	declare -p A_TO_P > "${cache_path}"
	sed -i -e "s|declare -A |declare -Ag |g" "${cache_path}"
	chmod 0644 "${cache_path}"
}

is_pkg_skippable() {
	[[ "${cat_pn}" =~ "-bin"$ ]] && return 0
	[[ "${cat_pn}" =~ "-data"$ ]] && return 0
	[[ "${cat_pn}" =~ "acct-"("group"|"user") ]] && return 0
	[[ "${cat_pn}" =~ "firmware" ]] && return 0
	[[ "${cat_pn}" =~ "media-fonts" ]] && return 0
	[[ "${cat_pn}" =~ "sec-"("keys"|"policy") ]] && return 0
	[[ "${cat_pn}" =~ "virtual/" ]] && return 0
	[[ "${cat_pn}" =~ "x11-themes" ]] && return 0
	return 1
}

search() {
	if [[ -n "${GREP_HAS_PCRE}" ]] ; then
		echo "GREP_HAS_PCRE=${GREP_HAS_PCRE} (from env)"
	elif echo -e "hello1\nhello2" | grep -q -P 'hello(?=1)' ; then
		export GREP_HAS_PCRE=1
	else
echo
echo "[warn] Using grep without pcre USE flag.  Expect more false positives."
echo
	fi

	local grep_args
	local delim
	export ASYM_ALGS_S=$(echo "${ASYM_ALGS[@]}" | tr " " "|")
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		grep_args="-P"
		delim="(?<!random|bench|test)[/_-]"
	else
		grep_args="-E"
		delim="[/_-]"
	fi
	gen_overlay_paths
	gen_tarball_to_p_dict
	unset cryptlst
	unset asym_cryptlst
	declare -A cryptlst
	local algs_s=$(echo "${ALL_ALGS[@]}" | tr " " "|")
	local found=()
	local x
	echo -n "" > "${T}/package.env.t"
	for x in $(find "${DISTDIR}" -maxdepth 1 -type f \( -name "*tar.*" -o -name "*.zip" \)) ; do
		[[ "${x}" =~ "__download__" ]] && continue
		[[ "${x}" =~ ".portage_lockfile" ]] && continue
		local cat_pn=$(get_cat_pn "${x}")
		is_pkg_skippable && continue
		echo "S1: Processing ${x}"
		if [[ "${ARCHIVES_SKIP_LARGE}" == "1" ]] \
			&& (( $(stat -c "%s" ${x} ) >= ${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE} )) ; then
			echo "[warn : search crypto] Skipped large tarball for ${x}"
			[[ -z "${cat_pn}" ]] && continue # Likely a removed ebuild
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "# skipped" "# Reason: Large tarball" >> "${T}/package.env.t"
			continue
		fi
		local a=$(basename "${x}")
		local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
		local paths
		[[ "${x}" =~ "zip"$ ]] && paths=($(unzip -l "${x}" | sed -r -e "s|[0-9]{2}:[0-9]{2}[ ]+|;|g" | grep ";" | cut -f 2 -d ";" 2>/dev/null))
		[[ "${x}" =~ "tar" ]] && paths=($(tar -tf "${x}" 2>/dev/null))
		if echo "${paths[@]}" \
			| grep -q ${grep_args} -i -e "${delim}(${algs_s})(\.c|\.cc|\.cpp|\.cxx|\.C|\.c\+\+|\.h|\.hh|\.hpp|\.hxx|\.H|\.h\+\+)($| |\n)"
		then
			found+=("${x}") # tarball path
			local s=""
			for a in ${ALL_ALGS[@]} ; do
				if echo -e "${paths[@]}" \
					| grep ${grep_args} -q -i -e "${delim}${a}\." ; then
					s+="${a}, "
				fi
			done
			s=$(echo "${s}" | sed -e 's|, $||g')
			[[ -n "${s}" ]] && cryptlst[${hc}]="${s}"
		fi
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		echo "S2: Processing ${x}"
		local cat_pn=$(get_cat_pn "${x}")
		[[ -z "${cat_pn}" ]] && continue # Likely a removed ebuild
		local a=$(basename "${x}")
		local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
		local s="${cryptlst[${hc}]}"
		if (( ${#cryptlst[${hc}]} > 0 )) && has_asym_alg "${s}" ; then
			printf "${mp}%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${CRYPTO_ASYM_OPT}" "# Contains ${cryptlst[${hc}]} (expensive)${mreason}" >> "${T}/package.env.t"
		elif (( ${#cryptlst[${hc}]} > 0 )) && has_expensive_crypto "${s}" ; then
			printf "${mp}%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${CRYPTO_EXPENSIVE_OPT}" "# Contains ${cryptlst[${hc}]} (expensive)${mreason}" >> "${T}/package.env.t"
		elif (( ${#cryptlst[${hc}]} > 0 )) ; then
			printf "${mp}%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${CRYPTO_CHEAP_OPT}" "# Contains ${cryptlst[${hc}]} (cheap)${mreason}" >> "${T}/package.env.t"
		fi
	done
}

search
