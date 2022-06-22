#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(dirname "$0")

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-1}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
CACHE_DURATION="${CACHE_DURATION:-86400}"
#CACHE_DURATION="${CACHE_DURATION:-432000}" # Testing only
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
FMATH_OPT="${FMATH_OPT:-Ofast-mt.conf}"
FMATH_UNSAFE_CFG="${FMATH_UNSAFE_CFG:-no-fast-math.conf}"
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}"
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

CX_LIMITED_RANGE_OFF_CFG="disable-cx-limited-range.conf"
ERRNO_ON_CFG="enable-errno-math.conf"
INFINITE_ON_CFG="enable-infinite.conf"
RECIPROCAL_MATH_OFF_CFG="disable-reciprocal-math.conf"
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
	[[ "${cat_p}" =~ "sec-"("keys"|"policy") ]] && return 0
	[[ "${cat_p}" =~ "virtual/" ]] && return 0
	[[ "${cat_p}" =~ "x11-themes" ]] && return 0
	return 1
}

exclude_results() {
	local data=$()
}

# This function tries to eliminate many non float based contexts (e.g. printing, memory, file access) as possible.
exclude_false_search_matches() {
	local ARG=$(</dev/stdin)
	echo -e -n "${ARG}" | grep ${grep_arg} -v -e "\[.*(${regex_s})" \
	| grep ${grep_arg} -v -e "\"[^\"]*(${regex_s})[^\"]*\"" \
	| grep ${grep_arg} -v -e \
"("\
"fgets"\
"|${sp}[a-z_]*printf"\
"|${sp}[a-z_]*str[nl]*(cpy|len|str|dup)[a-z_]*"\
"|${sp}stpncpy"\
"|${sp}(read|write)_string"\
"|${sp}[a-z_]*mem(set|cpy|move|chr|mem)"\
"|${sp}(const)?${sp}(unsigned)?${sp}(u)?(bool|char|int|short|short int|long|long int|long long|long long int|off|(s)?size)(_t)?"\
"|${sp}[a-z0-9_]*(u)?int32[a-z0-9_]*${sp}\("\
"|${sp}[_]*(u|s)(8|16|32|64|128)"\
"|${sp}U(32|64)${sp}"\
")"\
".*(${regex_s})" \
	| grep -v -E -e "#include" \
		-e "http" \
		-e ":${sp}//" \
		-e "and${sp}/${sp}or" \
		-e "/[*]" \
		-e ":${sp}[*]{2}" \
		-e ":${sp}[*]"
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

	gen_overlay_paths
	gen_tarball_to_p_dict
	local found=()
	local x
	echo "Scanning..."
	echo -n "" > package.env.t

	local sp="[[:space:]]*"
	local op="[<>=()*/+-]" # Don't match % which implies int context
	local s="([${op}])" # Separators
	local fcast="${sp}\((float|double)\)${sp}"

	# Spaced operators
	local smul="${sp}[*]${sp}"
	local sdiv="${sp}[/]${sp}"
	local sadd="${sp}[+]${sp}"
	local splus="${sp}[+]${sp}"
	local ssub="${sp}[-]${sp}"
	local sneg="${sp}[-]${sp}"
	local ssign="${sp}[+-]${sp}"
	local seq="${sp}==${sp}"
	local sneq="${sp}!=${sp}"
	local sfloat="${sp}\(float\)${sp}"
	local sdouble="${sp}\(double\)${sp}"

	local v
	local c
	local fz
	local f1
	local grep_arg
	local sreal="${sp}([0-9][.0-9]*e[+-]*[0-9]+[fFlL]?|[0-9]+\.[0-9]+[fFlL]?)${sp}" # ex. 0.0
	local si="${sp}([0-9]*i|[0-9][.0-9]*[fFlL]?if)"
	local lparen
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		fz="${sp}(0[.0]*(?![1-9]+)e[+-]*[0]+(?![1-9]+)[fFlL]?|0\.[0]+(?![1-9]+)[fFlL]?)${sp}" # ex. 0.0
		f1="${sp}(1[.0]*(?![1-9]+)e[+-]*[0]+(?![1-9]+)[fFlL]?|1\.[0]+(?![1-9]+)[fFlL]?)${sp}" # ex. 1.0
		v="${sp}[a-z_][a-z0-9_]*${sp}" # Variables
		v="${sp}[a-z_][a-z0-9_]*${sp}" # Variables
		C="${sp}(?<![a-z])*[A-Z_][A-Z0-9_]*(?![a-z])*${sp}" # Constants
		grep_arg="-P"
		lparen="(?<![A-Za-z_])\("
	else
		fz="${sp}(0[.0]*e[+-]*[0]+[fFlL]?|0\.[0]+[fFlL]?)${sp}"
		f1="${sp}(1[.0]*e[+-]*[0]+[fFlL]?|1\.[0]+[fFlL]?)${sp}"
		v="${sp}[a-z_][a-z0-9_]*${sp}"
		C="${sp}[A-Z_][A-Z0-9_]*${sp}"
		grep_arg="-E"
		lparen="\("
	fi

#		"(\u221E|\\u221E|\u221e|\\u221e)" # Infinity symbol
#		"(\U0000221E|\\U0000221E|\U0000221e|\\U0000221e)" # Infinity symbol
	local infinite=(
		"${s}nan(|l|f)${sp}\("

		# Possible NaN
		"${s}${fz}${sdiv}${v}${s}"
		"${s}${fcast}${fz}${sdiv}${v}${s}"

		"([${op}]|[[:space:]]|:)infinity${sp}\("

	)

	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		infinite+=(
			"${s}(?<!define)${sp}NAN${s}"
			"${s}(?<!define)${sp}INFINITY${s}"
		)
	else
		infinite+=(
			"${s}NAN${s}"
			"${s}INFINITY${s}"
		)
	fi

	local infinite_s=$(echo "${infinite[@]}" | tr " " "|")

	local rounding_math=(
		"${s}fesetround.*(FE_UPWARD|FE_DOWNWARD|FE_TOWARDZERO)"
		"${sneg}\(${v}/${v}\)"
	)
	local rounding_math_s=$(echo "${rounding_math[@]}" | tr " " "|")

	local signaling_nans=(
		"signaling_NaN"
		"${s}${v}${sdiv}${ssign}${f1}${s}"
	)
	local signaling_nans_s=$(echo "${signaling_nans[@]}" | tr " " "|")

	local signed_zeros=(
		"${ssign}${fz}${s}"
		"${fcast}${ssign}${fz}${s}" # from me

		"${ssign}${fz}${ssub}${v}${s}"
		"${fcast}${ssign}${fz}${ssub}${v}${s}" # from me

#		Below are duplicate cases of "${ssign}${fz}${s}" and "${fcast}${ssign}${fz}${s}"
#		"${ssign}${v}${sneg}${fz}${s}"
#		"${fcast}${ssign}${v}${sneg}${fz}"

		# Same as Possible NaN
		"${s}${fz}${sdiv}${v}${s}"
		"${s}${fcast}${fz}${sdiv}${v}${s}"
	)
	local signed_zeros_s=$(echo "${signed_zeros[@]}" | tr " " "|")

	local trapping_math=(
		"${s}signal${sp}\(${sp}SIGFPE${s}"
	)
	local trapping_math_s=$(echo "${trapping_math[@]}" | tr " " "|")

	local errno_fns=(
		"${s}expf${sp}\("
		"${s}exp2f${sp}\("
		"${s}exp10f${sp}\("
		"${s}pow${sp}\("
		"${s}powf${sp}\("
		"${s}sincosf${sp}\("

		# Not required if using sse2?
		"${s}sinf${sp}\("
		"${s}cosf${sp}\("
	)

	local errno_fns_s=$(echo "${errno_fns[@]}" | tr " " "|")

	local reciprocal_math=(
		# This is a maybe if the reciprocal can be eliminated.
		"${s}${v}${sdiv}${v}${s}"

		# Only if C is odd
#		"${s}${v}${sdiv}${C}${s}"
	)
	local reciprocal_math_s=$(echo "${reciprocal_math[@]}" | tr " " "|")

	# Validility of unsafe_math is by context.
	# No contract means preservation of rounding in every float instruction. (Safe always)
	# Contract means simplify means loss of precision. (Unsafe in some contexts)
	# Hints that it is allowed within the project
#	"#pragma[ ]+STDC[ ]+FP_CONTRACT[ ]+ON"
#	"#pragma[ ]+fp_contract[ ]+\(on\)"
#	"-ffp-contract=fast" # default on gcc (c89:off, c99:on, gnu*:on)
#	"-ffp-contract=on"
	local unsafe_math=(
		# The below is not exhaustive but common contractions upstream.
		"${lparen}\(${sfloat}${v}\)${sp}\(${sdouble}${v}\)"
		"${sneg}\(${v}${ssign}${v}\)"
		"${s}${v}${sdiv}${C}${s}"
		"${lparen}\(${v}${smul}${v}\)${sadd}\(${v}${smul}${C}\)"
		"${lparen}\(${v}${sadd}${v}\)${smul}${v}${s}"
		"${s}${v}${smul}\(${v}${sdiv}${v}\)"
		"${s}${v}${smul}\(${v}${smul}${v}\)"
		"${s}${v}${sadd}\(${v}${sadd}${v}\)"
		"${s}${v}${sadd}${C}${seq}${C}${s}"
		"${s}${v}${sadd}${C}${sneq}${C}${s}"
	)
	local unsafe_math_s=$(echo "${unsafe_math[@]}" | tr " " "|")

	local t0="\(${sreal}*${sreal}${sadd}${si}*${si}\)"
	local cx_limited_range=(
		"${lparen}\(${sp}\(${sreal}${smul}${sreal}${sadd}${si}${smul}${si}\)${sdiv}${t0}\)${sadd}${si}\(${sp}\(${si}${smul}${sreal}${ssub}${sreal}*${si}\)${sdiv}${t0}\)"
	)
	local cx_limited_range_s=$(echo "${cx_limited_range[@]}" | tr " " "|")

	unset fprop # Package float properities
	declare -A fprop

	# ecges = start color grep escape sequence
	# ecges = end color grep escape sequence
	local scges=$'\e[01;31m\e[K'
#	local ecges=$'\e[m\e[K'
	local ecges=$'\e[K'
	msg_fast_math_violation() {
echo
echo "Found violation for -ffast-math in ${x} for ${assumed_violation}"
echo "This has been fixed with ${solution}"
echo
echo "Context:"
echo
		cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})"
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
			exit 1
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
		# Not all -ffast-math patterns will be scanned.  -funsafe-math-optimizations
		# must be inspected manually.
		# Reason why is because the properties of the variables is unknown.
		# +0 and -0 requires manual inspection due to false positives if grep is not
		# built with perl regex support.

		local regex_s=""
		local assumed_violation=""
		local solution=""
		local nlines
		local pat

		regex_s="float|double"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			found+=( "${x}" )
			echo "Found float in ${x}"
		else
			continue
		fi
		unset regex_s

		regex_s="${errno_fns_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-errno-math"
			solution="-ferrno-math"
			regex_s="${errno_fns_s}"
			[[ "${fprop[${cat_p}]}" =~ "${ERRNO_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${ERRNO_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${infinite_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-ffinite-math-only"
			solution="-fno-finite-math-only"
			[[ "${fprop[${cat_p}]}" =~ "${INFINITE_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${INFINITE_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${rounding_math_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-rounding-math"
			solution="-frounding-math"
			[[ "${fprop[${cat_p}]}" =~ "${ROUNDING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${ROUNDING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${signaling_nans_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-signaling-nans"
			solution="-fsignaling-nans"
			[[ "${fprop[${cat_p}]}" =~ "${SIGNALING_NANS_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${SIGNALING_NANS_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${signed_zeros_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-signed-zeros"
			solution="-fsigned-zeros"
			[[ "${fprop[${cat_p}]}" =~ "${SIGNED_ZEROS_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${SIGNED_ZEROS_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${trapping_math_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-trapping-math"
			solution="-ftrapping-math"
			[[ "${fprop[${cat_p}]}" =~ "${TRAPPING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${TRAPPING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${unsafe_math_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-funsafe-math-optimizations"
			solution="-fno-unsafe-math-optimizations"
			[[ "${fprop[${cat_p}]}" =~ "${UNSAFE_MATH_OPT_OFF_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${UNSAFE_MATH_OPT_OFF_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${cx_limited_range_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fcx-limited-range"
			solution="-fno-cx-limited-range"
			[[ "${fprop[${cat_p}]}" =~ "${CX_LIMITED_RANGE_OFF_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${CX_LIMITED_RANGE_OFF_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s

		regex_s="${reciprocal_math_s}"
		nlines=$(cat "${DIR_SCRIPT}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| grep ${grep_arg} --color=always -n -e "(${regex_s})" \
			| wc -l)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-freciprocal-math"
			solution="-fno-reciprocal-math"
			[[ "${fprop[${cat_p}]}" =~ "${RECIPROCAL_MATH_OFF_CFG}" ]] \
				|| fprop["${cat_p}"]+=" ${RECIPROCAL_MATH_OFF_CFG}"
			msg_fast_math_violation
		fi
		unset regex_s
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		local cat_p=$(get_cat_p "${x}")
		[[ -z "${cat_p}" ]] && continue # Likely a removed ebuild
		printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "${FMATH_OPT} ${fprop[${cat_p}]}" >> package.env.t
	done
}

search
