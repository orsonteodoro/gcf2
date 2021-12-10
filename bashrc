#
# Copy the following inside /etc/portage/bashrc:
#
# or
#
# Copy this file as /etc/portage/gcf-bashrc
# then add this line:
#
#   source /etc/portage/gcf-bashrc
#
# in /etc/portage/bashrc.
#

gcf_info() {
	echo -e ">>> [GCF] ${@}"
}

gcf_warn() {
	echo -e ">>> \e[30m\e[43m[GCF]\e[0m ${@}"
}

gcf_error() {
	echo -e ">>> \e[30m\e[41m[GCF]\e[0m ${@}"
}

_gcf_replace_flag() {
	local i="${1}"
	local o="${2}"
	export COMMON_FLAGS=$(echo "${COMMON_FLAGS}" | sed -r -e "s/${i}/${o}/g")
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${i}|${o}|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${i}|${o}|g")
	export FCFLAGS=$(echo "${FCFLAGS}" | sed -e "s|${i}|${o}|g")
	export FFLAGS=$(echo "${FFLAGS}" | sed -e "s|${i}|${o}|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")

	# For the perl-module.eclass
	export DIST_MAKE=$(echo "${DIST_MAKE}" | sed -r -e "s/${i}/${o}/g")
}

_gcf_translate_to_gcc_retpoline() {
	gcf_info "Auto translating retpoline for gcc"
	_gcf_replace_flag "-mretpoline" "-mindirect-branch=thunk -mindirect-branch-register"
}

_gcf_translate_to_clang_retpoline() {
	gcf_info "Auto translating retpoline for clang"
	_gcf_replace_flag "-mindirect-branch=thunk" "-mretpoline"
	_gcf_replace_flag "-mindirect-branch-register" ""
}

gcf_retpoline_translate() {
	if [[ -n "${USE_CLANG}" && "${USE_CLANG}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_clang_retpoline
	elif [[ -n "${USE_GCC}" && "${USE_GCC}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_gcc_retpoline
	elif [[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_gcf_translate_to_clang_retpoline
	elif [[ ( -z "${CC}" && -z "${CXX}" ) || "${CC}" =~ "gcc" || "${CXX}" =~ "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_gcf_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_inline() {
	if [[ "${CFLAGS}" =~ "-fno-inline" \
		&& ( "${CFLAGS}" =~ ("-Ofast"|"-O2"|"O3") \
			|| ( -n "${DISABLE_NO_INLINE}" && "${DISABLE_NO_INLINE}" == "1" ) \
			|| ( "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ) \
		) ]] ; then
		gcf_info "Removing -fno-inline from *FLAGS"
		_gcf_replace_flag "-fno-inline" ""
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		gcf_info "Removing -fno-plt from *FLAGS"
		_gcf_replace_flag "-fno-plt" ""
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-inline
		-fopt-info-loop
		-fopt-info-vec
		-fprefetch-loop-arrays
		-frename-registers
		-freorder-blocks-algorithm=simple
		-freorder-blocks-algorithm=stc
	)

	if [[ ( -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ) \
		|| ( -n "${CC}" && "${CC}" == "clang" ) ]] ; then
		gcf_info "Removing ${gcc_flags[@]} from *FLAGS"
		for f in ${gcc_flags[@]} ; do
			_gcf_replace_flag "${f}" ""
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ -n "${DISABLE_Z_RETPOLINEPLT}" && "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		gcf_info "Removing -Wl,-z,retpolineplt from LDFLAGS"
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
}

gcf_met_clang_thinlto_requirement() {
	local llvm_slots=(14 13 12 11)
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( has_version "sys-devel/llvm:${s}" \
			&& has_version "sys-devel/clang:${s}" \
			&& has_version ">=sys-devel/lld-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=0
		fi
	done
	return ${found}
}

gcf_met_clang_goldlto_requirement() {
	local llvm_slots=(14 13 12 11)
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( ( has_version "sys-devel/llvm:${s}[gold]" || has_version "sys-devel/llvm:${s}[binutils-plugin]" ) \
			&& has_version "sys-devel/binutils[plugins,gold]" \
			&& has_version ">=sys-devel/llvmgold-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=0
		fi
	done
	return ${found}
}

gcf_met_gcc_bfdlto_requirement() {
	has_version "sys-devel/gcc" || return 1

	if has_version "sys-devel/binutils[plugins]" ; then
		return 0
	fi
	return 1
}

gcf_met_gcc_goldlto_requirement() {
	has_version "sys-devel/gcc" || return 1

	if has_version "sys-devel/binutils[plugins,gold]" ; then
		return 0
	fi
	return 1
}

gcf_use_clang() {
	gcf_info "Auto switching to clang"
	export CC=clang
	export CXX=clang++
	export CPP=clang-cpp
	export AR=llvm-ar
	export AS=llvm-as
	export NM=llvm-nm
	export OBJCOPY=llvm-objcopy
	export OBJDUMP=llvm-objdump
	export RANLIB=llvm-ranlib
	export READELF=llvm-readelf
	export STRIP=llvm-strip
}

gcf_use_thinlto() {
	gcf_info "Auto switching to ThinLTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto=thin")
	CFLAGS=$(echo "${CFLAGS} -flto=thin")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto=thin")
	FCFLAGS=$(echo "${FCFLAGS} -flto=thin")
	FFLAGS=$(echo "${FFLAGS} -flto=thin")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=lld -flto=thin")
}

gcf_use_clang_goldlto() {
	gcf_info "Auto switching to Clang Gold LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto=full")
	CFLAGS=$(echo "${CFLAGS} -flto=full")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto=full")
	FCFLAGS=$(echo "${FCFLAGS} -flto=full")
	FFLAGS=$(echo "${FFLAGS} -flto=full")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold -flto=full")
}

gcf_use_gcc_goldlto() {
	gcf_info "Auto switching to GCC Gold LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto")
	CFLAGS=$(echo "${CFLAGS} -flto")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto")
	FCFLAGS=$(echo "${FCFLAGS} -flto")
	FFLAGS=$(echo "${FFLAGS} -flto")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold -flto")
}

gcf_use_gcc_bfdlto() {
	gcf_info "Auto switching to GCC BFD LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto")
	CFLAGS=$(echo "${CFLAGS} -flto")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto")
	FCFLAGS=$(echo "${FCFLAGS} -flto")
	FFLAGS=$(echo "${FFLAGS} -flto")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=bfd -flto")
}

gcf_is_package_missing_in_lto_lists() {
	local emerge_set
	local p
	local type
	for emerge_set in system world ; do
		for type in lto-agnostic lto-restricted no-data no-lto ; do
			local L=($(cat /etc/portage/emerge-${emerge_set}-${type}.lst))
			for p in ${L[@]} ; do
				[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 1
			done
		done
	done
	return 0
}

gcf_is_package_in_lto_blacklists() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-no-lto.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_agnostic() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-agnostic.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_agnostic_world() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-agnostic.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_agnostic_system() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-system-lto-agnostic.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_restricted() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-restricted.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_restricted_world() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-restricted.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_restricted_system() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-restricted.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_unknown() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-no-data.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_lto() {
	[[ -n "${DISABLE_GCF_LTO}" && "${DISABLE_GCF_LTO}" == "1" ]] && return

	if ! has_version "sys-devel/binutils[plugins]" ; then
gcf_warn "The plugins USE flag must be enabled in sys-devel/binutils for LTO to work."
	fi

	_gcf_strip_lto_flags() {
		local flag_names=(
			COMMON_FLAGS
			CFLAGS
			CXXFLAGS
			FCFLAGS
			FFLAGS
			LDFLAGS
			DIST_MAKE
		)
		local f
		for f in ${flag_names[@]} ; do
			eval "export ${f}=\$(echo \"\$${f}\" | sed -r -e 's/-flto( |\$)//g' -e \"s/-flto=[0-9]+//g\" -e \"s/-flto=(auto|jobserver|thin|full)//g\" -e \"s/-fuse-ld=(lld|bfd|gold)//g\")"
		done
	}

	# New packages do not get LTO initially because it simplifies this script.
	# New packages from the no-data list will get moved into agnostic, no-lto,
	#   or lto-restricted list via generator script.
	if gcf_is_package_in_lto_blacklists \
		|| gcf_is_package_lto_unknown \
		|| gcf_is_package_missing_in_lto_lists ; then
		gcf_error "Stripping LTO flags for blacklisted, missing install file list"
		_gcf_strip_lto_flags
		if has lto ${IUSE_EFFECTIVE} && use lto ; then
gcf_error "Possible IR incompatibility.  Please disable the lto USE flag."
			die
		fi
	fi

	if gcf_is_package_lto_restricted_world ; then
gcf_warn "This package requires -flto stripped and lto USE disabled if there is"
gcf_warn "a future hard dependency on a specific compiler differing from"
gcf_warn "CC_LTO=${CC_LTO}."
	fi

	if has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by \
		#   make.conf/package.env.
		# Some packages want to manipulate LTO -O* flags.
gcf_info "Removing -flto from *FLAGS.  Using the USE flag setting instead."
		_gcf_strip_lto_flags
	fi

	if [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ); then
		if [[ -n "${DISABLE_LTO_COMPILER_SWITCH}" && "${DISABLE_LTO_COMPILER_SWITCH}" == "1" ]] ; then
			# Breaks the determinism in this closed system
			gcf_warn "Disabling compiler switch"
		elif gcf_is_package_lto_agnostic_system ; then
			# Disallow compiler autodetect
			CC="${CC_LIBC:=gcc}"
			CXX="${CXX_LIBC:=g++}"
		elif gcf_is_package_lto_restricted_world || gcf_is_package_lto_agnostic_world ; then
			CC="${CC_LTO}"
			CXX="${CXX_LTO}"
		else
			CC="${CC_LIBC:=gcc}"
			CXX="${CXX_LIBC:=g++}"
		fi
		[[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] && gcf_use_clang
	fi

	local linker=""
	if gcf_is_package_in_lto_blacklists \
		|| gcf_is_package_lto_unknown \
		|| gcf_is_package_missing_in_lto_lists ; then
		linker="no-lto"
	elif gcf_is_package_lto_agnostic \
		|| gcf_is_package_lto_restricted ; then
		if [[ "${CC}" == "clang" && "${USE_THINLTO}" == "1" ]] ; then
			linker="thinlto"
		elif [[ "${CC}" == "clang" && "${USE_GOLDLTO}" == "1" ]] ; then
			linker="clang-goldlto"
		elif [[ "${CC}" == "gcc" && "${USE_GOLDLTO}" == "1" ]] ; then
			linker="gcc-goldlto"
		elif [[ "${CC}" == "gcc" ]] ; then
			linker="gcc-bfdlto"
		fi
	fi

	if [[ "${CFLAGS}" =~ "-flto" || "${CXXFLAGS}" =~ "-flto" ]] ; then
		# A reminder that you can only use one LTO implementation as the
		# default systemwide.

		if [[ -n "${DISABLE_LTO_COMPILER_SWITCH}" && "${DISABLE_LTO_COMPILER_SWITCH}" == "1" ]] ; then
			gcf_warn "Disabling linker switch"
		elif [[ "${linker}" == "thinlto" ]] \
			&& gcf_met_clang_thinlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_thinlto
			if gcc --version | grep -q -e "Hardened" ; then
				if clang --version | grep -q -e "Hardened" ; then
					:;
				else
gcf_warn "Non-hardened clang detected.  Use the clang ebuild from the"
gcf_warn "oiledmachine-overlay.  Not doing so can weaken the security."
				fi
			fi
			# Avoiding gcc/lto because of *serious* memory issues \
			# on 1 GIB per core machines.
		elif [[ "${linker}" == "clang-goldlto" ]] \
			&& gcf_met_clang_goldlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_clang_goldlto
			if gcc --version | grep -q -e "Hardened" ; then
				if clang --version | grep -q -e "Hardened" ; then
					:;
				else
gcf_warn "Non-hardened clang detected.  Use the clang ebuild from the"
gcf_warn "oiledmachine-overlay.  Not doing so can weaken the security."
				fi
			fi
		elif [[ "${linker}" == "gcc-goldlto" ]] \
			&& gcf_met_gcc_goldlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_goldlto
		elif [[ "${linker}" == "gcc-bfdlto" ]] \
			&& gcf_met_gcc_bfdlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_bfdlto
		elif [[ "${linker}" == "no-lto" ]] ; then
			:;
		else
			gcf_warn "Did not meet LTO requirements."
echo "${CATEGORY}/${PN}" >> /etc/portage/emerge-requirements-not-met.lst
		fi

		# It's okay to use GCC+BFD LTO or WPA-LTO for small packages,
		# but not okay to mix and switch LTO IR.
		if [[ ( -n "${DISABLE_GCC_LTO}" && "${DISABLE_GCC_LTO}" == "1" ) \
			&& ( "${CC}" =~ "gcc" || "${CXX}" =~ "g++" \
				|| ( -z "${CC}" && -z "${CXX}" ) ) ]] ; then
			# This should be disabled for packages that take
			# literally most of the day or more to complete with
			# GCC LTO.
			# Auto switching to ThinLTO for larger packages instead.
			_gcf_strip_lto_flags
		fi

		if [[ -n "${DISABLE_CLANG_LTO}" && "${DISABLE_CLANG_LTO}" == "1" \
			&& ( "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_strip_lto_flags
		fi

		# Remove all LTO flags
		if [[ -n "${DISABLE_LTO}" && "${DISABLE_LTO}" == "1" ]] ; then
			gcf_info "Forced removal of -flto from *FLAGS"
			_gcf_strip_lto_flags
		fi
	fi

	export CC
	export CXX
	export COMMON_FLAGS
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS
	export DIST_MAKE
}

gcf_replace_flags()
{
	if [[ -n "${OPT_LEVEL}" && "${OPT_LEVEL}" =~ ("-O0"|"-O1"|"-O2"|"-O3"|"-O4"|"-Ofast"|"-Oz"|"-Os") ]] ; then
		_gcf_replace_flag "${DEFAULT_OPT_LEVEL}" "${OPT_LEVEL}"
	fi
}

gcf_strip_lossy()
{
	if [[ -n "${I_WANT_LOSSLESS}" && "${I_WANT_LOSSLESS}" == "1" ]] ; then
		if [[ "${CFLAGS}" =~ "-Ofast" ]] ; then
			gcf_info "Converting -Ofast -> -O3"
			_gcf_replace_flag "-Ofast" "-O3"
		fi

		if [[ "${CFLAGS}" =~ "-ffast-math" ]] ; then
			gcf_info "Stripping -ffast-math"
			_gcf_replace_flag "-ffast-math" ""
		fi
	fi
}

gcf_use_Oz()
{
	if [[ ( "${CC}" == "clang" || "${CXX}" == "clang++" ) && "${CFLAGS}" =~ "-Os" ]] ; then
		gcf_info "Detected clang.  Converting -Os -> -Oz"
		_gcf_replace_flag "-Os" "-Oz"
	fi
	if [[ ( "${CC}" == "gcc" || "${CXX}" == "g++" || ( -z "${CC}" && -z "${CXX}" ) ) && "${CFLAGS}" =~ "-Oz" ]] ; then
		gcf_info "Detected gcc.  Converting -Oz -> -Os"
		_gcf_replace_flag "-Oz" "-Os"
	fi
}

gcf_replace_freorder_blocks_algorithm()
{
	if [[ "FREORDER_BLOCKS_ALGORITHM" == "stc" ]] ; then
		_gcf_replace_flag "-freorder-blocks-algorithm=simple" "-freorder-blocks-algorithm=stc"
	fi
}

gcf_adjust_makeopts()
{
	if [[ -z "${NCORES}" ]] ; then
gcf_error "Set NCORES in the /etc/portage/make.conf.  Set the number of CPU cores"
gcf_error "not multiplying the threads per core."
		die
	fi
	if [[ -z "${MPROCS}" ]] ; then
gcf_error "Set MPROCS in the /etc/portage/make.conf.  2 is recommended."
		die
	fi
	local n
	if [[ "${MAKEOPTS_MODE:=normal}" == "normal" ]] ; then
		n=$(python -c "import math;print(int(round(${NCORES} * ${MPROCS})))")
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE}" == "swappy" ]] ; then
		n=$((${NCORES} / 2))
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE}" == "plain" ]] ; then
		n=${NCORES}
	elif [[ "${MAKEOPTS_MODE}" == "oom" \
		|| "${MAKEOPTS_MODE}" == "broken" \
		|| "${MAKEOPTS_MODE}" == "severe-swapping" ]] ; then
		n=1
	fi
	export MAKEOPTS="-j${n}"
	export MAKEFLAGS="-j${n}"
	gcf_info "MAKEOPTS_MODE is ${MAKEOPTS_MODE} (-j${n})"
	if [[ "${MAKEOPTS_MODE}" == "severe-swapping" ]] ; then
gcf_warn "Please close all web browsers and large programs to speed up"
gcf_warn "linking time."
	fi
}

gcf_strip_retpoline()
{
	if [[ -n "${DISABLE_RETPOLINE}" && "${DISABLE_RETPOLINE}" == "1" ]] ; then
			_gcf_replace_flag "-mindirect-branch=thunk" ""
			_gcf_replace_flag "-mretpoline" ""
			_gcf_replace_flag "-mindirect-branch-register" ""
			_gcf_replace_flag "-Wl,-z,retpolineplt" ""
	fi
}

gcf_record_start_time()
{
	export GCF_START_EMERGE_TIME=$(date +%s)
}

gcf_translate_no_inline()
{
	if [[ ( "${CFLAGS}" =~ "-fno-inline" || "${CXXFLAGS}" =~ "-fno-inline" ) \
		&& ( "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ) ]] ; then
		gcf_info "Detected clang.  Converting -fno-inline -> -fno-inline-functions"
		_gcf_replace_flag "-fno-inline" "-fno-inline-functions"
	fi
}

pre_pkg_setup()
{
	gcf_info "Running pre_pkg_setup()"
	gcf_replace_flags
	gcf_lto
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
	gcf_strip_retpoline
	gcf_strip_no_inline
	gcf_strip_lossy
	gcf_use_Oz
	gcf_translate_no_inline
	gcf_replace_freorder_blocks_algorithm
	gcf_adjust_makeopts
	gcf_record_start_time
}

gcf_check_Ofast_safety()
{
	[[ -n "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" && "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" == "1" ]] && return
	if [[ "${OPT_LEVEL}" == "-Ofast" && -e "${T}/build.log" ]] ; then
		if grep -q -E -e "(-lboost_thread|-lgthread|-lomp|-pthread|-lpthread|-ltbb)" "${T}/build.log" ; then
gcf_error "Detected thread use.  Disable -Ofast or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
			die
		fi
	fi
	if [[ "${CFLAGS}" =~ "-fallow-store-data-races" && -e "${T}/build.log" ]] ; then
		if grep -q -E -e "(-lboost_thread|-lgthread|-lomp|-pthread|-lpthread|-ltbb)" "${T}/build.log" ; then
gcf_error "Detected thread use.  Disable -fallow-store-data-races or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
			die
		fi
	fi
}

gcf_check_ebuild_compiler_override() {
	[[ -n "${DISABLE_OVERRIDE_COMPILER_CHECK}" && "${DISABLE_OVERRIDE_COMPILER_CHECK}" == "1" ]] && return

	_gcf_ir_message_incompatible() {
gcf_error
gcf_error "Detected possible ebuild override of CC/CXX with incompatible IR."
gcf_error "It is recommended disable LTO for this package."
gcf_error
gcf_error "CC=${CC}"
gcf_error "CXX=${CXX}"
gcf_error
			die
	}

	if ( [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ) ) \
		&& gcf_is_package_lto_restricted ; then
		gcf_info "Running gcf_check_ebuild_compiler_override()"
		if [[ ! ( "${CC}" =~ "${CC_LTO}" ) || ! ( "${CXX}" =~ "${CXX_LTO}" ) ]] ; then
			_gcf_ir_message_incompatible
		fi

		local start=$(grep -n "Compiling source in" "${T}/build.log" | head -n 1)
		local end=$(grep -n "Source compiled" "${T}/build.log" | head -n 1)
		[[ -z "${end}" ]] && end=$(wc -l "${T}/build.log")
		if [[ -n "${start}" && "${CC_LIBC}" != "${CC_LTO}" ]] \
			&& (( $(sed -n ${start},${end}p "${T}/build.log" \
				| grep -E -e "(^| |-)${CC_LIBC} " \
				| wc -l) > 1 )) ; then
			CC=${CC_LIBC}
			CXX=${CXX_LIBC}
			_gcf_ir_message_incompatible
		fi

		# TODO: auto inspect packages that turn off compiler verbosity.
	fi
}

pre_src_compile() {
	gcf_info "Running pre_src_compile()"
	gcf_check_ebuild_compiler_override
}

post_src_compile() {
	gcf_info "Running post_src_compile()"
	gcf_check_ebuild_compiler_override
}

pre_src_install() {
	gcf_info "Running pre_src_install()"
	gcf_check_Ofast_safety
}

gcf_report_emerge_time() {
	# Can used by log filtering
	local now=$(date +%s)
	local elapsed_time=$((${now} - ${GCF_START_EMERGE_TIME}))
	local et_days=$(( ${elapsed_time} / 86400  ))
	local et_hours=$(( ${elapsed_time} % 86400 / 3600 ))
	local et_min=$(( ${elapsed_time} % 3600 / 60 ))
	local et_sec=$(( ${elapsed_time} % 60 ))
	gcf_info "Completion Time: ${elapsed_time} seconds ( ${et_days} days ${et_hours} hours ${et_min} minutes ${et_sec} seconds )"
	if (( ${et_days} >= 1 || ${et_hours} >= 18 )) ; then # 3/4 of a day.
		# More than 1 day is not acceptable if updates are monotasking because it blocks
		# security updates for critical 0-day exploits.
		gcf_warn "The MAKEOPTS value may need to be reduced to increase goodput or"
		gcf_warn "don't use Full LTO or switch to ThinLTO instead."
	fi
}

post_src_install() {
	gcf_info "Running post_src_install()"
	gcf_report_emerge_time
}
