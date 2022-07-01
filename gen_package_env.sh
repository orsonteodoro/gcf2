#!/bin/bash

# Notes:
#*_OPT acceptable values O1.conf, O1.conf, O2.conf, O3.conf, O4.conf, Oz.conf, Os.conf, Ofast.conf Ofast-mt.conf
# You may add additional settings as follows FMATH_OPT="march-native.conf O1.conf ffast-math.conf"

# TODO: make gen_float_math_list respect previous generators selection
# TODO: fix gen_crypto_package_lst.sh confusing paths with division

SCRIPT_NAME=$(basename "$0")
DIR_SCRIPT=$(realpath $(dirname "$0"))
ARGV="${@}"

export ASM_OPT="O3.conf"
export ARCHIVES_AUTOFETCH=${ARCHIVES_AUTOFETCH:-1} # Also called tarballs
export ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-0}
export ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
export BACKUP_PACKAGE_ENV=${BACKUP_PACKAGE_ENV:-1}
export CACHE_DURATION="${CACHE_DURATION:-86400}"
export CCACHE_CFG="${CCACHE_CFG:-ccache.conf}"
export CCACHE_LARGE_PACKAGES="1" # Cutoff is the same as >= HEAVY_LOC_SIZE
export CCACHE_LOC_SIZE=${CCACHE_LOC_SIZE:-6235854} # 6.2M ELOC ; Match the number for >= 1 hr builds
export CODE_TO_TOTAL_RATIO="0.3882814715311033" # Average among small sample.  CODE_TO_TOTAL_RATIO = TOTAL_UNCOMPRESSED_CODE_BYTES / TOTAL_UNCOMPRESSED_ARCHIVE_BYTES
export CRYPTO_ASYM_OPT="${CRYPTO_ASYM_OPT:-Ofast-ts.conf}" # Based on benchmarks, expensive
export CRYPTO_CHEAP_OPT="${CRYPTO_CHEAP_OPT:-O1.conf}"
export CRYPTO_EXPENSIVE_OPT="${CRYPTO_EXPENSIVE_OPT:-O3.conf}"
export DATA_COMPRESSION_RATIO="6.562980063720293" # average among small sample ; DATA_COMPRESSION_RATIO = UNCOMPRESSED_SIZE / COMPRESSED_SIZE
export DOUBLE_TO_SINGLE_CONST_MODE="${DOUBLE_TO_SINGLE_CONST_MODE:-catpn}" # \
# Valid values:
#	any
#	catpn (apply to select packages typically to artistic packages, can be customized) ; catpn = ${CATEGORY}/${PN}
#	none
# See WHITELISTED_SINGLE_PRECISION_CONST_CAT_PN in gen_float_package_lst.sh to set up whitelist.
export DOUBLE_TO_SINGLE_SAFER="${DOUBLE_TO_SINGLE_SAFER:-1}" # \
# Only allow if all literals fit or are within overflow/underflow limits of a single float.
export DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT="${DOUBLE_TO_SINGLE_CONST_EXP_NTH_ROOT:-2}" # \
# Vaild values: 1-7 (integer only)
# You can set to square or cube root of the magnitude of the exponent.
# Setting to 1 may be dangerous if literal used with pow or fmul.
export MAINTENANCE_MODE="1"
export DISTDIR="${DISTDIR:-/var/cache/distfiles}"
export FMATH_OPT="${FMATH_OPT:-Ofast-mt.conf}"
export FMATH_UNSAFE_CFG="${FMATH_UNSAFE_CFG:-no-fast-math.conf}"
export HEAVY_LOC_OPT="O1.conf" # Optimize for build speed instead.  Often it is the data size not the code that is the problem.
export HEAVY_LOC_SIZE=${HEAVY_LOC_SIZE:-10000000} # 10M ELOC ; Match the number for 8 hr builds
export LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
export LINEAR_MATH_OPT="O3.conf"
export LOCB_RATIO="0.030879526993880038" # average of Python and C/C++ ratios of below formula \
#  LOC = Lines Of Code \
#  MLOC = Million Lines Of Code \
#  LOCB_RATIO = LINES_OF_CODE / T_SOURCE_CODE_BYTES \
#  Python LOCB ratio:  0.034346428375619575 \
#  C/C++ LOCB ratio:  0.027412625612140498 \
export OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
export OPENGL_OPT="O3.conf"
export PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}" # with ebuilds
export PORTAGE_ETC="${PORTAGE_DIR:-/etc/portage}" # with package.accept_keywords ; can be ${DIR_SCRIPT}
export T=$(mktemp -d)
export SIMD_OPT="O3.conf"
export SKIP_INTRO_PAUSE=0
export SSA_SIZE=${SSA_SIZE:-1000000} # 1M ELOC (Estimated Lines Of Code)
export SSA_OPT="O1.conf"
export VAR_PATH="${VAR_PATH:-/var/cache/gen_crypto_package}" # can be $(realpath $(pwd))
export WOPT=${WOPT:-"20"}
export WPKG=${WPKG:-"50"}

if [[ "${MAINTENANCE_MODE}" == "2" ]] ; then
# Testing only
export ARCHIVES_AUTOFETCH=0
export ARCHIVES_SKIP_LARGE=1
export ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=10000000
export BACKUP_PACKAGE_ENV=0
export CACHE_DURATION="2592000"
export SKIP_INTRO_PAUSE=1
export PORTAGE_ETC="${DIR_SCRIPT}"
fi

show_help() {
echo
echo "${SCRIPT_NAME} [options]"
echo
echo "Options:"
echo
echo "  -h, --help			Shows help"
echo "  -rc, --rebuild-cache		Rebuilds caches"
echo
}

remove_caches() {
	rm -fv "${T}/package.env.t"
	rm -fv "${VAR_PATH}/a_to_p.cache"
}

parse_command_line_args() {
	local argv=(${ARGV})
	for x in ${argv[@]} ; do
		case ${x} in
			--help|-h)
				show_help
				exit 0
				;;
			--rebuild-cache|-rc)
				remove_caches
				;;
		esac
	done
}

# See also gen_overlay_paths

get_path_pkg_idx() {
	local manifest_path="${1}"
	echo $(ls "${manifest_path}" | grep -o -e "/" | wc -l)
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

gen_loc_list() {
	echo "Processing LOC checks (SSA, CCACHE)"
	local path

	echo -n "" > "${T}/package.env.t.loc"
	echo -n "" > "${T}/package.env.t.ssa"
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		for path in $(find "${op}" -type f -name "Manifest") ; do
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			is_pkg_skippable && continue
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			local on=$(basename "${op}")
			echo "LOC:  Processing ${cat_pn}::${on}"
			local filesize=$(grep -e "DIST" "${path}" | cut -f 3 -d " " | sort -n | tail -n 1)
			[[ -z "${filesize}" ]] && continue
			local loc=$(python -c "print(${LOCB_RATIO}*${filesize}*${DATA_COMPRESSION_RATIO}*${CODE_TO_TOTAL_RATIO})" | cut -f 1 -d ".")
			local mloc=$(python -c "print(${LOCB_RATIO}*${filesize}*${DATA_COMPRESSION_RATIO}*${CODE_TO_TOTAL_RATIO}/1000000)")

			if [[ "${CCACHE_LARGE_PACKAGES}" == "1" ]] \
				&& (( ${loc} >= ${CCACHE_LOC_SIZE} )) ; then
				# Only apply to large projects because it may be counter productive in setup or building smaller packages.
				printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${CCACHE_CFG}" "# Archive size: ${filesize} ; Estimated MLOC: ${mloc}" >> "${T}/package.env.t.ccache"
			fi

			if (( ${loc} >= ${HEAVY_LOC_SIZE} )) ; then
				printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${HEAVY_LOC_OPT}" "# Archive size: ${filesize} ; Estimated MLOC: ${mloc}" >> "${T}/package.env.t.loc"
			elif (( ${loc} >= ${SSA_SIZE} )) ; then
				printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_pn}" "${SSA_OPT}" "# Archive size: ${filesize} ; Estimated MLOC: ${mloc}" >> "${T}/package.env.t.ssa"
			fi
		done
	done
}

gen_light_loc_list() {
	echo "Processing light LOC"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Large projects were marked for SSA optimizations" >> "${PORTAGE_ETC}/package.env"
	echo "# (Heavy LOCs deferred in different section below)" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
	cat "${T}/package.env.t.ssa" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_heavy_loc_list() {
	echo "Processing heavy LOC"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Reducing build times for large projects" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
	cat "${T}/package.env.t.loc" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_ccache_list() {
	[[ "${CCACHE_LARGE_PACKAGES}" != "1" ]] && return
	echo "Processing ccache list"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Enabling CCACHE for large projects" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
	cat "${T}/package.env.t.ccache" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_crypto_list() {
	echo "Processing crypto"
	echo
	echo "Generating crypto list.  This may take several minutes.  Please wait..."
	echo

	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Cryptography" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo -n "" > "${T}/package.env.t"
	./gen_crypto_package_lst.sh
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_opengl_list() {
	echo "Processing OGL"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# 3D (games, apps, ...)" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"

	echo -n "" > "${T}/package.env.t"
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local x
		for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "opengl" "${op}" \
			| grep "ebuild")
		do
			local path=$(dirname "${x}/Manifest")
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			is_pkg_skippable && continue
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			[[ "${pn}" =~ "-bin"$ ]] && continue
			[[ "${cat_pn}" =~ "virtual/" ]] && continue
			local on=$(basename "${op}")
			echo "OGL:  Processing ${cat_pn}::${on}"
			printf "%-${WPKG}s%-${WOPT}s\n" "${cat_pn}" "${OPENGL_OPT}" >> "${T}/package.env.t"
		done
	done
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_simd_list() {
	echo "Processing SIMD"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# SIMD (sse, mmx, avx, neon, ...)" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"

	echo -n "" > "${T}/package.env.t"
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local x
		for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "cpu_flags" "${op}" \
			| grep "ebuild")
		do
			local path=$(dirname "${x}/Manifest")
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			is_pkg_skippable && continue
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			[[ "${pn}" =~ "-bin"$ ]] && continue
			[[ "${cat_pn}" =~ "virtual/" ]] && continue
			local on=$(basename "${op}")
			echo "SIMD:  Processing ${cat_pn}::${on}"
			printf "%-${WPKG}s%-${WOPT}s\n" "${cat_pn}" "${SIMD_OPT}" >> "${T}/package.env.t"
		done
	done
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_asm_list() {
	echo "Processing ASM"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# ASM code but may contain the high level readable version" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"

	echo -n "" > "${T}/package.env.t"
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local x
		for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "(yasm|nasm|( |\")asm)" "${op}" \
			| grep "ebuild")
		do
			local path=$(dirname "${x}/Manifest")
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			is_pkg_skippable && continue
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			[[ "${pn}" =~ "-bin"$ ]] && continue
			[[ "${cat_pn}" =~ "virtual/" ]] && continue
			local on=$(basename "${op}")
			echo "ASM:  Processing ${cat_pn}::${on}"
			printf "%-${WPKG}s%-${WOPT}s\n" "${cat_pn}" "${ASM_OPT}" >> "${T}/package.env.t"
		done
	done
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

get_cat_pn() {
	local tarball_path="${@}"
	local a=$(basename "${tarball_path}")
	local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
	echo ${A_TO_P[${hc}]}
}

gen_float_math_list() {
	echo "Processing FMATH"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Floating point math packages" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo -n "" > "${T}/package.env.t"
	./gen_float_package_lst.sh
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

gen_linear_math_list() {
	echo "Processing LMATH"
	echo "" >> "${PORTAGE_ETC}/package.env"
	echo "# Linear math packages" >> "${PORTAGE_ETC}/package.env"
	echo "# Autogenerated list" >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"

	echo -n "" > "${T}/package.env.t"
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local x
		for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r \
			-e "linear.*solver" \
			-e "((sci-libs|virtual)/(lapack|openblas|mkl-rt|blis)|eigen)" \
			"${PORTAGE_DIR}/"* \
			| grep "ebuild")
		do
			local path=$(dirname "${x}/Manifest")
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_pn=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			is_pkg_skippable && continue
			local on=$(basename "${op}")
			echo "LMATH:  Processing ${cat_pn}::${on}"
			printf "%-${WPKG}s%-${WOPT}s\n" "${cat_pn}" "${LINEAR_MATH_OPT}" >> "${T}/package.env.t"
		done
	done
	cat "${T}/package.env.t" | sort | uniq >> "${PORTAGE_ETC}/package.env"
	echo "" >> "${PORTAGE_ETC}/package.env"
}

archives_autofetch() {
	if [[ "${ARCHIVES_AUTOFETCH}" == "1" ]] ; then
		echo "Autofetching archives"
		emerge -fve world
	fi
}

header() {
	echo "ASM_OPT=${ASM_OPT}"
	echo "ARCHIVES_AUTOFETCH=${ARCHIVES_AUTOFETCH}"
	echo "ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE}"
	echo "ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE}"
	echo "BACKUP_PACKAGE_ENV=${BACKUP_PACKAGE_ENV}"
	echo "CACHE_DURATION=${CACHE_DURATION}"
	echo "CCACHE_CFG=${CCACHE_CFG}"
	echo "CCACHE_LARGE_PACKAGES=${CCACHE_LARGE_PACKAGES}"
	echo "CRYPTO_CHEAP_OPT=${CRYPTO_CHEAP_OPT}"
	echo "CRYPTO_EXPENSIVE_OPT=${CRYPTO_EXPENSIVE_OPT}"
	echo "CRYPTO_ASYM_OPT=${CRYPTO_ASYM_OPT}"
	echo "DOUBLE_TO_SINGLE_CONST_MODE=${DOUBLE_TO_SINGLE_CONST_MODE}"
	echo "DISTDIR=${DISTDIR}"
	echo "FMATH_OPT=${FMATH_OPT}"
	echo "FMATH_UNSAFE_CFG=${FMATH_UNSAFE_CFG}"
	echo "HEAVY_LOC_OPT=${HEAVY_LOC_OPT}"
	echo "HEAVY_LOC_SIZE=${HEAVY_LOC_SIZE}"
	echo "LAYMAN_BASEDIR=${LAYMAN_BASEDIR}"
	echo "LINEAR_MATH_OPT=${LINEAR_MATH_OPT}"
	echo "OILEDMACHINE_OVERLAY_DIR=${OILEDMACHINE_OVERLAY_DIR}"
	echo "OPENGL_OPT=${OPENGL_OPT}"
	echo "PORTAGE_DIR=${PORTAGE_DIR}"
	echo "PORTAGE_ETC=${PORTAGE_ETC}"
	echo "SIMD_OPT=${SIMD_OPT}"
	echo "SSA_SIZE=${SSA_SIZE}"
	echo "SSA_OPT=${SSA_OPT}"
	echo "T=${T}"
	echo "VAR_PATH=${VAR_PATH}"

	[[ ! -d "${DISTDIR}" ]] && echo "Missing ${DISTDIR}.  Change DISTDIR in ${SCRIPT_NAME}"

	if [[ "${SKIP_INTRO_PAUSE}" != "1" ]] ; then
		echo
		echo "Edit global settings inside ${SCRIPT_NAME} now by pressing CTRL+C"
		echo "Continuing in 15 secs."
		echo
		sleep 15
	fi
}

gen_package_env() {
	echo
	echo "Generating package.env"
	echo

	if [[ -e "${PORTAGE_ETC}/package.env" && "${BACKUP_PACKAGE_ENV}" == "1" ]] ; then
		mv "${PORTAGE_ETC}/package.env" "${PORTAGE_ETC}/package-$(date +%s).env.bak"
	else
		rm "${PORTAGE_ETC}/package.env"
	fi
	touch "${PORTAGE_ETC}/package.env"

	cat package_env-header.txt >> "${PORTAGE_ETC}/package.env"

	gen_loc_list
	gen_light_loc_list
	gen_linear_math_list
	gen_opengl_list
	gen_asm_list
	gen_simd_list
	gen_crypto_list
	gen_heavy_loc_list
	gen_float_math_list
	gen_ccache_list

	cat fixes.lst >> "${PORTAGE_ETC}/package.env"
	cat static-opts.lst >> "${PORTAGE_ETC}/package.env"
	cat build-control.lst >> "${PORTAGE_ETC}/package.env"
	cat cfi.lst >> "${PORTAGE_ETC}/package.env"
	cat makeopts.lst >> "${PORTAGE_ETC}/package.env"
	cat testing.lst >> "${PORTAGE_ETC}/package.env"

	sed -i -r -e "s|[[:space:]]+$||g" "${PORTAGE_ETC}/package.env"
}

footer() {
echo "All work completed!"

echo
echo "NOTES:"
echo
echo "The crypto list needs to be manually edited."
echo
echo "The ffast-math with enabled flags list needs to be manually inspected and"
echo "edited.  Review the logs to see if the optimizations are safe."
echo
}

setup() {
	parse_command_line_args
	trap cleanups INT
	trap cleanups SIGTERM
	trap cleanups EXIT

	if echo -e "hello1\nhello2" | grep -q -P 'hello(?=1)' ; then
		export GREP_HAS_PCRE=1
	else
echo
echo "[warn] Using grep without pcre USE flag.  Expect more false positives."
echo
	fi
}

cleanups() {
	echo "cleanup() called"
	rm -rf "${T}"

	# It still loops even though I told it to stop with CTRL+C
	killall -9 gen_package_env
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
	# TODO: permissions?

	# Serialized data
	declare -p A_TO_P > "${cache_path}"
	sed -i -e "s|declare -A |declare -Ag |g" "${cache_path}"
	chmod 0644 "${cache_path}"
}

main()
{
	if [[ "${MAINTENANCE_MODE}" == "1" ]] ; then
		echo "${SCRIPT_NAME} is under construction"
		echo "Do not use yet!"
		return
	fi
	setup
	gen_overlay_paths
	gen_tarball_to_p_dict
	header
	archives_autofetch
	gen_package_env
	footer
}

main
