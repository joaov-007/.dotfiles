#!/bin/sh
# sync-apps.sh - sync allowlisted folders to an allowlist of remote hosts and
# dry-check the container pipeline without deploying anything.
#
# Design notes:
#   - Hosts and the folders they may receive come from an allowlist file, never
#     from the command line alone.
#   - Every SSH call is non-interactive (BatchMode=yes) so it works headless.
#   - "deploy" is a deliberate stub. Fill in cmd_deploy() when the deployment
#     design is final; the pipeline will not start containers before that.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -P -- "$SCRIPT_DIR/../../.." && pwd -P)
LOCAL_HOST=$(uname -n)
LOCAL_HOST=${LOCAL_HOST%%.*}

APPS_ROOT=${APPS_ROOT:-$REPO_ROOT/apps}
ALLOWLIST=${APPS_ALLOWLIST:-$SCRIPT_DIR/../config/remote-hosts.allow}
REMOTE_APPS_REL=${APPS_REMOTE_APPS_REL:-apps}
SSH_TIMEOUT=${APPS_SSH_TIMEOUT:-10}

EXIT_USAGE=1
EXIT_CHECK=1
EXIT_VALIDATE=2
EXIT_TEST=3
EXIT_DEPLOY_DISABLED=4
EXIT_LINT=5

COMMAND=""
VERBOSE=1
QUIET=0
DRY_RUN=0
DO_PULL=1
SYNC_DELETE=0
LOCAL_ONLY=0
WITH_DEPLOY=0
GIT_PULL=0
COMPOSE_BIN=""

SSH_OPTS="-T -o BatchMode=yes -o ConnectTimeout=$SSH_TIMEOUT -o ServerAliveInterval=15 -o ServerAliveCountMax=3"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/sync-apps.XXXXXX")
trap 'rm -rf -- "$TMP_ROOT"' 0
FOLDERS_DIR=$TMP_ROOT/folders
ALLOWED_FILE=$TMP_ROOT/allowed
HOST_ARGS_FILE=$TMP_ROOT/host-args
SELECTED_FILE=$TMP_ROOT/selected
APP_HOSTS_FILE=$TMP_ROOT/app-hosts
FOUND_FILE=$TMP_ROOT/found
mkdir -p "$FOLDERS_DIR"
: >"$ALLOWED_FILE"
: >"$HOST_ARGS_FILE"
: >"$SELECTED_FILE"
: >"$APP_HOSTS_FILE"

usage() {
    cat <<'EOF'
Usage: sync-apps.sh [OPTIONS] <command> [HOST...]

Sync the folders allowed for a remote host, then run the container pipeline
headlessly for hosts that receive apps/. Nothing is ever started on the
remote hosts.

Commands:
  hosts                 List the allowlisted hosts and their folders.
  check   [HOST...]     Preflight: tools, source dirs, SSH, remote podman.
  lint    [HOST...]     yamllint every YAML file under apps/<host>/ (local).
  sync    [HOST...]     rsync every folder allowlisted for each host.
  validate [HOST...]    podman-compose config -q, locally and remotely.
  test    [HOST...]     Pull the latest images and dry-run "up" (no containers).
  pipeline [HOST...]    check -> lint -> sync -> validate -> test -> deploy (stub).

Options:
  -n, --dry-run         Print what would happen; do not change anything.
      --delete          Allow rsync to delete remote files (destructive).
      --no-pull         Skip "podman-compose pull" during test.
      --local           Run against this machine only (no SSH, no sync).
      --git-pull        Fast-forward the dotfiles repo first (clean tree only).
      --with-deploy     Call the deploy stub (exits 4 until implemented).
  -q, --quiet           Only print warnings and errors.
  -h, --help            Show this help.

Environment:
  APPS_ROOT             Local apps root          (default: <repo>/apps)
  APPS_ALLOWLIST        Allowlist file          (default: scripts/app/config/remote-hosts.allow)
  APPS_REMOTE_APPS_REL  Remote path, relative to the remote home
                                                (default: apps)
  APPS_SSH_TIMEOUT      SSH ConnectTimeout      (default: 10)
  APPS_COMPOSE_BIN      Compose command         (default: podman-compose, then podman compose)

Allowlist format:
  <host> <folder> [folder...] per line. Blank lines and text after # are
  ignored. Host: [A-Za-z0-9][A-Za-z0-9._-]*
  Folder: top-level repo directory, [A-Za-z0-9][A-Za-z0-9._-]*
  apps -> <host>:~/apps/<host>/, any other folder -> <host>:~/<folder>/

Examples:
  ./sync-apps.sh hosts
  ./sync-apps.sh check app.duck admin.duck
  ./sync-apps.sh sync --dry-run admin.duck
  ./sync-apps.sh pipeline --no-pull app.duck
  ./sync-apps.sh pipeline --local
EOF
}

now() {
    date +%H:%M:%S
}

log() {
    level=$1
    shift
    if [ "$QUIET" -eq 1 ] && [ "$level" != WARN ] && [ "$level" != ERROR ]; then
        return 0
    fi
    printf '%s %-5s %s\n' "$(now)" "$level" "$*" >&2
}

info() { log INFO "$*"; }
warn() { log WARN "$*"; }
err() { log ERROR "$*"; }
die() {
    err "$*"
    exit "$EXIT_USAGE"
}

section() {
    [ "$QUIET" -eq 1 ] && return 0
    printf '\n==> %s\n' "$*" >&2
}

run() {
    if [ "$VERBOSE" -eq 1 ] && [ "$QUIET" -eq 0 ]; then
        printf '%s CMD   %s\n' "$(now)" "$*" >&2
    fi
    "$@"
}

pkg_of() {
    case $1 in
    bash) printf 'bash\n' ;;
    find) printf 'findutils\n' ;;
    git) printf 'git\n' ;;
    podman) printf 'podman\n' ;;
    podman-compose) printf 'podman-compose\n' ;;
    rsync) printf 'rsync\n' ;;
    sort) printf 'coreutils\n' ;;
    ssh) printf 'openssh\n' ;;
    yamllint) printf 'yamllint\n' ;;
    *) printf '%s\n' "$1" ;;
    esac
}

install_hint() {
    if command -v pacman >/dev/null 2>&1; then
        printf 'sudo pacman -S --needed %s' "$*"
    elif command -v apt-get >/dev/null 2>&1; then
        printf 'sudo apt-get install -y %s' "$*"
    elif command -v dnf >/dev/null 2>&1; then
        printf 'sudo dnf install -y %s' "$*"
    else
        printf 'install these packages: %s' "$*"
    fi
}

require_tools() {
    rt_missing=""
    rt_packages=""

    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            continue
        fi
        rt_missing="$rt_missing $cmd"
        pkg=$(pkg_of "$cmd")
        case " $rt_packages " in
        *" $pkg "*) ;;
        *) rt_packages="$rt_packages $pkg" ;;
        esac
    done

    [ -n "$rt_missing" ] || return 0

    for cmd in $rt_missing; do
        err "missing command: ${cmd} (package: $(pkg_of "$cmd"))"
    done
    # rt_packages is a list of package names on purpose.
    # shellcheck disable=SC2086
    err "install with: $(install_hint $rt_packages)"
    return 1
}

validate_host_name() {
    case $1 in
    '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*)
        die "invalid host '$1': use a plain SSH alias or DNS name"
        ;;
    esac
}

validate_folder_name() {
    case $1 in
    '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*)
        die "invalid folder '$1': use a top-level directory name"
        ;;
    esac
    [ -d "$REPO_ROOT/$1" ] ||
        die "allowlisted folder does not exist: ${REPO_ROOT}/$1"
}

load_allowlist() {
    [ "$LOCAL_ONLY" -eq 1 ] && return 0

    [ -r "$ALLOWLIST" ] || die "allowlist not readable: ${ALLOWLIST}"

    : >"$ALLOWED_FILE"
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%%#*}

        set -f
        # shellcheck disable=SC2086
        set -- $line
        set +f

        [ "$#" -gt 0 ] || continue
        host=$1
        shift

        validate_host_name "$host"
        [ "$#" -gt 0 ] ||
            die "allowlist entry has no folders: '${host}'"

        if ! grep -Fqx "$host" "$ALLOWED_FILE"; then
            printf '%s\n' "$host" >>"$ALLOWED_FILE"
            : >"$FOLDERS_DIR/$host"
        else
            warn "duplicate allowlist host merged: ${host}"
        fi

        for folder in "$@"; do
            validate_folder_name "$folder"
            if grep -Fqx "$folder" "$FOLDERS_DIR/$host"; then
                continue
            fi
            printf '%s\n' "$folder" >>"$FOLDERS_DIR/$host"
        done
    done <"$ALLOWLIST"

    [ -s "$ALLOWED_FILE" ] || die "allowlist is empty: ${ALLOWLIST}"
}

host_folders() {
    [ -f "$FOLDERS_DIR/$1" ] && cat "$FOLDERS_DIR/$1"
    return 0
}

host_has_folder() {
    if [ -f "$FOLDERS_DIR/$1" ] && grep -Fqx "$2" "$FOLDERS_DIR/$1"; then
        return 0
    fi
    return 1
}

host_has_apps() {
    host_has_folder "$1" apps
}

select_app_hosts() {
    : >"$APP_HOSTS_FILE"
    while IFS= read -r host; do
        if host_has_apps "$host"; then
            printf '%s\n' "$host" >>"$APP_HOSTS_FILE"
        fi
    done <"$SELECTED_FILE"
    return 0
}

select_hosts() {
    : >"$SELECTED_FILE"

    if [ "$LOCAL_ONLY" -eq 1 ]; then
        [ ! -s "$HOST_ARGS_FILE" ] || die "--local does not accept host arguments"
        printf '%s\n' "$LOCAL_HOST" >"$SELECTED_FILE"
        # No allowlist is read in local mode; the only folder that makes sense
        # is this machine's own app stack.
        if [ -d "$APPS_ROOT/$LOCAL_HOST" ]; then
            printf 'apps\n' >"$FOLDERS_DIR/$LOCAL_HOST"
        fi
        return 0
    fi

    if [ ! -s "$HOST_ARGS_FILE" ]; then
        cp "$ALLOWED_FILE" "$SELECTED_FILE"
        return 0
    fi

    while IFS= read -r host; do
        validate_host_name "$host"
        if ! grep -Fqx "$host" "$ALLOWED_FILE"; then
            die "host '${host}' is not in the allowlist (${ALLOWLIST})"
        fi
        printf '%s\n' "$host" >>"$SELECTED_FILE"
    done <"$HOST_ARGS_FILE"
}

detect_compose() {
    if [ -n "${APPS_COMPOSE_BIN:-}" ]; then
        COMPOSE_BIN=$APPS_COMPOSE_BIN
        first=${COMPOSE_BIN%% *}
        command -v "$first" >/dev/null 2>&1 ||
            die "compose command not found: ${first} (package: $(pkg_of "$first"))"
    elif command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_BIN=podman-compose
    elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        COMPOSE_BIN="podman compose"
    else
        die "no compose provider found (missing package: podman-compose; or docker-compose for 'podman compose')"
    fi
}

compose() {
    # COMPOSE_BIN is either "podman-compose" or "podman compose".
    # shellcheck disable=SC2086
    $COMPOSE_BIN "$@"
}

local_check_sync_tools() {
    if [ "$GIT_PULL" -eq 1 ]; then
        require_tools rsync ssh git || exit "$EXIT_USAGE"
    else
        require_tools rsync ssh || exit "$EXIT_USAGE"
    fi
}

local_check_lint_tools() {
    require_tools find sort yamllint || exit "$EXIT_USAGE"
}

local_check_tools() {
    need_apps=0
    while IFS= read -r host; do
        if host_has_apps "$host"; then
            need_apps=1
        fi
    done <"$SELECTED_FILE"

    if [ "$GIT_PULL" -eq 1 ]; then
        require_tools find sort rsync git || exit "$EXIT_USAGE"
    else
        require_tools find sort rsync || exit "$EXIT_USAGE"
    fi
    if [ "$need_apps" -eq 1 ]; then
        require_tools podman || exit "$EXIT_USAGE"
    fi
    if [ "$LOCAL_ONLY" -eq 0 ]; then
        require_tools ssh || exit "$EXIT_USAGE"
    fi
    if [ "$need_apps" -eq 1 ]; then
        detect_compose
    fi
    return 0
}

app_dir_for() {
    printf '%s/%s' "$APPS_ROOT" "$1"
}

remote_app_dir_for() {
    printf '%s/%s' "$REMOTE_APPS_REL" "$1"
}

discover_compose() {
    : >"$FOUND_FILE"
    [ -d "$1" ] || return 1
    find "$1" -maxdepth 3 -type f \
        \( -name compose.yaml -o -name compose.yml -o -name docker-compose.yml \) \
        -print | LC_ALL=C sort >"$FOUND_FILE"
    [ -s "$FOUND_FILE" ]
}

discover_yaml() {
    : >"$FOUND_FILE"
    [ -d "$1" ] || return 1
    find "$1" -maxdepth 3 -type f \
        \( -name '*.yaml' -o -name '*.yml' \) \
        -not -path '*/data/*' -print | LC_ALL=C sort >"$FOUND_FILE"
    [ -s "$FOUND_FILE" ]
}

git_pull_latest() {
    section "git: fast-forward ${REPO_ROOT}"

    if [ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=no)" ]; then
        warn "tracked files have local changes; refusing --git-pull"
        return 0
    fi

    run git -C "$REPO_ROOT" fetch --prune
    run git -C "$REPO_ROOT" pull --ff-only
}

ssh_probe() {
    # shellcheck disable=SC2086
    run ssh $SSH_OPTS "$1" sh -s -- "${2:-1}" <<'REMOTE'
set -eu
need_apps=$1
failed=0
packages=

add_package() {
	case " $packages " in
	*" $1 "*) ;;
	*) packages="$packages $1" ;;
	esac
}

check_tool() {
	cmd=$1
	pkg=$2
	if command -v "$cmd" >/dev/null 2>&1; then
		printf 'ok: %s (%s)\n' "$cmd" "$(command -v "$cmd")"
	else
		printf 'missing: %s (package: %s)\n' "$cmd" "$pkg" >&2
		add_package "$pkg"
		failed=1
	fi
}

check_tool rsync rsync

if [ "$need_apps" -eq 1 ]; then
	check_tool podman podman

	if command -v podman-compose >/dev/null 2>&1; then
		printf 'ok: podman-compose\n'
	elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
		printf 'ok: podman compose\n'
	else
		printf 'missing: compose provider (package: podman-compose, or docker-compose)\n' >&2
		add_package podman-compose
		failed=1
	fi
fi

if [ -n "$packages" ]; then
	if command -v pacman >/dev/null 2>&1; then
		printf 'install with: sudo pacman -S --needed%s\n' "$packages" >&2
	elif command -v apt-get >/dev/null 2>&1; then
		printf 'install with: sudo apt-get install -y%s\n' "$packages" >&2
	elif command -v dnf >/dev/null 2>&1; then
		printf 'install with: sudo dnf install -y%s\n' "$packages" >&2
	else
		printf 'missing packages:%s\n' "$packages" >&2
	fi
fi

if [ "$need_apps" -eq 1 ]; then
	if podman info >/dev/null 2>&1; then
		rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf 'unknown')
		printf 'ok: podman info (rootless=%s)\n' "$rootless"
	else
		printf 'fail: podman info (is the podman socket running?)\n' >&2
		failed=1
	fi
fi

exit "$failed"
REMOTE
}

folder_src_for() {
    host=$1
    folder=$2
    if [ "$folder" = apps ]; then
        app_dir_for "$host"
    else
        printf '%s/%s' "$REPO_ROOT" "$folder"
    fi
}

folder_dest_for() {
    host=$1
    folder=$2
    if [ "$folder" = apps ]; then
        remote_app_dir_for "$host"
    else
        printf '%s' "$folder"
    fi
}

check_source() {
    host=$1
    with_apps=0
    section "check: ${host}"

    if host_has_apps "$host"; then
        with_apps=1
    fi

    if [ ! -s "$FOLDERS_DIR/$host" ]; then
        err "no folders allowlisted for ${host}"
        return "$EXIT_CHECK"
    fi

    while IFS= read -r folder; do
        src=$(folder_src_for "$host" "$folder")
        if [ ! -d "$src" ]; then
            err "source directory missing: ${src}"
            return "$EXIT_CHECK"
        fi
        info "source: ${src#"$REPO_ROOT"/}"

        [ "$folder" = apps ] || continue
        if discover_compose "$src"; then
            info "compose files: $(wc -l <"$FOUND_FILE" | tr -d ' ')"
            while IFS= read -r file; do
                printf '    %s\n' "${file#"$REPO_ROOT"/}" >&2
            done <"$FOUND_FILE"
        else
            warn "no compose files under ${src}"
        fi
    done <"$FOLDERS_DIR/$host"

    if [ "$LOCAL_ONLY" -eq 1 ]; then
        return 0
    fi

    while IFS= read -r folder; do
        info "remote: ${host}:$(folder_dest_for "$host" "$folder")/"
    done <"$FOLDERS_DIR/$host"

    if ! ssh_probe "$host" "$with_apps"; then
        err "remote preflight failed: ${host}"
        return "$EXIT_CHECK"
    fi
    return 0
}

sync_folder() {
    host=$1
    folder=$2
    src=$(folder_src_for "$host" "$folder")
    dest=$(folder_dest_for "$host" "$folder")

    section "sync: ${host} ${folder}"
    if [ ! -d "$src" ]; then
        err "source directory missing: ${src}"
        return "$EXIT_CHECK"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        info "dry-run: would create ${host}:${dest}/"
    else
        # shellcheck disable=SC2086
        run ssh $SSH_OPTS "$host" sh -s -- "$dest" <<'REMOTE'
set -eu
mkdir -p "$1"
REMOTE
    fi

    set -- -av --itemize-changes --human-readable --protect-args --compress
    if [ "$SYNC_DELETE" -eq 1 ]; then
        set -- "$@" --delete
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        set -- "$@" --dry-run
    fi

    set -- "$@" --exclude=.git/ --exclude=.DS_Store --exclude='*.log' \
        --exclude='*.tmp' --exclude='*.swp'

    if [ "$folder" = apps ]; then
        set -- "$@" --exclude=data/
    else
        # Build and cache output in scripts/ is local, never worth shipping.
        set -- "$@" --exclude=.ruff_cache/ --exclude=.pytest_cache/ \
            --exclude=.benchmarks/ --exclude=__pycache__/ \
            --exclude=node_modules/ --exclude=target/ --exclude='*.pyc'
    fi

    run rsync "$@" \
        -e "ssh -T -o BatchMode=yes -o ConnectTimeout=${SSH_TIMEOUT}" \
        "${src}/" "${host}:${dest}/"
}

sync_host() {
    host=$1
    if [ ! -s "$FOLDERS_DIR/$host" ]; then
        warn "no folders allowlisted for ${host}; nothing to sync"
        return 0
    fi

    while IFS= read -r folder; do
        if ! sync_folder "$host" "$folder"; then
            return "$EXIT_CHECK"
        fi
    done <"$FOLDERS_DIR/$host"
    return 0
}

lint_local_dir() {
    dir=$1
    failures=0

    if ! discover_yaml "$dir"; then
        warn "no YAML files under ${dir}; lint skipped"
        return 0
    fi

    while IFS= read -r file; do
        base=${file##*/}
        section "lint: ${file#"$REPO_ROOT"/}"
        if run yamllint -d relaxed -- "$file"; then
            info "lint ok: ${base}"
        else
            err "lint failed: ${file}"
            failures=1
        fi
    done <"$FOUND_FILE"

    return "$failures"
}

validate_local_dir() {
    dir=$1
    failures=0

    if ! discover_compose "$dir"; then
        warn "no compose files under ${dir}; validation skipped"
        return 0
    fi

    while IFS= read -r file; do
        base=${file##*/}
        section "validate: ${file#"$REPO_ROOT"/}"
        if (cd "$(dirname -- "$file")" && run compose -f "$base" config -q); then
            info "valid: ${base}"
        else
            err "invalid compose file: ${file}"
            failures=1
        fi
    done <"$FOUND_FILE"

    return "$failures"
}

test_local_dir() {
    dir=$1
    failures=0

    if ! discover_compose "$dir"; then
        warn "no compose files under ${dir}; test skipped"
        return 0
    fi

    while IFS= read -r file; do
        base=${file##*/}
        section "test: ${file#"$REPO_ROOT"/}"

        if [ "$DRY_RUN" -eq 1 ]; then
            info "dry-run: would pull images and dry-run up for ${base}"
            continue
        fi

        if [ "$DO_PULL" -eq 1 ]; then
            if ! (cd "$(dirname -- "$file")" && run compose -f "$base" pull); then
                err "image pull failed: ${file}"
                failures=1
                continue
            fi
        else
            info "pull skipped (--no-pull)"
        fi

        # --dry-run never creates containers or binds ports; it is the safe
        # equivalent of "would this stack come up" in a headless check.
        if ! (cd "$(dirname -- "$file")" && run compose --dry-run -f "$base" up -d); then
            err "up simulation failed: ${file}"
            failures=1
        fi
    done <"$FOUND_FILE"

    return "$failures"
}

remote_stage() {
    host=$1
    stage=$2
    pull=${3:-1}
    dir=$(remote_app_dir_for "$host")

    section "${stage}: ${host}:${dir}"
    # shellcheck disable=SC2086
    run ssh $SSH_OPTS "$host" sh -s -- "$dir" "$stage" "$pull" <<'REMOTE'
set -eu
dir=$1
stage=$2
pull=$3

if [ ! -d "$dir" ]; then
	printf 'missing remote directory: %s\n' "$dir" >&2
	exit 1
fi

cd "$dir"

if command -v podman-compose >/dev/null 2>&1; then
	compose_bin=podman-compose
elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
	compose_bin="podman compose"
else
	printf 'no compose provider on this host\n' >&2
	exit 1
fi

run_compose() {
	# shellcheck disable=SC2086
	$compose_bin "$@"
}

list=$(mktemp)
trap 'rm -f -- "$list"' 0
find . -maxdepth 3 -type f \
	\( -name compose.yaml -o -name compose.yml -o -name docker-compose.yml \) \
	-print | LC_ALL=C sort >"$list"

if [ ! -s "$list" ]; then
	printf 'no compose files under %s\n' "$dir" >&2
	exit 0
fi

failed=0
while IFS= read -r file; do
	base=${file##*/}
	sub=$(dirname -- "$file")
	printf '-> %s\n' "${file#./}"

	case $stage in
	validate)
		if (cd "$sub" && run_compose -f "$base" config -q); then
			printf '   ok: %s\n' "$base"
		else
			printf '   failed: %s\n' "$file" >&2
			failed=1
		fi
		;;
	test)
		if [ "$pull" -eq 1 ]; then
			if ! (cd "$sub" && run_compose -f "$base" pull); then
				printf '   pull failed: %s\n' "$file" >&2
				failed=1
				continue
			fi
		else
			printf '   pull skipped (--no-pull)\n'
		fi
		if ! (cd "$sub" && run_compose --dry-run -f "$base" up -d); then
			printf '   up simulation failed: %s\n' "$file" >&2
			failed=1
		fi
		;;
	*)
		printf 'unknown stage: %s\n' "$stage" >&2
		exit 2
		;;
	esac
done <"$list"

exit "$failed"
REMOTE
}

cmd_hosts() {
    [ "$LOCAL_ONLY" -eq 1 ] && die "--local is not valid with the hosts command"
    load_allowlist
    section "allowlisted hosts (${ALLOWLIST})"

    while IFS= read -r host; do
        folders=$(host_folders "$host" | tr '\n' ' ')
        printf '%s\t%s\n' "$host" "${folders% }" >&2
    done <"$ALLOWED_FILE"
}

cmd_check() {
    load_allowlist
    select_hosts
    local_check_tools
    [ "$GIT_PULL" -eq 1 ] && git_pull_latest

    failed=0
    while IFS= read -r host; do
        if ! check_source "$host"; then
            failed=$EXIT_CHECK
        fi
    done <"$SELECTED_FILE"
    return "$failed"
}

cmd_sync() {
    load_allowlist
    select_hosts
    [ "$LOCAL_ONLY" -eq 1 ] && die "sync does not make sense with --local"
    local_check_sync_tools
    [ "$GIT_PULL" -eq 1 ] && git_pull_latest

    while IFS= read -r host; do
        if ! sync_host "$host"; then
            return "$EXIT_CHECK"
        fi
    done <"$SELECTED_FILE"
    return 0
}

cmd_lint() {
    load_allowlist
    select_hosts
    select_app_hosts

    if [ ! -s "$APP_HOSTS_FILE" ]; then
        info "no selected host receives apps/; lint skipped"
        return 0
    fi
    local_check_lint_tools

    failed=0
    while IFS= read -r host; do
        if ! lint_local_dir "$(app_dir_for "$host")"; then
            failed=$EXIT_LINT
        fi
    done <"$APP_HOSTS_FILE"
    return "$failed"
}

cmd_validate() {
    load_allowlist
    select_hosts
    select_app_hosts
    local_check_tools

    failed=0
    while IFS= read -r host; do
        if [ "$LOCAL_ONLY" -eq 1 ]; then
            if ! validate_local_dir "$(app_dir_for "$host")"; then
                failed=$EXIT_VALIDATE
            fi
        else
            if ! remote_stage "$host" validate; then
                failed=$EXIT_VALIDATE
            fi
        fi
    done <"$APP_HOSTS_FILE"
    [ -s "$APP_HOSTS_FILE" ] || info "no selected host receives apps/; validate skipped"
    return "$failed"
}

cmd_test() {
    load_allowlist
    select_hosts
    select_app_hosts
    local_check_tools

    failed=0
    while IFS= read -r host; do
        if [ "$LOCAL_ONLY" -eq 1 ]; then
            if ! test_local_dir "$(app_dir_for "$host")"; then
                failed=$EXIT_TEST
            fi
        elif [ "$DRY_RUN" -eq 1 ]; then
            info "dry-run: would pull and dry-run up on ${host}"
        else
            if ! remote_stage "$host" test "$DO_PULL"; then
                failed=$EXIT_TEST
            fi
        fi
    done <"$APP_HOSTS_FILE"
    [ -s "$APP_HOSTS_FILE" ] || info "no selected host receives apps/; test skipped"
    return "$failed"
}

# Deliberately empty: deployment is not designed yet. Keep the signature so
# pipeline wiring and future tests do not change when this is implemented.
cmd_deploy() {
    err "deploy is not implemented yet; nothing was started"
    err "fill in cmd_deploy() in $0 when the design is final"
    for host in "$@"; do
        info "pending host: ${host}"
    done
    return "$EXIT_DEPLOY_DISABLED"
}

cmd_pipeline() {
    load_allowlist
    select_hosts
    select_app_hosts

    local_check_tools
    if [ -s "$APP_HOSTS_FILE" ]; then
        local_check_lint_tools
    fi
    [ "$GIT_PULL" -eq 1 ] && git_pull_latest

    failed=0

    section "pipeline: check"
    while IFS= read -r host; do
        if ! check_source "$host"; then
            failed=$EXIT_CHECK
        fi
    done <"$SELECTED_FILE"
    [ "$failed" -eq 0 ] || return "$failed"

    section "pipeline: lint"
    while IFS= read -r host; do
        if ! lint_local_dir "$(app_dir_for "$host")"; then
            failed=$EXIT_LINT
        fi
    done <"$APP_HOSTS_FILE"
    [ -s "$APP_HOSTS_FILE" ] || info "no selected host receives apps/; lint skipped"
    [ "$failed" -eq 0 ] || return "$failed"

    if [ "$LOCAL_ONLY" -eq 1 ]; then
        info "sync skipped (--local)"
    else
        section "pipeline: sync"
        while IFS= read -r host; do
            if ! sync_host "$host"; then
                return "$EXIT_CHECK"
            fi
        done <"$SELECTED_FILE"
    fi

    section "pipeline: validate"
    while IFS= read -r host; do
        if [ "$LOCAL_ONLY" -eq 1 ]; then
            if ! validate_local_dir "$(app_dir_for "$host")"; then
                failed=$EXIT_VALIDATE
            fi
        elif [ "$DRY_RUN" -eq 1 ]; then
            info "dry-run: validate skipped on ${host} (remote tree was not changed)"
        else
            if ! remote_stage "$host" validate; then
                failed=$EXIT_VALIDATE
            fi
        fi
    done <"$APP_HOSTS_FILE"
    [ -s "$APP_HOSTS_FILE" ] || info "no selected host receives apps/; validate skipped"
    [ "$failed" -eq 0 ] || return "$failed"

    section "pipeline: test"
    while IFS= read -r host; do
        if [ "$LOCAL_ONLY" -eq 1 ]; then
            if ! test_local_dir "$(app_dir_for "$host")"; then
                failed=$EXIT_TEST
            fi
        elif [ "$DRY_RUN" -eq 1 ]; then
            info "dry-run: would pull and dry-run up on ${host}"
        else
            if ! remote_stage "$host" test "$DO_PULL"; then
                failed=$EXIT_TEST
            fi
        fi
    done <"$APP_HOSTS_FILE"
    [ -s "$APP_HOSTS_FILE" ] || info "no selected host receives apps/; test skipped"
    [ "$failed" -eq 0 ] || return "$failed"

    section "pipeline: deploy"
    if [ "$WITH_DEPLOY" -eq 1 ]; then
        # shellcheck disable=SC2046
        cmd_deploy $(cat "$APP_HOSTS_FILE")
    else
        info "deploy skipped by design; rerun with --with-deploy after cmd_deploy() is implemented"
    fi
}

while [ "$#" -gt 0 ]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -q | --quiet)
        QUIET=1
        VERBOSE=0
        ;;
    -v | --verbose)
        VERBOSE=1
        QUIET=0
        ;;
    -n | --dry-run) DRY_RUN=1 ;;
    --delete) SYNC_DELETE=1 ;;
    --no-pull) DO_PULL=0 ;;
    --local) LOCAL_ONLY=1 ;;
    --with-deploy) WITH_DEPLOY=1 ;;
    --git-pull) GIT_PULL=1 ;;
    --)
        shift
        while [ "$#" -gt 0 ]; do
            printf '%s\n' "$1" >>"$HOST_ARGS_FILE"
            shift
        done
        break
        ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *)
        if [ -z "$COMMAND" ]; then
            COMMAND=$1
        else
            printf '%s\n' "$1" >>"$HOST_ARGS_FILE"
        fi
        ;;
    esac
    shift
done

[ -n "$COMMAND" ] || {
    usage >&2
    exit "$EXIT_USAGE"
}

case $COMMAND in
hosts) cmd_hosts ;;
check) cmd_check ;;
lint) cmd_lint ;;
sync) cmd_sync ;;
validate) cmd_validate ;;
test) cmd_test ;;
pipeline) cmd_pipeline ;;
deploy)
    load_allowlist
    select_hosts
    select_app_hosts
    # shellcheck disable=SC2046
    cmd_deploy $(cat "$APP_HOSTS_FILE")
    ;;
*) die "unknown command: ${COMMAND} (try --help)" ;;
esac
