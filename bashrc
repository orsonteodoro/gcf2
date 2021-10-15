# Copy the following inside /etc/portage/bashrc:

_gcf_translate_to_gcc_retpoline() {
	einfo "Auto translating retpoline for gcc"
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
}

_gcf_translate_to_clang_retpoline() {
	einfo "Auto translating retpoline for clang"
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g")
}

gcf_retpoline_translate() {
	if [[ -n "${USE_CLANG}" && "${USE_CLANG}" == "1" ]] ; then
		# explicit
		_translate_to_clang_retpoline
	elif [[ -n "${USE_GCC}" && "${USE_GCC}" == "1" ]] ; then
		# explicit
		_translate_to_gcc_retpoline
	elif [[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_translate_to_clang_retpoline
	elif [[ "${CC}" =~ "gcc" || "${CXX}" =~ "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		einfo "Removing -fno-plt from ${C,CXX,LD}FLAGS"
		export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-fno-plt||g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-fno-plt||g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-fno-plt||g")
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-vec
		-fopt-info-inline
		-frename_registers
	)

	if [[ -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ]] ; then
		einfo "Removing ${gcc_flags[@]} from ${C,CXX,LD}FLAGS"
		for f in ${gcc_flags[@]} ; do
			export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${f}||g")
			export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${f}||g")
			export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|${f}||g")
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ -n "${DISABLE_Z_RETPOLINEPLT}" && "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		einfo "Removing -Wl,-z,retpolineplt from LDFLAGS"
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
}

pre_src_configure()
{
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
}
