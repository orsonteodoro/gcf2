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

GCF_LIST_VERSION_MIN=3

gcf_info() {
	echo -e ">>> [GCF] ${@}"
}

gcf_warn() {
	echo -e ">>> \e[30m\e[43m[GCF]\e[0m ${@}"
}

gcf_error() {
	echo -e ">>> \e[30m\e[41m[GCF]\e[0m ${@}"
}

gcf_append_ldflags() {
	export LDFLAGS=$(echo "${LDFLAGS} ${@}")
}

gcf_print_flags() {
	[[ -z "${GCF_SHOW_FLAGS}" || "${GCF_SHOW_FLAGS}" != "1" ]] && return
	gcf_info "COMMON_FLAGS=${COMMON_FLAGS}"
	gcf_info "CFLAGS=${CFLAGS}"
	gcf_info "CXXFLAGS=${CXXFLAGS}"
	gcf_info "FCFLAGS=${FCFLAGS}"
	gcf_info "FFLAGS=${FFLAGS}"
	gcf_info "LDFLAGS=${LDFLAGS}"
	gcf_info "DIST_MAKE=${DIST_MAKE}"
}

gcf_append_flags() {
	export COMMON_FLAGS=$(echo "${COMMON_FLAGS} ${@}")
	export CFLAGS=$(echo "${CFLAGS} ${@}")
	export CXXFLAGS=$(echo "${CXXFLAGS} ${@}")
	export FCFLAGS=$(echo "${FCFLAGS} ${@}")
	export FFLAGS=$(echo "${FFLAGS} ${@}")
	export LDFLAGS=$(echo "${LDFLAGS} ${@}")

	# For the perl-module.eclass
	export DIST_MAKE=$(echo "${DIST_MAKE} ${@}")
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
	if [[ "${USE_CLANG}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_clang_retpoline
	elif [[ "${USE_GCC}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_gcc_retpoline
	elif [[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_gcf_translate_to_clang_retpoline
	elif [[ ( -z "${CC}" && -z "${CXX}" ) || "${CC}" == "gcc" || "${CXX}" == "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_gcf_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_inline() {
	if [[ "${CFLAGS}" =~ "-fno-inline" \
		&& ( "${CFLAGS}" =~ ("-Ofast"|"-O2"|"O3") \
			|| ( "${DISABLE_NO_INLINE}" == "1" ) \
		) ]] ; then
		gcf_info "Removing -fno-inline from *FLAGS"
		_gcf_replace_flag "-fno-inline" ""
	fi
}

gcf_strip_no_plt() {
	if [[ "${DISABLE_FNO_PLT}" == "1" ]] ; then
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

	if [[ "${DISABLE_GCC_FLAGS}" == "1" \
		|| "${CC}" == "clang" ]] ; then
		gcf_info "Removing ${gcc_flags[@]} from *FLAGS"
		for f in ${gcc_flags[@]} ; do
			_gcf_replace_flag "${f}" ""
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		gcf_info "Removing -Wl,-z,retpolineplt from LDFLAGS"
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
	if [[ -z "${USE_THINLTO}" || "${USE_THINLTO}" != "1" ]] ; then
		_gcf_replace_flag "-Wl,-z,retpolineplt" ""
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

gcf_met_clang_bfdlto_requirement() {
	has_version "sys-devel/clang" || return 1

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
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=lld")
	gcf_append_flags "-flto=thin"
}

gcf_use_clang_goldlto() {
	gcf_info "Auto switching to Clang Gold LTO"
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold")
	gcf_append_flags "-flto=full"
}

gcf_use_gcc_goldlto() {
	gcf_info "Auto switching to GCC Gold LTO"
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold")
	gcf_append_flags "-flto"
}

gcf_use_gcc_bfdlto() {
	gcf_info "Auto switching to GCC BFD LTO"
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=bfd")
	gcf_append_flags "-flto"
}

gcf_use_clang_bfdlto() {
	gcf_info "Auto switching to Clang BFD LTO"
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=bfd")
	gcf_append_flags "-flto"
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

gcf_is_clang_cfi() {
	[[ "${USE_CLANG_CFI}" == "1" ]] && return 0
	return 1
}

gcf_is_skipless() {
	[[ "${USE_CLANG_CFI}" == "1" ]] && return 1

	if [[ "${FORCE_PREFETCH_LOOP_ARRAYS}" == "1" ]] ; then
		return 0
	elif [[ "${GCF_IS_SKIPLESS}" == "1" ]] ; then
		return 0
	fi
	return 1
}

gcf_is_lto_skippable() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-skip.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_cfi_skippable() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-cfi-skip.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_cfiable() {
	if grep -q -e "${CATEGORY}/${PN}:" /etc/portage/emerge-{cfi-system,cfi-world}.lst 2>/dev/null ; then
		return 0
	fi
	return 1
}

get_cfi_flags() {
	if grep -q -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-{cfi-system,cfi-world}.lst ; then
		grep -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-{cfi-system,cfi-world}.lst | head -n 1 | cut -f 2- -d ":" | cut -f 2 -d ":"
	fi
}

gcf_is_clang_cfi_ready() {
	local llvm_slots=(14 13 12 11)
	has_version "sys-devel/llvm" || return 1

	if [[ "${CC_LTO}" == "clang" && "${CXX_LTO}" == "clang++" ]] ; then
		:;
	else
gcf_error "CC_LTO=clang and CXX_LTO=clang++ must be the systemwide default."
gcf_error "Disabling Clang CFI support."
		return 1
	fi

	local found=1
	for s in ${llvm_slots[@]} ; do
		if (       has_version "sys-devel/clang:${s}" \
			&& has_version "=sys-devel/clang-runtime-${s}*[compiler-rt,sanitize]" \
			&& has_version "=sys-libs/compiler-rt-${s}*" \
			&& ( \
				( has_version ">=sys-devel/lld-${s}" ) \
					|| \
				( ( has_version "sys-devel/llvm:${s}[gold]" \
					|| has_version "sys-devel/llvm:${s}[binutils-plugin]" ) \
		                        && has_version "sys-devel/binutils[plugins,gold]" \
                		        && has_version ">=sys-devel/llvmgold-${s}" ) \
			) \
			&& has_version "=sys-libs/compiler-rt-sanitizers-${s}*[cfi,ubsan]" \
			&& has_version "sys-devel/llvm:${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=0
		fi
	done
	return ${found}
}

gcf_check_emerge_list_ready() {
	if ! find /etc/portage/emerge*.lst 2>/dev/null 1>/dev/null ; then
gcf_error "Missing lto lists.  Use gen_pkg_lists.sh to generate them"
		die
	else
		if ! grep -q -e "# version " $(find /etc/portage/emerge*.lst | head -n1) ; then
gcf_error "The generated list is missing the version header.  Use the"
gcf_error "gen_pkg_lists.sh to generate them."
			die
		fi

		local gcf_list_ver=$(grep -e "# version " /etc/portage/emerge*.lst \
			| head -n 1 | cut -f 2- -d ":" | cut -f 3 -d " ")
		if (( ${gcf_list_ver} < ${GCF_LIST_VERSION_MIN} )) ; then
gcf_error "The generated list version header is too old.  Use the"
gcf_error "gen_pkg_lists.sh to generate a compatible list."
			die
		fi
	fi
}

gcf_lto() {
	[[ "${DISABLE_GCF_LTO}" == "1" ]] && return

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

	if gcf_is_lto_skippable ; then
		# For packages that use compiler checks but don't install
		# binaries.
		if [[ -z "${CC}" || -z "${CXX}" ]] ; then
			export CC="${CC_LIBC:=gcc}"
			export CXX="${CXX_LIBC:=g++}"
		fi
		_gcf_strip_lto_flags
		[[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] && gcf_use_clang
		return
	fi

	if ! has_version "sys-devel/binutils[plugins]" ; then
gcf_warn "The plugins USE flag must be enabled in sys-devel/binutils for LTO to work."
	fi

	gcf_check_emerge_list_ready

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
gcf_warn "CC_LTO=${CC_LTO} when linking static-libs."
	fi

	if has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by \
		#   make.conf/package.env.
		# Some packages want to manipulate LTO -O* flags.
gcf_info "Removing -flto from *FLAGS.  Using the USE flag setting instead."
		_gcf_strip_lto_flags
	fi

	if [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ) ; then
		local pkg_flags=$(get_cfi_flags)
		if [[ "${DISABLE_LTO_COMPILER_SWITCH}" == "1" ]] ; then
			# Breaks the determinism in this closed system
			gcf_warn "Disabling compiler switch"
		elif [[ "${USE_GCC}" == "1" ]] ; then
			CC="gcc"
			CXX="g++"
		elif gcf_is_package_lto_agnostic_world && gcf_is_clang_cfi && gcf_is_clang_cfi_ready && [[ ! ( "${pkg_flags}" =~ "A" ) ]] ; then
			CC="clang"
			CXX="clang++"
		elif gcf_is_skipless ; then
			CC="gcc"
			CXX="g++"
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
		[[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] && gcf_use_clang
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
		elif [[ "${CC}" == "clang" ]] ; then
			linker="clang-bfdlto"
		elif [[ "${CC}" == "gcc" ]] ; then
			linker="gcc-bfdlto"
		fi
	fi

	if gcf_is_package_lto_agnostic && gcf_is_skipless ; then
		if [[ "${USE_GOLDLTO}" == "1" ]] ; then
			linker="gcc-goldlto"
		else
			linker="gcc-bfdlto"
		fi
	elif ! gcf_is_package_lto_agnostic && gcf_is_skipless ; then
		linker="no-lto"
	fi

	if [[ "${CFLAGS}" =~ "-flto" || "${CXXFLAGS}" =~ "-flto" ]] ; then
		# A reminder that you can only use one LTO implementation as the
		# default systemwide.

		if [[ "${DISABLE_LTO_COMPILER_SWITCH}" == "1" ]] ; then
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
		elif [[ "${linker}" == "clang-bfdlto" ]] \
			&& gcf_met_clang_bfdlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_clang_bfdlto
		elif [[ "${linker}" == "no-lto" ]] ; then
			:;
		else
			gcf_warn "Did not meet LTO requirements."
echo "${CATEGORY}/${PN}" >> /etc/portage/emerge-requirements-not-met.lst
		fi

		# It's okay to use GCC+BFD LTO or WPA-LTO for small packages,
		# but not okay to mix and switch LTO IR.
		if [[ "${DISABLE_GCC_LTO}" == "1" \
			&& ( "${CC}" == "gcc" || "${CXX}" == "g++" \
				|| ( -z "${CC}" && -z "${CXX}" ) ) ]] ; then
			# This should be disabled for packages that take
			# literally most of the day or more to complete with
			# GCC LTO.
			# Auto switching to ThinLTO for larger packages instead.
			gcf_info "Forced removal of -flto from *FLAGS for gcc"
			_gcf_strip_lto_flags
		fi

		if [[ "${DISABLE_CLANG_LTO}" == "1" \
			&& ( "${CC}" == "clang" || "${CXX}" == "clang++" ) ]] ; then
			gcf_info "Forced removal of -flto from *FLAGS for clang"
			_gcf_strip_lto_flags
		fi

		# Remove all LTO flags
		if [[ "${DISABLE_LTO}" == "1" ]] ; then
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
	if [[ "${OPT_LEVEL}" =~ ("-O0"|"-O1"|"-O2"|"-O3"|"-O4"|"-Ofast"|"-Oz"|"-Os") ]] ; then
		_gcf_replace_flag "${DEFAULT_OPT_LEVEL}" "${OPT_LEVEL}"
	fi
}

gcf_strip_lossy()
{
	if [[ "${I_WANT_LOSSLESS}" == "1" ]] ; then
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
	local n=1
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
gcf_warn "Please close all web browsers, downloaders, and large programs to"
gcf_warn "speed up linking time."
	fi
}

gcf_strip_retpoline()
{
	if [[ "${DISABLE_RETPOLINE}" == "1" ]] ; then
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
		&& ( "${CC}" == "clang" || "${CXX}" == "clang++" ) ]] ; then
		# Test with metalog package
		gcf_info "Detected clang.  Converting -fno-inline -> -fno-inline-functions"
		_gcf_replace_flag "-fno-inline" "-fno-inline-functions"
	fi
}

gcf_add_cfi_flags() {
	#
	# The configure, compile, and installs for shared- and static-libs
	# should totally isolated due to the -fvisibility changes.
	#
	# This means that CFI Cross-DSO and basic CFI are mutually exclusive
	# at current state of this distro.  If a static-lib is detected, then
	# CFI may have be disabled.
	#
	# CFI requires static linking (with -static for static executibles or
	# -Wl,-Bstatic with static-libs) for Basic CFI or building with
	# -fsanitize-cfi-cross-dso for shared-libs.
	#
	local flags=$(get_cfi_flags)
	gcf_info "Package flags: ${flags}"
	if [[ "${flags}" =~ "A" ]] ; then
		gcf_info "Found static-libs in package.  Disabling CFI."
	elif [[ ( "${flags}" =~ "S" || "${flags}" =~ "X" ) && ! ( "${flags}" =~ "A" ) ]] ; then
		gcf_info "Adding base CFI flags"
		gcf_append_flags -fsanitize=${CFI_BASELINE}
		# CFI_BASELINE, CFI_EXCEPTIONS, USE_CFI_IGNORE_LIST can be per package customizable.
		if [[ -n "${USE_CFI_IGNORE_LIST}" ]] ; then
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}" ]] ; then
				gcf_append_flags -fsanitize-ignorelist=/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}
			fi
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PV}" ]] ; then
				gcf_append_flags -fsanitize-ignorelist=/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PV}
			fi
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PVR}" ]] ; then
				gcf_append_flags -fsanitize-ignorelist=/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PVR}
			fi
		fi

		local cfi_exceptions=()
		[[ -n "${CFI_EXCEPTIONS}" ]] && cfi_exceptions+=( ${CFI_EXCEPTIONS} )
		[[ "${NO_CFI_CAST}" == "1" ]] && cfi_exceptions+=( cfi-derived-cast cfi-unrelated-cast )
		[[ "${NO_CFI_CAST_STRICT}" == "1" ]] && cfi_exceptions+=( cfi-cast-strict )
		[[ "${NO_CFI_DERIVED_CAST}" == "1" ]] && cfi_exceptions+=( cfi-derived-cast )
		[[ "${NO_CFI_ICALL}" == "1" ]] && cfi_exceptions+=( cfi-icall )
		[[ "${NO_CFI_MFCALL}" == "1" ]] && cfi_exceptions+=( cfi-mfcall )
		[[ "${NO_CFI_NVCALL}" == "1" ]] && cfi_exceptions+=( cfi-nvcall )
		[[ "${NO_CFI_UNRELATED_CAST}" == "1" ]] && cfi_exceptions+=( cfi-unrelated-cast )
		[[ "${NO_CFI_VCALL}" == "1" ]] && cfi_exceptions+=( cfi-vcall )
		[[ ! ( "${flags}" =~ "I" ) ]] && cfi_exceptions+=( cfi-icall )

		gcf_info "Adding CFI Cross-DSO flags"
		gcf_append_flags -fvisibility=default
		gcf_append_flags -fsanitize-cfi-cross-dso
		if [[ "${GCF_CFI_DEBUG}" == "1" ]] ; then
			gcf_warn "CFI debug is enabled.  Turn it off in production."
			gcf_append_flags -fno-sanitize-trap=cfi
		fi

		if (( ${#cfi_exceptions[@]} > 0 )) ; then
			gcf_info "Adding CFI exception flags"
			gcf_append_flags -fno-sanitize=$(echo "${cfi_exceptions[@]}" | tr " " ",")
		fi
		export GCF_CFI="1"
	fi
}

gcf_add_clang_cfi() {
	[[ -z "${USE_CLANG_CFI}" || "${USE_CLANG_CFI}" == "0" ]] && return
	[[ "${CC}" == "clang" && "${CXX}" == "clang++" ]] || return
	if ! gcf_is_clang_cfi_ready ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi
	if ! which clang 2>/dev/null 1>/dev/null ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi

	if [[ ( "${CFLAGS}" =~ "-flto" ) \
		|| ( "${CXXFLAGS}" =~ "-flto" ) ]] \
		|| ( has lto ${IUSE_EFFECTIVE} && use lto ) ; then
		:;
	else
		# Clang CFI requires LTO
		gcf_warn "Skipping CFI because it requires LTO."
		return
	fi

	local llvm_v=$(clang --version | grep "clang version" | cut -f 3 -d " " | cut -f 1 -d ".")

	if ! has_version "=sys-libs/compiler-rt-sanitizers-${llvm_v}*[cfi,ubsan]" ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi

	gcf_check_emerge_list_ready

	if gcf_is_cfiable ; then
		gcf_warn "Clang Cross-DSO CFI is experimental and buggy"
		gcf_add_cfi_flags
	fi
}

gcf_catch_errors() {
	gcf_info "Called gcf_catch_errors()"
	if [[ -e "${PWD}/config.log" ]] ; then
		if grep -q -F -e "Assertion \`(cfi_check & (kShadowAlign - 1)) == 0' failed" "${PWD}/config.log" ; then
			# Test package: app-editors/leafpad
			# This is a bug in the config test.
gcf_error "Detected a Clang CFI bug.  Use the sys-libs/compiler-rt-sanitizers"
gcf_error "package from oiledmachine-overlay that disables this assert."
			# Portage will terminate after showing this.
		fi
		if grep -q -F -e "gcc: error: unrecognized argument to '-fsanitize=' option: 'cfi-vcall'" "${PWD}/config.log" ; then
			# Test package: media-libs/opus
gcf_error "Clang CFI is not supported by GCC.  Please switch to clang for this"
gcf_error "package or disable CFI flags."
			# Portage will terminate after showing this.
		fi
	fi
	if grep -q -E -e "lto-llvm-[a-z0-9]+.o: relocation .* against hidden symbol \`__typeid__.*_align' can not be used when making a shared object" "${T}/build.log" ; then
gcf_error "Try disabling cfi-icall, first then more cfi related flags like"
gcf_error "cfi-nvcall, cfi-vcall."
			# Portage will terminate after showing this.
	fi
	if grep -q -E -e "undefined reference to \`__ubsan_handle_cfi_check_fail_abort'" "${T}/build.log" ; then
gcf_error "Detected possible dead end that may require some rollback."
gcf_error
gcf_error "Steps to resolve in order with one re-emerge per case:"
gcf_error
gcf_error "(1) Try disabling all CFI flags first, and if it works then converge"
gcf_error "towards the minimal CFI exception set for this package."
gcf_error "(2) Disable CFI for this package."
gcf_error "(3) Switch back to GCC."
gcf_error "(4) If this package is placed in the no-data LTO list, disable CFI"
gcf_error "in each named dependency temporary until this package is emerged"
gcf_error "then re-emerge back the dependencies with CFI."
gcf_error "(5) If this package is permenently blacklisted (because it contains"
gcf_error "a static-lib or other), the dependencies need to be re-emerged"
gcf_error "without CFI depending on how importance of the executable in this"
gcf_error "package."
gcf_error "For cases 4 and 5 use \`equery b libfile\` to determine the package"
gcf_error "and \`emerge -1vO depend_pkg_name\` to revert with package.env"
gcf_error "changes"
			# Portage will terminate after showing this.
	fi
}

gcf_setup_traps() {
	register_die_hook gcf_catch_errors
}

pre_pkg_setup()
{
	gcf_info "Running pre_pkg_setup()"
	gcf_setup_traps
	gcf_replace_flags
	gcf_lto
	gcf_add_clang_cfi
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
	gcf_print_flags
}

gcf_check_Ofast_safety()
{
	[[ "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" == "1" ]] && return
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
	[[ "${DISABLE_OVERRIDE_COMPILER_CHECK}" == "1" ]] && return
	gcf_is_lto_skippable && return

	_gcf_ir_message_incompatible() {
gcf_error
gcf_error "Detected possible ebuild override of CC/CXX with incompatible IR."
gcf_error "It is recommended disable LTO for this package."
gcf_error
gcf_error "CC=${CC}"
gcf_error "CXX=${CXX}"
gcf_error
gcf_error "You may supply DISABLE_OVERRIDE_COMPILER_CHECK=1 in the package.env"
gcf_error "if it is a false-positive."
gcf_error
			die
	}

	if ( [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ) ) \
		&& gcf_is_package_lto_restricted ; then
		gcf_info "Running gcf_check_ebuild_compiler_override()"

		# The ebuild author can override with ${CHOST}-clang or ${CHOST}-gcc.
		# Sample of possible values:
		# gcc, ${CHOST}-gcc, gcc-11.2.0, ${CHOST}-gcc-11.2.0, unset CC # normalizes to gcc
		# clang, ${CHOST}-clang, clang-14, ${CHOST}-clang-14 # normalizes to clang
		# g++, ${CHOST}-g++, ${CHOST}-g++-11.2.0, unset CXX # normalizes to g++
		# clang++, ${CHOST}-clang++, ${CHOST}-clang++-14 # normalizes to clang
		#
		# g++ and clang++ are ambiguous in substring search.
		#
		local cc
		local cxx
		# Simplify / Normalize the above cases
		if [[ "${CC}" =~ "gcc" || -z "${CC}" ]] ; then # trivial
			cc="gcc"
		elif [[ "${CC}" =~ "clang" ]] ; then # trivial
			cc="clang"
		fi

		if [[ "g++" =~ (^|-| )"${CXX}"( |-|$) || -z "${CXX}" ]] ; then # not trivial
			cxx="g++"
		elif [[ "${CXX}" =~ "clang++" ]] ; then # trivial
			cxx="clang++"
		fi

		if [[ ! ( "${cc}" == "${CC_LTO}" ) || ! ( "${cxx}" == "${CXX_LTO}" ) ]] ; then
			_gcf_ir_message_incompatible
		fi
		local start=$(grep -n "Compiling source in" "${T}/build.log" | head -n 1 | cut -f 1 -d ":")
		local end=$(grep -n "Source compiled" "${T}/build.log" | head -n 1 | cut -f 1 -d ":")
		[[ -z "${end}" ]] && end=$(wc -l "${T}/build.log")
		if [[ -n "${start}" && ( ! "${CC_LIBC}" == "${CC_LTO}" ) ]] \
			&& (( $(sed -n ${start},${end}p "${T}/build.log" \
				| grep -e "${CC_LIBC}" \
				| wc -l) >= 1 )) ; then
			CC=${CC_LIBC}
			CXX=${CXX_LIBC}
			_gcf_ir_message_incompatible
		fi
		# non trivial
		if [[ -n "${start}" && ! ( "${CXX_LIBC}" == "${CXX_LTO}" ) ]] \
			&& (( $(sed -n ${start},${end}p "${T}/build.log" \
				| grep -E -e "(^|-| )${CXX_LIBC//+/\\+}( |-|$)" \
				| wc -l) >= 1 )) ; then
			CC=${CC_LIBC}
			CXX=${CXX_LIBC}
			_gcf_ir_message_incompatible
		fi

		# TODO: auto inspect packages that turn off compiler verbosity.
	fi
}

post_src_prepare() {
	:;
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
		# More than 1 day is not acceptable.  If updates are monotasking, it blocks
		# security updates for critical 0-day exploits.  Critical updates require
		# updates within a day.
		gcf_warn "The MAKEOPTS value may need to be reduced to increase goodput or"
		gcf_warn "don't use Full LTO or switch to ThinLTO instead."
	fi
}

gcf_report_cfi_preload() {
	local found_cef=0
	found_cef=$(find "${D}" -name "libcef.so" 2>/dev/null 1>/dev/null | wc -l)

	if [[ "${REQUIRES_CFI_PRELOAD}" == "1" ]] ; then
gcf_warn "Prebuilt packages linking to this package require"
gcf_warn "LD_PRELOAD=\"/usr/lib/clang/14.0.0/lib/linux/libclang_rt.ubsan_standalone-x86_64.so\""
gcf_warn "be set as an environment variable before running, replacing the LLVM"
gcf_warn "version and ARCH.  See \`equery f sys-libs/compiler-rt-sanitizers\` for"
gcf_warn "details.  Using a wrapper script for the app helps."
	fi
	if [[ "${REQUIRES_CFI_PRELOAD_APP}" == "1" || "${MERGE_TYPE}" =~ "binary" ]] || (( ${found_cef} >= 1 )) ; then
gcf_warn "This package requires the following"
gcf_warn "LD_PRELOAD=\"/usr/lib/clang/14.0.0/lib/linux/libclang_rt.ubsan_standalone-x86_64.so\""
gcf_warn "be set as an environment variable before running, replacing the LLVM"
gcf_warn "version and ARCH.  See \`equery f sys-libs/compiler-rt-sanitizers\` for"
gcf_warn "details.  Using a wrapper script for the app helps."
	fi
}

gcf_verify_cfi() {
	[[ "${DISABLE_CFI_VERIFY}" == "1" ]] && return
	[[ "${GCF_CFI}" == "1" ]] || return

	# Strip may interfere with CFI
	for f in $(find "${ED}" -name "*.so*") ; do
		local is_so=0
		file "${f}" | grep -q -e "ELF.*shared object" && is_so=1

		if (( ${is_so} == 1 )) ; then
			if grep -E -q -e "(__cfi_init|__cfi_check_fail)" "${f}" ; then
				:;
			else
gcf_error "${f} is not Clang CFI protected.  nostrip must be added to"
gcf_error "per-package FEATURES.  You may disable this check by adding"
gcf_error "DISABLE_CFI_VERIFY=1."
				die
			fi
		fi
	done
}

post_src_install() {
	gcf_info "Running post_src_install()"
	gcf_report_emerge_time
	gcf_report_cfi_preload
	gcf_verify_cfi
}
