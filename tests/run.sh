#!/bin/bash

# Tests install.sh and uninstall.sh inside throwaway Docker containers.
#
#   tests/run.sh               run every test case
#   tests/run.sh backup        run only the cases whose name contains "backup"
#   tests/run.sh --shell       open a shell in a fresh container to explore by hand
#
# Your real files are never touched:
#   - the repo is mounted read-only at /src, each case works on a copy of it
#   - every case runs in a new container, deleted afterwards (--rm)
#   - containers have no network access (--network none)

set -u

#####################
##### VARIABLES #####
#####################

IMAGE="rice-test"
REPO="$(dirname "$(realpath "$0")")/.."

# Must match scripts/common.sh
DIRECTORIES=(hypr tmux nvim kitty waybar wlogout fuzzel)
FILES=(.zshrc)
BACKUP_DIR="config-back"	# inside ~/.config
WALLPAPERS_DIR=".local/share/wallpapers"	# inside ~

DEFAULT=$'\e[0m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'

#################
##### UTILS #####
#################

# Loaded in every container: the lists above + the helpers from tests/helpers.sh
HELPERS="$(declare -p DIRECTORIES FILES BACKUP_DIR WALLPAPERS_DIR)
source /src/tests/helpers.sh"

# Copies the repo where a real user would have it
SETUP='mkdir -p "$HOME/.config" && cp -r /src "$HOME/.config/rice"'

build_image() {
	echo "Building ${IMAGE} image (cached after the first time)..."
	docker build -q -t "${IMAGE}" "${REPO}/tests" >/dev/null || {
		echo "${RED}Docker build failed${DEFAULT}"
		exit 1
	}
}

# $1 code to run, fed on stdin after the setup and helpers
run_case() {
	docker run --rm --network none -i -v "${REPO}:/src:ro" "${IMAGE}" bash -s <<< "set -u
${HELPERS}
${SETUP}
${1}"
}

# Interactive shell with the helpers loaded. In it, fail only prints
# instead of exiting, so a failed assert doesn't close your shell.
open_shell() {
	docker run --rm --network none -it -e HELPERS="${HELPERS}" -v "${REPO}:/src:ro" "${IMAGE}" \
		bash -c "${SETUP}"' && printf "%s\nfail() { echo \"ASSERT FAILED: \$*\"; return 1; }\n" "$HELPERS" > ~/.helpers && exec bash --rcfile ~/.helpers'
}

######################
##### TEST CASES #####
######################

# Each case: a name and the code run inside a fresh container.
# A case passes if its code exits with 0, exit 77 means skipped.
CASE_NAMES=()
CASE_CODES=()
add_case() { CASE_NAMES+=("$1"); CASE_CODES+=("$2"); }

add_case "scripts have no syntax error" '
	for script in install.sh uninstall.sh diff.sh common.sh; do
		bash -n "$REPO/scripts/$script" || fail "bash -n reports a syntax error in $script"
	done
'

add_case "fresh install" '
	install
	assert_installed
	assert_repo_untouched
'

add_case "existing config gets backed up" '
	make_old_config
	install
	assert_backed_up OLD_HYPR
	assert_backed_up OLD_EXTRA
	assert_backed_up OLD_ZSHRC
	assert_installed	# also fails if old files were left mixed with the new ones
'

add_case "running twice is safe" '
	make_old_config
	install
	install
	assert_installed
	assert_wallpapers_installed	# cp -r into an existing folder nests it: wallpapers/wallpapers
	assert_backed_up OLD_HYPR	# the first backup must not be overwritten
	assert_backed_up OLD_ZSHRC
	assert_repo_untouched
'

add_case "each run gets its own backup folder" '
	make_old_config
	install
	echo RUN2_HYPR > "$HOME/.config/hypr/hyprland.conf"	# user edits the installed config
	install
	echo RUN3_HYPR > "$HOME/.config/hypr/hyprland.conf"
	install

	folders=()
	for marker in OLD_HYPR RUN2_HYPR RUN3_HYPR; do
		file=$(grep -rls "$marker" "$HOME/.config/$BACKUP_DIR")
		[[ -n "$file" ]] || fail "backup containing $marker is missing"
		# the backup must keep the structure: <backup>/hypr/hyprland.conf
		[[ "$file" == */hypr/hyprland.conf ]] || fail "$marker backed up as $file, expected .../hypr/hyprland.conf"
		folders+=("$(dirname "$(dirname "$file")")")
	done
	(( $(printf "%s\n" "${folders[@]}" | sort -u | wc -l) == 3 )) || fail "the 3 backups are not in 3 separate folders: ${folders[*]}"
'

add_case "uninstall restores the old config" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	make_old_config
	install
	uninstall
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "old hyprland.conf not restored"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "old .zshrc not restored"
	assert_no_broken_links
'

add_case "uninstall after a fresh install removes the rice" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	install
	uninstall
	for dir in "${DIRECTORIES[@]}"; do
		[[ ! -e "$HOME/.config/$dir" ]] || fail "~/.config/$dir still installed (no backup existed, so it should be removed)"
	done
	[[ ! -e "$HOME/$WALLPAPERS_DIR" ]] || fail "~/$WALLPAPERS_DIR still installed"
	[[ ! -e "$HOME/.zshrc" ]] || fail "~/.zshrc from the rice still installed"
'

add_case "install twice, uninstall restores the original config" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	make_old_config
	install
	install
	uninstall
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "~/.config/hypr is not the original config: $(head -c 80 "$HOME/.config/hypr/hyprland.conf")"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "~/.zshrc is not the original one"
'

add_case "existing wallpapers are backed up and restored" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	mkdir -p "$HOME/$WALLPAPERS_DIR"
	echo MY_WALLPAPER > "$HOME/$WALLPAPERS_DIR/mine.png"
	install
	assert_backed_up MY_WALLPAPER
	assert_wallpapers_installed	# also fails if mine.png was left mixed with the rice ones
	uninstall
	grep -qs MY_WALLPAPER "$HOME/$WALLPAPERS_DIR/mine.png" || fail "user wallpaper not restored"
	[[ ! -e "$HOME/$WALLPAPERS_DIR/Oneshot1.png" ]] || fail "rice wallpapers still there after uninstall"
'

add_case "uninstall twice keeps the user config" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	make_old_config
	install
	uninstall
	uninstall	# by mistake
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "user hyprland.conf deleted by the 2nd uninstall"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "user .zshrc deleted by the 2nd uninstall"
'

add_case "uninstall without install keeps the user config" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	make_old_config
	uninstall	# rice was never installed
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "user hyprland.conf deleted"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "user .zshrc deleted"
'

add_case "uninstall after editing the rice loses nothing" '
	[[ -x "$REPO/scripts/uninstall.sh" ]] || { echo "uninstall.sh not implemented yet"; exit 77; }
	make_old_config
	install
	echo "# my tweak" >> "$HOME/.config/hypr/hyprland.conf"	# user edits the installed rice
	echo "# my alias" >> "$HOME/.zshrc"
	uninstall
	[[ ! -e "$HOME/.config/hypr/hypr" ]] || fail "backup restored INSIDE the edited config: ~/.config/hypr/hypr"
	grep -qs "my tweak" "$HOME/.config/hypr/hyprland.conf" || fail "user edit in hyprland.conf lost"
	grep -qs "my alias" "$HOME/.zshrc" || fail "user edit in .zshrc lost (overwritten by the backup)"
	assert_backed_up OLD_HYPR	# not restored, so the backup must still be there
	assert_backed_up OLD_ZSHRC
'

add_case "a backup with only .zshrc is kept" '
	echo OLD_ZSHRC > "$HOME/.zshrc"	# user has a .zshrc but no other config
	install
	assert_backed_up OLD_ZSHRC
'

# The configs reference wallpapers and assets by path:
# after installing, those paths must exist.
add_case "wallpapers + paths used in configs exist" '
	install
	assert_wallpapers_installed
	assert_config_paths_exist
'

add_case "no broken symlinks after install" '
	make_old_config
	install
	assert_no_broken_links
'

#####################
###### FIREFOX ######
#####################

# Skip the Firefox cases until the scripts actually call the functions
FF_INSTALL_GUARD='grep -qE "^[[:space:]]*ff_install[[:space:]]*$" "$REPO/scripts/install.sh" || { echo "ff_install not called yet"; exit 77; }
'
FF_UNINSTALL_GUARD='grep -qE "^[[:space:]]*ff_uninstall[[:space:]]*$" "$REPO/scripts/uninstall.sh" || { echo "ff_uninstall not called yet"; exit 77; }
'

add_case "firefox: no profile, install skips it without failing" "$FF_INSTALL_GUARD"'
	install	# fails if install.sh logged a FAIL line
	[[ ! -e "$HOME/.mozilla" ]] || fail "~/.mozilla was created, Firefox was never launched"
	[[ ! -e "$HOME/.config/mozilla" ]] || fail "~/.config/mozilla was created, Firefox was never launched"
'

add_case "firefox: installs into the profile in ~/.mozilla" "$FF_INSTALL_GUARD"'
	ff="$HOME/.mozilla/firefox"
	make_ff_profile "$ff"
	install
	assert_ff_installed "$ff/$FF_PROFILE"
	assert_ff_not_installed "$ff/$FF_DECOY"	# Profile0 / Default=1 is not the one Firefox uses
	grep -qs browser.startup.page "$ff/$FF_PROFILE/prefs.js" || fail "prefs.js was modified or removed"
'

add_case "firefox: installs into the profile in ~/.config/mozilla" "$FF_INSTALL_GUARD"'
	ff="$HOME/.config/mozilla/firefox"
	make_ff_profile "$ff"
	install
	assert_ff_installed "$ff/$FF_PROFILE"
	assert_ff_not_installed "$ff/$FF_DECOY"
'

add_case "firefox: uses ~/.mozilla when both locations exist" "$FF_INSTALL_GUARD"'
	make_ff_profile "$HOME/.mozilla/firefox"
	make_ff_profile "$HOME/.config/mozilla/firefox"
	install
	assert_ff_installed "$HOME/.mozilla/firefox/$FF_PROFILE"	# Firefox keeps using the old location if it exists
	assert_ff_not_installed "$HOME/.config/mozilla/firefox/$FF_PROFILE"
'

add_case "firefox: follows XDG_CONFIG_HOME" "$FF_INSTALL_GUARD"'
	export XDG_CONFIG_HOME="$HOME/xdg"
	ff="$XDG_CONFIG_HOME/mozilla/firefox"
	make_ff_profile "$ff"
	install
	assert_ff_installed "$ff/$FF_PROFILE"
'

add_case "firefox: absolute profile path (IsRelative=0)" "$FF_INSTALL_GUARD"'
	# Profile outside the Firefox dir, referenced by its full path
	ff="$HOME/.mozilla/firefox"
	elsewhere="$HOME/my-profiles/custom"
	mkdir -p "$ff" "$elsewhere"
	printf "%s\n" "[Profile0]" "Name=custom" "IsRelative=0" "Path=$elsewhere" "Default=1" "" \
		"[Install4F96D1932A9F858E]" "Default=$elsewhere" "Locked=1" > "$ff/profiles.ini"
	install
	assert_ff_installed "$elsewhere"
	[[ ! -e "$ff$elsewhere" ]] || fail "absolute path was glued to the Firefox dir: $ff$elsewhere"
'

add_case "firefox: running twice is safe" "$FF_INSTALL_GUARD"'
	ff="$HOME/.mozilla/firefox"
	make_ff_profile "$ff"
	install
	install
	assert_ff_installed "$ff/$FF_PROFILE"	# cp -r into an existing chrome/ nests it: chrome/chrome
'

add_case "firefox: existing user.js and chrome are backed up" "$FF_INSTALL_GUARD"'
	p="$HOME/.mozilla/firefox/$FF_PROFILE"
	make_ff_profile "$HOME/.mozilla/firefox"
	echo "// OLD_USERJS" > "$p/user.js"
	mkdir "$p/chrome"
	echo "/* OLD_CHROME */" > "$p/chrome/userChrome.css"
	echo "/* OLD_EXTRA */" > "$p/chrome/only-in-old.css"
	install
	assert_backed_up OLD_USERJS
	assert_backed_up OLD_CHROME
	assert_backed_up OLD_EXTRA
	assert_ff_installed "$p"	# also fails if only-in-old.css was left mixed with the rice
'

add_case "firefox: uninstall restores the old user.js and chrome" "$FF_INSTALL_GUARD$FF_UNINSTALL_GUARD"'
	p="$HOME/.mozilla/firefox/$FF_PROFILE"
	make_ff_profile "$HOME/.mozilla/firefox"
	echo "// OLD_USERJS" > "$p/user.js"
	mkdir "$p/chrome"
	echo "/* OLD_CHROME */" > "$p/chrome/userChrome.css"
	install
	uninstall
	grep -qs OLD_USERJS "$p/user.js" || fail "old user.js not restored"
	grep -qs OLD_CHROME "$p/chrome/userChrome.css" || fail "old chrome/userChrome.css not restored"
	[[ ! -e "$p/chrome/chrome" ]] || fail "backup restored INSIDE chrome/: chrome/chrome"
	leftover=$(find "$HOME/.config/$BACKUP_DIR" -mindepth 1 2>/dev/null)
	[[ -z "$leftover" ]] || fail "backup folder not cleaned up after restoring everything: $leftover"
'

add_case "firefox: uninstall after a fresh install removes only the rice" "$FF_INSTALL_GUARD$FF_UNINSTALL_GUARD"'
	p="$HOME/.mozilla/firefox/$FF_PROFILE"
	make_ff_profile "$HOME/.mozilla/firefox"
	install
	uninstall
	assert_ff_not_installed "$p"
	grep -qs browser.startup.page "$p/prefs.js" || fail "uninstall touched prefs.js"
	[[ -f "$HOME/.mozilla/firefox/profiles.ini" ]] || fail "uninstall removed profiles.ini"
'

##################
###### DIFF ######
##################

add_case "diff: fresh install matches the repo" '
	install
	run_diff
	(( DIFF_STATUS == 0 )) || fail "diff.sh exited with ${DIFF_STATUS} right after installing"
	! grep -qE "\[ (DIFF|MISSING) \]" <<< "$DIFF_OUTPUT" || fail "diff.sh reports a difference right after installing"
'

add_case "diff: reports what is not installed" '
	run_diff
	(( DIFF_STATUS == 1 )) || fail "diff.sh exited with ${DIFF_STATUS}, expected 1"
	grep -q "\[ MISSING \] ~/.config/hypr" <<< "$DIFF_OUTPUT" || fail "missing ~/.config/hypr not reported"
	grep -q "\[ MISSING \] ~/.zshrc" <<< "$DIFF_OUTPUT" || fail "missing ~/.zshrc not reported"
'

add_case "diff: reports edited, added and removed files" '
	install
	echo "# my tweak" >> "$HOME/.config/hypr/hyprland.conf"
	echo extra > "$HOME/.config/hypr/mine.conf"
	rm "$HOME/.config/kitty/kitty.conf"
	run_diff
	(( DIFF_STATUS == 1 )) || fail "diff.sh exited with ${DIFF_STATUS}, expected 1"
	grep -qE "modified +hyprland.conf" <<< "$DIFF_OUTPUT" || fail "edited hyprland.conf not reported"
	grep -qE "only installed +mine.conf" <<< "$DIFF_OUTPUT" || fail "added mine.conf not reported"
	grep -qE "only in repo +kitty.conf" <<< "$DIFF_OUTPUT" || fail "removed kitty.conf not reported"
	grep -q "\[ SAME \] ~/.config/tmux" <<< "$DIFF_OUTPUT" || fail "untouched ~/.config/tmux not reported as same"
'

add_case "diff: --full shows the changed lines" '
	install
	echo "# my tweak" >> "$HOME/.config/hypr/hyprland.conf"
	run_diff --full
	grep -q "^+# my tweak" <<< "$DIFF_OUTPUT" || fail "added line not in the full diff"
'

add_case "diff: never changes a file" '
	make_old_config
	install
	echo "# my tweak" >> "$HOME/.config/hypr/hyprland.conf"
	before=$(find "$HOME" -printf "%p %s %T@\n" | sort)
	run_diff >/dev/null
	run_diff --full >/dev/null
	after=$(find "$HOME" -printf "%p %s %T@\n" | sort)
	[[ "$before" == "$after" ]] || fail "diff.sh changed files: $(diff <(echo "$before") <(echo "$after") | head -5)"
'

add_case "diff: checks the Firefox profile" "$FF_INSTALL_GUARD"'
	p="$HOME/.mozilla/firefox/$FF_PROFILE"
	make_ff_profile "$HOME/.mozilla/firefox"
	install
	echo "// my pref" >> "$p/user.js"
	run_diff
	grep -q "\[ DIFF \] ~/.mozilla/firefox/$FF_PROFILE/user.js" <<< "$DIFF_OUTPUT" || fail "edited user.js not reported"
	grep -q "\[ SAME \] ~/.mozilla/firefox/$FF_PROFILE/chrome" <<< "$DIFF_OUTPUT" || fail "untouched chrome/ not reported as same"
'

################
##### MAIN #####
################

command -v docker >/dev/null || { echo "${RED}docker is not installed${DEFAULT}"; exit 1; }
build_image

if [[ "${1:-}" == "--shell" ]]; then
	echo "Fresh container, repo copied to ~/.config/rice. Helpers from tests/helpers.sh are loaded."
	echo "Type 'exit' to leave, everything is deleted afterwards."
	open_shell
	exit
fi

filter="${1:-}"
passed=0 failed=0 skipped=0

for i in "${!CASE_NAMES[@]}"; do
	name="${CASE_NAMES[$i]}"
	[[ -n "$filter" && "$name" != *"$filter"* ]] && continue

	output=$(run_case "${CASE_CODES[$i]}" 2>&1)
	status=$?

	if (( status == 0 )); then
		echo "[${GREEN} PASS ${DEFAULT}] ${name}"
		(( passed++ ))
	elif (( status == 77 )); then
		echo "[${YELLOW} SKIP ${DEFAULT}] ${name}: ${output##*$'\n'}"
		(( skipped++ ))
	else
		echo "[${RED} FAIL ${DEFAULT}] ${name}"
		# Show the container output only for failures, indented
		sed 's/^/        | /' <<< "${output}" | tail -n 25
		(( failed++ ))
	fi
done

echo
echo "${passed} passed, ${failed} failed, ${skipped} skipped"
(( failed == 0 ))
