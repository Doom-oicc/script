#!/bin/bash
# ============================================================
# Ubuntu 20.04 combined initialization launcher
# The original desktop and server scripts are embedded unchanged.
# This launcher only checks the OS, detects the installation type,
# and asks for manual confirmation before running one original script.
# ============================================================

set -u
EXPECTED_VERSION="20.04"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root: sudo bash $0" >&2
    exit 1
fi

if [ ! -r /etc/os-release ]; then
    echo "ERROR: Cannot read /etc/os-release. Aborting." >&2
    exit 1
fi

. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
    echo "ERROR: This launcher is for Ubuntu 20.04; detected: ${PRETTY_NAME:-unknown}" >&2
    exit 1
fi

if [ "${VERSION_ID:-}" != "$EXPECTED_VERSION" ] && [[ "${VERSION_ID:-}" != "$EXPECTED_VERSION".* ]]; then
    echo "ERROR: Wrong Ubuntu version for this launcher." >&2
    echo "Expected: Ubuntu $EXPECTED_VERSION" >&2
    echo "Detected: ${PRETTY_NAME:-${VERSION_ID:-unknown}}" >&2
    exit 1
fi

# A single launcher log records the mode choice and all later script decisions.
RUN_USER="${SUDO_USER:-${USER:-root}}"
RUN_HOME="$(getent passwd "$RUN_USER" | awk -F: '{print $6}')"
if [ -z "$RUN_HOME" ] || [ ! -d "$RUN_HOME" ]; then RUN_HOME="${HOME:-/root}"; fi
LAUNCHER_LOG="${RUN_HOME}/ubuntu-${EXPECTED_VERSION}-combined-$(date +%Y%m%d-%H%M%S)-$$.log"
: > "$LAUNCHER_LOG" || { echo "ERROR: Cannot create log: $LAUNCHER_LOG" >&2; exit 1; }
chmod 600 "$LAUNCHER_LOG" 2>/dev/null || true
if id "$RUN_USER" >/dev/null 2>&1; then chown "$RUN_USER":"$(id -gn "$RUN_USER")" "$LAUNCHER_LOG" 2>/dev/null || true; fi
launcher_log() { printf '%s\n' "$*" >> "$LAUNCHER_LOG"; }
launcher_log "===== Ubuntu ${EXPECTED_VERSION} combined initialization ====="
launcher_log "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
launcher_log "Invoking user: ${RUN_USER}"
launcher_log "Log file: ${LAUNCHER_LOG}"

DESKTOP_EVIDENCE=""
detect_desktop_environment() {
    local pkg status directory entry
    # Strong indicators: installed desktop metapackages, shells, or sessions.
    for pkg in \
        ubuntu-desktop ubuntu-desktop-minimal ubuntu-desktop-gnome \
        gnome-shell gdm3 lightdm sddm xfce4-session xfce4-panel \
        plasma-desktop kde-plasma-desktop mate-session-manager \
        cinnamon-session budgie-desktop lxqt-session lxde-core; do
        status="$(dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null || true)"
        if [ "$status" = "installed" ]; then
            DESKTOP_EVIDENCE="installed desktop package: $pkg"
            return 0
        fi
    done

    for directory in /usr/share/xsessions /usr/share/wayland-sessions; do
        if [ -d "$directory" ]; then
            entry="$(find "$directory" -maxdepth 1 -type f -name '*.desktop' -print -quit 2>/dev/null || true)"
            if [ -n "$entry" ]; then
                DESKTOP_EVIDENCE="desktop session file: $entry"
                return 0
            fi
        fi
    done

    if [ -L /etc/systemd/system/display-manager.service ]; then
        DESKTOP_EVIDENCE="display-manager service link exists"
        return 0
    fi

    DESKTOP_EVIDENCE="no recognized desktop package or session found"
    return 1
}

if detect_desktop_environment; then
    DETECTED_MODE="desktop"
    DEFAULT_CHOICE="1"
else
    DETECTED_MODE="server"
    DEFAULT_CHOICE="2"
fi
launcher_log "[DETECTION] OS=${PRETTY_NAME:-Ubuntu $VERSION_ID}; detected_mode=${DETECTED_MODE}; default_choice=${DEFAULT_CHOICE}; evidence=${DESKTOP_EVIDENCE}"

clear 2>/dev/null || true
echo "============================================================"
echo " Ubuntu $EXPECTED_VERSION - Combined Initialization Script"
echo "============================================================"
echo "Detected OS       : ${PRETTY_NAME:-Ubuntu $VERSION_ID}"
echo "Automatic detection: ${DETECTED_MODE^^}"
echo "Detection details : $DESKTOP_EVIDENCE"
echo
echo "Choose which original script to run:"
echo "  1) Desktop version"
echo "  2) Server version"
echo "  3) Cancel and exit"
echo
read -r -p "Select [1-3] (default: $DEFAULT_CHOICE based on detection): " mode_choice || {
    echo "ERROR: Unable to read your selection. Aborting." >&2
    launcher_log "[ERROR] Could not read Desktop/Server selection; aborting."
    exit 1
}
mode_choice_input="$mode_choice"
mode_choice=${mode_choice:-$DEFAULT_CHOICE}

case "$mode_choice" in
    1) SELECTED_MODE="desktop" ;;
    2) SELECTED_MODE="server" ;;
    3)
        launcher_log "[OPTION] Execution mode | input=3 | selected=CANCEL"
        echo "Cancelled. No changes made."
        exit 0
        ;;
    *)
        launcher_log "[OPTION] Execution mode | input=${mode_choice_input:-<ENTER>} | selected=INVALID"
        echo "Invalid selection. No changes made." >&2
        exit 1
        ;;
esac
launcher_log "[OPTION] Execution mode | input=${mode_choice_input:-<ENTER>} | selected=${SELECTED_MODE} | auto_detected=${DETECTED_MODE} | default=${DEFAULT_CHOICE}"

echo
echo "Selected original script: ${SELECTED_MODE^^}"
echo "Starting the selected ${SELECTED_MODE^^} initialization flow directly; no second confirmation is required."
launcher_log "[INFO] Mode selected; launching ${SELECTED_MODE} flow directly (startup confirmation prompt removed)."
export LAUNCHER_LOG SELECTED_MODE DETECTED_MODE

TMP_SCRIPT="$(mktemp "/tmp/ubuntu-${EXPECTED_VERSION}-${SELECTED_MODE}.XXXXXX.sh")" || {
    echo "ERROR: Failed to create a temporary script file." >&2
    exit 1
}
cleanup() {
    if [ -n "${TMP_SCRIPT:-}" ] && [ -f "$TMP_SCRIPT" ]; then
        rm -f -- "$TMP_SCRIPT"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

write_original_script() {
    local mode="$1"
    local destination="$2"
    case "$mode" in
        desktop)
            cat > "$destination" <<'__ORIGINAL_UBUNTU_20_04_DESKTOP_PAYLOAD_END_7A4C19__'
#!/bin/bash

# ============================================================
# Ubuntu 20.04 desktop init script
# version: v1.1
# Description: automated system config, tool install, driver deployment
# Usage: sudo bash ubuntu20.04-init-tty.sh
# Note: NVIDIA driver install may reset display service. Run this in TTY.
#          (Ctrl+Alt+F3~F6) Do not run this script from a desktop terminal.
# ============================================================

set -e

# ================= Config variables =================

INTRANET_SERVER="http://192.168.19.1"
INTRANET_PATH="${INTRANET_SERVER}/chfs/shared/autoinstall"

NVIDIA_DRIVER="NVIDIA-Linux-x86_64-595.80.run"
CUDA_PACKAGE="cuda_13.2.1_595.58.03_linux.run"

TEST_FILES=(
    "check_V5.sh"
    "storcli64"
    "mount_V6.sh"
    "yc.sh"
    "upload_check.sh"
)

COMMON_TOOLS="vim ssh dkms htop ipmitool stress lm-sensors stress-ng \
ethtool net-tools unzip make gcc g++ wget curl git cmake mdadm chrony \
stressapptest fio smartmontools nvme-cli nvtop sshpass tmux"

EXTRA_LIBS="pkg-config libglvnd-dev lib32z1 lib32ncurses6"

BUILD_LIBS="build-essential linux-headers-$(uname -r) libcap-dev libssl-dev \
libnl-3-dev libnl-route-3-dev autoconf automake libtool flex bison"

# ================================================= environment variables =================================================

if [ -n "$SUDO_USER" ]; then
    WORK_USER="$SUDO_USER"
else
    WORK_USER="$USER"
fi
WORK_HOME=$(eval echo ~"$WORK_USER")
LOG_FILE="${WORK_HOME}/ubuntu-init-$(date +%Y%m%d-%H%M%S).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_STEPS=10
CURRENT_STEP=0

# ================================================= Helper functions =================================================

log() {
    local rendered
    rendered="$(echo -e "$1")"
    printf '%s
' "$rendered" | tee -a "$LOG_FILE"
    if [ -n "${LAUNCHER_LOG:-}" ] && [ "$LAUNCHER_LOG" != "$LOG_FILE" ]; then
        printf '%s
' "$rendered" >> "$LAUNCHER_LOG"
    fi
}

log_plain() {
    printf '%s
' "$1" >> "$LOG_FILE"
    if [ -n "${LAUNCHER_LOG:-}" ] && [ "$LAUNCHER_LOG" != "$LOG_FILE" ]; then
        printf '%s
' "$1" >> "$LAUNCHER_LOG"
    fi
}

record_choice() {
    local label="$1" input="$2" selected="$3" details="${4:-}"
    [ -n "$input" ] || input="<ENTER>"
    log_plain "[OPTION] ${label} | input=${input} | selected=${selected} | ${details}"
}

step_header() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log ""
    log "${BLUE}============================================================${NC}"
    log "${BLUE} Step ${CURRENT_STEP}/${TOTAL_STEPS}: $1 ${NC}"
    log "${BLUE}============================================================${NC}"
}

ok()    { log "${GREEN}[ OK ]${NC} $1"; }
warn()  { log "${YELLOW}[WARN]${NC} $1"; }
err()   { log "${RED}[ERR ]${NC} $1"; }

confirm() {
    local msg="$1" default="${2:-Y}" prompt input_choice choice outcome
    if [ "$default" = "Y" ]; then prompt=" [Y/n] "; else prompt=" [y/N] "; fi
    while true; do
        input_choice=""
        read -r -p "${msg}${prompt}" input_choice || input_choice=""
        choice="$input_choice"
        choice=${choice:-$default}
        case "$choice" in
            [Yy]*) outcome="YES"; record_choice "$msg" "${input_choice:-<ENTER>}" "$outcome" "effective=${choice}; default=${default}"; return 0 ;;
            [Nn]*) outcome="NO"; record_choice "$msg" "${input_choice:-<ENTER>}" "$outcome" "effective=${choice}; default=${default}"; return 1 ;;
            *) record_choice "$msg" "$input_choice" "INVALID" "expected=Y/N; default=${default}"; echo "Please enter Y or N" ;;
        esac
    done
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "This script must be run as root. Use: sudo bash $0"
        exit 1
    fi
}

# ================================================= Pre-check interaction =================================================

check_nvidia_gpu() {
    local gpucount
    gpucount=$(lspci 2>/dev/null | grep -i "nvidia" | grep -ci "vga\|3d\|display" || true)
    if [ "$gpucount" -gt 0 ]; then
        echo "1"
    else
        echo "0"
    fi
}

detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-$VERSION}"
    else
        echo "Unknown"
    fi
}

# Check whether NVIDIA driver is installed
check_nvidia_driver_installed() {
    # Use subshell + || true to avoid set -e exit
    local drv_version
    drv_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1) || true
    if [ -n "$drv_version" ]; then
        echo "$drv_version"
        return 0
    fi
    # Fallback: check kernel module
    if [ -f /proc/driver/nvidia/version ]; then
        local mod_version
        mod_version=$(grep -oP 'Module\s+\K[0-9.]+' /proc/driver/nvidia/version 2>/dev/null | head -1) || true
        if [ -n "$mod_version" ]; then
            echo "$mod_version"
            return 0
        fi
    fi
    echo ""
    return 1
}

# Check whether CUDA toolkit is installed
check_cuda_installed() {
    local cuda_ver
    cuda_ver=$(ls /usr/local/ 2>/dev/null | grep -E "^cuda-[0-9.]+" | cut -d- -f2 | sort -V | tail -n 1) || true
    if [ -n "$cuda_ver" ]; then
        echo "$cuda_ver"
        return 0
    fi
    echo ""
    return 1
}

list_installed_cuda_toolkits() {
    local path version
    for path in /usr/local/cuda-[0-9]*; do
        [ -d "$path" ] || continue
        version="${path##*/cuda-}"
        [[ "$version" =~ ^[0-9]+([.][0-9]+)*$ ]] || continue
        printf '%s\n' "$version"
    done | sort -Vu
}

pre_interaction() {
    log ""
    log "${BLUE}======================== Configuration confirmation ========================${NC}"

    PRESTART_OPTIONS=1
    step_select_apt_mirror

    SYS_VER=$(detect_ubuntu_version)
    log "Current system: ${YELLOW}${SYS_VER}${NC}"

    GPU_FOUND=$(check_nvidia_gpu)
    if [ "$GPU_FOUND" = "1" ]; then
        log "NVIDIA GPU: ${GREEN}detected${NC}"

        # Check existing driver(|| true avoid set -e when function returns 1)
        EXISTING_DRIVER=$(check_nvidia_driver_installed) || true
        if [ -n "$EXISTING_DRIVER" ]; then
            log "Installed driver: ${GREEN}${EXISTING_DRIVER}${NC}"
        fi

        # Check existing CUDA
        EXISTING_CUDA=$(check_cuda_installed) || true
        if [ -n "$EXISTING_CUDA" ]; then
            log "Installed CUDA:  ${GREEN}${EXISTING_CUDA}${NC}"
        fi
    else
        log "NVIDIA GPU: ${YELLOW}not detected${NC}"
    fi

    NVIDIA_MODULE_TYPE=""
    GPU_INSTALL_MODE="4"
    INSTALL_NVIDIA=0
    if [ "$GPU_FOUND" = "1" ]; then
        log ""
        log "Select the GPU installation mode for this run:"
        log "  1) Default installation (intranet download; install missing components only; preserve installed driver/CUDA)"
        log "  2) Custom installation (scan the current user home directory; choose a version if multiple installers exist)"
        log "  3) Skip GPU installation (keep the current driver and CUDA)"
        while true; do
            gpu_mode_input=""
            read -r -p "Enter choice [1-3, default 1]: " gpu_mode_input || gpu_mode_input=""
            gpu_mode_choice=${gpu_mode_input:-1}
            case "$gpu_mode_choice" in
                1)
                    GPU_INSTALL_MODE="1"
                    INSTALL_NVIDIA=1
                    log "Selected option 1: Default installation; use configured intranet packages and install missing components only."
                    break
                    ;;
                2)
                    # Internal mode 3 implements custom package selection and replacement confirmations.
                    GPU_INSTALL_MODE="3"
                    INSTALL_NVIDIA=1
                    log "Selected option 2: Custom installation; scan the home directory and confirm any version replacement before initialization."
                    break
                    ;;
                3)
                    GPU_INSTALL_MODE="4"
                    INSTALL_NVIDIA=0
                    log "Selected option 3: Skip GPU installation and preserve current components."
                    break
                    ;;
                *) echo "Enter 1, 2, or 3." ;;
            esac
        done
        case "$GPU_INSTALL_MODE" in
            1) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "1 - Default installation (intranet download)" "existing components=preserve; configured intranet package names; no installer selection prompt" ;;
            3) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "2 - Custom installation" "scan home directory; select among multiple installer versions; explicitly confirm replacements" ;;
            4) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "3 - Skip GPU installation" "existing components=preserve" ;;
        esac
    else
        GPU_INSTALL_MODE="4"
        INSTALL_NVIDIA=0
        warn "No NVIDIA GPU detected. Skipping NVIDIA driver and CUDA installation."
        record_choice "GPU installation mode" "AUTO" "3 - Skip GPU installation" "reason=no NVIDIA GPU detected"
    fi
    log ""
    # Plan all installer names before system changes begin. Existing components are always preserved.
    CUSTOM_DRIVER_PACKAGE=""
    CUSTOM_CUDA_PACKAGE=""
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ "${GPU_INSTALL_MODE:-4}" != "4" ]; then
        if [ -n "${EXISTING_DRIVER:-}" ] && [ "${GPU_INSTALL_MODE:-1}" != "3" ]; then
            log "Existing NVIDIA driver ${EXISTING_DRIVER} will be preserved; no driver package selection needed."
            record_choice "NVIDIA driver action" "AUTO" "preserve ${EXISTING_DRIVER}" "reason=driver already installed"
        else
            if [ "$GPU_INSTALL_MODE" = "1" ]; then package_policy="intranet"; else package_policy="manual"; fi
            if select_install_package "driver" "$NVIDIA_DRIVER" "$package_policy"; then
                CUSTOM_DRIVER_PACKAGE="$SELECTED_INSTALLER_NAME"
            else
                warn "No NVIDIA driver installer was selected; driver installation will be skipped."
                record_choice "NVIDIA driver action" "selection failed/cancelled" "skip" "no installer selected"
            fi
        fi
        if [ -n "${EXISTING_CUDA:-}" ] && [ "${GPU_INSTALL_MODE:-1}" != "3" ]; then
            log "Existing CUDA Toolkit ${EXISTING_CUDA} will be preserved; no CUDA package selection needed."
            record_choice "CUDA action" "AUTO" "preserve ${EXISTING_CUDA}" "reason=CUDA already installed"
        else
            if [ "$GPU_INSTALL_MODE" = "1" ]; then package_policy="intranet"; else package_policy="manual"; fi
            if select_install_package "cuda" "$CUDA_PACKAGE" "$package_policy"; then
                CUSTOM_CUDA_PACKAGE="$SELECTED_INSTALLER_NAME"
            else
                warn "No CUDA installer was selected; CUDA installation will be skipped."
                record_choice "CUDA action" "selection failed/cancelled" "skip" "no installer selected"
            fi
        fi
    fi

    # Mode 3 is the only mode allowed to replace an installed component. Confirm every change now.
    REPLACE_DRIVER=0
    REPLACE_CUDA=0
    if [ "${GPU_INSTALL_MODE:-4}" = "3" ]; then
        if [ -n "${EXISTING_DRIVER:-}" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ]; then
            target_driver_pre=$(get_driver_version_from_filename "$CUSTOM_DRIVER_PACKAGE")
            if [ -n "$target_driver_pre" ] && [ "$target_driver_pre" = "$EXISTING_DRIVER" ]; then
                log "Selected driver package matches the installed version ${EXISTING_DRIVER}; no replacement is needed."
                CUSTOM_DRIVER_PACKAGE=""
                record_choice "NVIDIA driver replacement" "AUTO" "NO CHANGE" "selected target version matches installed version"
            elif confirm "Replace installed NVIDIA driver ${EXISTING_DRIVER} with ${target_driver_pre:-$CUSTOM_DRIVER_PACKAGE}?" "N"; then
                REPLACE_DRIVER=1
                record_choice "NVIDIA driver replacement" "confirmed in startup prompts" "YES" "current=${EXISTING_DRIVER}; target=${target_driver_pre:-unknown}"
            else
                CUSTOM_DRIVER_PACKAGE=""
                record_choice "NVIDIA driver replacement" "confirmed in startup prompts" "NO; preserve ${EXISTING_DRIVER}" "target=${target_driver_pre:-unknown}"
            fi
        fi
        if [ -n "${EXISTING_CUDA:-}" ] && [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
            target_cuda_pre=$(get_cuda_version_from_filename "$CUSTOM_CUDA_PACKAGE")
            if [ -n "$target_cuda_pre" ] && [ "$target_cuda_pre" = "$EXISTING_CUDA" ]; then
                log "Selected CUDA package matches the installed Toolkit ${EXISTING_CUDA}; no replacement is needed."
                CUSTOM_CUDA_PACKAGE=""
                record_choice "CUDA version change" "AUTO" "NO CHANGE" "selected target version matches installed version"
            elif confirm "Switch the active CUDA Toolkit from ${EXISTING_CUDA} to ${target_cuda_pre:-$CUSTOM_CUDA_PACKAGE}? Old versions are retained unless you separately approve cleanup." "N"; then
                REPLACE_CUDA=1
                record_choice "CUDA version change" "confirmed in startup prompts" "YES" "current=${EXISTING_CUDA}; target=${target_cuda_pre:-unknown}; other versions retained unless cleanup is approved"
            else
                CUSTOM_CUDA_PACKAGE=""
                record_choice "CUDA version change" "confirmed in startup prompts" "NO; preserve ${EXISTING_CUDA}" "target=${target_cuda_pre:-unknown}"
            fi
        fi
    fi

    # Optional cleanup of additional CUDA runfile installations is decided before any changes begin.
    CLEANUP_OLD_CUDA=0
    CUDA_CLEANUP_KEEP_VERSION="${EXISTING_CUDA:-}"
    if [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
        selected_cuda_version_for_cleanup=$(get_cuda_version_from_filename "$CUSTOM_CUDA_PACKAGE")
        if [ -n "$selected_cuda_version_for_cleanup" ]; then
            if [ -z "${EXISTING_CUDA:-}" ] || [ "${REPLACE_CUDA:-0}" = "1" ] || [ "$selected_cuda_version_for_cleanup" = "${EXISTING_CUDA:-}" ]; then
                CUDA_CLEANUP_KEEP_VERSION="$selected_cuda_version_for_cleanup"
            fi
        fi
    fi
    mapfile -t installed_cuda_versions_pre < <(list_installed_cuda_toolkits)
    if [ "${GPU_INSTALL_MODE:-4}" = "3" ] && [ "${#installed_cuda_versions_pre[@]}" -gt 1 ]; then
        log "Multiple CUDA Toolkit versions were found in /usr/local:"
        cleanup_keep_found=0
        for installed_cuda_ver in "${installed_cuda_versions_pre[@]}"; do
            if [ "$installed_cuda_ver" = "${CUDA_CLEANUP_KEEP_VERSION:-}" ]; then
                cleanup_keep_found=1
                log "  - ${installed_cuda_ver} (planned keep version)"
            else
                log "  - ${installed_cuda_ver} (candidate for cleanup after the selected version is verified)"
            fi
        done
        if [ -n "${CUDA_CLEANUP_KEEP_VERSION:-}" ] && [ "$cleanup_keep_found" = "0" ]; then
            log "  - ${CUDA_CLEANUP_KEEP_VERSION} (selected target; keep only if installation and verification succeed)"
        fi
        if [ -n "${CUDA_CLEANUP_KEEP_VERSION:-}" ]; then
            apt_cuda_packages_pre=$(get_apt_cuda_packages)
            if [ -n "$apt_cuda_packages_pre" ]; then
                warn "APT-managed CUDA packages were detected; automatic cleanup of other CUDA versions is disabled for safety."
                log "$apt_cuda_packages_pre"
                record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=APT-managed CUDA packages detected"
            else
                if confirm "After the selected/kept CUDA Toolkit version is verified, uninstall other CUDA runfile versions that provide cuda-uninstaller? This is irreversible." "N"; then
                    CLEANUP_OLD_CUDA=1
                    record_choice "CUDA duplicate cleanup" "confirmed before initialization" "YES" "keep_version=${CUDA_CLEANUP_KEEP_VERSION}; remove other runfile versions only after target verification"
                else
                    CLEANUP_OLD_CUDA=0
                    record_choice "CUDA duplicate cleanup" "confirmed before initialization" "NO" "keep all installed CUDA versions"
                fi
            fi
        else
            warn "Cannot determine a CUDA version to keep; leaving all installed CUDA versions untouched."
            record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=no keep version identified"
        fi
    else
        record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=not custom mode or fewer than two CUDA toolkit versions detected"
    fi

    # Choose the module type only if a driver is missing or a replacement was approved.
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ] && { [ -z "${EXISTING_DRIVER:-}" ] || [ "${REPLACE_DRIVER:-0}" = "1" ]; }; then
        if [ "${GPU_INSTALL_MODE:-1}" = "1" ] || [ "${GPU_INSTALL_MODE:-1}" = "2" ] || [ "${GPU_INSTALL_MODE:-1}" = "3" ]; then
            if ! choose_driver_module_type; then
                err "Unable to read the NVIDIA module-type selection; aborting before initialization."
                exit 1
            fi
        fi
    fi

    # Safety check is still an upfront choice: never install a driver from an active GUI terminal.
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ] && { [ -z "${EXISTING_DRIVER:-}" ] || [ "${REPLACE_DRIVER:-0}" = "1" ]; } && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        warn "A graphical display session appears active. NVIDIA driver installation may interrupt this session."
        if ! confirm "Continue anyway? Recommended: switch to TTY (Ctrl+Alt+F3 to F6) or SSH first." "N"; then
            log "User chose not to continue from the active graphical session; exiting before system changes."
            exit 0
        fi
    else
        record_choice "NVIDIA installation session check" "AUTO" "continue" "no active DISPLAY/WAYLAND session detected, or no driver installation/replacement selected"
    fi

    if confirm "Upgrade system to latest version? (Choose N to keep current version)" "Y"; then
        DO_SYSTEM_UPGRADE=1
    else
        DO_SYSTEM_UPGRADE=0
        warn "Skip system upgrade and keep current version"
    fi

    log ""
    PRESTART_OPTIONS=0
    record_choice "System upgrade" "chosen in pre-run prompts" "$DO_SYSTEM_UPGRADE" "1=dist-upgrade; 0=skip"
    log "${GREEN}Configuration confirmed. Starting initialization...${NC}"
    log ""
}

# ================================================= Stage 1: Network check =================================================

step_check_network() {
    step_header "Check network connection"
    log "Testing public network connectivity..."
    if ping -c 3 -W 2 223.5.5.5 > /dev/null 2>&1; then
        ok "Public network is reachable"
    else
        err "Public network is unreachable. Stop script"
        log "Check network settings and rerun"
        exit 1
    fi

    log "Testing intranet server (192.168.19.1) connectivity..."
    if ping -c 3 -W 2 192.168.19.1 > /dev/null 2>&1; then
        ok "Intranet server is reachable"
    else
        warn "Intranet server is unreachable. Download-related steps will be skipped"
        warn "Script will continue, but NVIDIA driver and test files cannot be downloaded"
    fi
}

# ================================================= Stage 2: Select APT mirror =================================================

step_select_apt_mirror() {
    if [ "${PRESTART_OPTIONS:-0}" = "1" ]; then
        log "[PRE-RUN OPTION] Select APT mirror"
    else
        step_header "Select APT mirror"
    fi
    log "Please select the Ubuntu 20.04 (focal) APT mirror to use:"
    log "  1) USTC (default)"
    log "  2) Tsinghua University TUNA"
    log "  3) Alibaba Cloud"
    log "  4) Huawei Cloud"
    log "  5) HUST Mirror"
    log "  6) Tencent Mirror"
    log "  7) Ubuntu official mirrors"

    while true; do
        read -r -p "Enter choice [1-7, default: 1]: " mirror_input
        mirror_choice=${mirror_input:-1}
        case "$mirror_choice" in
            1)
                APT_MIRROR_NAME="USTC"
                APT_MIRROR_URL="https://mirrors.ustc.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            2)
                APT_MIRROR_NAME="Tsinghua University TUNA"
                APT_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            3)
                APT_MIRROR_NAME="Alibaba Cloud"
                APT_MIRROR_URL="https://mirrors.aliyun.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            4)
                APT_MIRROR_NAME="Huawei Cloud"
                APT_MIRROR_URL="https://repo.huaweicloud.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            5)
                APT_MIRROR_NAME="HUST Mirror"
                APT_MIRROR_URL="https://mirrors.hust.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            6)
                APT_MIRROR_NAME="Tencent Mirror"
                APT_MIRROR_URL="https://mirrors.cloud.tencent.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            7)
                APT_MIRROR_NAME="Ubuntu official mirrors"
                APT_MIRROR_URL="http://archive.ubuntu.com/ubuntu"
                APT_SECURITY_URL="http://security.ubuntu.com/ubuntu"
                break ;;
            *) echo "Please enter a number from 1 to 7." ;;
        esac
    done

    record_choice "APT mirror" "${mirror_input:-<ENTER>}" "${APT_MIRROR_NAME}" "index=${mirror_choice}; main=${APT_MIRROR_URL}; security=${APT_SECURITY_URL}"
    ok "Selected APT mirror: ${APT_MIRROR_NAME}"
    log "  Main/update URL: ${APT_MIRROR_URL}"
    log "  Security URL: ${APT_SECURITY_URL}"
}

# ================================================= Stage 2: APT source config =================================================

step_configure_sources() {
    step_header "Backup and update APT sources"

    if [ -f /etc/apt/sources.list ]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
        ok "Backed up /etc/apt/sources.list -> sources.list.bak"
    fi

    # Ubuntu 20.04 uses the traditional /etc/apt/sources.list format for better compatibility
    if [ -z "${APT_MIRROR_URL:-}" ] || [ -z "${APT_SECURITY_URL:-}" ]; then
        err "No APT mirror selected; run step_select_apt_mirror first."
        return 1
    fi

    tee /etc/apt/sources.list > /dev/null << EOF
deb ${APT_MIRROR_URL}/ focal main restricted universe multiverse
deb ${APT_MIRROR_URL}/ focal-updates main restricted universe multiverse
deb ${APT_MIRROR_URL}/ focal-backports main restricted universe multiverse
deb ${APT_SECURITY_URL}/ focal-security main restricted universe multiverse
EOF
    ok "Written /etc/apt/sources.list using ${APT_MIRROR_NAME}"

    log "Updating APT cache..."
    apt update 2>&1 | tee -a "$LOG_FILE" | tail -5
    ok "APT cache update completed"

    log "Removing unused packages..."
    apt remove --purge apport update-notifier zsys -y >> "$LOG_FILE" 2>&1 || true
    ok "Unused packages removed"
}

# ================================================= Stage 3: Install common tools =================================================

step_install_tools() {
    step_header "Install common tools"

    log "Installing common tools..."
    apt install -y $COMMON_TOOLS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Common tools installed"

    log "Installing dependency libraries..."
    apt install -y $EXTRA_LIBS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Dependency libraries installed"

    log "Installing build tools..."
    apt install -y $BUILD_LIBS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Build tools installed"

    log "Cleaning system..."
    apt autoremove -y >> "$LOG_FILE" 2>&1 && apt clean >> "$LOG_FILE" 2>&1
    ok "Cleanup completed"
}

# ================================================= Stage 4: Time sync =================================================

step_sync_time() {
    step_header "Check and sync time"

    LOCAL_TIME=$(date +"%Y-%m-%d %H:%M:%S")
    log "  Current time: $LOCAL_TIME"

    # Step 1: ensure timezone is correct
    timedatectl set-timezone Asia/Shanghai
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    ok "Timezone set to Asia/Shanghai"

    # Step 2: quick time sync with chrony
    if command -v chronyc >/dev/null 2>&1; then
        systemctl enable chrony 2>/dev/null || true
        systemctl restart chrony 2>/dev/null || true
        sleep 2
        # Try force sync
        chronyc -a burst 4/4 2>/dev/null || true
        sleep 3
        chronyc -a makestep 2>/dev/null || true
        sleep 1
        SYNC_CHECK=$(chronyc tracking 2>/dev/null | grep -i "leap status" | grep -i "normal" || true)
        if [ -n "$SYNC_CHECK" ]; then
            ok "Time sync completed (chrony)"
        else
            log "  chrony sync status not confirmed. Trying another method..."
        fi
    fi

    ok "Timezone set to Asia/Shanghai"
    log "  Time after sync: $(date +"%Y-%m-%d %H:%M:%S")"

    # No.threestep:verifyverifytimeWhetherincombinedprocessrangeinside(andCurrent timedifferencenotexceed1day)
    SYNCED_TIME=$(date +%s)
    NOW_APPROX=$(date -u +%s)
    DIFF=$((SYNCED_TIME - NOW_APPROX))
    if [ $DIFF -lt 0 ]; then DIFF=$((DIFF * -1)); fi
    if [ $DIFF -gt 86400 ]; then
        warn "System time differs from network time by more than 24 hours. Check network and timezone manually"
    fi
}

# ================================================= Stage 5: System upgrade =================================================

step_system_upgrade() {
    step_header "System upgrade"

    if [ "$DO_SYSTEM_UPGRADE" = "1" ]; then
        log "correctinrunSystem upgrade..."
        export DEBIAN_FRONTEND=noninteractive
        apt update >> "$LOG_FILE" 2>&1
        apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
            dist-upgrade 2>&1 | tee -a "$LOG_FILE" | tail -5
        ok "System upgrade completed"
    else
        warn "according toyourchoice,skipSystem upgrade"
    fi
}

# ================================================= Stage 6: System optimization =================================================

step_system_optimize() {
    step_header "System optimization config"

    # 6.1 Disable nouveau
    if [ "$INSTALL_NVIDIA" = "1" ]; then
        log "  -> Disable nouveau opensourcedriver"
        tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
        rmmod nouveau 2>/dev/null || true
        ok "nouveau disabled"
    else
        log "  -> Skip nouveau disable (NVIDIA driver not installed)"
    fi

    # 6.2 Set 1920x1080 resolution
    log "  -> Set 1920x1080 resolution"
    mkdir -p /etc/X11/xorg.conf.d/
    tee /etc/X11/xorg.conf.d/10-monitor.conf > /dev/null << 'EOF'
Section "Monitor"
    Identifier    "VGA-1"
    VendorName    "Generic"
    ModelName     "LCD"

    Option        "ExactModeTimings" "true"
    Option        "TargetRefresh" "60"
    Option        "Prefer" "1920x1080"

    ModeLine      "1920x1080" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 +hsync +vsync
    ModeLine      "1680x1050" 146.25 1680 1784 1960 2240 1050 1053 1059 1089 +hsync -vsync
    ModeLine      "1600x900" 118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync
    Option        "PreferredMode" "1920x1080"
    Option        "Position" "0 0"
EndSection

Section "Screen"
    Identifier "Screen0"
    Monitor "VGA-1"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1680x1050" "1600x900"
    EndSubSection
EndSection
EOF

    if [ -f "${WORK_HOME}/.config/monitors.xml" ]; then
        cp "${WORK_HOME}/.config/monitors.xml" /var/lib/gdm3/.config/
        chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
    fi
    ok "resolutionconfigWritten"

    # 6.3 Time timezone
    log "  -> Set timezone"
    timedatectl set-timezone Asia/Shanghai 2>/dev/null || true
    timedatectl set-local-rtc 1 --adjust-system-clock 2>/dev/null || true
    ok "Timezone config completed (Asia/Shanghai)"

    # 6.4 Modify grub
    log "  -> Modify grub config (enable os-prober)"
    if [ -f /etc/default/grub ]; then
        if [ ! -f /etc/default/grub.bak ]; then
            cp /etc/default/grub /etc/default/grub.bak
        fi
        sed -i -E '/^[[:space:]]*#?[[:space:]]*GRUB_DISABLE_OS_PROBER=.*/d' /etc/default/grub
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    fi
    ok "grub config updated"

    # 6.5 Update grub and initramfs
    log "  -> Update grub"
    update-grub 2>&1 | tee -a "$LOG_FILE" | tail -2
    ok "grub update completed"

    log "  -> Update initramfs"
    update-initramfs -u -k all 2>&1 | tee -a "$LOG_FILE" | tail -2
    ok "initramfs update completed"
}

# ================================================= Stage 7: NVIDIA driver + CUDA =================================================

format_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes/1024/1024)) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes/1024)) KB"
    else
        echo "${bytes} B"
    fi
}

# Download file (skip existing complete file)
download_file() {
    local remote_file="$1"
    local save_path="$2"
    local url="${INTRANET_PATH}/${remote_file}"

    # If file exists and is not empty, treat it as downloaded and skip
    if [ -f "$save_path" ]; then
        local existing_size
        existing_size=$(stat -c%s "$save_path" 2>/dev/null || echo 0)
        if [ "$existing_size" -gt 0 ]; then
            ok "File already exists. Skip download: ${remote_file} ($(format_size "$existing_size"))"
            return 0
        else
            warn "File exists but is empty. Redownload: ${remote_file}"
            rm -f "$save_path"
        fi
    fi

    log "  Download: ${remote_file}"
    if command -v wget >/dev/null 2>&1; then
        if ! wget -q --timeout=30 --tries=2 --no-check-certificate \
             -O "${save_path}" "${url}" >> "$LOG_FILE" 2>&1; then
            rm -f "$save_path"
            warn "Download failed: ${remote_file}"
            return 1
        fi
    else
        if ! curl -fsSL --max-time 60 --connect-timeout 15 --retry 1 \
             -o "${save_path}" "${url}" >> "$LOG_FILE" 2>&1; then
            rm -f "$save_path"
            warn "Download failed: ${remote_file}"
            return 1
        fi
    fi

    if [ ! -s "$save_path" ]; then
        rm -f "$save_path"
        warn "Download failed: ${remote_file}"
        return 1
    fi
    local local_size
    local_size=$(stat -c%s "$save_path" 2>/dev/null || echo 0)
    ok "Download completed (size: $(format_size "$local_size"))"
    return 0
}

# Set NVIDIA persistence mode
setup_nvidia_persistence() {
    log "  -> Set NVIDIA persistence mode"
    tee /lib/systemd/system/nvidia-pm.service > /dev/null << 'EOF'
[Unit]
Description=ps deploy
ConditionPathExists=/usr/bin/nvidia-smi

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-smi --persistence-mode=1
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=true
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nvidia-pm.service
    # Start immediately(if nvidia-smi is available)
    if command -v nvidia-smi >/dev/null 2>&1; then
        systemctl start nvidia-pm.service 2>/dev/null || true
        ok "NVIDIA persistence mode enabled and started"
    else
        ok "NVIDIA persistence service registered (effective after reboot)"
    fi
}

# write CUDA environment variables(use /etc/profile.d/ to avoid escaping issues)
setup_cuda_env() {
    local cuda_ver="$1"
    if [ -z "$cuda_ver" ]; then
        warn "nomethod CUDA version,skipenvironment variablesconfig"
        return 1
    fi

    tee /etc/profile.d/cuda.sh > /dev/null << EOF
# CUDA toolkit environment
export PATH=/usr/local/cuda-${cuda_ver}/bin\${PATH:+:\${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-${cuda_ver}/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}
EOF
    ok "CUDA environment variablesWritten /etc/profile.d/cuda.sh"
}

ensure_nouveau_not_loaded() {
    if lsmod | awk '{print $1}' | grep -qx "nouveau"; then
        warn "nouveau is still loaded; the NVIDIA .run installer cannot be started safely during this boot."
        warn "No mid-run reboot will be performed. The NVIDIA driver component will be skipped; remaining initialization steps will continue."
        record_choice "NVIDIA nouveau check" "AUTO" "driver skipped" "reason=nouveau remains loaded; reboot handled only at final stage"
        return 1
    fi
    ok "nouveau is not loaded; the NVIDIA driver installer may proceed."
    record_choice "NVIDIA nouveau check" "AUTO" "continue driver install" "nouveau not loaded"
    return 0
}

# ================================================= NVIDIA driver + CUDA interactive install =================================================

# ================================================= NVIDIA/CUDA interactive package selection =================================================

# Option 1 uses the configured intranet default directly; custom modes can scan/select local or intranet installers.
select_install_package() {
    local component="$1" default_file="$2" policy="${3:-manual}"
    local selected="" choice_input="" choice="" entered="" source="intranet" i
    local -a candidates=()

    # Option 1 is explicitly "default install (intranet download)". Use the configured
    # package name without scanning the home directory or asking the user to choose.
    # A previously downloaded cache with this exact default filename may be reused.
    if [ "$policy" = "intranet" ]; then
        selected="$default_file"
        source="intranet-default"
        if [ -s "${WORK_HOME}/${selected}" ]; then
            log "Default intranet installer already cached; reusing the configured file: ${selected}"
            source="intranet-default-cache"
        else
            log "Default install selected: download ${selected} from intranet when the component is installed."
        fi
        SELECTED_INSTALLER_NAME="$selected"
        SELECTED_INSTALLER="${WORK_HOME}/${selected}"
        record_choice "${component} installer source" "AUTO" "$selected" "source=${source}; policy=default intranet download; no package-selection prompt"
        record_choice "Final ${component} package" "$selected" "$selected" "source=${source}; path=${SELECTED_INSTALLER}; intranet_url=${INTRANET_PATH}/${selected}"
        return 0
    fi

    log "Scanning ${WORK_HOME} for local ${component} installer packages..."
    if [ -d "$WORK_HOME" ]; then
        if [ "$component" = "driver" ]; then
            mapfile -t candidates < <(find "$WORK_HOME" -maxdepth 1 -type f -size +0c \
                \( -iname 'NVIDIA-Linux-x86_64-*.run' -o -iname 'NVIDIA*.run' \) \
                -printf '%f
' 2>/dev/null | sort -Vr)
        else
            mapfile -t candidates < <(find "$WORK_HOME" -maxdepth 1 -type f -size +0c \
                -iname 'cuda*.run' -printf '%f
' 2>/dev/null | sort -Vr)
        fi
    fi

    if [ "${#candidates[@]}" -eq 1 ]; then
        selected="${candidates[0]}"; source="home"
        record_choice "${component} installer selection" "AUTO" "$selected" "source=home; only one matching local installer; auto-selected without prompt"
    elif [ "${#candidates[@]}" -gt 0 ]; then
        log ""
        log "Found ${component} installer package(s) in ${WORK_HOME}:"
        for i in "${!candidates[@]}"; do log "  $((i + 1))) ${candidates[$i]}"; done
        log "  0) Enter a custom intranet filename (press Enter to use the configured default filename)"
        while true; do
            choice_input=""
            read -r -p "Select a file [0-${#candidates[@]}, default 1]: " choice_input || choice_input=""
            choice=${choice_input:-1}
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -eq 0 ]; then
                record_choice "Local ${component} installer number" "${choice_input:-<ENTER>}" "$choice" "action=default/custom filename; policy=${policy}"
                selected=""; break
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#candidates[@]}" ]; then
                selected="${candidates[$((choice - 1))]}"; source="home"
                record_choice "Local ${component} installer number" "${choice_input:-<ENTER>}" "$choice" "selected_file=${selected}; source=home"
                break
            else echo "Enter a number between 0 and ${#candidates[@]}。"; fi
        done
    else
        warn "No matching ${component} installer was found in the home directory."
    fi

    if [ -z "$selected" ]; then
        if [ "$policy" = "auto" ]; then
            selected="$default_file"; source="intranet"
            log "No local ${component} installer was available; use the configured intranet default: ${selected}"
            record_choice "${component} installer source" "AUTO" "$selected" "source=intranet; default package; no prompt"
        else
            read -r -p "Enter the filename to download from the intranet (press Enter for default: ${default_file}; enter q to cancel): " entered || entered="q"
            if [ "$entered" = "q" ] || [ "$entered" = "Q" ]; then
                record_choice "${component} intranet filename" "$entered" "CANCEL" "component will be skipped"
                warn "Cancelled selection of the ${component} installer."; return 1
            fi
            selected=${entered:-$default_file}
            if [[ "$selected" == */* ]] || [[ ! "$selected" =~ \.run$ ]]; then
                record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "must be a .run filename without a path"
                err "Invalid filename: enter a .run filename without a path."; return 1
            fi
            if [ "$component" = "driver" ]; then
                if [[ ! "$selected" =~ ^NVIDIA.*\.run$ ]]; then
                    record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "driver file must start with NVIDIA"
                    err "The driver installer filename must start with NVIDIA and end with .run."; return 1
                fi
            else
                if [[ ! "$selected" =~ ^cuda.*\.run$ ]]; then
                    record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "CUDA file must start with cuda"
                    err "The CUDA installer filename must start with cuda and end with .run."; return 1
                fi
            fi
            if [ -s "${WORK_HOME}/${selected}" ]; then source="home"; else source="intranet"; fi
            record_choice "${component} intranet filename" "${entered:-<ENTER>}" "$selected" "source=${source}; default=${default_file}"
        fi
    fi

    SELECTED_INSTALLER_NAME="$selected"
    SELECTED_INSTALLER="${WORK_HOME}/${selected}"
    if [ -s "$SELECTED_INSTALLER" ]; then source="home"; ok "Selected home-directory installer: ${SELECTED_INSTALLER}"
    else source="intranet"; log "Selected installer: ${selected}; intranet download will be attempted if needed."; fi
    record_choice "Final ${component} package" "$selected" "$selected" "source=${source}; path=${SELECTED_INSTALLER}"
    return 0
}

get_driver_version_from_filename() {
    local name
    name=$(basename "$1")
    if [[ "$name" =~ ^NVIDIA-Linux-x86_64-([0-9]+([.][0-9]+)+)\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

get_cuda_version_from_filename() {
    local name
    name=$(basename "$1")
    # A CUDA runfile is commonly named cuda_13.2.1_<driver-build>_linux.run; the Toolkit installation directory is cuda-13.2.
    if [[ "$name" =~ ^cuda_([0-9]+[.][0-9]+)([.][0-9]+)?_.*linux\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$name" =~ ^cuda_([0-9]+[.][0-9]+)([.][0-9]+)?\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

get_cuda_package_driver_version_from_filename() {
    local name
    name=$(basename "$1")
    # Some CUDA runfile names include the associated driver build, for example cuda_13.2.1_595.58.03_linux.run.
    if [[ "$name" =~ ^cuda_[0-9]+([.][0-9]+)+_([0-9]+([.][0-9]+)+)_linux\.run$ ]]; then
        echo "${BASH_REMATCH[2]}"
    else
        echo ""
    fi
}

get_apt_nvidia_packages() {
    dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' \
        'nvidia-driver-*' 'nvidia-dkms-*' 2>/dev/null | awk '$1 ~ /^ii/ {print $2}' | head -10 || true
}

get_apt_cuda_packages() {
    dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' \
        'cuda' 'cuda-[0-9]*' 'cuda-toolkit-*' 'cuda-compiler-*' 'cuda-libraries-*' 'cuda-runtime-*' 'nvidia-cuda-toolkit' 2>/dev/null | awk '$1 ~ /^ii/ {print $2}' | head -10 || true
}

choose_driver_module_type() {
    log ""
    log "Select the NVIDIA driver module type:"
    log "  1) Proprietary kernel module"
    log "  2) Open kernel module (only for GPUs/drivers that support it)"
    while true; do
        read -r -p "Enter choice [1/2, required]: " module_choice || return 1
        case "$module_choice" in
            1)
                NVIDIA_MODULE_TYPE="proprietary"
                record_choice "NVIDIA module type" "$module_choice" "proprietary" "selected option=1"
                log "Selected NVIDIA module type: PROPRIETARY"
                return 0
                ;;
            2)
                NVIDIA_MODULE_TYPE="open"
                record_choice "NVIDIA module type" "$module_choice" "open" "selected option=2"
                log "Selected NVIDIA module type: OPEN"
                return 0
                ;;
            *) echo "Invalid choice. Enter 1 or 2 explicitly." ;;
        esac
    done
}

install_selected_nvidia_driver() {
    local installer="$1"
    local package_version=""
    local current_version=""
    local apt_packages=""
    local installer_rc=0
    DRIVER_INSTALL_ATTEMPTED=0

    package_version=$(get_driver_version_from_filename "$installer")
    current_version=$(check_nvidia_driver_installed) || true
    if [ -n "$current_version" ] && [ "${REPLACE_DRIVER:-0}" != "1" ]; then
        warn "NVIDIA driver ${current_version} is already installed and no replacement was approved; preserving it."
        DRIVER_INSTALL_ATTEMPTED=0
        return 0
    fi

    # Determine the currently installed kernel-module type where possible.
    # NVIDIA open modules commonly report Dual MIT/GPL; proprietary modules report NVIDIA.
    local current_module_license=""
    local current_module_type=""
    current_module_license=$(modinfo -F license nvidia 2>/dev/null | head -n 1 || true)
    case "$current_module_license" in
        *MIT*|*GPL*) current_module_type="open" ;;
        *NVIDIA*) current_module_type="proprietary" ;;
        *) current_module_type="" ;;
    esac

    if [ -n "$current_version" ] && [ -n "$package_version" ] && [ "$current_version" = "$package_version" ]; then
        if [ "$current_module_type" = "$NVIDIA_MODULE_TYPE" ]; then
            ok "The installed driver version and module type match the selected configuration; skipping reinstallation."
            return 0
        elif [ -n "$current_module_type" ]; then
            log "The driver version matches (${current_version}), but the installed module type is ${current_module_type} and the selected type is ${NVIDIA_MODULE_TYPE}."
            log "A confirmed driver replacement is required to change the module type."
        else
            warn "The driver version matches (${current_version}), but the current module type could not be detected. A replacement will require confirmation."
        fi
    fi

    apt_packages=$(get_apt_nvidia_packages)
    if [ -n "$apt_packages" ]; then
        warn "Detected NVIDIA driver packages managed by APT/dpkg:"
        log "$apt_packages"
        warn "To avoid mixing APT-managed drivers with the NVIDIA .run installer, these packages will not be removed automatically and the .run driver installation will not continue."
        warn "Handle the APT-managed driver separately, then run this script again."
        return 1
    fi

    # Verify that nouveau will not block the install before removing an existing working driver.
    if ! ensure_nouveau_not_loaded; then
        warn "Existing NVIDIA driver, if any, was not uninstalled because nouveau is still loaded."
        return 1
    fi

    if [ -n "$current_version" ] && [ "${REPLACE_DRIVER:-0}" = "1" ]; then
        if command -v nvidia-uninstall >/dev/null 2>&1; then
            log "Replacing the pre-approved NVIDIA .run driver noninteractively..."
            if ! nvidia-uninstall --silent >> "$LOG_FILE" 2>&1; then
                warn "nvidia-uninstall failed; stopping driver replacement safely."
                return 1
            fi
        else
            warn "Cannot safely replace the installed driver because nvidia-uninstall is unavailable. Existing driver will be kept."
            return 1
        fi
    fi

    log "Driver installation was authorized in the pre-run configuration stage; no additional prompt will be shown."
    chmod +x "$installer"

    log "Installing the NVIDIA driver (module type: ${NVIDIA_MODULE_TYPE})..."
    DRIVER_INSTALL_ATTEMPTED=1
    set +e
    sh "$installer" -s --no-x-check --dkms --kernel-module-type="${NVIDIA_MODULE_TYPE}" 2>&1 | tee -a "$LOG_FILE" | tail -6
    installer_rc=${PIPESTATUS[0]}
    set -e

    current_version=$(check_nvidia_driver_installed) || true
    if [ "$installer_rc" -ne 0 ]; then
        warn "The NVIDIA driver installer returned error code ${installer_rc}. Check the log: ${LOG_FILE}"
        return 1
    fi
    if [ -n "$current_version" ]; then
        ok "The NVIDIA driver installer finished; detected driver version: ${current_version}"
    elif command -v nvidia-smi >/dev/null 2>&1 || [ -f /usr/bin/nvidia-smi ]; then
        warn "Driver utilities are installed, but the kernel module has not been confirmed as loaded; a reboot may be required."
    else
        warn "No NVIDIA driver was detected after installation. Check the log: ${LOG_FILE}"
        return 1
    fi
    return 0
}

install_selected_cuda_toolkit() {
    local installer="$1"
    local package_version=""
    local current_version=""
    local current_driver=""
    local package_driver_version=""
    local installer_rc=0
    CUDA_INSTALL_ATTEMPTED=0

    package_version=$(get_cuda_version_from_filename "$installer")
    package_driver_version=$(get_cuda_package_driver_version_from_filename "$installer")
    current_version=$(check_cuda_installed) || true
    if [ -n "$current_version" ] && [ "${REPLACE_CUDA:-0}" != "1" ]; then
        CUDA_VERSION="$current_version"
        setup_cuda_env "$CUDA_VERSION"
        warn "CUDA Toolkit ${current_version} is already installed and no version change was approved; preserving it."
        CUDA_INSTALL_ATTEMPTED=0
        return 0
    fi
    current_driver=$(check_nvidia_driver_installed) || true

    if [ -n "$package_driver_version" ]; then
        if [ -z "$current_driver" ]; then
            if [ "${DRIVER_INSTALL_SUCCEEDED_THIS_RUN:-0}" = "1" ]; then
                warn "The NVIDIA driver installer ran, but the module is not recognized by the current session. Continuing with CUDA Toolkit installation; reboot afterward and verify with nvidia-smi."
            else
                warn "The selected CUDA installer filename indicates an associated driver version of ${package_driver_version}, but no NVIDIA driver is currently detected."
                log "No NVIDIA driver is currently detected. Proceeding with Toolkit-only installation; verify driver availability after reboot."
                record_choice "CUDA compatibility action" "AUTO" "continue Toolkit only" "no driver detected; CUDA runfile driver component is disabled"
            fi
        elif dpkg --compare-versions "$current_driver" lt "$package_driver_version"; then
            warn "The installed NVIDIA driver ${current_driver} is older than the CUDA runfile's associated driver ${package_driver_version}; skipping CUDA automatically to avoid a likely compatibility problem."
            record_choice "CUDA compatibility action" "AUTO" "skip Toolkit install" "installed driver older than package-associated driver"
            return 0
        fi
    fi

    if [ -n "$package_version" ] && [ -x "/usr/local/cuda-${package_version}/bin/nvcc" ]; then
        ok "CUDA Toolkit ${package_version} already exists. Switching the environment configuration to this version without reinstalling it."
        CUDA_VERSION="$package_version"
        setup_cuda_env "$CUDA_VERSION"
        return 0
    fi

    if [ -n "$package_version" ] && [ -n "$current_version" ] && [ "$current_version" = "$package_version" ]; then
        ok "The installed CUDA Toolkit version ${current_version} matches the selected version; skipping reinstallation."
        CUDA_VERSION="$current_version"
        setup_cuda_env "$CUDA_VERSION"
        return 0
    fi

    if [ -n "$current_version" ]; then
        log "Currently detected CUDA Toolkit version: ${current_version}"
        log "Target version from selected installer: ${package_version:-unable to determine from filename}"
        if [ -n "$package_version" ]; then
            log "A different version will be installed to its own /usr/local/cuda-${package_version} directory when possible; this script will not automatically remove older versions."
        fi
    fi

    local apt_cuda_packages
    apt_cuda_packages=$(get_apt_cuda_packages)
    if [ -n "$apt_cuda_packages" ]; then
        warn "Detected CUDA-related packages managed by APT/dpkg:"
        log "$apt_cuda_packages"
        warn "To avoid conflicts between APT and .run installations, these packages will not be removed automatically and the CUDA .run installation will not continue."
        return 1
    fi

    if [ -n "$package_version" ] && [ -d "/usr/local/cuda-${package_version}" ]; then
        warn "Target directory /usr/local/cuda-${package_version} already exists, but no executable nvcc was found. Stopping to avoid overwriting an unknown installation."
        return 1
    fi

    chmod +x "$installer"
    log "Installing the CUDA Toolkit (without installing the driver bundled with CUDA)..."
    CUDA_INSTALL_ATTEMPTED=1
    set +e
    sh "$installer" --silent --toolkit --samples --override 2>&1 | tee -a "$LOG_FILE" | tail -6
    installer_rc=${PIPESTATUS[0]}
    set -e
    if [ "$installer_rc" -ne 0 ]; then
        warn "The CUDA installer returned error code ${installer_rc}. Check the log: ${LOG_FILE}"
        return 1
    fi

    if [ -n "$package_version" ] && [ -x "/usr/local/cuda-${package_version}/bin/nvcc" ]; then
        CUDA_VERSION="$package_version"
    else
        CUDA_VERSION=$(check_cuda_installed) || true
    fi
    if [ -n "$CUDA_VERSION" ]; then
        ok "CUDA Toolkit installation completed/verified. Configured target version: ${CUDA_VERSION}"
        setup_cuda_env "$CUDA_VERSION"
    else
        warn "The CUDA Toolkit version could not be identified after the installer ran. Check the log: ${LOG_FILE}"
        return 1
    fi
    return 0
}


cleanup_other_cuda_toolkits() {
    [ "${CLEANUP_OLD_CUDA:-0}" = "1" ] || return 0

    local keep_version="${CUDA_VERSION:-${CUDA_CLEANUP_KEEP_VERSION:-}}"
    local path version uninstaller
    local apt_cuda_packages=""

    if [ -z "$keep_version" ] || [ ! -x "/usr/local/cuda-${keep_version}/bin/nvcc" ]; then
        warn "CUDA cleanup skipped: the selected/kept Toolkit version has not been verified at /usr/local/cuda-${keep_version:-UNKNOWN}."
        record_choice "CUDA cleanup result" "AUTO" "SKIPPED" "reason=keep version missing or nvcc not executable"
        return 0
    fi

    apt_cuda_packages=$(get_apt_cuda_packages)
    if [ -n "$apt_cuda_packages" ]; then
        warn "CUDA cleanup skipped because APT-managed CUDA packages are present. No APT packages will be removed automatically."
        log "$apt_cuda_packages"
        record_choice "CUDA cleanup result" "AUTO" "SKIPPED" "reason=APT-managed CUDA packages detected"
        return 0
    fi

    for path in /usr/local/cuda-[0-9]*; do
        [ -d "$path" ] || continue
        version="${path##*/cuda-}"
        [[ "$version" =~ ^[0-9]+([.][0-9]+)*$ ]] || continue
        [ "$version" = "$keep_version" ] && continue

        uninstaller="${path}/bin/cuda-uninstaller"
        if [ -x "$uninstaller" ]; then
            log "Uninstalling additional CUDA Toolkit ${version} using its official runfile uninstaller..."
            if yes | "$uninstaller" >> "$LOG_FILE" 2>&1; then
                ok "Removed CUDA Toolkit ${version} via cuda-uninstaller."
                record_choice "CUDA cleanup result" "approved before initialization" "REMOVED ${version}" "kept=${keep_version}; method=cuda-uninstaller"
            else
                warn "Uninstaller failed for CUDA Toolkit ${version}; leaving remaining files for manual review."
                record_choice "CUDA cleanup result" "approved before initialization" "FAILED ${version}" "kept=${keep_version}; method=cuda-uninstaller"
            fi
        else
            warn "No cuda-uninstaller found for CUDA Toolkit ${version}; leaving it untouched."
            record_choice "CUDA cleanup result" "approved before initialization" "KEPT ${version}" "reason=no cuda-uninstaller found; kept=${keep_version}"
        fi
    done
}

step_install_nvidia() {
    step_header "NVIDIA Driver and CUDA Installation"

    local mode="${GPU_INSTALL_MODE:-3}"
    DRIVER_INSTALL_SUCCEEDED_THIS_RUN=0
    if [ "$mode" = "4" ] || [ "${INSTALL_NVIDIA:-0}" != "1" ]; then
        log "Skipping NVIDIA driver and CUDA installation as requested; existing components will not be removed."
        return 0
    fi

    local current_driver="" current_cuda="" target_driver="" target_cuda=""
    local do_driver=1 do_cuda=1 driver_installer="" cuda_installer=""
    current_driver=$(check_nvidia_driver_installed) || true
    current_cuda=$(check_cuda_installed) || true

    log ""
    log "Current GPU component status:"
    log "  NVIDIA driver: ${current_driver:-not detected}"
    log "  CUDA Toolkit: ${current_cuda:-not detected}"

    if [ "$mode" = "1" ]; then
        local wanted_driver="${CUSTOM_DRIVER_PACKAGE:-$NVIDIA_DRIVER}"
        local wanted_cuda="${CUSTOM_CUDA_PACKAGE:-$CUDA_PACKAGE}"
        log "Automatic missing-only policy: existing NVIDIA/CUDA versions are never replaced."
        log "Selected packages: driver=${wanted_driver}; CUDA=${wanted_cuda}"
        target_driver=$(get_driver_version_from_filename "$wanted_driver")
        target_cuda=$(get_cuda_version_from_filename "$wanted_cuda")

        if [ -n "$current_driver" ]; then
            do_driver=0
            log "Preserving already-installed NVIDIA driver ${current_driver}; no replacement or download."
        fi
        if [ -n "$current_cuda" ]; then
            do_cuda=0
            CUDA_VERSION="$current_cuda"
            setup_cuda_env "$CUDA_VERSION"
            log "Preserving already-installed CUDA Toolkit ${current_cuda}; no replacement or download."
        fi
        if [ "$do_driver" = "1" ]; then
            if download_file "$wanted_driver" "${WORK_HOME}/${wanted_driver}"; then
                driver_installer="${WORK_HOME}/${wanted_driver}"
            else
                warn "Could not obtain the selected NVIDIA driver package from the intranet: ${wanted_driver}"
            fi
        fi
        if [ "$do_cuda" = "1" ]; then
            if download_file "$wanted_cuda" "${WORK_HOME}/${wanted_cuda}"; then
                cuda_installer="${WORK_HOME}/${wanted_cuda}"
            else
                warn "Could not obtain the selected CUDA installer from the intranet: ${wanted_cuda}"
            fi
        fi
    elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
        # All custom package names and replacement permissions were decided before initialization.
        if [ -n "$current_driver" ] && [ "${REPLACE_DRIVER:-0}" != "1" ]; then
            log "Preserving already-installed NVIDIA driver ${current_driver}; no replacement was approved."
        elif [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ]; then
            driver_installer="${WORK_HOME}/${CUSTOM_DRIVER_PACKAGE}"
            if [ ! -s "$driver_installer" ]; then
                if ! download_file "$CUSTOM_DRIVER_PACKAGE" "$driver_installer"; then
                    warn "Could not obtain the custom NVIDIA driver package: ${CUSTOM_DRIVER_PACKAGE}. Skipping the driver component."
                    driver_installer=""
                fi
            fi
        else
            warn "No NVIDIA driver installer was selected during the pre-initialization stage; skipping the driver component."
        fi

        if [ -n "$current_cuda" ] && [ "${REPLACE_CUDA:-0}" != "1" ]; then
            CUDA_VERSION="$current_cuda"
            setup_cuda_env "$CUDA_VERSION"
            log "Preserving already-installed CUDA Toolkit ${current_cuda}; no version change was approved."
        elif [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
            cuda_installer="${WORK_HOME}/${CUSTOM_CUDA_PACKAGE}"
            if [ ! -s "$cuda_installer" ]; then
                if ! download_file "$CUSTOM_CUDA_PACKAGE" "$cuda_installer"; then
                    warn "Could not obtain the custom CUDA installer: ${CUSTOM_CUDA_PACKAGE}. Skipping the CUDA component."
                    cuda_installer=""
                fi
            fi
        else
            warn "No CUDA installer was selected during the pre-initialization stage; skipping the CUDA component."
        fi
    else
        warn "Unknown GPU installation mode. Skipping GPU installation for safety."
        return 0
    fi

    if [ -n "$driver_installer" ]; then
        if install_selected_nvidia_driver "$driver_installer"; then
            if [ "${DRIVER_INSTALL_ATTEMPTED:-0}" = "1" ]; then
                DRIVER_INSTALL_SUCCEEDED_THIS_RUN=1
                setup_nvidia_persistence
                if command -v dkms >/dev/null 2>&1; then
                    log "Running dkms autoinstall to build the NVIDIA module for the current kernel..."
                    if dkms autoinstall 2>&1 | tee -a "$LOG_FILE" | tail -5; then
                        ok "dkms autoinstall completed"
                    else
                        warn "dkms autoinstall failed. Check the log: ${LOG_FILE}"
                    fi
                fi
            fi
        else
            warn "The NVIDIA driver step did not complete; this operation will not be marked successful."
        fi
    else
        log "The NVIDIA driver was not installed during this run."
    fi

    if [ -n "$cuda_installer" ]; then
        if ! install_selected_cuda_toolkit "$cuda_installer"; then
            warn "The CUDA Toolkit step did not complete; this operation will not be marked successful."
        fi
    else
        log "The CUDA Toolkit was not installed during this run."
    fi

    cleanup_other_cuda_toolkits

    # Keep the original gpu-burn download behavior (only when fresh or custom installation is selected).
    log "Downloading the gpu-burn stress-test tool (if available on the intranet)..."
    download_file "gpu-burn.zip" "${WORK_HOME}/gpu-burn.zip" || true

    log "NVIDIA/CUDA stage finished. Any reboot decision is deferred to the final step; verify the driver with nvidia-smi after reboot."
}

step_download_test_files() {
    step_header "Download test files"

    log "Downloading test files to ${WORK_HOME}..."
    for f in "${TEST_FILES[@]}"; do
        download_file "$f" "${WORK_HOME}/${f}" || true
    done

    if [ -f "${WORK_HOME}/storcli64" ]; then
        chmod +x "${WORK_HOME}/storcli64"
        mv "${WORK_HOME}/storcli64" /usr/bin/storcli64
        ok "storcli64 moved to /usr/bin/"
    fi

    for f in "${WORK_HOME}"/check_V5.sh "${WORK_HOME}"/mount_V6.sh "${WORK_HOME}"/yc.sh "${WORK_HOME}"/upload_check.sh; do
        if [ -f "$f" ]; then
            chmod +x "$f"
        fi
    done
    ok "Test scripts marked executable"
}

# ================================================= Stage 9: Run upload check script =================================================

step_run_upload_check() {
    step_header "Run upload_check.sh"

    local upload_script="${WORK_HOME}/upload_check.sh"
    if [ ! -f "$upload_script" ]; then
        warn "upload_check.sh not found. Skip execution"
        return 0
    fi

    chmod +x "$upload_script"
    log "Running ${upload_script}..."
    if bash "$upload_script" 2>&1 | tee -a "$LOG_FILE"; then
        ok "upload_check.sh completed"
    else
        warn "upload_check.sh failed. Check log: ${LOG_FILE}"
    fi
}

# ================================================= Stage 10: Finish =================================================

step_finish() {
    step_header "Initialization completed"

    log ""
    log "${GREEN}============================================================${NC}"
    log "${GREEN}  allStepdonecompletefinished${NC}"
    log "${GREEN}============================================================${NC}"
    log "  Log file: ${LOG_FILE}"
    log "  Run user: ${WORK_USER}"
    log "  systemversion: $(detect_ubuntu_version)"
    INSTALLED_DRIVER=$(check_nvidia_driver_installed) || true
    INSTALLED_CUDA=$(check_cuda_installed) || true
    if [ -n "$INSTALLED_DRIVER" ]; then
        log "  NVIDIA driver: detected (${INSTALLED_DRIVER})"
    else
        log "  NVIDIA driver: not detected"
    fi
    if [ -n "$INSTALLED_CUDA" ]; then
        log "  CUDA Toolkit: detected (${INSTALLED_CUDA})"
    else
        log "  CUDA Toolkit: not detected"
    fi
    if [ "$DO_SYSTEM_UPGRADE" = "1" ]; then
        log "  System upgrade: done"
    else
        log "  System upgrade: skip"
    fi
    log ""

    if confirm "Reboot system now?" "N"; then
        log "${YELLOW}System will reboot in 5 seconds...${NC}"
        sleep 5
        reboot
    else
        log "Please reboot manually to apply all changes."
    fi
}

# ================================================= Main flow =================================================

main() {
    check_root

    touch "$LOG_FILE"
    chown "$WORK_USER":"$WORK_USER" "$LOG_FILE" 2>/dev/null || true
    if [ -n "${LAUNCHER_LOG:-}" ] && [ -f "$LAUNCHER_LOG" ]; then
        cat "$LAUNCHER_LOG" >> "$LOG_FILE"
    fi
    log_plain "[RUN] Selected combined mode: ${SELECTED_MODE:-unknown}"
    log_plain "[RUN] Operating system: $(detect_ubuntu_version)"
    log_plain "[RUN] Initial kernel: $(uname -r)"
    log_plain "===== Ubuntu 20.04 init log ====="
    log_plain "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_plain "Run user: ${WORK_USER} (root=${USER})"
    log_plain "systemversion: $(detect_ubuntu_version)"
    log_plain "kernelversion: $(uname -r)"
    log_plain "===================================="

    pre_interaction

    step_check_network
    step_configure_sources
    step_install_tools
    step_sync_time
    step_system_upgrade
    step_system_optimize
    step_install_nvidia
    step_download_test_files
    step_run_upload_check
    step_finish
}

main "$@"
__ORIGINAL_UBUNTU_20_04_DESKTOP_PAYLOAD_END_7A4C19__
            ;;
        server)
            cat > "$destination" <<'__ORIGINAL_UBUNTU_20_04_SERVER_PAYLOAD_END_7A4C19__'
#!/bin/bash

# ============================================================
# Ubuntu 20.04.6 Server System Initialization Script
# Version: v1.0 (integrated from ubuntu20.04-init.sh and net.sh)
# Description: Server initialization (no desktop), including:
#       - APT sources, common tools, time synchronization, system upgrade, and GRUB
#       - Disable cloud-init network management and configure DHCP with Netplan
#       - Optimize systemd-networkd-wait-online timeout
#       - Disable NetworkManager-wait-online
#       - Optional NVIDIA driver and CUDA installation
# Usage: sudo bash ubuntu20.04server-init.sh
# ============================================================

set -e

# ================= Configuration variables =================

INTRANET_SERVER="http://192.168.19.1"
INTRANET_PATH="${INTRANET_SERVER}/chfs/shared/autoinstall"

NVIDIA_DRIVER="NVIDIA-Linux-x86_64-595.80.run"
CUDA_PACKAGE="cuda_13.2.1_595.58.03_linux.run"

TEST_FILES=(
    "check_V5.sh"
    "storcli64"
    "mount_V6.sh"
    "yc.sh"
    "upload_check.sh"
)

COMMON_TOOLS="vim ssh dkms htop ipmitool stress lm-sensors stress-ng \
ethtool net-tools unzip make gcc g++ wget curl git cmake mdadm chrony \
stressapptest fio smartmontools nvme-cli nvtop sshpass tmux"

EXTRA_LIBS="pkg-config libglvnd-dev lib32z1 lib32ncurses6"

BUILD_LIBS="build-essential linux-headers-$(uname -r) libcap-dev libssl-dev \
libnl-3-dev libnl-route-3-dev autoconf automake libtool flex bison"

# Netplan configuration target file
NETPLAN_FILE="/etc/netplan/01-auto-dhcp.yaml"

# ================================================= Environment variables =================================================

if [ -n "$SUDO_USER" ]; then
    WORK_USER="$SUDO_USER"
else
    WORK_USER="$USER"
fi
WORK_HOME=$(eval echo ~"$WORK_USER")
LOG_FILE="${WORK_HOME}/ubuntu-server-init-$(date +%Y%m%d-%H%M%S).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_STEPS=11
CURRENT_STEP=0

# ================================================= Helper functions =================================================

log() {
    local rendered
    rendered="$(echo -e "$1")"
    printf '%s
' "$rendered" | tee -a "$LOG_FILE"
    if [ -n "${LAUNCHER_LOG:-}" ] && [ "$LAUNCHER_LOG" != "$LOG_FILE" ]; then
        printf '%s
' "$rendered" >> "$LAUNCHER_LOG"
    fi
}

log_plain() {
    printf '%s
' "$1" >> "$LOG_FILE"
    if [ -n "${LAUNCHER_LOG:-}" ] && [ "$LAUNCHER_LOG" != "$LOG_FILE" ]; then
        printf '%s
' "$1" >> "$LAUNCHER_LOG"
    fi
}

record_choice() {
    local label="$1" input="$2" selected="$3" details="${4:-}"
    [ -n "$input" ] || input="<ENTER>"
    log_plain "[OPTION] ${label} | input=${input} | selected=${selected} | ${details}"
}

step_header() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log ""
    log "${BLUE}============================================================${NC}"
    log "${BLUE} Step ${CURRENT_STEP}/${TOTAL_STEPS}: $1 ${NC}"
    log "${BLUE}============================================================${NC}"
}

ok()    { log "${GREEN}[ OK ]${NC} $1"; }
warn()  { log "${YELLOW}[WARN]${NC} $1"; }
err()   { log "${RED}[ERR ]${NC} $1"; }

confirm() {
    local msg="$1" default="${2:-Y}" prompt input_choice choice outcome
    if [ "$default" = "Y" ]; then prompt=" [Y/n] "; else prompt=" [y/N] "; fi
    while true; do
        input_choice=""
        read -r -p "${msg}${prompt}" input_choice || input_choice=""
        choice="$input_choice"
        choice=${choice:-$default}
        case "$choice" in
            [Yy]*) outcome="YES"; record_choice "$msg" "${input_choice:-<ENTER>}" "$outcome" "effective=${choice}; default=${default}"; return 0 ;;
            [Nn]*) outcome="NO"; record_choice "$msg" "${input_choice:-<ENTER>}" "$outcome" "effective=${choice}; default=${default}"; return 1 ;;
            *) record_choice "$msg" "$input_choice" "INVALID" "expected=Y/N; default=${default}"; echo "Please enter Y or N" ;;
        esac
    done
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "This script must be run as root. Use: sudo bash $0"
        exit 1
    fi
}

# ================================================= Pre-initialization prompts =================================================

check_nvidia_gpu() {
    local gpucount
    gpucount=$(lspci 2>/dev/null | grep -i "nvidia" | grep -ci "vga\|3d\|display" || true)
    if [ "$gpucount" -gt 0 ]; then
        echo "1"
    else
        echo "0"
    fi
}

detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-$VERSION}"
    else
        echo "unknown"
    fi
}

check_nvidia_driver_installed() {
    local drv_version
    drv_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1) || true
    if [ -n "$drv_version" ]; then
        echo "$drv_version"
        return 0
    fi
    if [ -f /proc/driver/nvidia/version ]; then
        local mod_version
        mod_version=$(grep -oP 'Module\s+\K[0-9.]+' /proc/driver/nvidia/version 2>/dev/null | head -1) || true
        if [ -n "$mod_version" ]; then
            echo "$mod_version"
            return 0
        fi
    fi
    echo ""
    return 1
}

check_cuda_installed() {
    local cuda_ver
    cuda_ver=$(ls /usr/local/ 2>/dev/null | grep -E "^cuda-[0-9.]+" | cut -d- -f2 | sort -V | tail -n 1) || true
    if [ -n "$cuda_ver" ]; then
        echo "$cuda_ver"
        return 0
    fi
    echo ""
    return 1
}

list_installed_cuda_toolkits() {
    local path version
    for path in /usr/local/cuda-[0-9]*; do
        [ -d "$path" ] || continue
        version="${path##*/cuda-}"
        [[ "$version" =~ ^[0-9]+([.][0-9]+)*$ ]] || continue
        printf '%s\n' "$version"
    done | sort -Vu
}

pre_interaction() {
    log ""
    log "${BLUE}======================== Configuration Summary ========================${NC}"

    PRESTART_OPTIONS=1
    step_select_apt_mirror

    SYS_VER=$(detect_ubuntu_version)
    log "Current system: ${YELLOW}${SYS_VER}${NC}"
    log "Run mode: ${YELLOW}Server (no desktop)${NC}"

    GPU_FOUND=$(check_nvidia_gpu)
    if [ "$GPU_FOUND" = "1" ]; then
        log "NVIDIA GPU: ${GREEN}detected${NC}"
        EXISTING_DRIVER=$(check_nvidia_driver_installed) || true
        if [ -n "$EXISTING_DRIVER" ]; then
            log "Installed driver: ${GREEN}${EXISTING_DRIVER}${NC}"
        fi
        EXISTING_CUDA=$(check_cuda_installed) || true
        if [ -n "$EXISTING_CUDA" ]; then
            log "Installed CUDA:  ${GREEN}${EXISTING_CUDA}${NC}"
        fi
    else
        log "NVIDIA GPU: ${YELLOW}not detected${NC}"
    fi

    NVIDIA_MODULE_TYPE=""
    GPU_INSTALL_MODE="4"
    INSTALL_NVIDIA=0
    if [ "$GPU_FOUND" = "1" ]; then
        log ""
        log "Select the GPU installation mode for this run:"
        log "  1) Default installation (intranet download; install missing components only; preserve installed driver/CUDA)"
        log "  2) Custom installation (scan the current user home directory; choose a version if multiple installers exist)"
        log "  3) Skip GPU installation (keep the current driver and CUDA)"
        while true; do
            gpu_mode_input=""
            read -r -p "Enter choice [1-3, default 1]: " gpu_mode_input || gpu_mode_input=""
            gpu_mode_choice=${gpu_mode_input:-1}
            case "$gpu_mode_choice" in
                1)
                    GPU_INSTALL_MODE="1"
                    INSTALL_NVIDIA=1
                    log "Selected option 1: Default installation; use configured intranet packages and install missing components only."
                    break
                    ;;
                2)
                    # Internal mode 3 implements custom package selection and replacement confirmations.
                    GPU_INSTALL_MODE="3"
                    INSTALL_NVIDIA=1
                    log "Selected option 2: Custom installation; scan the home directory and confirm any version replacement before initialization."
                    break
                    ;;
                3)
                    GPU_INSTALL_MODE="4"
                    INSTALL_NVIDIA=0
                    log "Selected option 3: Skip GPU installation and preserve current components."
                    break
                    ;;
                *) echo "Enter 1, 2, or 3." ;;
            esac
        done
        case "$GPU_INSTALL_MODE" in
            1) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "1 - Default installation (intranet download)" "existing components=preserve; configured intranet package names; no installer selection prompt" ;;
            3) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "2 - Custom installation" "scan home directory; select among multiple installer versions; explicitly confirm replacements" ;;
            4) record_choice "GPU installation mode" "${gpu_mode_input:-<ENTER>}" "3 - Skip GPU installation" "existing components=preserve" ;;
        esac
    else
        GPU_INSTALL_MODE="4"
        INSTALL_NVIDIA=0
        warn "No NVIDIA GPU detected. Skipping NVIDIA driver and CUDA installation."
        record_choice "GPU installation mode" "AUTO" "3 - Skip GPU installation" "reason=no NVIDIA GPU detected"
    fi
    log ""
    # Plan all installer names before system changes begin. Existing components are always preserved.
    CUSTOM_DRIVER_PACKAGE=""
    CUSTOM_CUDA_PACKAGE=""
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ "${GPU_INSTALL_MODE:-4}" != "4" ]; then
        if [ -n "${EXISTING_DRIVER:-}" ] && [ "${GPU_INSTALL_MODE:-1}" != "3" ]; then
            log "Existing NVIDIA driver ${EXISTING_DRIVER} will be preserved; no driver package selection needed."
            record_choice "NVIDIA driver action" "AUTO" "preserve ${EXISTING_DRIVER}" "reason=driver already installed"
        else
            if [ "$GPU_INSTALL_MODE" = "1" ]; then package_policy="intranet"; else package_policy="manual"; fi
            if select_install_package "driver" "$NVIDIA_DRIVER" "$package_policy"; then
                CUSTOM_DRIVER_PACKAGE="$SELECTED_INSTALLER_NAME"
            else
                warn "No NVIDIA driver installer was selected; driver installation will be skipped."
                record_choice "NVIDIA driver action" "selection failed/cancelled" "skip" "no installer selected"
            fi
        fi
        if [ -n "${EXISTING_CUDA:-}" ] && [ "${GPU_INSTALL_MODE:-1}" != "3" ]; then
            log "Existing CUDA Toolkit ${EXISTING_CUDA} will be preserved; no CUDA package selection needed."
            record_choice "CUDA action" "AUTO" "preserve ${EXISTING_CUDA}" "reason=CUDA already installed"
        else
            if [ "$GPU_INSTALL_MODE" = "1" ]; then package_policy="intranet"; else package_policy="manual"; fi
            if select_install_package "cuda" "$CUDA_PACKAGE" "$package_policy"; then
                CUSTOM_CUDA_PACKAGE="$SELECTED_INSTALLER_NAME"
            else
                warn "No CUDA installer was selected; CUDA installation will be skipped."
                record_choice "CUDA action" "selection failed/cancelled" "skip" "no installer selected"
            fi
        fi
    fi

    # Mode 3 is the only mode allowed to replace an installed component. Confirm every change now.
    REPLACE_DRIVER=0
    REPLACE_CUDA=0
    if [ "${GPU_INSTALL_MODE:-4}" = "3" ]; then
        if [ -n "${EXISTING_DRIVER:-}" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ]; then
            target_driver_pre=$(get_driver_version_from_filename "$CUSTOM_DRIVER_PACKAGE")
            if [ -n "$target_driver_pre" ] && [ "$target_driver_pre" = "$EXISTING_DRIVER" ]; then
                log "Selected driver package matches the installed version ${EXISTING_DRIVER}; no replacement is needed."
                CUSTOM_DRIVER_PACKAGE=""
                record_choice "NVIDIA driver replacement" "AUTO" "NO CHANGE" "selected target version matches installed version"
            elif confirm "Replace installed NVIDIA driver ${EXISTING_DRIVER} with ${target_driver_pre:-$CUSTOM_DRIVER_PACKAGE}?" "N"; then
                REPLACE_DRIVER=1
                record_choice "NVIDIA driver replacement" "confirmed in startup prompts" "YES" "current=${EXISTING_DRIVER}; target=${target_driver_pre:-unknown}"
            else
                CUSTOM_DRIVER_PACKAGE=""
                record_choice "NVIDIA driver replacement" "confirmed in startup prompts" "NO; preserve ${EXISTING_DRIVER}" "target=${target_driver_pre:-unknown}"
            fi
        fi
        if [ -n "${EXISTING_CUDA:-}" ] && [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
            target_cuda_pre=$(get_cuda_version_from_filename "$CUSTOM_CUDA_PACKAGE")
            if [ -n "$target_cuda_pre" ] && [ "$target_cuda_pre" = "$EXISTING_CUDA" ]; then
                log "Selected CUDA package matches the installed Toolkit ${EXISTING_CUDA}; no replacement is needed."
                CUSTOM_CUDA_PACKAGE=""
                record_choice "CUDA version change" "AUTO" "NO CHANGE" "selected target version matches installed version"
            elif confirm "Switch the active CUDA Toolkit from ${EXISTING_CUDA} to ${target_cuda_pre:-$CUSTOM_CUDA_PACKAGE}? Old versions are retained unless you separately approve cleanup." "N"; then
                REPLACE_CUDA=1
                record_choice "CUDA version change" "confirmed in startup prompts" "YES" "current=${EXISTING_CUDA}; target=${target_cuda_pre:-unknown}; other versions retained unless cleanup is approved"
            else
                CUSTOM_CUDA_PACKAGE=""
                record_choice "CUDA version change" "confirmed in startup prompts" "NO; preserve ${EXISTING_CUDA}" "target=${target_cuda_pre:-unknown}"
            fi
        fi
    fi

    # Optional cleanup of additional CUDA runfile installations is decided before any changes begin.
    CLEANUP_OLD_CUDA=0
    CUDA_CLEANUP_KEEP_VERSION="${EXISTING_CUDA:-}"
    if [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
        selected_cuda_version_for_cleanup=$(get_cuda_version_from_filename "$CUSTOM_CUDA_PACKAGE")
        if [ -n "$selected_cuda_version_for_cleanup" ]; then
            if [ -z "${EXISTING_CUDA:-}" ] || [ "${REPLACE_CUDA:-0}" = "1" ] || [ "$selected_cuda_version_for_cleanup" = "${EXISTING_CUDA:-}" ]; then
                CUDA_CLEANUP_KEEP_VERSION="$selected_cuda_version_for_cleanup"
            fi
        fi
    fi
    mapfile -t installed_cuda_versions_pre < <(list_installed_cuda_toolkits)
    if [ "${GPU_INSTALL_MODE:-4}" = "3" ] && [ "${#installed_cuda_versions_pre[@]}" -gt 1 ]; then
        log "Multiple CUDA Toolkit versions were found in /usr/local:"
        cleanup_keep_found=0
        for installed_cuda_ver in "${installed_cuda_versions_pre[@]}"; do
            if [ "$installed_cuda_ver" = "${CUDA_CLEANUP_KEEP_VERSION:-}" ]; then
                cleanup_keep_found=1
                log "  - ${installed_cuda_ver} (planned keep version)"
            else
                log "  - ${installed_cuda_ver} (candidate for cleanup after the selected version is verified)"
            fi
        done
        if [ -n "${CUDA_CLEANUP_KEEP_VERSION:-}" ] && [ "$cleanup_keep_found" = "0" ]; then
            log "  - ${CUDA_CLEANUP_KEEP_VERSION} (selected target; keep only if installation and verification succeed)"
        fi
        if [ -n "${CUDA_CLEANUP_KEEP_VERSION:-}" ]; then
            apt_cuda_packages_pre=$(get_apt_cuda_packages)
            if [ -n "$apt_cuda_packages_pre" ]; then
                warn "APT-managed CUDA packages were detected; automatic cleanup of other CUDA versions is disabled for safety."
                log "$apt_cuda_packages_pre"
                record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=APT-managed CUDA packages detected"
            else
                if confirm "After the selected/kept CUDA Toolkit version is verified, uninstall other CUDA runfile versions that provide cuda-uninstaller? This is irreversible." "N"; then
                    CLEANUP_OLD_CUDA=1
                    record_choice "CUDA duplicate cleanup" "confirmed before initialization" "YES" "keep_version=${CUDA_CLEANUP_KEEP_VERSION}; remove other runfile versions only after target verification"
                else
                    CLEANUP_OLD_CUDA=0
                    record_choice "CUDA duplicate cleanup" "confirmed before initialization" "NO" "keep all installed CUDA versions"
                fi
            fi
        else
            warn "Cannot determine a CUDA version to keep; leaving all installed CUDA versions untouched."
            record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=no keep version identified"
        fi
    else
        record_choice "CUDA duplicate cleanup" "AUTO" "NO" "reason=not custom mode or fewer than two CUDA toolkit versions detected"
    fi

    # Choose the module type only if a driver is missing or a replacement was approved.
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ] && { [ -z "${EXISTING_DRIVER:-}" ] || [ "${REPLACE_DRIVER:-0}" = "1" ]; }; then
        if [ "${GPU_INSTALL_MODE:-1}" = "1" ] || [ "${GPU_INSTALL_MODE:-1}" = "2" ] || [ "${GPU_INSTALL_MODE:-1}" = "3" ]; then
            if ! choose_driver_module_type; then
                err "Unable to read the NVIDIA module-type selection; aborting before initialization."
                exit 1
            fi
        fi
    fi

    # Safety check is still an upfront choice: never install a driver from an active GUI terminal.
    if [ "${INSTALL_NVIDIA:-0}" = "1" ] && [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ] && { [ -z "${EXISTING_DRIVER:-}" ] || [ "${REPLACE_DRIVER:-0}" = "1" ]; } && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        warn "A graphical display session appears active. NVIDIA driver installation may interrupt this session."
        if ! confirm "Continue anyway? Recommended: switch to TTY (Ctrl+Alt+F3 to F6) or SSH first." "N"; then
            log "User chose not to continue from the active graphical session; exiting before system changes."
            exit 0
        fi
    else
        record_choice "NVIDIA installation session check" "AUTO" "continue" "no active DISPLAY/WAYLAND session detected, or no driver installation/replacement selected"
    fi

    if confirm "Upgrade the system to the latest packages? (Choose N to keep the current versions)" "Y"; then
        DO_SYSTEM_UPGRADE=1
    else
        DO_SYSTEM_UPGRADE=0
        warn "Skipping system upgrade; keeping current versions."
    fi

    log ""
    log "${YELLOW}WARNING: The network configuration stage will move all existing files from /etc/netplan/ to a backup and generate a new DHCP configuration.${NC}"
    log "${YELLOW}   If connected via SSH, ensure the system can obtain an IP address via DHCP after Netplan is regenerated.${NC}"

    log ""
    PRESTART_OPTIONS=0
    record_choice "System upgrade" "chosen in pre-run prompts" "$DO_SYSTEM_UPGRADE" "1=dist-upgrade; 0=skip"
    log "${GREEN}Configuration confirmed. Starting initialization...${NC}"
    log ""
}

# ================================================= Stage 1: Network Check =================================================

step_check_network() {
    step_header "Check network connectivity"
    log "Checking public network connectivity..."
    if ping -c 3 -W 2 223.5.5.5 > /dev/null 2>&1; then
        ok "Public network is reachable"
    else
        err "Public network is unreachable. Aborting the script."
        log "Check network configuration and run the script again."
        exit 1
    fi

    log "Checking intranet server (192.168.19.1) connectivity..."
    if ping -c 3 -W 2 192.168.19.1 > /dev/null 2>&1; then
        ok "Intranet server is reachable"
    else
        warn "Intranet server is unreachable; download-related steps may be skipped."
    fi
}

# ================================================= Stage 2: Select APT Mirror =================================================

step_select_apt_mirror() {
    if [ "${PRESTART_OPTIONS:-0}" = "1" ]; then
        log "[PRE-RUN OPTION] Select APT Mirror"
    else
        step_header "Select APT Mirror"
    fi
    log "Select the Ubuntu 20.04 (focal) mirror to use:"
    log "  1) USTC Mirror (default)"
    log "  2) Tsinghua University TUNA Mirror"
    log "  3) Alibaba Cloud Mirror"
    log "  4) Huawei Cloud Mirror"
    log "  5) HUST Mirror"
    log "  6) Tencent Cloud Mirror"
    log "  7) Official Ubuntu Repository"

    while true; do
        read -r -p "Enter a number [1-7, default 1]: " mirror_input
        mirror_choice=${mirror_input:-1}
        case "$mirror_choice" in
            1)
                APT_MIRROR_NAME="USTC Mirror"
                APT_MIRROR_URL="https://mirrors.ustc.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            2)
                APT_MIRROR_NAME="Tsinghua University TUNA Mirror"
                APT_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            3)
                APT_MIRROR_NAME="Alibaba Cloud Mirror"
                APT_MIRROR_URL="https://mirrors.aliyun.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            4)
                APT_MIRROR_NAME="Huawei Cloud Mirror"
                APT_MIRROR_URL="https://repo.huaweicloud.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            5)
                APT_MIRROR_NAME="HUST Mirror"
                APT_MIRROR_URL="https://mirrors.hust.edu.cn/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            6)
                APT_MIRROR_NAME="Tencent Cloud Mirror"
                APT_MIRROR_URL="https://mirrors.cloud.tencent.com/ubuntu"
                APT_SECURITY_URL="$APT_MIRROR_URL"
                break ;;
            7)
                APT_MIRROR_NAME="Official Ubuntu Repository"
                APT_MIRROR_URL="http://archive.ubuntu.com/ubuntu"
                APT_SECURITY_URL="http://security.ubuntu.com/ubuntu"
                break ;;
            *) echo "Enter a number between 1 and 7." ;;
        esac
    done

    record_choice "APT mirror" "${mirror_input:-<ENTER>}" "${APT_MIRROR_NAME}" "index=${mirror_choice}; main=${APT_MIRROR_URL}; security=${APT_SECURITY_URL}"
    ok "Selected APT mirror: ${APT_MIRROR_NAME}"
    log "  Main/updates repository URL: ${APT_MIRROR_URL}"
    log "  Security repository URL: ${APT_SECURITY_URL}"
}

# ================================================= Stage 2: APT Source Configuration =================================================

step_configure_sources() {
    step_header "Back up and configure APT sources"

    if [ -f /etc/apt/sources.list ]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
        ok "Backed up /etc/apt/sources.list -> sources.list.bak"
    fi

    # Ubuntu 20.04 uses the traditional /etc/apt/sources.list format for compatibility.
    if [ -z "${APT_MIRROR_URL:-}" ] || [ -z "${APT_SECURITY_URL:-}" ]; then
        err "No APT mirror selected. Run step_select_apt_mirror first."
        return 1
    fi

    tee /etc/apt/sources.list > /dev/null << EOF
deb ${APT_MIRROR_URL}/ focal main restricted universe multiverse
deb ${APT_MIRROR_URL}/ focal-updates main restricted universe multiverse
deb ${APT_MIRROR_URL}/ focal-backports main restricted universe multiverse
deb ${APT_SECURITY_URL}/ focal-security main restricted universe multiverse
EOF
    ok "Wrote ${APT_MIRROR_NAME} to /etc/apt/sources.list"

    log "Updating APT package lists..."
    apt update 2>&1 | tee -a "$LOG_FILE" | tail -5
    ok "APT package lists updated."

    log "Removing unused packages..."
    apt remove --purge apport update-notifier zsys -y >> "$LOG_FILE" 2>&1 || true
    ok "Unused packages removed."
}

# ================================================= Stage 3: Install Common Tools =================================================

step_install_tools() {
    step_header "Install common tools"

    log "Installing common tools..."
    apt install -y $COMMON_TOOLS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Common tools installed."

    log "Installing dependency libraries..."
    apt install -y $EXTRA_LIBS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Dependency libraries installed."

    log "Installing build tools..."
    apt install -y $BUILD_LIBS 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "Build tools installed."

    log "Cleaning up the system..."
    apt autoremove -y >> "$LOG_FILE" 2>&1 && apt clean >> "$LOG_FILE" 2>&1
    ok "Cleanup completed."
}

# ================================================= Stage 4: Time Synchronization =================================================

step_sync_time() {
    step_header "Check and synchronize time"

    LOCAL_TIME=$(date +"%Y-%m-%d %H:%M:%S")
    log "  Current time: $LOCAL_TIME"

    timedatectl set-timezone Asia/Shanghai
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    ok "Timezone set to Asia/Shanghai."

    if command -v sntp >/dev/null 2>&1; then
        log "  Trying to synchronize time via sntp..."
        if sntp -sP ntp.aliyun.com 2>/dev/null; then
            ok "Time synchronization completed (sntp)."
        fi
    fi

    if command -v chronyc >/dev/null 2>&1; then
        systemctl enable chrony 2>/dev/null || true
        systemctl restart chrony 2>/dev/null || true
        sleep 2
        chronyc -a burst 4/4 2>/dev/null || true
        sleep 3
        chronyc -a makestep 2>/dev/null || true
        sleep 1
        SYNC_CHECK=$(chronyc tracking 2>/dev/null | grep -i "leap status" | grep -i "normal" || true)
        if [ -n "$SYNC_CHECK" ]; then
            ok "Time synchronization completed (chrony)."
        else
            log "  Chrony synchronization was not confirmed; trying another method..."
        fi
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-ntp false 2>/dev/null || true
        timedatectl set-ntp true 2>/dev/null || true
        sleep 2
    fi

    log "  Time after synchronization: $(date +"%Y-%m-%d %H:%M:%S")"

    SYNCED_TIME=$(date +%s)
    NOW_APPROX=$(date -u +%s)
    DIFF=$((SYNCED_TIME - NOW_APPROX))
    if [ $DIFF -lt 0 ]; then DIFF=$((DIFF * -1)); fi
    if [ $DIFF -gt 86400 ]; then
        warn "System time differs from network time by more than 24 hours. Check network and timezone settings."
    fi
}

# ================================================= Stage 5: System Upgrade =================================================

step_system_upgrade() {
    step_header "System upgrade"

    if [ "$DO_SYSTEM_UPGRADE" = "1" ]; then
        log "Applying system updates..."
        export DEBIAN_FRONTEND=noninteractive
        apt update >> "$LOG_FILE" 2>&1
        apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
            dist-upgrade 2>&1 | tee -a "$LOG_FILE" | tail -5
        ok "System upgrade completed."
    else
        warn "Skipping system upgrade as requested."
    fi
}

# ================================================= Stage 6: System Optimization (Server) =================================================

step_system_optimize() {
    step_header "System Optimization (Server)"

    # 6.1 Disable nouveau
    if [ "$INSTALL_NVIDIA" = "1" ]; then
        log "  -> Disable the open-source nouveau driver"
        tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
        rmmod nouveau 2>/dev/null || true
        ok "nouveau has been disabled."
    else
        log "  -> Skipping nouveau blacklist (NVIDIA driver installation was not selected)"
    fi

    # 6.2 Timezone (redundant configuration)
    log "  -> Set timezone"
    timedatectl set-timezone Asia/Shanghai 2>/dev/null || true
    timedatectl set-local-rtc 1 --adjust-system-clock 2>/dev/null || true
    ok "Timezone configured (Asia/Shanghai)."

    # 6.3 Update GRUB configuration
    log "  -> Update GRUB configuration (enable os-prober)"
    if [ -f /etc/default/grub ]; then
        if [ ! -f /etc/default/grub.bak ]; then
            cp /etc/default/grub /etc/default/grub.bak
        fi
        sed -i -E '/^[[:space:]]*#?[[:space:]]*GRUB_DISABLE_OS_PROBER=.*/d' /etc/default/grub
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    fi
    ok "GRUB configuration updated."

    log "  -> Update GRUB"
    update-grub 2>&1 | tee -a "$LOG_FILE" | tail -2
    ok "GRUB updated."

    log "  -> Update initramfs"
    update-initramfs -u -k all 2>&1 | tee -a "$LOG_FILE" | tail -2
    ok "initramfs updated."
}

# ================================================= Stage 7: Network and cloud-init Configuration =================================================

step_configure_network() {
    step_header "Network Configuration (disable cloud-init and rebuild Netplan)"

    # 7.1 Disable cloud-init network management
    log "  -> Disable cloud-init network management"
    mkdir -p /etc/cloud/cloud.cfg.d
    echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    ok "Wrote /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"

    # 7.2 Remove all existing configuration files under /etc/netplan/(including Ubuntu 20.04 Server default 00-installer-config.yaml and cloud-init 50-cloud-init.yaml)
    log "  -> Clean up existing configuration files under /etc/netplan/"
    if [ -d /etc/netplan ]; then
        BACKUP_DIR="/etc/netplan/.bak.$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        # Back up and remove
        shopt -s nullglob
        for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
            mv "$f" "$BACKUP_DIR/" 2>/dev/null || true
            log "     Moved to backup: $f"
        done
        shopt -u nullglob
    else
        mkdir -p /etc/netplan
    fi
    ok "Existing Netplan configuration backed up."

    # 7.3 Detect physical Ethernet interfaces(based on the logic from net.sh)
    log "  -> Detect physical Ethernet interfaces"
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E '^(en|eth)[A-Za-z0-9_.-]+$' | grep -vE '^(lo|docker|veth|br-|virbr|tap|tun)' || true)
    if [ -z "$interfaces" ]; then
        warn "No physical interface matched the expected names; trying a broader match..."
        interfaces=$(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E '^e' | grep -vE '^(lo|docker|veth|br-|virbr|tap|tun)' || true)
    fi
    if [ -z "$interfaces" ]; then
        err "No usable Ethernet interface was found; cannot generate Netplan configuration."
        return 1
    fi
    log "     Detected network interfaces: $interfaces"

    # 7.4 Generate a new Netplan configuration
    log "  -> Generate ${NETPLAN_FILE}"
    cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF
    for iface in $interfaces; do
        cat >> "$NETPLAN_FILE" << EOF
    ${iface}:
      dhcp4: true
      dhcp6: false
      optional: true
EOF
    done
    chmod 600 "$NETPLAN_FILE"
    ok "Netplan configuration generated (permissions 600)."

    # 7.5 Apply Netplan
    log "  -> Apply Netplan configuration"
    if netplan generate >> "$LOG_FILE" 2>&1; then
        ok "Netplan syntax check passed."
    else
        err "Netplan configuration syntax error."
        return 1
    fi
    if netplan apply >> "$LOG_FILE" 2>&1; then
        ok "Netplan applied successfully."
    else
        warn "Warnings occurred while applying Netplan. Check the log."
    fi

    # 7.6 Adjust systemd-networkd-wait-online startup timeout
    WAIT_ONLINE_SVC="/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
    if [ -f "$WAIT_ONLINE_SVC" ]; then
        if ! grep -q "TimeoutStartSec=2sec" "$WAIT_ONLINE_SVC"; then
            sed -i '/\[Service\]/a TimeoutStartSec=2sec' "$WAIT_ONLINE_SVC"
            ok "Added TimeoutStartSec=2sec to systemd-networkd-wait-online.service"
        else
            ok "systemd-networkd-wait-online.service already has TimeoutStartSec=2sec; skipping"
        fi
    else
        warn "${WAIT_ONLINE_SVC} not found; skipping TimeoutStartSec configuration"
    fi

    # 7.7 Disable and mask NetworkManager-wait-online
    if systemctl list-unit-files 2>/dev/null | grep -q '^NetworkManager-wait-online\.service'; then
        systemctl disable NetworkManager-wait-online.service >> "$LOG_FILE" 2>&1 || true
        systemctl mask NetworkManager-wait-online.service    >> "$LOG_FILE" 2>&1 || true
        ok "NetworkManager-wait-online.service disabled and masked"
    else
        log "     NetworkManager is not installed; no need to disable its wait-online service."
    fi

    systemctl daemon-reload >> "$LOG_FILE" 2>&1 || true

    # 7.8 Wait and show results
    sleep 3
    log "  -> Interface status summary:"
    for iface in $interfaces; do
        link_state=$(ip link show dev "$iface" | grep -oP '(?<=state )\S+' || true)
        ipv4_addr=$(ip -4 addr show dev "$iface" | grep -oP '(?<=inet )\d+(\.\d+){3}/\d+' || true)
        if [ -n "$ipv4_addr" ]; then
            log "     ${iface}: state=${link_state}, IPv4=${ipv4_addr}"
        else
            warn "     ${iface}: state=${link_state}, no IPv4 address received yet"
        fi
    done

    ok "Network and system services configured."
}

# ================================================= Stage 8: NVIDIA Driver and CUDA =================================================

format_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes/1024/1024)) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes/1024)) KB"
    else
        echo "${bytes} B"
    fi
}

download_file() {
    local remote_file="$1"
    local save_path="$2"
    local url="${INTRANET_PATH}/${remote_file}"

    if [ -f "$save_path" ]; then
        local existing_size
        existing_size=$(stat -c%s "$save_path" 2>/dev/null || echo 0)
        if [ "$existing_size" -gt 0 ]; then
            ok "File already exists; skipping download: ${remote_file} ($(format_size "$existing_size"))"
            return 0
        else
            warn "File exists but is empty; downloading again: ${remote_file}"
            rm -f "$save_path"
        fi
    fi

    log "  Downloading: ${remote_file}"
    if command -v wget >/dev/null 2>&1; then
        if ! wget -q --timeout=30 --tries=2 --no-check-certificate \
             -O "${save_path}" "${url}" >> "$LOG_FILE" 2>&1; then
            rm -f "$save_path"
            warn "Download failed: ${remote_file}"
            return 1
        fi
    else
        if ! curl -fsSL --max-time 60 --connect-timeout 15 --retry 1 \
             -o "${save_path}" "${url}" >> "$LOG_FILE" 2>&1; then
            rm -f "$save_path"
            warn "Download failed: ${remote_file}"
            return 1
        fi
    fi

    if [ ! -s "$save_path" ]; then
        rm -f "$save_path"
        warn "Download failed: ${remote_file}"
        return 1
    fi
    local local_size
    local_size=$(stat -c%s "$save_path" 2>/dev/null || echo 0)
    ok "Download completed (size: $(format_size "$local_size"))"
    return 0
}

setup_nvidia_persistence() {
    log "  -> Enable NVIDIA persistence mode"
    tee /lib/systemd/system/nvidia-pm.service > /dev/null << 'EOF'
[Unit]
Description=ps deploy
ConditionPathExists=/usr/bin/nvidia-smi

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-smi --persistence-mode=1
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=true
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nvidia-pm.service
    if command -v nvidia-smi >/dev/null 2>&1; then
        systemctl start nvidia-pm.service 2>/dev/null || true
        ok "NVIDIA persistence mode enabled and started."
    else
        ok "NVIDIA persistence service registered (will take effect after reboot)."
    fi
}

setup_cuda_env() {
    local cuda_ver="$1"
    if [ -z "$cuda_ver" ]; then
        warn "Could not determine the CUDA version; skipping environment variable configuration."
        return 1
    fi

    tee /etc/profile.d/cuda.sh > /dev/null << EOF
# CUDA toolkit environment
export PATH=/usr/local/cuda-${cuda_ver}/bin\${PATH:+:\${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-${cuda_ver}/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}
EOF
    ok "CUDA environment variables written to /etc/profile.d/cuda.sh"
}

ensure_nouveau_not_loaded() {
    if lsmod | awk '{print $1}' | grep -qx "nouveau"; then
        warn "nouveau is still loaded; the NVIDIA .run installer cannot be started safely during this boot."
        warn "No mid-run reboot will be performed. The NVIDIA driver component will be skipped; remaining initialization steps will continue."
        record_choice "NVIDIA nouveau check" "AUTO" "driver skipped" "reason=nouveau remains loaded; reboot handled only at final stage"
        return 1
    fi
    ok "nouveau is not loaded; the NVIDIA driver installer may proceed."
    record_choice "NVIDIA nouveau check" "AUTO" "continue driver install" "nouveau not loaded"
    return 0
}

# ================================================= NVIDIA driver + CUDA interactive install =================================================

# ================================================= NVIDIA/CUDA interactive package selection =================================================

# Option 1 uses the configured intranet default directly; custom modes can scan/select local or intranet installers.
select_install_package() {
    local component="$1" default_file="$2" policy="${3:-manual}"
    local selected="" choice_input="" choice="" entered="" source="intranet" i
    local -a candidates=()

    # Option 1 is explicitly "default install (intranet download)". Use the configured
    # package name without scanning the home directory or asking the user to choose.
    # A previously downloaded cache with this exact default filename may be reused.
    if [ "$policy" = "intranet" ]; then
        selected="$default_file"
        source="intranet-default"
        if [ -s "${WORK_HOME}/${selected}" ]; then
            log "Default intranet installer already cached; reusing the configured file: ${selected}"
            source="intranet-default-cache"
        else
            log "Default install selected: download ${selected} from intranet when the component is installed."
        fi
        SELECTED_INSTALLER_NAME="$selected"
        SELECTED_INSTALLER="${WORK_HOME}/${selected}"
        record_choice "${component} installer source" "AUTO" "$selected" "source=${source}; policy=default intranet download; no package-selection prompt"
        record_choice "Final ${component} package" "$selected" "$selected" "source=${source}; path=${SELECTED_INSTALLER}; intranet_url=${INTRANET_PATH}/${selected}"
        return 0
    fi

    log "Scanning ${WORK_HOME} for local ${component} installer packages..."
    if [ -d "$WORK_HOME" ]; then
        if [ "$component" = "driver" ]; then
            mapfile -t candidates < <(find "$WORK_HOME" -maxdepth 1 -type f -size +0c \
                \( -iname 'NVIDIA-Linux-x86_64-*.run' -o -iname 'NVIDIA*.run' \) \
                -printf '%f
' 2>/dev/null | sort -Vr)
        else
            mapfile -t candidates < <(find "$WORK_HOME" -maxdepth 1 -type f -size +0c \
                -iname 'cuda*.run' -printf '%f
' 2>/dev/null | sort -Vr)
        fi
    fi

    if [ "${#candidates[@]}" -eq 1 ]; then
        selected="${candidates[0]}"; source="home"
        record_choice "${component} installer selection" "AUTO" "$selected" "source=home; only one matching local installer; auto-selected without prompt"
    elif [ "${#candidates[@]}" -gt 0 ]; then
        log ""
        log "Found ${component} installer package(s) in ${WORK_HOME}:"
        for i in "${!candidates[@]}"; do log "  $((i + 1))) ${candidates[$i]}"; done
        log "  0) Enter a custom intranet filename (press Enter to use the configured default filename)"
        while true; do
            choice_input=""
            read -r -p "Select a file [0-${#candidates[@]}, default 1]: " choice_input || choice_input=""
            choice=${choice_input:-1}
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -eq 0 ]; then
                record_choice "Local ${component} installer number" "${choice_input:-<ENTER>}" "$choice" "action=default/custom filename; policy=${policy}"
                selected=""; break
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#candidates[@]}" ]; then
                selected="${candidates[$((choice - 1))]}"; source="home"
                record_choice "Local ${component} installer number" "${choice_input:-<ENTER>}" "$choice" "selected_file=${selected}; source=home"
                break
            else echo "Enter a number between 0 and ${#candidates[@]}。"; fi
        done
    else
        warn "No matching ${component} installer was found in the home directory."
    fi

    if [ -z "$selected" ]; then
        if [ "$policy" = "auto" ]; then
            selected="$default_file"; source="intranet"
            log "No local ${component} installer was available; use the configured intranet default: ${selected}"
            record_choice "${component} installer source" "AUTO" "$selected" "source=intranet; default package; no prompt"
        else
            read -r -p "Enter the filename to download from the intranet (press Enter for default: ${default_file}; enter q to cancel): " entered || entered="q"
            if [ "$entered" = "q" ] || [ "$entered" = "Q" ]; then
                record_choice "${component} intranet filename" "$entered" "CANCEL" "component will be skipped"
                warn "Cancelled selection of the ${component} installer."; return 1
            fi
            selected=${entered:-$default_file}
            if [[ "$selected" == */* ]] || [[ ! "$selected" =~ \.run$ ]]; then
                record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "must be a .run filename without a path"
                err "Invalid filename: enter a .run filename without a path."; return 1
            fi
            if [ "$component" = "driver" ]; then
                if [[ ! "$selected" =~ ^NVIDIA.*\.run$ ]]; then
                    record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "driver file must start with NVIDIA"
                    err "The driver installer filename must start with NVIDIA and end with .run."; return 1
                fi
            else
                if [[ ! "$selected" =~ ^cuda.*\.run$ ]]; then
                    record_choice "${component} intranet filename" "${entered:-<ENTER>}" "INVALID" "CUDA file must start with cuda"
                    err "The CUDA installer filename must start with cuda and end with .run."; return 1
                fi
            fi
            if [ -s "${WORK_HOME}/${selected}" ]; then source="home"; else source="intranet"; fi
            record_choice "${component} intranet filename" "${entered:-<ENTER>}" "$selected" "source=${source}; default=${default_file}"
        fi
    fi

    SELECTED_INSTALLER_NAME="$selected"
    SELECTED_INSTALLER="${WORK_HOME}/${selected}"
    if [ -s "$SELECTED_INSTALLER" ]; then source="home"; ok "Selected home-directory installer: ${SELECTED_INSTALLER}"
    else source="intranet"; log "Selected installer: ${selected}; intranet download will be attempted if needed."; fi
    record_choice "Final ${component} package" "$selected" "$selected" "source=${source}; path=${SELECTED_INSTALLER}"
    return 0
}

get_driver_version_from_filename() {
    local name
    name=$(basename "$1")
    if [[ "$name" =~ ^NVIDIA-Linux-x86_64-([0-9]+([.][0-9]+)+)\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

get_cuda_version_from_filename() {
    local name
    name=$(basename "$1")
    # A CUDA runfile is commonly named cuda_13.2.1_<driver-build>_linux.run; the Toolkit installation directory is cuda-13.2.
    if [[ "$name" =~ ^cuda_([0-9]+[.][0-9]+)([.][0-9]+)?_.*linux\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$name" =~ ^cuda_([0-9]+[.][0-9]+)([.][0-9]+)?\.run$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

get_cuda_package_driver_version_from_filename() {
    local name
    name=$(basename "$1")
    # Some CUDA runfile names include the associated driver build, for example cuda_13.2.1_595.58.03_linux.run.
    if [[ "$name" =~ ^cuda_[0-9]+([.][0-9]+)+_([0-9]+([.][0-9]+)+)_linux\.run$ ]]; then
        echo "${BASH_REMATCH[2]}"
    else
        echo ""
    fi
}

get_apt_nvidia_packages() {
    dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' \
        'nvidia-driver-*' 'nvidia-dkms-*' 2>/dev/null | awk '$1 ~ /^ii/ {print $2}' | head -10 || true
}

get_apt_cuda_packages() {
    dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' \
        'cuda' 'cuda-[0-9]*' 'cuda-toolkit-*' 'cuda-compiler-*' 'cuda-libraries-*' 'cuda-runtime-*' 'nvidia-cuda-toolkit' 2>/dev/null | awk '$1 ~ /^ii/ {print $2}' | head -10 || true
}

choose_driver_module_type() {
    log ""
    log "Select the NVIDIA driver module type:"
    log "  1) Proprietary kernel module"
    log "  2) Open kernel module (only for GPUs/drivers that support it)"
    while true; do
        read -r -p "Enter choice [1/2, required]: " module_choice || return 1
        case "$module_choice" in
            1)
                NVIDIA_MODULE_TYPE="proprietary"
                record_choice "NVIDIA module type" "$module_choice" "proprietary" "selected option=1"
                log "Selected NVIDIA module type: PROPRIETARY"
                return 0
                ;;
            2)
                NVIDIA_MODULE_TYPE="open"
                record_choice "NVIDIA module type" "$module_choice" "open" "selected option=2"
                log "Selected NVIDIA module type: OPEN"
                return 0
                ;;
            *) echo "Invalid choice. Enter 1 or 2 explicitly." ;;
        esac
    done
}

install_selected_nvidia_driver() {
    local installer="$1"
    local package_version=""
    local current_version=""
    local apt_packages=""
    local installer_rc=0
    DRIVER_INSTALL_ATTEMPTED=0

    package_version=$(get_driver_version_from_filename "$installer")
    current_version=$(check_nvidia_driver_installed) || true
    if [ -n "$current_version" ] && [ "${REPLACE_DRIVER:-0}" != "1" ]; then
        warn "NVIDIA driver ${current_version} is already installed and no replacement was approved; preserving it."
        DRIVER_INSTALL_ATTEMPTED=0
        return 0
    fi

    # Determine the currently installed kernel-module type where possible.
    # NVIDIA open modules commonly report Dual MIT/GPL; proprietary modules report NVIDIA.
    local current_module_license=""
    local current_module_type=""
    current_module_license=$(modinfo -F license nvidia 2>/dev/null | head -n 1 || true)
    case "$current_module_license" in
        *MIT*|*GPL*) current_module_type="open" ;;
        *NVIDIA*) current_module_type="proprietary" ;;
        *) current_module_type="" ;;
    esac

    if [ -n "$current_version" ] && [ -n "$package_version" ] && [ "$current_version" = "$package_version" ]; then
        if [ "$current_module_type" = "$NVIDIA_MODULE_TYPE" ]; then
            ok "The installed driver version and module type match the selected configuration; skipping reinstallation."
            return 0
        elif [ -n "$current_module_type" ]; then
            log "The driver version matches (${current_version}), but the installed module type is ${current_module_type} and the selected type is ${NVIDIA_MODULE_TYPE}."
            log "A confirmed driver replacement is required to change the module type."
        else
            warn "The driver version matches (${current_version}), but the current module type could not be detected. A replacement will require confirmation."
        fi
    fi

    apt_packages=$(get_apt_nvidia_packages)
    if [ -n "$apt_packages" ]; then
        warn "Detected NVIDIA driver packages managed by APT/dpkg:"
        log "$apt_packages"
        warn "To avoid mixing APT-managed drivers with the NVIDIA .run installer, these packages will not be removed automatically and the .run driver installation will not continue."
        warn "Handle the APT-managed driver separately, then run this script again."
        return 1
    fi

    # Verify that nouveau will not block the install before removing an existing working driver.
    if ! ensure_nouveau_not_loaded; then
        warn "Existing NVIDIA driver, if any, was not uninstalled because nouveau is still loaded."
        return 1
    fi

    if [ -n "$current_version" ] && [ "${REPLACE_DRIVER:-0}" = "1" ]; then
        if command -v nvidia-uninstall >/dev/null 2>&1; then
            log "Replacing the pre-approved NVIDIA .run driver noninteractively..."
            if ! nvidia-uninstall --silent >> "$LOG_FILE" 2>&1; then
                warn "nvidia-uninstall failed; stopping driver replacement safely."
                return 1
            fi
        else
            warn "Cannot safely replace the installed driver because nvidia-uninstall is unavailable. Existing driver will be kept."
            return 1
        fi
    fi

    log "Driver installation was authorized in the pre-run configuration stage; no additional prompt will be shown."
    chmod +x "$installer"

    log "Installing the NVIDIA driver (module type: ${NVIDIA_MODULE_TYPE})..."
    DRIVER_INSTALL_ATTEMPTED=1
    set +e
    sh "$installer" -s --no-x-check --dkms --kernel-module-type="${NVIDIA_MODULE_TYPE}" 2>&1 | tee -a "$LOG_FILE" | tail -6
    installer_rc=${PIPESTATUS[0]}
    set -e

    current_version=$(check_nvidia_driver_installed) || true
    if [ "$installer_rc" -ne 0 ]; then
        warn "The NVIDIA driver installer returned error code ${installer_rc}. Check the log: ${LOG_FILE}"
        return 1
    fi
    if [ -n "$current_version" ]; then
        ok "The NVIDIA driver installer finished; detected driver version: ${current_version}"
    elif command -v nvidia-smi >/dev/null 2>&1 || [ -f /usr/bin/nvidia-smi ]; then
        warn "Driver utilities are installed, but the kernel module has not been confirmed as loaded; a reboot may be required."
    else
        warn "No NVIDIA driver was detected after installation. Check the log: ${LOG_FILE}"
        return 1
    fi
    return 0
}

install_selected_cuda_toolkit() {
    local installer="$1"
    local package_version=""
    local current_version=""
    local current_driver=""
    local package_driver_version=""
    local installer_rc=0
    CUDA_INSTALL_ATTEMPTED=0

    package_version=$(get_cuda_version_from_filename "$installer")
    package_driver_version=$(get_cuda_package_driver_version_from_filename "$installer")
    current_version=$(check_cuda_installed) || true
    if [ -n "$current_version" ] && [ "${REPLACE_CUDA:-0}" != "1" ]; then
        CUDA_VERSION="$current_version"
        setup_cuda_env "$CUDA_VERSION"
        warn "CUDA Toolkit ${current_version} is already installed and no version change was approved; preserving it."
        CUDA_INSTALL_ATTEMPTED=0
        return 0
    fi
    current_driver=$(check_nvidia_driver_installed) || true

    if [ -n "$package_driver_version" ]; then
        if [ -z "$current_driver" ]; then
            if [ "${DRIVER_INSTALL_SUCCEEDED_THIS_RUN:-0}" = "1" ]; then
                warn "The NVIDIA driver installer ran, but the module is not recognized by the current session. Continuing with CUDA Toolkit installation; reboot afterward and verify with nvidia-smi."
            else
                warn "The selected CUDA installer filename indicates an associated driver version of ${package_driver_version}, but no NVIDIA driver is currently detected."
                log "No NVIDIA driver is currently detected. Proceeding with Toolkit-only installation; verify driver availability after reboot."
                record_choice "CUDA compatibility action" "AUTO" "continue Toolkit only" "no driver detected; CUDA runfile driver component is disabled"
            fi
        elif dpkg --compare-versions "$current_driver" lt "$package_driver_version"; then
            warn "The installed NVIDIA driver ${current_driver} is older than the CUDA runfile's associated driver ${package_driver_version}; skipping CUDA automatically to avoid a likely compatibility problem."
            record_choice "CUDA compatibility action" "AUTO" "skip Toolkit install" "installed driver older than package-associated driver"
            return 0
        fi
    fi

    if [ -n "$package_version" ] && [ -x "/usr/local/cuda-${package_version}/bin/nvcc" ]; then
        ok "CUDA Toolkit ${package_version} already exists. Switching the environment configuration to this version without reinstalling it."
        CUDA_VERSION="$package_version"
        setup_cuda_env "$CUDA_VERSION"
        return 0
    fi

    if [ -n "$package_version" ] && [ -n "$current_version" ] && [ "$current_version" = "$package_version" ]; then
        ok "The installed CUDA Toolkit version ${current_version} matches the selected version; skipping reinstallation."
        CUDA_VERSION="$current_version"
        setup_cuda_env "$CUDA_VERSION"
        return 0
    fi

    if [ -n "$current_version" ]; then
        log "Currently detected CUDA Toolkit version: ${current_version}"
        log "Target version from selected installer: ${package_version:-unable to determine from filename}"
        if [ -n "$package_version" ]; then
            log "A different version will be installed to its own /usr/local/cuda-${package_version} directory when possible; this script will not automatically remove older versions."
        fi
    fi

    local apt_cuda_packages
    apt_cuda_packages=$(get_apt_cuda_packages)
    if [ -n "$apt_cuda_packages" ]; then
        warn "Detected CUDA-related packages managed by APT/dpkg:"
        log "$apt_cuda_packages"
        warn "To avoid conflicts between APT and .run installations, these packages will not be removed automatically and the CUDA .run installation will not continue."
        return 1
    fi

    if [ -n "$package_version" ] && [ -d "/usr/local/cuda-${package_version}" ]; then
        warn "Target directory /usr/local/cuda-${package_version} already exists, but no executable nvcc was found. Stopping to avoid overwriting an unknown installation."
        return 1
    fi

    chmod +x "$installer"
    log "Installing the CUDA Toolkit (without installing the driver bundled with CUDA)..."
    CUDA_INSTALL_ATTEMPTED=1
    set +e
    sh "$installer" --silent --toolkit --samples --override 2>&1 | tee -a "$LOG_FILE" | tail -6
    installer_rc=${PIPESTATUS[0]}
    set -e
    if [ "$installer_rc" -ne 0 ]; then
        warn "The CUDA installer returned error code ${installer_rc}. Check the log: ${LOG_FILE}"
        return 1
    fi

    if [ -n "$package_version" ] && [ -x "/usr/local/cuda-${package_version}/bin/nvcc" ]; then
        CUDA_VERSION="$package_version"
    else
        CUDA_VERSION=$(check_cuda_installed) || true
    fi
    if [ -n "$CUDA_VERSION" ]; then
        ok "CUDA Toolkit installation completed/verified. Configured target version: ${CUDA_VERSION}"
        setup_cuda_env "$CUDA_VERSION"
    else
        warn "The CUDA Toolkit version could not be identified after the installer ran. Check the log: ${LOG_FILE}"
        return 1
    fi
    return 0
}


cleanup_other_cuda_toolkits() {
    [ "${CLEANUP_OLD_CUDA:-0}" = "1" ] || return 0

    local keep_version="${CUDA_VERSION:-${CUDA_CLEANUP_KEEP_VERSION:-}}"
    local path version uninstaller
    local apt_cuda_packages=""

    if [ -z "$keep_version" ] || [ ! -x "/usr/local/cuda-${keep_version}/bin/nvcc" ]; then
        warn "CUDA cleanup skipped: the selected/kept Toolkit version has not been verified at /usr/local/cuda-${keep_version:-UNKNOWN}."
        record_choice "CUDA cleanup result" "AUTO" "SKIPPED" "reason=keep version missing or nvcc not executable"
        return 0
    fi

    apt_cuda_packages=$(get_apt_cuda_packages)
    if [ -n "$apt_cuda_packages" ]; then
        warn "CUDA cleanup skipped because APT-managed CUDA packages are present. No APT packages will be removed automatically."
        log "$apt_cuda_packages"
        record_choice "CUDA cleanup result" "AUTO" "SKIPPED" "reason=APT-managed CUDA packages detected"
        return 0
    fi

    for path in /usr/local/cuda-[0-9]*; do
        [ -d "$path" ] || continue
        version="${path##*/cuda-}"
        [[ "$version" =~ ^[0-9]+([.][0-9]+)*$ ]] || continue
        [ "$version" = "$keep_version" ] && continue

        uninstaller="${path}/bin/cuda-uninstaller"
        if [ -x "$uninstaller" ]; then
            log "Uninstalling additional CUDA Toolkit ${version} using its official runfile uninstaller..."
            if yes | "$uninstaller" >> "$LOG_FILE" 2>&1; then
                ok "Removed CUDA Toolkit ${version} via cuda-uninstaller."
                record_choice "CUDA cleanup result" "approved before initialization" "REMOVED ${version}" "kept=${keep_version}; method=cuda-uninstaller"
            else
                warn "Uninstaller failed for CUDA Toolkit ${version}; leaving remaining files for manual review."
                record_choice "CUDA cleanup result" "approved before initialization" "FAILED ${version}" "kept=${keep_version}; method=cuda-uninstaller"
            fi
        else
            warn "No cuda-uninstaller found for CUDA Toolkit ${version}; leaving it untouched."
            record_choice "CUDA cleanup result" "approved before initialization" "KEPT ${version}" "reason=no cuda-uninstaller found; kept=${keep_version}"
        fi
    done
}

step_install_nvidia() {
    step_header "NVIDIA Driver and CUDA Installation"

    local mode="${GPU_INSTALL_MODE:-3}"
    DRIVER_INSTALL_SUCCEEDED_THIS_RUN=0
    if [ "$mode" = "4" ] || [ "${INSTALL_NVIDIA:-0}" != "1" ]; then
        log "Skipping NVIDIA driver and CUDA installation as requested; existing components will not be removed."
        return 0
    fi

    local current_driver="" current_cuda="" target_driver="" target_cuda=""
    local do_driver=1 do_cuda=1 driver_installer="" cuda_installer=""
    current_driver=$(check_nvidia_driver_installed) || true
    current_cuda=$(check_cuda_installed) || true

    log ""
    log "Current GPU component status:"
    log "  NVIDIA driver: ${current_driver:-not detected}"
    log "  CUDA Toolkit: ${current_cuda:-not detected}"

    if [ "$mode" = "1" ]; then
        local wanted_driver="${CUSTOM_DRIVER_PACKAGE:-$NVIDIA_DRIVER}"
        local wanted_cuda="${CUSTOM_CUDA_PACKAGE:-$CUDA_PACKAGE}"
        log "Automatic missing-only policy: existing NVIDIA/CUDA versions are never replaced."
        log "Selected packages: driver=${wanted_driver}; CUDA=${wanted_cuda}"
        target_driver=$(get_driver_version_from_filename "$wanted_driver")
        target_cuda=$(get_cuda_version_from_filename "$wanted_cuda")

        if [ -n "$current_driver" ]; then
            do_driver=0
            log "Preserving already-installed NVIDIA driver ${current_driver}; no replacement or download."
        fi
        if [ -n "$current_cuda" ]; then
            do_cuda=0
            CUDA_VERSION="$current_cuda"
            setup_cuda_env "$CUDA_VERSION"
            log "Preserving already-installed CUDA Toolkit ${current_cuda}; no replacement or download."
        fi
        if [ "$do_driver" = "1" ]; then
            if download_file "$wanted_driver" "${WORK_HOME}/${wanted_driver}"; then
                driver_installer="${WORK_HOME}/${wanted_driver}"
            else
                warn "Could not obtain the selected NVIDIA driver package from the intranet: ${wanted_driver}"
            fi
        fi
        if [ "$do_cuda" = "1" ]; then
            if download_file "$wanted_cuda" "${WORK_HOME}/${wanted_cuda}"; then
                cuda_installer="${WORK_HOME}/${wanted_cuda}"
            else
                warn "Could not obtain the selected CUDA installer from the intranet: ${wanted_cuda}"
            fi
        fi
    elif [ "$mode" = "2" ] || [ "$mode" = "3" ]; then
        # All custom package names and replacement permissions were decided before initialization.
        if [ -n "$current_driver" ] && [ "${REPLACE_DRIVER:-0}" != "1" ]; then
            log "Preserving already-installed NVIDIA driver ${current_driver}; no replacement was approved."
        elif [ -n "${CUSTOM_DRIVER_PACKAGE:-}" ]; then
            driver_installer="${WORK_HOME}/${CUSTOM_DRIVER_PACKAGE}"
            if [ ! -s "$driver_installer" ]; then
                if ! download_file "$CUSTOM_DRIVER_PACKAGE" "$driver_installer"; then
                    warn "Could not obtain the custom NVIDIA driver package: ${CUSTOM_DRIVER_PACKAGE}. Skipping the driver component."
                    driver_installer=""
                fi
            fi
        else
            warn "No NVIDIA driver installer was selected during the pre-initialization stage; skipping the driver component."
        fi

        if [ -n "$current_cuda" ] && [ "${REPLACE_CUDA:-0}" != "1" ]; then
            CUDA_VERSION="$current_cuda"
            setup_cuda_env "$CUDA_VERSION"
            log "Preserving already-installed CUDA Toolkit ${current_cuda}; no version change was approved."
        elif [ -n "${CUSTOM_CUDA_PACKAGE:-}" ]; then
            cuda_installer="${WORK_HOME}/${CUSTOM_CUDA_PACKAGE}"
            if [ ! -s "$cuda_installer" ]; then
                if ! download_file "$CUSTOM_CUDA_PACKAGE" "$cuda_installer"; then
                    warn "Could not obtain the custom CUDA installer: ${CUSTOM_CUDA_PACKAGE}. Skipping the CUDA component."
                    cuda_installer=""
                fi
            fi
        else
            warn "No CUDA installer was selected during the pre-initialization stage; skipping the CUDA component."
        fi
    else
        warn "Unknown GPU installation mode. Skipping GPU installation for safety."
        return 0
    fi

    if [ -n "$driver_installer" ]; then
        if install_selected_nvidia_driver "$driver_installer"; then
            if [ "${DRIVER_INSTALL_ATTEMPTED:-0}" = "1" ]; then
                DRIVER_INSTALL_SUCCEEDED_THIS_RUN=1
                setup_nvidia_persistence
                if command -v dkms >/dev/null 2>&1; then
                    log "Running dkms autoinstall to build the NVIDIA module for the current kernel..."
                    if dkms autoinstall 2>&1 | tee -a "$LOG_FILE" | tail -5; then
                        ok "dkms autoinstall completed"
                    else
                        warn "dkms autoinstall failed. Check the log: ${LOG_FILE}"
                    fi
                fi
            fi
        else
            warn "The NVIDIA driver step did not complete; this operation will not be marked successful."
        fi
    else
        log "The NVIDIA driver was not installed during this run."
    fi

    if [ -n "$cuda_installer" ]; then
        if ! install_selected_cuda_toolkit "$cuda_installer"; then
            warn "The CUDA Toolkit step did not complete; this operation will not be marked successful."
        fi
    else
        log "The CUDA Toolkit was not installed during this run."
    fi

    cleanup_other_cuda_toolkits

    # Keep the original gpu-burn download behavior (only when fresh or custom installation is selected).
    log "Downloading the gpu-burn stress-test tool (if available on the intranet)..."
    download_file "gpu-burn.zip" "${WORK_HOME}/gpu-burn.zip" || true

    log "NVIDIA/CUDA stage finished. Any reboot decision is deferred to the final step; verify the driver with nvidia-smi after reboot."
}

step_download_test_files() {
    step_header "Download test files"

    log "Downloading test files to ${WORK_HOME}..."
    for f in "${TEST_FILES[@]}"; do
        download_file "$f" "${WORK_HOME}/${f}" || true
    done

    if [ -f "${WORK_HOME}/storcli64" ]; then
        chmod +x "${WORK_HOME}/storcli64"
        mv "${WORK_HOME}/storcli64" /usr/bin/storcli64
        ok "Moved storcli64 to /usr/bin/"
    fi

    for f in "${WORK_HOME}"/check_V5.sh "${WORK_HOME}"/mount_V6.sh "${WORK_HOME}"/yc.sh "${WORK_HOME}"/upload_check.sh; do
        if [ -f "$f" ]; then
            chmod +x "$f"
        fi
    done
    ok "Made test scripts executable."
}

# ================================================= Stage 10: Run Upload Check Script =================================================

step_run_upload_check() {
    step_header "Run upload_check.sh"

    local upload_script="${WORK_HOME}/upload_check.sh"
    if [ ! -f "$upload_script" ]; then
        warn "upload_check.sh was not found; skipping execution."
        return 0
    fi

    chmod +x "$upload_script"
    log "Running ${upload_script}..."
    if bash "$upload_script" 2>&1 | tee -a "$LOG_FILE"; then
        ok "upload_check.sh completed."
    else
        warn "upload_check.sh failed. Check the log: ${LOG_FILE}"
    fi
}

# ================================================= Stage 11: Finish =================================================

step_finish() {
    step_header "Initialization complete"

    log ""
    log "${GREEN}============================================================${NC}"
    log "${GREEN}  All steps completed.${NC}"
    log "${GREEN}============================================================${NC}"
    log "  Log file: ${LOG_FILE}"
    log "  Run as user: ${WORK_USER}"
    log "  System version: $(detect_ubuntu_version)"
    log "  Netplan : ${NETPLAN_FILE}"
    INSTALLED_DRIVER=$(check_nvidia_driver_installed) || true
    INSTALLED_CUDA=$(check_cuda_installed) || true
    if [ -n "$INSTALLED_DRIVER" ]; then
        log "  NVIDIA driver: detected (${INSTALLED_DRIVER})"
    else
        log "  NVIDIA driver: not detected"
    fi
    if [ -n "$INSTALLED_CUDA" ]; then
        log "  CUDA Toolkit: detected (${INSTALLED_CUDA})"
    else
        log "  CUDA Toolkit: not detected"
    fi
    if [ "$DO_SYSTEM_UPGRADE" = "1" ]; then
        log "  System upgrade: completed"
    else
        log "  System upgrade: skipped"
    fi
    log ""

    if confirm "Reboot the system now?" "N"; then
        log "${YELLOW}The system will reboot in 5 seconds...${NC}"
        sleep 5
        reboot
    else
        log "Reboot manually to apply all configuration changes."
    fi
}

# ================================================= Main flow =================================================

main() {
    check_root

    touch "$LOG_FILE"
    chown "$WORK_USER":"$WORK_USER" "$LOG_FILE" 2>/dev/null || true
    if [ -n "${LAUNCHER_LOG:-}" ] && [ -f "$LAUNCHER_LOG" ]; then
        cat "$LAUNCHER_LOG" >> "$LOG_FILE"
    fi
    log_plain "[RUN] Selected combined mode: ${SELECTED_MODE:-unknown}"
    log_plain "[RUN] Operating system: $(detect_ubuntu_version)"
    log_plain "[RUN] Initial kernel: $(uname -r)"
    log_plain "===== Ubuntu 20.04.6 Server Initialization Log ====="
    log_plain "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_plain "Run as user: ${WORK_USER} (root=${USER})"
    log_plain "System version: $(detect_ubuntu_version)"
    log_plain "Kernel version: $(uname -r)"
    log_plain "==========================================="

    pre_interaction

    step_check_network
    step_configure_sources
    step_install_tools
    step_sync_time
    step_system_upgrade
    step_system_optimize
    step_configure_network
    step_install_nvidia
    step_download_test_files
    step_run_upload_check
    step_finish
}

main "$@"
__ORIGINAL_UBUNTU_20_04_SERVER_PAYLOAD_END_7A4C19__
            ;;
        *)
            echo "Internal error: invalid script mode: $mode" >&2
            return 1
            ;;
    esac
}


if ! write_original_script "$SELECTED_MODE" "$TMP_SCRIPT"; then
    echo "ERROR: Failed to prepare the original script." >&2
    exit 1
fi
chmod 700 "$TMP_SCRIPT"

# Final protection: check the extracted original payload syntax before execution.
if ! bash -n "$TMP_SCRIPT"; then
    echo "ERROR: The selected original script failed syntax validation. No initialization was run." >&2
    exit 1
fi

launcher_log "[RUN] Syntax validation passed for selected ${SELECTED_MODE} payload."
echo
echo "Starting the original ${SELECTED_MODE^^} initialization script..."
echo "============================================================"
set +e
bash "$TMP_SCRIPT" "$@"
script_status=$?
launcher_log "[RESULT] Selected payload exit status=${script_status}"
launcher_log "End time: $(date '+%Y-%m-%d %H:%M:%S')"
exit "$script_status"
