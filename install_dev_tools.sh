#!/usr/bin/env bash
#
# install_dev_tools.sh
# Automatically installs Docker, Docker Compose, Python (>= 3.9) and Django.
# Skips any tool that is already installed.

set -euo pipefail

MIN_PYTHON_MAJOR=3
MIN_PYTHON_MINOR=9

log() {
    echo ">> $1"
}

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log "Docker is already installed: $(docker --version)"
        return
    fi

    log "Docker not found. Installing..."
    if is_macos; then
        if command -v brew >/dev/null 2>&1; then
            brew install --cask docker
        else
            echo "Homebrew is required to install Docker on macOS. Install it from https://brew.sh and re-run this script." >&2
            exit 1
        fi
    elif is_linux; then
        curl -fsSL https://get.docker.com | sh
    else
        echo "Unsupported OS for automatic Docker installation." >&2
        exit 1
    fi
    log "Docker installed: $(docker --version)"
}

# ---------------------------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------------------------
install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose is already installed: $(docker compose version)"
        return
    fi
    if command -v docker-compose >/dev/null 2>&1; then
        log "Docker Compose is already installed: $(docker-compose --version)"
        return
    fi

    log "Docker Compose not found. Installing..."
    if is_macos; then
        log "Docker Compose ships with Docker Desktop on macOS; reinstalling Docker should provide it."
    elif is_linux; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y docker-compose-plugin
        else
            COMPOSE_VERSION="v2.27.0"
            sudo curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
                -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    else
        echo "Unsupported OS for automatic Docker Compose installation." >&2
        exit 1
    fi
    log "Docker Compose installed."
}

# ---------------------------------------------------------------------------
# Python (>= 3.9)
# ---------------------------------------------------------------------------
python_version_ok() {
    local python_bin="$1"
    "$python_bin" - <<'EOF'
import sys
sys.exit(0 if sys.version_info >= (3, 9) else 1)
EOF
}

find_suitable_python() {
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 && python_version_ok "$candidate"; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

install_python() {
    if PYTHON_BIN="$(find_suitable_python)"; then
        log "Python is already installed: $("$PYTHON_BIN" --version)"
        return
    fi

    log "Python ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}+ not found. Installing..."
    if is_macos; then
        if command -v brew >/dev/null 2>&1; then
            brew install python
        else
            echo "Homebrew is required to install Python on macOS. Install it from https://brew.sh and re-run this script." >&2
            exit 1
        fi
    elif is_linux; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv
        else
            echo "Unsupported Linux package manager for automatic Python installation." >&2
            exit 1
        fi
    else
        echo "Unsupported OS for automatic Python installation." >&2
        exit 1
    fi

    if ! PYTHON_BIN="$(find_suitable_python)"; then
        echo "Python ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}+ installation failed or version is still too old." >&2
        exit 1
    fi
    log "Python installed: $("$PYTHON_BIN" --version)"
}

# ---------------------------------------------------------------------------
# Django
# ---------------------------------------------------------------------------
install_django() {
    if "$PYTHON_BIN" -m django --version >/dev/null 2>&1; then
        log "Django is already installed: $("$PYTHON_BIN" -m django --version)"
        return
    fi

    log "Django not found. Installing via pip..."
    "$PYTHON_BIN" -m pip install --upgrade pip
    "$PYTHON_BIN" -m pip install django
    log "Django installed: $("$PYTHON_BIN" -m django --version)"
}

main() {
    install_docker
    install_docker_compose
    install_python
    install_django
    log "All tools are installed and ready to use."
}

main "$@"
