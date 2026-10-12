# Helpers sourced inside the test containers (see tests/run.sh).
# Not meant to be run on your machine.

REPO="${HOME}/.config/rice"

# Stop the test case with a message
fail() {
	echo "ASSERT FAILED: $*"
	exit 1
}

# Run install.sh from / so it can't rely on the current directory.
# Fails if it exits with an error, logged a FAIL line, or if a command
# inside it printed an error (mv: cannot..., command not found...).
install() {
	local output status
	output=$(cd / && "${REPO}/install.sh" "$@" 2>&1)
	status=$?
	echo "${output}"
	(( status == 0 )) || fail "install.sh $* exited with code ${status}"
	# Remove colors before searching the log
	output=$(sed 's/\x1b\[[0-9;]*m//g' <<< "${output}")
	if grep -q '\[ *FAIL *\]' <<< "${output}"; then
		fail "install.sh logged: $(grep -m1 '\[ *FAIL *\]' <<< "${output}")"
	fi
	local errors='^(mv|cp|mkdir|ln|rm|ls|cat|xdg-user-dir): |command not found|syntax error|unbound variable'
	if grep -qE "${errors}" <<< "${output}"; then
		fail "a command failed inside install.sh: $(grep -m1 -E "${errors}" <<< "${output}")"
	fi
}

# Every config from the repo must be installed and identical
assert_installed() {
	local dir file
	for dir in "${DIRECTORIES[@]}"; do
		diff -r "${REPO}/${dir}" "${HOME}/.config/${dir}" || fail "~/.config/${dir} differs from the repo"
	done
	for file in "${FILES[@]}"; do
		diff "${REPO}/${file}" "${HOME}/${file}" || fail "~/${file} differs from the repo"
	done
}

# Some file in the backup folder must contain the given text
assert_backed_up() {
	grep -rqs "$1" "${HOME}/.config/${BACKUP_DIR}" || fail "'$1' not found in ~/.config/${BACKUP_DIR}"
}

# install.sh must never modify the repo itself
assert_repo_untouched() {
	diff -r /src "${REPO}" || fail "the repo copy was modified"
}

# Wallpapers must be installed and identical to the repo
assert_wallpapers_installed() {
	diff -r "${REPO}/wallpapers" "${HOME}/${WALLPAPERS_DIR}" || fail "~/${WALLPAPERS_DIR} differs from the repo"
}

# Every path written in the installed configs (~/..., $HOME/..., /home/...)
# must exist, otherwise a program will look for a file that isn't there.
assert_config_paths_exist() {
	local configs=() path real missing=""
	for dir in "${DIRECTORIES[@]}"; do
		configs+=("${HOME}/.config/${dir}")
	done

	while read -r path; do
		real="${path/#\~/${HOME}}"
		real="${real/#\$\{HOME\}/${HOME}}"
		real="${real/#\$HOME/${HOME}}"
		[[ -e "${real}" ]] || missing+=$'\n'"    ${path}"
	done < <(grep -rhoE '(~|\$\{?HOME\}?|/home/[^/[:space:]]+)/[^"'\''[:space:]);,]+' "${configs[@]}" | sort -u)

	[[ -z "${missing}" ]] || fail "paths used in the configs don't exist:${missing}"
}

# Nothing in the home should point to a file that doesn't exist
assert_no_broken_links() {
	local broken
	broken=$(find "${HOME}" -xtype l)
	[[ -z "${broken}" ]] || fail "broken symlinks: ${broken}"
}

# Simulate a user who already has their own config
make_old_config() {
	mkdir -p "${HOME}/.config/hypr"
	echo OLD_HYPR > "${HOME}/.config/hypr/hyprland.conf"
	echo OLD_EXTRA > "${HOME}/.config/hypr/only-in-old-config.conf"
	echo OLD_ZSHRC > "${HOME}/.zshrc"
}
