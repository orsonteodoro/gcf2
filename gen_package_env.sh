#!/bin/bash

SCRIPT_NAME=$(basename "$0")

ASM_OPT="O3.conf"
AUTOFETCH_TARBALLS=1
CRYPTO_ASYM_OPT_CFG="${CRYPTO_ASYM_OPT_CFG:-Ofast-ts.conf}" # Based on benchmarks, expensive
CRYPTO_CHEAP_OPT_CFG="${CRYPTO_CHEAP_OPT_CFG:-O1.conf}"
CRYPTO_EXPENSIVE_OPT_CFG="${CRYPTO_EXPENSIVE_OPT_CFG:-O3.conf}"
DEVELOPER_MODE="1"
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
LINEAR_MATH_OPT="O3.conf"
MATH_OPT="O3.conf"
OPENGL_OPT="O3.conf"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}"
SIMD_OPT="O3.conf"
SKIP_INTRO_PAUSE=0
SSA_SIZE=${SSA_SIZE:-1000000} # 1M ELOC (Estimated Lines Of Code)
# 19342692
#
SSA_OPT="O1.conf"
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}
# LOC = Lines Of Code
# MLOC = Million Lines Of Code
CODE_PCT="0.3882814715311033" # Average among small sample
DATA_COMPRESSION_RATIO="6.562980063720293" # average among small sample ; DATA_COMPRESSION_RATIO = UNCOMPRESSED_SIZE / COMPRESSED_SIZE
LOCB_RATIO="0.030879526993880038" # average of Python and C/C++ ratios of below formula
# LOCB_RATIO = LINES_OF_CODE / T_SOURCE_CODE_BYTES
# Python LOCB ratio:  0.034346428375619575
# C/C++ LOCB ratio:  0.027412625612140498
LOC_MAXLIMIT_OPT="O1.conf" # Optimize for build speed instead.  Often it is the data size not the code that is the problem.
LOC_MAXLIMIT_SIZE=${LOC_MAXLIMIT_SIZE:-10000000} # 10M ELOC ; Match the number for 8 hr builds
# See also gen_overlay_paths

get_path_pkg_idx() {
	local manifest_path="${1}"
	echo $(ls "${manifest_path}" | grep -o -e "/" | wc -l)
}

gen_ssa_opt_list() {
	echo "" >> package.env
	echo "# Large projects marked for SSA optimizations" >> package.env
	echo "# (LOC list deferred in different section below)" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env
	local path

	echo -n "" > package.env.t.loc
	echo -n "" > package.env.t.ssa
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		for path in $(find "${op}/" -name "Manifest") ; do
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			local filesize=$(grep -r -e "DIST" "${path}" | cut -f 3 -d " " | sort -n | tail -n 1)
			[[ "${pn}" =~ "-bin"$ ]] && continue
			[[ -z "${filesize}" ]] && continue
			local loc=$(python -c "print(${LOCB_RATIO}*${filesize}*${DATA_COMPRESSION_RATIO}*${CODE_PCT})" | cut -f 1 -d ".")
			local mloc=$(python -c "print(${LOCB_RATIO}*${filesize}*${DATA_COMPRESSION_RATIO}*${CODE_PCT}/1000000)")
			if (( ${loc} >= ${LOC_MAXLIMIT_SIZE} )) ; then
				printf "%-${WPKG}s%-${WOPT}s %s\n" "${p}" "${LOC_MAXLIMIT_OPT}" "# Archive size: ${filesize} ; Estimated MLOC: ${mloc}" >> package.env.t.loc
			elif (( ${loc} >= ${SSA_SIZE} )) ; then
				printf "%-${WPKG}s%-${WOPT}s %s\n" "${p}" "${SSA_OPT}" "# Archive size: ${filesize} ; Estimated MLOC: ${mloc}" >> package.env.t.ssa
			fi
		done
	done
	cat package.env.t.ssa | sort | uniq >> package.env
	echo "" >> package.env
}

gen_loc_list() {
	echo "" >> package.env
	echo "# Optimizing large projects for ~2x build speed" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env
	cat package.env.t.loc | sort | uniq >> package.env
	echo "" >> package.env
}

gen_crypto_list() {
	echo
	echo "Generating crypto list.  This may take several minutes.  Please wait..."
	echo

	echo "" >> package.env
	echo "# Cryptography" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env
	bash gen_crypto_package_lst.sh > package.env.t
	cat package.env.t | sort | uniq >> package.env
	echo "" >> package.env
}

gen_opengl_list() {
	echo "" >> package.env
	echo "# 3D {games, apps, ...}" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env

	echo -n "" > package.env.t
	local x
	for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "opengl" "${PORTAGE_DIR}/"* \
		| grep "ebuild")
	do
		local path=$(dirname "${x}/Manifest")
		local idx_pn=$(get_path_pkg_idx "${path}")
		local idx_cat=$(( ${idx_pn} - 1 ))
		local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
		local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
		printf "%-${WPKG}s%-${WOPT}s\n" "${p}" "${OPENGL_OPT}" >> package.env.t
	done
	cat package.env.t | sort | uniq >> package.env
	echo "" >> package.env
}

gen_simd_list() {
	echo "" >> package.env
	echo "# SIMD (sse, mmx, avx, neon, etc)" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env

	echo -n "" > package.env.t
	local x
	for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "cpu_flags" "${PORTAGE_DIR}/"* \
		| grep "ebuild")
	do
		local path=$(dirname "${x}/Manifest")
		local idx_pn=$(get_path_pkg_idx "${path}")
		local idx_cat=$(( ${idx_pn} - 1 ))
		local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
		local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
		printf "%-${WPKG}s%-${WOPT}s\n" "${p}" "${SIMD_OPT}" >> package.env.t
	done
	cat package.env.t | sort | uniq >> package.env
	echo "" >> package.env
}

gen_asm_list() {
	echo "" >> package.env
	echo "# ASM code but may contain the high level readable version" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env

	echo -n "" > package.env.t
	local x
	for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "(yasm|nasm|( |\")asm)" "${PORTAGE_DIR}/"* \
		| grep "ebuild")
	do
		local path=$(dirname "${x}/Manifest")
		local idx_pn=$(get_path_pkg_idx "${path}")
		local idx_cat=$(( ${idx_pn} - 1 ))
		local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
		local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
		printf "%-${WPKG}s%-${WOPT}s\n" "${p}" "${ASM_OPT}" >> package.env.t
	done
	cat package.env.t | sort | uniq >> package.env
	echo "" >> package.env
}

gen_math_list() {
	echo "" >> package.env
	echo "# Math" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env
	:;
	echo "" >> package.env
}

gen_linear_math_list() {
	echo "" >> package.env
	echo "# Linear math" >> package.env
	echo "# Autogenerated list" >> package.env
	echo "" >> package.env

	echo -n "" > package.env.t
	local x
	for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "linear.*solver" "${PORTAGE_DIR}/"* \
		| grep "ebuild")
	do
		local path=$(dirname "${x}/Manifest")
		local idx_pn=$(get_path_pkg_idx "${path}")
		local idx_cat=$(( ${idx_pn} - 1 ))
		local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
		local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
		printf "%-${WPKG}s%-${WOPT}s\n" "${p}" "${MATH_OPT}" >> package.env.t
	done
	for x in $(grep --exclude-dir=.git --exclude-dir=distfiles -l -E -i -r -e "((sci-libs|virtual)/(lapack|openblas|mkl-rt|blis)|eigen)" "${PORTAGE_DIR}/"* \
		| grep "ebuild")
	do
		local path=$(dirname "${x}/Manifest")
		local idx_pn=$(get_path_pkg_idx "${path}")
		local idx_cat=$(( ${idx_pn} - 1 ))
		local p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
		local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
		printf "%-${WPKG}s%-${WOPT}s\n" "${p}" "${LINEAR_MATH_OPT}" >> package.env.t
	done
	cat package.env.t | sort | uniq >> package.env
	echo "" >> package.env
}

autofetch_tarballs() {
	if [[ "${AUTOFETCH_TARBALLS}" == "1" ]] ; then
		echo "Autofetching tarballs"
		emerge -fve world
	fi
}

header() {
	echo "ASM_OPT=${ASM_OPT}"
	echo "AUTOFETCH_TARBALLS=${AUTOFETCH_TARBALLS}"
	echo "CRYPTO_CHEAP_OPT_CFG=${CRYPTO_CHEAP_OPT_CFG}"
	echo "CRYPTO_EXPENSIVE_OPT_CFG=${CRYPTO_EXPENSIVE_OPT_CFG}"
	echo "CRYPTO_ASYM_OPT_CFG=${CRYPTO_ASYM_OPT_CFG}"
	echo "DISTDIR=${DISTDIR}"
	echo "LINEAR_MATH_OPT=${LINEAR_MATH_OPT}"
	echo "OPENGL_OPT=${OPENGL_OPT}"
	echo "PORTAGE_DIR=${PORTAGE_DIR}"
	echo "MATH_OPT=${MATH_OPT}"
	echo "SIMD_OPT=${SIMD_OPT}"
	echo "SSA_SIZE=${SSA_SIZE}"
	echo "SSA_OPT=${SSA_OPT}"

	[[ ! -d "${DISTDIR}" ]] && echo "Missing ${DISTDIR}.  Change DISTDIR in ${SCRIPT_NAME}"

	if [[ "${SKIP_INTRO_PAUSE}" != "1" ]] ; then
		echo
		echo "Edit changes inside ${SCRIPT_NAME} now by pressing CTRL+C"
		echo "Continuing in 15 secs."
		echo
		sleep 15
	fi
}

gen_package_env() {
	echo
	echo "Generating package.env"
	echo

	[[ -e "package.env" ]] && mv package.env package-$(date +"%s").env.bak
	touch package.env

	cat package_env-header.txt >> package.env

	gen_ssa_opt_list
	gen_math_list
	gen_linear_math_list
	gen_opengl_list
	gen_asm_list
	gen_simd_list
	gen_crypto_list
	gen_loc_list

	cat fixes.lst >> package.env
	cat static-opts.lst >> package.env
	cat build-control.lst >> package.env
	cat cfi.lst >> package.env
	cat makeopts.lst >> package.env
	cat testing.lst >> package.env
}

footer() {
	echo "All work completed!"

	echo
	echo "NOTE:"
	echo "The crypto list needs to be manually edited."
	echo
}

setup() {
	trap cleanups INT
	trap cleanups SIGTERM
	trap cleanups EXIT
}

cleanups() {
	echo "cleanup() called"
	rm -rf package.env.t*
}

gen_overlay_paths() {
	local _overlay_paths=(
		${PORTAGE_DIR}
		/usr/local/oiledmachine-overlay
		$(find "${LAYMAN_BASEDIR}" -maxdepth 1 -type d -name "profiles" -o -name "metadata" \
			| sed -r -e "s/(metadata|profiles)//g" \
			| sed -e "s|/$||g" \
			| sort \
			| uniq)
	)
	export OVERLAY_PATHS="${_overlay_paths[@]}"
}

main()
{
	if [[ "${DEVELOPER_MODE}" != "1" ]] ; then
		echo "${SCRIPT_NAME} is under construction"
		echo "Do not use yet!"
		return
	fi
	setup
	gen_overlay_paths
	header
	autofetch_tarballs
	gen_package_env
	footer
}

main
