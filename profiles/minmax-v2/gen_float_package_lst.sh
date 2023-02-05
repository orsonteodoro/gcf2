#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(realpath $(dirname "$0"))

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-0}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
CACHE_DURATION="${CACHE_DURATION:-86400}"
DISTDIR=${DISTDIR:-"${EROOT}/var/cache/distfiles"}
DOUBLE_TO_SINGLE_CONST_MODE="${DOUBLE_TO_SINGLE_CONST_MODE:-catpn}" # \
# Valid values:
#	any
#	catpn (apply to select packages typically to artistic packages, can be customized) ; catpn = ${CATEGORY}/${PN}
#	none
export DOUBLE_TO_SINGLE_SAFER="${DOUBLE_TO_SINGLE_SAFER:-1}" # \
# Valid values: 0 or 1
# Only allow if all implicit decimal literals fit and are within overflow/underflow limits of a single float.
export DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT="${DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT:-2}" # \
# Vaild values: 1-7 (integer only)
# You can set to n-th root of the magnitude of the exponent.
# Setting to 1 may be dangerous if literal used with pow or fmul.
FMATH_OPT="${FMATH_OPT:-Ofast-mt.conf}"
FMATH_UNSAFE_CFG="${FMATH_UNSAFE_CFG:-no-fast-math.conf}"
LAYMAN_BASEDIR=${LAYMAN_BASEDIR:-"${EROOT}/var/lib/layman"}
OILEDMACHINE_OVERLAY_DIR=${OILEDMACHINE_OVERLAY_DIR:-"${EROOT}/usr/local/oiledmachine-overlay"}
PORTAGE_DIR=${PORTAGE_DIR:-"${EROOT}/usr/portage"} # with ebuilds
PORTAGE_ETC=${PORTAGE_DIR:-"${EROOT}/etc/portage"} # with package.accept_keywords ; can be ${DIR_SCRIPT}
SHORTCUT_D2S="${SHORTCUT_D2S:-1}"
SKIP_GMPFR=${SKIP_GMPFR:-1}
VAR_PATH=${VAR_PATH:-"${EROOT}/var/cache/gen_crypto_package"} # can be $(realpath $(pwd))
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

CX_LIMITED_RANGE_OFF_CFG="disable-cx-limited-range.conf"
ERRNO_ON_CFG="enable-errno-math.conf"
INFINITE_ON_CFG="enable-infinite.conf"
RECIPROCAL_MATH_OFF_CFG="disable-reciprocal-math.conf"
ROUNDING_MATH_ON_CFG="enable-rounding-math.conf"
SIGNALING_NANS_ON_CFG="enable-signaling-nans.conf"
SIGNED_ZEROS_ON_CFG="enable-signed-zeros.conf"
SINGLE_PRECISION_CONST_CFG="enable-single-precision-constant.conf"
TRAPPING_MATH_ON_CFG="enable-trapping-math.conf"
UNSAFE_MATH_OPT_OFF_CFG="disable-unsafe-optimizations.conf"

WHITELISTED_SINGLE_PRECISION_CONST_CAT_PN=(
	"games-[a-zA-Z0-9_-]+/"
	"gui-[a-zA-Z0-9_-]+/"
	"media-[a-zA-Z0-9_-]+/"
	"x11-[a-zA-Z0-9_-]+/"
	"[a-zA-Z0-9-]+/.*screensaver.*"
)
WHITELISTED_SINGLE_PRECISION_CONST_CAT_PN_S=$(echo "${WHITELISTED_SINGLE_PRECISION_CONST_CAT_PN[@]}"  | tr " " "|")

# Place anything using asymmetric encryption or large multiplication
# or serious projects.
BLACKLISTED_SINGLE_PRECISION_CONST=(
	"null/null" # Do not remove
)
BLACKLISTED_SINGLE_PRECISION_CONST_S=$(echo "${BLACKLISTED_SINGLE_PRECISION_CONST[@]}" | tr " " "|")

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

# This function tries to eliminate many non float based contexts (e.g. printing, memory, file access) as possible.
exclude_false_search_matches() {
	local ARG=$(</dev/stdin)
	local extra1
	local extra2
	local exclude_pat
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		extra1="${sp}\(${sp}unsigned${sp}\)${sp}\((${regex_s})\)"
		extra2="${sp}unsigned${sp}"'(?!(float|double))'"${sp}"
		exclude_pat="(?<![a-zA-Z0-9_])+" # disallow cutoff and off_t confusion
	else
		extra1="${sp}\(${sp}unsigned${sp}\)${sp}\((${regex_s})\)"
		extra2=""
		exclude_pat=""
	fi
	local loc=$(echo -n "${ARG}" | cut -f 1-2 -d ":")
	local _code=$(echo -n "${ARG}" | cut -f 3- -d ":")
	local code=$(echo -n "${_code}" \
	| sed -r -e "s|//.*||g" \
		-e "s|^${sp}[*].*||g" \
		-e "s|\"[^\"]+\"||g" \
		-e "s#/[*].*([*]/|$)##g" \
		-e "s#(^|/[*]).*[*]/##g" \
		-e 's|\\".*\\"||g' \
		-e "s|[[:space:]]+$||g" \
	| grep -E -v \
		-e "[0-9]+\.[0-9]+ [a-zA-Z]+" \
		-e "([${_sp}]+[a-zA-Z]+){3}" \
		-e "([ a-zA-Z0-9._-]+[/]){3}" \
		-e "([/][ a-zA-Z0-9._-]+){3}" \
		-e "^${sp}\"" \
		-e "(>>|<<)" \
		-e "\.$" \
		-e "(U|W)?INT(MAX|PTR|8|16|32|64|_)" \
		-e "f(seeko|tello|open|close|seek|tell)" \
		-e "${sp}"'[|&^]'"=${sp}" \
		-e "display_ratio" \
		-e "fgets" \
		-e ":\[" \
		-e "hexdump_data" \
		-e "le48" \
		-e "log_(warn|debug|info)" \
		-e "SWAP_FLAGS" \
		-e "[0-9A-Za-z]+UL${sp}" \
		-e "${sp}[a-z_]*printf" \
		-e "${sp}[a-z_]*str[nl]*(cpy|len|str|dup)[a-z_]*" \
		-e "${sp}stpncpy" \
		-e "${sp}(read|write)_string" \
		-e "${sp}[a-z_]*mem(set|cpy|move|chr|mem)" \
		-e "${sp}[a-z0-9_]*(u)?int32[a-z0-9_]*${sp}\(" \
		-e "${sp}[_]*(u|s)(8|16|32|64|128)" \
		-e "${sp}U(32|64)${sp}" \
		-e "#${sp}(include|endif|pragma)" \
		-e "http" \
	| grep ${grep_arg} -v -e "\[.*(${regex_s})" \
	| grep ${grep_arg} -v \
		-e "${sp}(${sp}const${sp})?${sp}(${sp}unsigned${sp})?${sp}(u)?(bool|char|int|short|short int|long|long int|long long|long long int|${exclude_pat}off|(s)?size|time)(_t)?" \
	| grep ${grep_arg} -v -e "${extra1}" \
	| grep ${grep_arg} -v -e "${extra2}" \
	| grep ${grep_arg} -e "${regex_s}" \
	)
	if [[ -n "${code}" ]] ; then
		echo -n "${loc}:"
		echo -n "${code}"
	fi
}

add_if_d2f_safe() {
	local max_sigfigs=0
	local max_exp=0
	local min_exp=0
	IFS=$'\n'
	local line
	local contexts=""
	regex_s="${sreal}"
	echo -n "" > "${T}/d2s-contexts.txt"
	local found_shortcut=0
	while read -r -d $'\n' line ; do
		local location=$(echo -n "${line}" | cut -f 1-2 -d ":")
		local code=$(echo -n "${line}" | cut -f 3- -d ":")

		found_shortcut=0
		local _line=$(echo -n "${code}" \
			| sed -r -e "s|/[*].*[*]/||g" \
				-e "s|//.*||g" \
				-e "s|^[[:space:]]+[*].*||g" \
				-e "s|^${sp}[*].*||g" \
				-e "s|\"[^\"]+\"||g" \
				-e "s#/[*].*([*]/|$)##g" \
				-e "s#(^|/[*]).*[*]/##g" \
				-e "s|[[:space:]]+$||g" \
				-e 's|\\".*\\"||g' \
		)
		[[ "${_line}" =~ \.[0-9]+\. ]] && continue # Skip semver versions (ex 3.1.2)
		[[ "${_line}" =~ 0x ]] && continue # hex
		[[ "${_line}" =~ ".h>" ]] && continue # header
		[[ "${line}" =~ version ]] && continue

		# Skip sentences in block comments
		echo -n "${_line}" | grep -q -E \
			-e "([${_sp}]+[a-zA-Z]+){3}" && continue

		local val
		for val in $(echo -n "${_line}" | grep ${grep_arg} -o -e "${sreal}") ; do
			# Process raw possibly padded real number
			[[ "${val}" =~ ("float"|"double") ]] && continue
			[[ "${val}" =~ [fFlL]$ ]] && continue
			# Only implicit real numbers passes
			val=$(echo -n "${val}" | grep -o ${grep_arg} -e "${s_imp_double}")
			val=$(echo -n "${val}" | sed -r -e "s|[[:space:]]+||g")

			# The literal is still implied.
			#echo -n "${_line}" | grep -q -E -e "\((double|single)\)${sp}${val}" && continue

			# Complex numbers magnitude are determined by template parameters.
			echo -n "${_line}" | grep -q -E -e "${val}${sp}i" && continue

			[[ -z "${val}" ]] && continue
			local sigfigs
			local exp
			local t_exp=0
			local base_sigfigs
			local base
			if [[ ${val} =~ "e" ]] ; then
				base=${val%e*}
				base_sigfigs="${base}"
				exp=${val#*e}
				[[ -z "${exp}" ]] && exp=0
			else
				base=${val}
				base_sigfigs="${base}"
				exp=0
			fi

			# 2002e10 = 2002 * 10^10
			# 0.01e2 = 0.01 * 10^2
			[[ "${base}" =~ \. ]] || base="${base}."
			local trailing_figs_len=$(echo -n "${base}" | cut -f 2 -d "." | sed -r -e "s|[0]+$||g" | tr "\n" " " | sed -e "s| ||g" | wc -c)
			local leading_figs_len=$(echo -n "${base}" | cut -f 1 -d "." | sed -r -e "s|^[0]+||g" | tr "\n" " " | sed -e "s| ||g" | wc -c)
			local zeros_right=$(echo "${base}" | cut -f 2 -d "." | grep -E -o -e "^[0]+" | tr "\n" " " | sed -e "s| ||g" | wc -c)
			local zeros_left=$(echo "${base}" | cut -f 1 -d "." | grep -E -o -e "[0]+$" | tr "\n" " " | sed -e "s| ||g" | wc -c)
			if [[ "${base}" =~ \. && ( "${leading_figs_len}" == "0" || "${base}" =~ ^[0]+\. ) ]] ; then
				# Test cases:
				# .0123
				# .0123000
				# 0.1234
				# 0.01234
				# 0.01234000
				t_exp=$((-${trailing_figs_len}))
			else
				# Test cases:
				# 1.
				# 101.01
				# 0
				# 1
				# 101
				# 1000
				# 0001000
				if (( ${trailing_figs_len} > 0 )) ; then
					t_exp=$((-${trailing_figs_len}))
				elif (( ${zeros_left} > 0 )) ; then
					t_exp=${zeros_left}
				else
					t_exp=0
				fi
			fi

#			echo "[debug] val: |${val}| base_sigfigs: |${base_sigfigs}| exp: |${exp}| context: ${location}:${code}"
			exp=$((${exp} + ${t_exp}))

			base_sigfigs=$(echo "${base_sigfigs}" | sed -r -e "s|\.||g" -e "s|^[0]+([1-9])|\1|g" -e "s|([1-9])[0]+$|\1|g" -e "s|[+-]||g")
			sigfigs="${#base_sigfigs}"

			(( ${sigfigs} > ${max_sigfigs} )) && max_sigfigs=${sigfigs}
			(( ${exp} < 0 && ${exp} < ${min_exp} )) && min_exp=${exp}
			(( ${exp} > 0 && ${exp} > ${max_exp} )) && max_exp=${exp}
			echo "val: |${val}| base_sigfigs: |${base_sigfigs}| exp: |${exp}| context: ${location}:${code}" >> "${T}/d2s-contexts.txt"

			if [[ "${SHORTCUT_D2S}" == "1" ]] ; then
				if (( ${max_sigfigs} >= 1 && ${max_sigfigs} <= ${MAX_SIGFIGS} \
					&& ( ${min_exp} >= ${MIN_EXP} && ${max_exp} <= ${MAX_EXP} ) )) ; then
					:;
				else
					found_shortcut=1
					break
				fi
			fi
		done
		[[ "${SHORTCUT_D2S}" == "1" ]] && (( ${found_shortcut} == 1 )) && break
	done < <(cat "${T}/dump.txt" \
		| xargs -0 \
		  grep ${grep_arg} --color=never -n -e "${regex_s}")
	IFS=$' \n\t'
	echo "Max sigfigs:  ${max_sigfigs}"
	echo "Min exp:  ${min_exp}"
	echo "Max exp:  ${max_exp}"
	# FIXME: add conditional to check max and min significand (9xe38 should not pass)
	if (( ${max_sigfigs} >= 0 && ${max_sigfigs} <= ${MAX_SIGFIGS} \
		&& ( ${min_exp} >= ${MIN_EXP} && ${max_exp} <= ${MAX_EXP} ) )) ; then
		add_d2sc "Found safer implied double const in ${cat_pn}"
		cat "${T}/d2s-contexts.txt"
	fi
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
	echo -n "" > "${T}/package.env.t"

	local _sp="[:space:]"
	local sp="[${_sp}]*"
	local op
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		op="("'(?<!-)'"[>]|[<=()*/+])" # Don't match % which implies int context
	else
		op="[<>=()*/+-]" # Don't match % which implies int context
	fi
	local s="(${op})" # Separators
	local fcast="${sp}\((float|double)\)${sp}"

	# Spaced operators
	local smul="${sp}[*]${sp}"
	local sdiv="${sp}[/]${sp}"
	local sadd="${sp}[+]${sp}"
	local splus="${sp}[+]${sp}"
	local ssub
	local ssign
	local _ssign
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		ssub="${sp}[-]"'(?!>)'"${sp}"
		_ssign="([+]|[-]"'(?!>))'
		ssign="${sp}${_ssign}${sp}"
	else
		ssub="${sp}[-]${sp}"
		ssign="${sp}[+-]${sp}"
	fi
	local sneg="${ssub}"
	local seq="${sp}==${sp}"
	local sneq="${sp}!=${sp}"
	local sfloat="${sp}\(float\)${sp}"
	local sdouble="${sp}\(double\)${sp}"

	# Spaced operands
	local v
	local C
	local fz
	local f1
	local grep_arg
	local imp_double
	local s_imp_double
	local si="${sp}([0-9]*i|[0-9][.0-9]*[fFlL]?if)"
	local lparen
	local real
	local sreal
	# TODO: fix sizeof() confused with variable names
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		# The regex exclude for 1.0i used for *real*, *imp_double*, fz, f1 may not work properly.
		real="${sp}([0-9][.0-9]*e${_ssign}*[0-9]+[fFlL]?|[0-9]+\.[0-9]+[fFlL]?(?!i))${sp}" # ex. 0.0
		sreal="${sp}${real}${sp}" # ex. 0.0
		imp_double="([0-9][.0-9]*e${_ssign}*[0-9]+"'(?![fFlL])'"|[0-9]+\.[0-9]+"'(?![fFlLi])'")" # ex. 0.0
		s_imp_double="${sp}${imp_double}${sp}" # ex. 0.0
		fz="${sp}(0[.0]*"'(?![1-9]+)'"e${_ssign}*[0]+"'(?![1-9]+)'"[fFlL]?|0\.[0]+"'(?![1-9]+)'"[fFlL]?(?!i))${sp}" # ex. 0.0
		f1="${sp}(1[.0]*"'(?![1-9]+)'"e${_ssign}*[0]+"'(?![1-9]+)'"[fFlL]?|1\.[0]+"'(?![1-9]+)'"[fFlL]?(?!i))${sp}" # ex. 1.0
		v="${sp}[_]*[a-z][a-zA-Z0-9_]*${sp}"'(?![(])+'"${sp}" # Variables
		C="${sp}"'(?<![a-z])*'"[_]*[A-Z][A-Z0-9_]*${sp}"'(?![a-z(])+'"${sp}"'(?!\()' # Constants
		grep_arg="-P"
		lparen='(?<![A-Za-z_])\('
	else
		real="${sp}([0-9][.0-9]*e${_ssign}*[0-9]+[fFlL]?|[0-9]+\.[0-9]+[fFlL]?)${sp}" # ex. 0.0
		sreal="${sp}${real}${sp}" # ex. 0.0
		imp_double="([0-9][.0-9]*e${_ssign}*[0-9]+|[0-9]+\.[0-9]+)" # Is this too lax or allow only if have perl regex?
		s_imp_double="${sp}${imp_double}${sp}" # ex. 0.0
		fz="${sp}(0[.0]*e${_ssign}*[0]+[fFlL]?|0\.[0]+[fFlL]?)${sp}"
		f1="${sp}(1[.0]*e${_ssign}*[0]+[fFlL]?|1\.[0]+[fFlL]?)${sp}"
		v="${sp}[_]*[a-z][a-zA-Z0-9_]*${sp}"
		C="${sp}[_]*[A-Z][A-Z0-9_]*${sp}"
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

		"(${op}|[${_sp}]|:)infinity${sp}\("
	)

	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		infinite+=(
			"${s}"'(?<!define)'"${sp}NAN${s}"
			"${s}"'(?<!define)'"${sp}INFINITY${s}"
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
		"${ssign}${v}${sneg}${fz}${s}"
		"${fcast}${ssign}${v}${sneg}${fz}"

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

	local reciprocal_math
	if [[ "${GREP_HAS_PCRE}" == "1" ]] ; then
		reciprocal_math=(
			# This is a maybe if the reciprocal can be eliminated.
			"${s}${v}${sdiv}${v}${s}"

			# Only if C is odd
#			"${s}${v}${sdiv}${C}${s}"
		)
	else
		reciprocal_math=(
			# This is a maybe if the reciprocal can be eliminated.
			"${s}${v}${sdiv}${v}${s}"

			# Only if C is odd
#			"${s}${v}${sdiv}${C}${s}"
		)
	fi
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

	# TODO: handle/review signs [+-]?${real}
	local t0="\(${sreal}[*]${sreal}${sadd}${si}*${si}\)"
	local cx_limited_range=(
		"${lparen}\(${sp}\(${sreal}${smul}${sreal}${sadd}${si}${smul}${si}\)${sdiv}${t0}\)${sadd}${si}\(${sp}\(${si}${smul}${sreal}${ssub}${sreal}[*]${si}\)${sdiv}${t0}\)"
	)
	local cx_limited_range_s=$(echo "${cx_limited_range[@]}" | tr " " "|")

	local wl_d2sc_s
	if [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" == "none" ]] ; then
		wl_d2sc_s=""
	elif [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" == "any" ]] ; then
		wl_d2sc_s=""
	elif [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" == "catpn" ]] ; then
		wl_d2sc_s="${WHITELISTED_SINGLE_PRECISION_CONST_CAT_PN_S}"
	else
echo
echo "DOUBLE_TO_SINGLE_CONST_MODE is not set properly"
echo "Valid values:  none, any, d2s, d2f, catpn"
echo
		exit 1
	fi

	unset fprop # Package float properities
	declare -A fprop

	print_fast_math_context() {
		IFS=$'\n'
		local line
		while read -r -d $'\n' line ; do
			echo -n "${line}" \
				| exclude_false_search_matches \
				| grep ${grep_arg} --color=always -n -e "(${regex_s})"
		done < <(cat "${T}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})")
		IFS=$' \n\t'
	}

	count_regex_lines_fast() {
		cat "${T}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| wc -l
	}

	count_regex_lines_excluded() {
		local count=0
		IFS=$'\n'
		local line
		while read -r -d $'\n' line ; do
			[[ -n "${line}" ]] && count=$(( ${count} + 1 ))
		done < <(cat "${T}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| exclude_false_search_matches \
			| cut -f 3 -d ":")
		IFS=$' \n\t'
		echo -n "${count}"
	}

	count_regex_lines_excluded_d2sc() {
		local count=0
		IFS=$'\n'
		local line
		while read -r -d $'\n' line ; do
			[[ -n "${line}" ]] && count=$(( ${count} + 1 ))
		done < <(cat "${T}/dump.txt" \
			| xargs -0 \
			  grep ${grep_arg} --color=never -n -e "(${regex_s})" \
			| cut -f 3 -d ":")
		IFS=$' \n\t'
		echo -n "${count}"
	}

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
echo "Context (fast-math):"
echo
		print_fast_math_context
echo
	}

	add_d2sc() {
		echo "Found implied double const to single optimization opportunity for ${cat_pn}"
		[[ "${fprop[${cat_pn}]}" =~ "${SINGLE_PRECISION_CONST_CFG}" ]] \
			|| fprop["${cat_pn}"]+=" ${SINGLE_PRECISION_CONST_CFG}"
	}

	local MIN_EXP="-"$(python -c "import math; print(math.floor(pow(10,(1/${DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT})*(math.log(37)/math.log(10)))))" | tr "\n" " " | sed -e "s| ||g") # 37 same as FLT_MIN_10_EXP
	local MAX_EXP=$(python -c "import math; print(math.ceil(pow(10,(1/${DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT})*(math.log(38)/math.log(10)))))" | tr "\n" " " | sed -e "s| ||g") # 38 same as FLT_MAX_10_EXP
	local MAX_SIGFIGS="7"

	echo "MIN_EXP=${MIN_EXP}"
	echo "MAX_EXP=${MAX_EXP}"

	for x in $(find "${DISTDIR}" -maxdepth 1 -type f \( -name "*tar.*" -o -name "*.zip" \)) ; do
		[[ "${x}" =~ "__download__" ]] && continue
		[[ "${x}" =~ ".portage_lockfile" ]] && continue
		local cat_pn=$(get_cat_pn "${x}")
		[[ -z "${cat_pn}" ]] && continue # Likely a removed ebuild
		is_pkg_skippable && continue

		if [[ "${ARCHIVES_SKIP_LARGE}" == "1" ]] \
			&& (( $(stat -c "%s" ${x} ) >= ${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE} )) ; then
			echo "[warn : search float] Skipped large tarball for ${x}"
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "# skipped" "# Reason: Large tarball" >> "${T}/package.env.t"
			continue
			exit 1
		fi
		echo "Processing ${x}"
		if [[ "${x}" =~ "zip"$ ]] ; then
			rm -rf "${T}/sandbox"
			mkdir -p "${T}/sandbox"
			unzip "${x}" -d "${T}/sandbox" 1>/dev/null
		fi
		if [[ "${x}" =~ "tar" ]] ; then
			rm -rf "${T}/sandbox"
			mkdir -p "${T}/sandbox"
			tar -C "${T}/sandbox" -xf "${x}" 1>/dev/null
		fi

		local targets=()
		find "${T}/sandbox" \
			-type f \
			-regextype 'posix-extended' \
			-regex ".*(\.c|\.cc|\.cpp|\.cxx|\.C|\.c\+\+|\.h|\.hh|\.hpp|\.hxx|\.H|\.h\+\+)$" \
			-print0 > "${T}/dump.txt"
		[[ -e "${T}/dump.txt" ]] || continue
		(( $(wc -c "${T}/dump.txt" | cut -f 1 -d " ") == 0 )) && continue
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
		nlines=$(count_regex_lines_fast)
		if (( ${nlines} > 0 )) ; then
			found+=( "${x}" )
			echo "Found float in ${x}"
			# This just tells it exist in the package but...
		else
			continue
		fi

		# ...we now need to inspect every file for floats and delete lines that don't have em.

		echo -n > "${T}/dump2.txt" || exit 1
		IFS=
		local p
		local line
		while read -r -d $'' p ; do
			if grep -q ${grep_arg} -e "(${regex_s})" "${p}" ; then
				echo -e -n "${p}\0" >> "${T}/dump2.txt" || exit 1
			fi
		done < <(cat "${T}/dump.txt")
		IFS=$' \n\t'
		mv "${T}/dump2.txt" "${T}/dump.txt" || exit 1

		local size=$(stat -c "%s" "${T}/dump.txt")
		size=$((${size} - 1))
		(( ${size} < 0 )) && size=0
		truncate -s ${size} "${T}/dump.txt" || exit 1

		regex_s="${errno_fns_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-errno-math"
			solution="-ferrno-math"
			regex_s="${errno_fns_s}"
			[[ "${fprop[${cat_pn}]}" =~ "${ERRNO_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${ERRNO_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${infinite_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-ffinite-math-only"
			solution="-fno-finite-math-only"
			[[ "${fprop[${cat_pn}]}" =~ "${INFINITE_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${INFINITE_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${rounding_math_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-rounding-math"
			solution="-frounding-math"
			[[ "${fprop[${cat_pn}]}" =~ "${ROUNDING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${ROUNDING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${signaling_nans_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-signaling-nans"
			solution="-fsignaling-nans"
			[[ "${fprop[${cat_pn}]}" =~ "${SIGNALING_NANS_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${SIGNALING_NANS_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${signed_zeros_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-signed-zeros"
			solution="-fsigned-zeros"
			[[ "${fprop[${cat_pn}]}" =~ "${SIGNED_ZEROS_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${SIGNED_ZEROS_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${trapping_math_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fno-trapping-math"
			solution="-ftrapping-math"
			[[ "${fprop[${cat_pn}]}" =~ "${TRAPPING_MATH_ON_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${TRAPPING_MATH_ON_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${unsafe_math_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-funsafe-math-optimizations"
			solution="-fno-unsafe-math-optimizations"
			[[ "${fprop[${cat_pn}]}" =~ "${UNSAFE_MATH_OPT_OFF_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${UNSAFE_MATH_OPT_OFF_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${cx_limited_range_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-fcx-limited-range"
			solution="-fno-cx-limited-range"
			[[ "${fprop[${cat_pn}]}" =~ "${CX_LIMITED_RANGE_OFF_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${CX_LIMITED_RANGE_OFF_CFG}"
			msg_fast_math_violation
		fi

		# Regex modified for grep --never because ambiguity with path
		regex_s="${reciprocal_math_s}"
		nlines=$(count_regex_lines_excluded)
		if (( ${nlines} > 0 )) ; then
			assumed_violation="-freciprocal-math"
			solution="-fno-reciprocal-math"
			[[ "${fprop[${cat_pn}]}" =~ "${RECIPROCAL_MATH_OFF_CFG}" ]] \
				|| fprop["${cat_pn}"]+=" ${RECIPROCAL_MATH_OFF_CFG}"
			msg_fast_math_violation
		fi

		regex_s="${s_imp_double}" # Sample if it exists
		local nlines=$(count_regex_lines_excluded_d2sc)
		if [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" != "none" ]] && ( echo "${cat_pn}" | grep -q -E -e "(${BLACKLISTED_SINGLE_PRECISION_CONST_S})" ) ; then
			echo "Skipped -fsingle-precision-constant for blacklisted ${cat_pn}"
		elif [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" =~ ("any") ]] && (( ${nlines} > 0 )) ; then
			if [[ "${DOUBLE_TO_SINGLE_SAFER}" == "1" ]] ; then
				add_if_d2f_safe
			else
				add_d2sc
			fi
		elif [[ "${DOUBLE_TO_SINGLE_CONST_MODE}" =~ ("catpn") ]] && (( ${nlines} > 0 )) ; then
			if [[ -n "${wl_d2sc_s}" ]] && ( echo "${cat_pn}" | grep -q -E -e "(${wl_d2sc_s})" ) ; then
				if [[ "${DOUBLE_TO_SINGLE_SAFER}" == "1" ]] ; then
					add_if_d2f_safe
				else
					add_d2sc
				fi
			fi
		fi
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		local cat_pn=$(get_cat_pn "${x}")
		[[ -z "${cat_pn}" ]] && continue # Likely a removed ebuild
		printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${FMATH_OPT} ${fprop[${cat_pn}]}" >> "${T}/package.env.t"
	done
}

search
