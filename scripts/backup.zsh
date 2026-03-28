#!/usr/bin/env zsh

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${SCRIPT_DIR}"

WALLPAPER_BACKUP_DIR="${SCRIPT_DIR}"
WALLPAPER_BACKUP_FILE="${WALLPAPER_BACKUP_DIR}/Desktop.png"
WALLPAPER_STATE_FILE="${SCRIPT_DIR}/last_wallpaper_state.txt"

TARGET_BRANCH="main"
AUTO_PUSH="${AUTO_PUSH:-true}"
KEEP_MACKUP_UNINSTALL="${KEEP_MACKUP_UNINSTALL:-true}"

LOCK_DIR="${SCRIPT_DIR}/.backup.lock"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

run_optional() {
    local label="$1"
    shift
    log "${label}"
    if ! "$@"; then
        warn "${label} failed (continuing)"
    fi
}

run_optional_if_exists() {
    local cmd="$1"
    shift
    local label="$1"
    shift
    if command -v "${cmd}" >/dev/null 2>&1; then
        run_optional "${label}" "$@"
    else
        warn "Skipping ${label}: '${cmd}' not installed"
    fi
}

log "Current user: $(whoami)"
log "Script dir: ${SCRIPT_DIR}"
log "Backup started"

# Prevent overlapping runs
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    log "Another backup run is already in progress. Exiting."
    exit 0
fi
trap 'rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT INT TERM

# Homebrew path bootstrap (Apple Silicon + Intel)
if ! command -v brew >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
    elif [[ -x /usr/local/bin/brew ]]; then
        export PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
    fi
fi

# Ensure wallpaper state file exists
if [[ ! -f "${WALLPAPER_STATE_FILE}" ]]; then
    : > "${WALLPAPER_STATE_FILE}"
fi

# -------- Wallpaper backup (force PNG, atomic + validated) --------
wallpaper_path="$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null || true)"

if [[ -z "${wallpaper_path}" || ! -f "${wallpaper_path}" ]]; then
    log "No valid wallpaper detected."
else
    wallpaper_mtime="$(stat -f "%m" "${wallpaper_path}" 2>/dev/null || echo "0")"
    wallpaper_hash="$(shasum -a 256 "${wallpaper_path}" 2>/dev/null | awk '{print $1}' || echo "")"
    current_state="${wallpaper_path}|${wallpaper_mtime}|${wallpaper_hash}"
    last_state="$(cat "${WALLPAPER_STATE_FILE}" 2>/dev/null || true)"

    if [[ "${current_state}" != "${last_state}" ]]; then
        if [[ "${wallpaper_path}" == "${WALLPAPER_BACKUP_FILE}" ]]; then
            log "Wallpaper already points to ${WALLPAPER_BACKUP_FILE}; updating state only."
            echo "${current_state}" > "${WALLPAPER_STATE_FILE}"
        else
            if command -v sips >/dev/null 2>&1; then
                tmp_png="${WALLPAPER_BACKUP_FILE}.tmp"

                if sips -s format png "${wallpaper_path}" --out "${tmp_png}" >/dev/null 2>&1; then
                    if file "${tmp_png}" | grep -q "PNG image data"; then
                        mv -f "${tmp_png}" "${WALLPAPER_BACKUP_FILE}"
                        echo "${current_state}" > "${WALLPAPER_STATE_FILE}"
                        log "Wallpaper converted and backed up to ${WALLPAPER_BACKUP_FILE}"
                    else
                        rm -f "${tmp_png}"
                        warn "Converted file is not valid PNG"
                        exit 1
                    fi
                else
                    rm -f "${tmp_png}" 2>/dev/null || true
                    warn "Failed to convert wallpaper to PNG"
                    exit 1
                fi
            else
                warn "sips not found; cannot force PNG backup"
                exit 1
            fi
        fi
    else
        log "Wallpaper unchanged."
    fi
fi

# -------- Homebrew updates --------
run_optional_if_exists brew "Running brew doctor" brew doctor
run_optional_if_exists brew "Updating Homebrew metadata" brew update
run_optional_if_exists brew "Upgrading Homebrew formulas" brew upgrade
run_optional_if_exists brew "Upgrading Homebrew casks" brew upgrade --cask
run_optional_if_exists brew "Cleaning up Homebrew" brew cleanup --prune=all

# -------- Spicetify --------
run_optional_if_exists spicetify "Updating Spicetify" spicetify update

# -------- Brewfile export --------
if command -v brew >/dev/null 2>&1; then
    run_optional "Dumping Brewfile (full temp)" \
        brew bundle dump --describe --force --file="${SCRIPT_DIR}/Brewfile.tmp"

    if [[ -f "${SCRIPT_DIR}/Brewfile.tmp" ]]; then
        grep -v "^mas " "${SCRIPT_DIR}/Brewfile.tmp" | grep -v "^vscode " > "${SCRIPT_DIR}/Brewfile" || true
        rm -f "${SCRIPT_DIR}/Brewfile.tmp"
    fi

    run_optional "Dumping Brewfile.mas (temp)" \
        brew bundle dump --describe --force --mas --file="${SCRIPT_DIR}/Brewfile.mas.tmp"

    if [[ -f "${SCRIPT_DIR}/Brewfile.mas.tmp" ]]; then
        grep "^mas " "${SCRIPT_DIR}/Brewfile.mas.tmp" > "${SCRIPT_DIR}/Brewfile.mas" || true
        rm -f "${SCRIPT_DIR}/Brewfile.mas.tmp"
    fi
else
    warn "Skipping Brewfile export: brew not installed"
fi

# -------- Mackup --------
run_optional_if_exists mackup "Running Mackup backup" mackup backup --force
if [[ "${KEEP_MACKUP_UNINSTALL}" == "true" ]]; then
    run_optional_if_exists mackup "Running Mackup uninstall" mackup uninstall --force
else
    log "Skipping Mackup uninstall (KEEP_MACKUP_UNINSTALL=false)"
fi

# -------- Git commit/push --------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

    if [[ "${current_branch}" != "${TARGET_BRANCH}" ]]; then
        log "Skipping git commit/push: current branch '${current_branch}' is not '${TARGET_BRANCH}'"
    else
        setopt null_glob
        typeset -a managed_files=(
            "${WALLPAPER_STATE_FILE}"
            "${WALLPAPER_BACKUP_FILE}"
            "${SCRIPT_DIR}/Brewfile"
            "${SCRIPT_DIR}/Brewfile.mas"
            "${SCRIPT_DIR}/scripts/backup.zsh"
            "${SCRIPT_DIR}/scripts/setup.zsh"
            "${SCRIPT_DIR}/scripts/dock.zsh"
            "${SCRIPT_DIR}/scripts/.gitignore"
        )

        for managed_file in "${managed_files[@]}"; do
            if [[ -f "${managed_file}" ]]; then
                git add "${managed_file}"
            fi
        done

        if ! git diff --cached --quiet; then
            git commit -m "chore(backup): auto update"
            if [[ "${AUTO_PUSH}" == "true" ]]; then
                if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
                    git push
                else
                    log "No upstream configured; skipping push"
                fi
            else
                log "AUTO_PUSH=false; skipping push"
            fi
        else
            log "No managed backup files changed"
        fi
    fi
else
    log "Not inside a git repository; skipping commit/push"
fi

log "Backup complete!"
