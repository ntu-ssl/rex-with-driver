#!/usr/bin/env bash
# rex-setup.sh — Rex kernel extension build environment for Ubuntu
# Requirements: clang+LLVM >= 18.1.0, cmake, elfutils, libstdc++ >= 13,
#               meson, mold, ninja, python >= 3.11, QEMU, rust-bindgen
set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[rex-setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[rex-setup]${NC} $*"; }
die()  { echo -e "${RED}[rex-setup] FATAL:${NC} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo or as root."

UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || true)
[[ -z "$UBUNTU_CODENAME" ]] && die "Could not detect Ubuntu codename."
info "Ubuntu codename: $UBUNTU_CODENAME"

# Determine the invoking non-root user (for cargo/rustup installs)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
CARGO_BIN="$REAL_HOME/.cargo/bin"

# run_as <cmd>  — run a shell snippet as REAL_USER.
# Uses sudo -u rather than su - to avoid PAM login restrictions that block
# su when invoked from within a sudo session ("su: Permission denied").
# HOME and PATH are pinned explicitly so cargo/rustup are always found.
run_as() {
    sudo -u "$REAL_USER" \
        HOME="$REAL_HOME" \
        PATH="$CARGO_BIN:/usr/local/bin:/usr/bin:/bin" \
        bash -c "$1"
}

# ── 1. Base apt packages ──────────────────────────────────────────────────────
info "Updating apt..."
# Fix broken command-not-found hook that fires after apt-get update.
# This happens when the system python3 was upgraded to 3.12 but
# python3-apt still links against the old ABI.  The update itself
# succeeds; only the post-invoke hook fails, producing the scary
# "No module named 'apt_pkg'" traceback.  Reinstalling python3-apt
# against the current python3 binary clears it permanently.
if python3 -c "import apt_pkg" 2>/dev/null; then
    : # apt_pkg is fine
else
    warn "python3-apt broken (apt_pkg missing) — reinstalling against current python3..."
    # Temporarily disable the offending hook so the reinstall can proceed
    chmod -x /usr/lib/cnf-update-db 2>/dev/null || true
    apt-get update -qq 2>/dev/null || true   # may still warn, that's OK
    apt-get install -y --reinstall python3-apt 2>/dev/null || true
    # Re-enable and rebuild the db if the reinstall fixed the import
    chmod +x /usr/lib/cnf-update-db 2>/dev/null || true
    python3 /usr/lib/cnf-update-db 2>/dev/null || true
fi
apt-get update -qq 2>/dev/null || true   # tolerate residual hook warnings

apt-get install -y --no-install-recommends \
    build-essential git pkg-config curl wget \
    cmake \
    elfutils libelf-dev libdw-dev \
    libstdc++-13-dev \
    ninja-build \
    python3 python3-pip python3-venv \
    qemu-system-x86 qemu-utils ovmf \
    libssl-dev libzstd-dev bc flex bison pahole xz-utils zlib1g-dev \
    lsb-release software-properties-common gnupg

# ── 2. LLVM / Clang >= 18.1.0 from apt.llvm.org ──────────────────────────────
CLANG_TARGET=20
CLANG_MIN=18

# Check if a sufficient clang is already installed
INSTALLED_VER=""
for v in 20 19 18; do
    if command -v "clang-$v" &>/dev/null; then
        ACTUAL=$(clang-$v --version | grep -oP 'version \K[0-9]+')
        if [[ $ACTUAL -ge $CLANG_MIN ]]; then
            INSTALLED_VER=$v
            info "Found existing clang-$v (clang version $ACTUAL)"
            break
        fi
    fi
done

if [[ -z "$INSTALLED_VER" ]]; then
    info "No clang >= $CLANG_MIN found (system has clang $(clang --version 2>/dev/null | grep -oP 'version \K[0-9.]+' || echo 'none'))."
    info "Installing clang-$CLANG_TARGET from apt.llvm.org..."

    # Remove any stale/conflicting LLVM apt sources
    rm -f /etc/apt/sources.list.d/llvm*.list \
          /etc/apt/sources.list.d/*llvm*.sources \
          /etc/apt/trusted.gpg.d/apt.llvm.org.gpg 2>/dev/null || true

    TMP=$(mktemp -d)
    wget -qO "$TMP/llvm.sh" https://apt.llvm.org/llvm.sh
    chmod +x "$TMP/llvm.sh"
    # The 'all' argument installs clang, lld, lldb, clang-tools, etc.
    bash "$TMP/llvm.sh" "$CLANG_TARGET" all
    rm -rf "$TMP"

    INSTALLED_VER=$CLANG_TARGET
fi

# Ensure lld-N is actually installed — llvm.sh 'all' sometimes misses it
# on certain Ubuntu releases. Install explicitly to be safe.
if ! command -v "lld-${INSTALLED_VER}" &>/dev/null; then
    info "lld-${INSTALLED_VER} not found after llvm.sh; installing explicitly..."
    apt-get install -y "lld-${INSTALLED_VER}"
fi

# Register LLVM tools with update-alternatives.
# Priority 200 (> Ubuntu's default 100) ensures these win over any older
# system clang/lld/llvm-* packages (e.g. lld-14 that ships with Ubuntu 22.04).
for tool in clang clang++ clang-format clang-tidy lld \
            llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-strip; do
    binary="/usr/bin/${tool}-${INSTALLED_VER}"
    if [[ -x "$binary" ]]; then
        # Remove any existing alternative first so --install doesn't fail on
        # a pre-existing entry with a different path
        update-alternatives --remove-all "${tool}" 2>/dev/null || true
        update-alternatives --install "/usr/bin/${tool}" "${tool}" "$binary" 200
    fi
done

# Hard-verify lld resolves to the correct version
LLD_ACTUAL=$( (lld --version 2>/dev/null || lld -v 2>/dev/null) | grep -oP '[0-9]+' | head -1 || echo 0)
if [[ $LLD_ACTUAL -lt 15 ]]; then
    warn "update-alternatives did not win for lld (got version $LLD_ACTUAL); forcing symlink..."
    ln -sf "/usr/bin/lld-${INSTALLED_VER}" /usr/local/bin/lld
    # /usr/local/bin is earlier in PATH than /usr/bin
fi

info "Active clang: $(clang --version | head -1)"
info "Active lld:   $(lld --version 2>/dev/null | head -1)"

# ── 3. mold linker ────────────────────────────────────────────────────────────
MOLD_NEED_INSTALL=0
if command -v mold &>/dev/null; then
    MOLD_MAJOR=$(mold --version | grep -oP '[0-9]+' | head -1)
    if [[ $MOLD_MAJOR -ge 2 ]]; then
        info "mold $(mold --version) — sufficient"
    else
        warn "mold major version $MOLD_MAJOR is too old; reinstalling..."
        MOLD_NEED_INSTALL=1
    fi
else
    MOLD_NEED_INSTALL=1
fi

if [[ $MOLD_NEED_INSTALL -eq 1 ]]; then
    MOLD_RELEASE="2.40.1"
    ARCH=$(uname -m)
    MOLD_TAR="mold-${MOLD_RELEASE}-${ARCH}-linux.tar.gz"
    MOLD_URL="https://github.com/rui314/mold/releases/download/v${MOLD_RELEASE}/${MOLD_TAR}"
    info "Downloading mold $MOLD_RELEASE from GitHub..."
    TMP=$(mktemp -d)
    wget -qO "$TMP/$MOLD_TAR" "$MOLD_URL"
    tar -xzf "$TMP/$MOLD_TAR" -C "$TMP"
    install -m755 "$TMP/mold-${MOLD_RELEASE}-${ARCH}-linux/bin/mold" /usr/local/bin/mold
    rm -rf "$TMP"
fi
info "mold: $(mold --version)"

# ── 4. meson >= 1.0 ──────────────────────────────────────────────────────────
# Strategy: prefer apt (zero Python dependency issues).
# Ubuntu 22.04's meson package is 0.61 — too old.
# The upstream meson PPA ships current releases.
# Fallback: python3.12 -m pip (avoids the broken system pip3/distutils).
MESON_MAJOR=$(meson --version 2>/dev/null | cut -d. -f1 || echo 0)
if [[ $MESON_MAJOR -lt 1 ]]; then
    warn "System meson $(meson --version 2>/dev/null) < 1.0; upgrading..."

    # Try the official meson PPA first (cleanest, no pip involved)
    MESON_UPGRADED=0
    if add-apt-repository -y ppa:ubuntu-toolchain-r/test 2>/dev/null; then
        apt-get update -qq 2>/dev/null || true
    fi
    # meson itself publishes a PPA
    if add-apt-repository -y ppa:mesonbuild/stable 2>/dev/null; then
        apt-get update -qq 2>/dev/null || true
        apt-get install -y meson && MESON_UPGRADED=1
    fi

    # Fallback: install via python3.12's own pip (not the broken system pip3)
    if [[ $MESON_UPGRADED -eq 0 ]]; then
        warn "PPA unavailable; installing meson via python3.12 -m pip..."
        python3.12 -m ensurepip --upgrade 2>/dev/null || true
        python3.12 -m pip install --upgrade pip 2>/dev/null || true
        python3.12 -m pip install --upgrade meson
        # The binary lands in /usr/local/bin
        export PATH="/usr/local/bin:$PATH"
        hash -r
    fi
fi
info "meson: $(meson --version)"

# ── 5. ninja >= 1.11 ─────────────────────────────────────────────────────────
NINJA_MINOR=$(ninja --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2 || echo 0)
if [[ $NINJA_MINOR -lt 11 ]]; then
    warn "ninja $(ninja --version 2>/dev/null) may be outdated; installing newer..."
    # ninja-build from the toolchain PPA is usually current enough
    apt-get install -y ninja-build 2>/dev/null || true
    # Re-check; if still old, use python3.12 -m pip
    NINJA_MINOR=$(ninja --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2 || echo 0)
    if [[ $NINJA_MINOR -lt 11 ]]; then
        python3.12 -m ensurepip --upgrade 2>/dev/null || true
        python3.12 -m pip install --upgrade pip 2>/dev/null || true
        python3.12 -m pip install --upgrade ninja
        export PATH="/usr/local/bin:$PATH"
        hash -r
    fi
fi
info "ninja: $(ninja --version)"

# ── 6. Python >= 3.11 ────────────────────────────────────────────────────────
PY_MINOR=$(python3 --version | grep -oP '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)
if [[ $PY_MINOR -lt 11 ]]; then
    warn "python3 is $(python3 --version); need >= 3.11. Installing 3.12 from deadsnakes PPA..."
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -qq
    apt-get install -y python3.12 python3.12-venv python3.12-dev
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 100
fi
info "python3: $(python3 --version)"

# ── 7. Rust toolchain ─────────────────────────────────────────────────────────
# Install rustup as REAL_USER (never as root).
# run_as uses sudo -u to avoid PAM su restrictions on locked root accounts.
if ! run_as "command -v rustup" &>/dev/null; then
    info "Installing rustup for user '$REAL_USER'..."
    run_as "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
            sh -s -- -y --no-modify-path --default-toolchain stable --profile minimal"
else
    info "rustup already present for '$REAL_USER'"
fi

# Always ensure a default toolchain is set and current
info "Setting rustup default to stable..."
run_as "
    source \"\$HOME/.cargo/env\"
    rustup default stable
    rustup update stable
"

export PATH="$CARGO_BIN:$PATH"

info "cargo: $(run_as 'cargo --version')"
info "rustc: $(run_as 'rustc --version')"

# ── 8. rust-bindgen CLI ───────────────────────────────────────────────────────
BINDGEN_VER="0.70.1"
CURRENT_BINDGEN=$(run_as 'bindgen --version 2>/dev/null || true')

if [[ -z "$CURRENT_BINDGEN" ]]; then
    info "Installing bindgen-cli $BINDGEN_VER..."
    run_as "cargo install bindgen-cli --version $BINDGEN_VER --locked"
else
    info "bindgen already installed: $CURRENT_BINDGEN"
fi

# ── 9. Wire lld into kernel and Rex builds ────────────────────────────────────
# The kernel Makefile respects LLVM=1 (uses llvm-* prefixed tools + ld.lld)
# and LD=ld.lld.  Rex's Meson native file needs c_ld and cpp_ld set.
# We write both a shell env file and a Meson native file so neither build
# needs manual flags.

LLD_BIN="/usr/bin/lld-${INSTALLED_VER}"
LDLLD_BIN="/usr/bin/ld.lld-${INSTALLED_VER}"

# ld.lld-N may be a separate binary or a symlink to lld-N; normalise it
if [[ ! -x "$LDLLD_BIN" ]]; then
    ln -sf "$LLD_BIN" "$LDLLD_BIN"
fi
# Also ensure the unversioned ld.lld points here (same priority logic as lld)
update-alternatives --remove-all ld.lld 2>/dev/null || true
update-alternatives --install /usr/bin/ld.lld ld.lld "$LDLLD_BIN" 200
LLD_ACTUAL_VER=$( (ld.lld --version 2>/dev/null) | grep -oP '[0-9]+' | head -1 || echo 0)
info "ld.lld: $(ld.lld --version 2>/dev/null | head -1)"
[[ $LLD_ACTUAL_VER -ge 15 ]] || die "ld.lld version $LLD_ACTUAL_VER < 15 even after registration. Check lld-${INSTALLED_VER} install."

# -- Shell environment file --
# Source this before any kernel make invocation.
ENV_FILE="/etc/profile.d/rex-llvm.sh"
cat > "$ENV_FILE" <<EOF
# Rex / Linux kernel LLVM toolchain environment
# Generated by rex-setup.sh — do not edit by hand
export LLVM=1
export LLVM_IAS=1
export CC=clang-${INSTALLED_VER}
export CXX=clang++-${INSTALLED_VER}
export LD=ld.lld-${INSTALLED_VER}
export AR=llvm-ar-${INSTALLED_VER}
export NM=llvm-nm-${INSTALLED_VER}
export OBJCOPY=llvm-objcopy-${INSTALLED_VER}
export OBJDUMP=llvm-objdump-${INSTALLED_VER}
export STRIP=llvm-strip-${INSTALLED_VER}
export HOSTCC=clang-${INSTALLED_VER}
export HOSTCXX=clang++-${INSTALLED_VER}
export HOSTLD=ld.lld-${INSTALLED_VER}
EOF
chmod 644 "$ENV_FILE"
info "Wrote kernel build env file: $ENV_FILE"

# Also append to user's .bashrc so interactive shells pick it up
for RC in "$REAL_HOME/.bashrc" "$REAL_HOME/.profile"; do
    grep -qF 'rex-llvm.sh' "$RC" 2>/dev/null || \
        echo "[ -f $ENV_FILE ] && source $ENV_FILE" >> "$RC"
done

# -- Meson native file --
# Place alongside the repo-provided rex-native.ini so the user can use it
# directly:  meson setup build --native-file rex-llvm-native.ini
NATIVE_FILE="$REAL_HOME/rex-llvm-native.ini"
cat > "$NATIVE_FILE" <<EOF
# Rex Meson native file — generated by rex-setup.sh
# Usage: meson setup build --native-file rex-llvm-native.ini
[binaries]
c       = 'clang-${INSTALLED_VER}'
cpp     = 'clang++-${INSTALLED_VER}'
ar      = 'llvm-ar-${INSTALLED_VER}'
nm      = 'llvm-nm-${INSTALLED_VER}'
objcopy = 'llvm-objcopy-${INSTALLED_VER}'
objdump = 'llvm-objdump-${INSTALLED_VER}'
strip   = 'llvm-strip-${INSTALLED_VER}'
ld      = 'ld.lld-${INSTALLED_VER}'

[built-in options]
c_ld    = 'lld'
cpp_ld  = 'lld'
EOF
chown "$REAL_USER:" "$NATIVE_FILE"
info "Wrote Meson native file: $NATIVE_FILE"

# ── 10. Persist PATH additions to user's shell rc ────────────────────────────
for RC in "$REAL_HOME/.bashrc" "$REAL_HOME/.profile"; do
    grep -qF '.cargo/bin' "$RC" 2>/dev/null || \
        echo 'export PATH="$HOME/.cargo/bin:/usr/local/bin:$HOME/.local/bin:$PATH"' >> "$RC"
done

# Set the Rust to nightly version
info "Setup Rust tool"
rustup toolchain install nightly --profile minimal
rustup default nightly
rustup component add rust-src --toolchain nightly
rustup component add clippy
cargo install bindgen-cli --version 0.72.1 --locked --force

# ── 10. Sanity checks ─────────────────────────────────────────────────────────
for cmd in cmake eu-strip pahole qemu-system-x86_64; do
    if command -v "$cmd" &>/dev/null; then
        info "$cmd OK: $($cmd --version 2>&1 | head -1)"
    else
        warn "$cmd not found — review install output above"
    fi
done

# ── 11. Summary ───────────────────────────────────────────────────────────────
echo ""
info "=== Rex build environment ready ==="
echo ""
printf "  %-22s %s\n" "clang"    "$(clang --version | head -1)"
printf "  %-22s %s\n" "cmake"    "$(cmake --version | head -1)"
printf "  %-22s %s\n" "eu-strip" "$(eu-strip --version 2>/dev/null | head -1)"
printf "  %-22s %s\n" "meson"    "$(meson --version)"
printf "  %-22s %s\n" "mold"     "$(mold --version)"
printf "  %-22s %s\n" "ninja"    "$(ninja --version)"
printf "  %-22s %s\n" "python3"  "$(python3 --version)"
printf "  %-22s %s\n" "qemu"     "$(qemu-system-x86_64 --version | head -1)"
printf "  %-22s %s\n" "bindgen"  \
    "$(run_as 'bindgen --version 2>/dev/null' || echo 'not found')"
printf "  %-22s %s\n" "cargo"    \
    "$(run_as 'cargo --version 2>/dev/null' || echo 'not found')"
echo ""
warn "REMINDER: Rex requires its custom compiler forks (forked rustc + LLVM)."
warn "The above installs host-level dependencies only. Next steps:"
warn "  1. git clone --recurse-submodules https://github.com/rex-rs/rex"
warn "  2. source $ENV_FILE   (or open a fresh shell — it loads automatically)"
warn "  3. Build with:  nix develop"
warn "     OR: meson setup build --native-file rex-native.ini --native-file ~/rex-llvm-native.ini"
warn "  4. Kernel builds: make LLVM=1 LLVM_IAS=1 LD=ld.lld-${INSTALLED_VER} ..."
echo ""
