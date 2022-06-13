#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(dirname "$0")

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-1}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
FMATH_OPT="${FMATH_OPT:-Ofast-mt.conf}"
FMATH_UNSAFE_CFG="${FMATH_UNSAFE_CFG:-no-fast-math.conf}"
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}"
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

ERRNO_ON_CFG="enable-errno-math.conf"
INFINITE_ON_CFG="enable-infinite.conf"
ROUNDING_MATH_ON_CFG="enable-rounding-math.conf"
SIGNALING_NANS_ON_CFG="enable-signaling-nans.conf"
SIGNED_ZEROS_ON_CFG="enable-signed-zeros.conf"
TRAPPING_MATH_ON_CFG="enable-trapping-math.conf"
UNSAFE_MATH_OPT_OFF_CFG="disable-unsafe-optimizations.conf"

# Low priority TODO: -fsingle-precision-constant optimization

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

# This is very expensive to do a lookup
gen_tarball_to_p_dict() {
	unset A_TO_P
	declare -Ag A_TO_P
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
			local line
			for line in $(grep -e "DIST" "${path}") ; do
				local a=$(echo "${line}" | cut -f 2 -d " ")
				local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
				A_TO_P[${hc}]="${cat_p}"
			done
		done
	done
	# Serialized data
	declare -p A_TO_P > "${cache_path}"
	sed -i -e "s|declare -A |declare -Ag |g" "${cache_path}"
}

is_pkg_skippable() {
	[[ "${cat_p}" =~ "-bin"$ ]] && return 0
	[[ "${cat_p}" =~ "-data"$ ]] && return 0
	[[ "${cat_p}" =~ "acct-"("group"|"user") ]] && return 0
	[[ "${cat_p}" =~ "firmware" ]] && return 0
	[[ "${cat_p}" =~ "media-fonts" ]] && return 0
	[[ "${cat_p}" =~ "virtual/" ]] && return 0
	[[ "${cat_p}" =~ "x11-themes" ]] && return 0
	return 1
}

search() {
	gen_overlay_paths
	gen_tarball_to_p_dict
	local found=()
	local x
	echo "Scanning..."
	echo -n "" > package.env.t

	local op="[\[\]<>=()+\\%-]"
	local m="([${op}]|[\s])"
	local fcast="[\s)]*\((float|double)\)[\s)]*"

	local fz="[(\s]*(0[.0]*e[+-]*[0]+[fFlL]?|0\.[0]+[fFlL]?)[\s)]*"
	local id="[(\s]*[a-zA-Z_][a-zA-Z0-9_]*[)\s]*"

#		"(\u221E|\\u221E|\u221e|\\u221e)" # infinity symbol
#		"(\U0000221E|\\U0000221E|\U0000221e|\\U0000221e)" # infinity symbol
	local infinite=(
		"${m}NAN${m}"
		"${m}nan(|l|f)[\s]*\("

		# Possible NaN
		"${m}${fz}${m}*/${m}*${id}${m}"
		"${m}${fcast}${fz}${m}/${m}*${id}${m}"

		"${m}INFINITY${m}"
		"infinity[\s]*\("

	)
	local infinite_s=$(echo "${infinite[@]}" | tr " " "|")

	local rounding_math=(
		"fesetround.*(FE_UPWARD|FE_DOWNWARD|FE_TOWARDZERO)"
	)
	local rounding_math_s=$(echo "${rounding_math[@]}" | tr " " "|")

	local signaling_nans=(
		"signaling_NaN"
		"${id}/${fz}"
	)
	local signaling_nans_s=$(echo "${signaling_nans[@]}" | tr " " "|")

	local signed_zeros=(
		"[+-]${fz}${m}"
		"${fcast}[+-]${fz}${m}"

		"[+-]${fz}${m}-${id}${m}"
		"${fcast}[+-]${fz}-${id}"

		# Same as Possible NaN
		"${m}${fz}/${id}${m}"
		"${fcast}${fz}/${id}${m}"
	)
	local signed_zeros_s=$(echo "${signed_zeros[@]}" | tr " " "|")

	local trapping_math=(
		"signal.*SIGFPE${m}"
	)
	local trapping_math_s=$(echo "${trapping_math[@]}" | tr " " "|")

	local errno_fns=(
		"${m}expf[\s]*\("
		"${m}exp2f[\s]*\("
		"${m}exp10f[\s]*\("
		"${m}pow[\s]*\("
		"${m}powf[\s]*\("
		"${m}sincosf[\s]*\("

		# Not required if using sse2?
		"${m}sinf[\s]*\("
		"${m}cosf[\s]*\("
	)
	local errno_fns_s=$(echo "${errno_fns[@]}" | tr " " "|")

	unset fprop # Package float properities
	declare -A fprop

	msg_fast_math_violation() {
echo
echo "Found violation for -ffast-math in ${x} for ${assumed_violation}"
echo "This has been fixed with ${solution}"
echo
echo "Context:"
echo
cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep --color=always -P -z -e "(${regex_s})"
echo
	}

	for x in $(find "${DISTDIR}" -maxdepth 1 -type f \( -name "*tar.*" -o -name "*.zip" \)) ; do
		[[ "${x}" =~ "__download__" ]] && continue
		[[ "${x}" =~ ".portage_lockfile" ]] && continue
		local cat_p=$(get_cat_p "${x}")
		is_pkg_skippable && continue
		if [[ "${ARCHIVES_SKIP_LARGE}" == "1" ]] \
			&& (( $(stat -c "%s" ${x} ) >= ${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE} )) ; then
			echo "[warn : search float] Skipped large tarball for ${x}"
			[[ -z "${cat_p}" ]] && continue # Likely a removed ebuild
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "# skipped" "# Reason: Large tarball" >> package.env.t
			continue
		fi
		echo "Processing ${x}"
		if [[ "${x}" =~ "zip"$ ]] ; then
			rm -rf "${DIR_SCRIPT}/sandbox"
			mkdir -p "${DIR_SCRIPT}/sandbox"
			unzip "${x}" -d "${DIR_SCRIPT}/sandbox" 1>/dev/null
		fi
		if [[ "${x}" =~ "tar" ]] ; then
			rm -rf "${DIR_SCRIPT}/sandbox"
			mkdir -p "${DIR_SCRIPT}/sandbox"
			tar -C "${DIR_SCRIPT}/sandbox" -xf "${x}" 1>/dev/null
		fi

		local targets=()
		find "${DIR_SCRIPT}/sandbox" \
			-type f \
			-regextype 'posix-extended' \
			-regex ".*(\.c|\.cc|\.cpp|\.cxx|\.C|\.c\+\+|\.h|\.hh|\.hpp|\.hxx|\.H|\.h\+\+)$" \
			-print0 > "${DIR_SCRIPT}/dump.txt"
		[[ -e "${DIR_SCRIPT}/dump.txt" ]] || continue
		(( $(wc -c "${DIR_SCRIPT}/dump.txt" | cut -f 1 -d " ") == 0 )) && continue
		# Not all -ffast-math patterns will be scanned.  -funsafe-math-optimizations must be inspected manually.
		# Reason why is because the properties of the variables is unknown.
		# +0 and -0 requires manual inspection due to false positives

		local regex_s=""
		local assumed_violation=""
		local solution=""

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(float|double)" ; then
			found+=( "${x}" )
			echo "Found float in ${x}"
		else
			continue
		fi

		if ( cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${errno_fns_s})" ) ; then
			assumed_violation="-fno-errno-math"
			solution="-ferrno-math"
			regex_s="${errno_fns_s}"
			[[ "${fprop[${cat_p}]}" =~ "${ERRNO_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${ERRNO_ON_CFG}"
			msg_fast_math_violation
		fi

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${infinite_s})" ; then
			assumed_violation="-ffinite-math-only"
			solution="-fno-finite-math-only"
			regex_s="${infinite_s}"
			[[ "${fprop[${cat_p}]}" =~ "${INFINITE_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${INFINITE_ON_CFG}"
			msg_fast_math_violation
		fi

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${rounding_math_s})" ; then
			assumed_violation="-fno-rounding-math"
			solution="-frounding-math"
			regex_s="${rounding_math_s}"
			[[ "${fprop[${cat_p}]}" =~ "${ROUNDING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${ROUNDING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${signaling_nans_s})" ; then
			assumed_violation="-fno-signaling-nans"
			solution="-fsignaling-nans"
			regex_s="${signaling_nans_s}"
			[[ "${fprop[${cat_p}]}" =~ "${SIGNALING_NANS_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${SIGNALING_NANS_ON_CFG}"
			msg_fast_math_violation
		fi

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${signed_zeros_s})" ; then
			assumed_violation="-fno-signed-zeros"
			solution="-fsigned-zeros"
			regex_s="${signed_zeros_s}"
			[[ "${fprop[${cat_p}]}" =~ "${SIGNED_ZEROS_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${SIGNED_ZEROS_ON_CFG}"
			msg_fast_math_violation
		fi

		if cat "${DIR_SCRIPT}/dump.txt" | xargs -0 grep -P -z -q -e "(${trapping_math_s})" ; then
			assumed_violation="-fno-trapping-math"
			solution="-ftrapping-math"
			regex_s="${trapping_math_s}"
			[[ "${fprop[${cat_p}]}" =~ "${TRAPPING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_p}"]=" ${TRAPPING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		local cat_p=$(get_cat_p "${x}")
		[[ -z "${cat_p}" ]] && continue # Likely a removed ebuild
		printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "${FMATH_OPT} ${fprop[${cat_p}]}" >> package.env.t
	done
}

search
