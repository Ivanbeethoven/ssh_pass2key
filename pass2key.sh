#!/usr/bin/env bash
# SSH password-to-key helper
# Usage: pass2key.sh [--hosts hosts.txt] [--user user] [--port port] [--identity ~/.ssh/id_ed25519] [--dry-run] [--parallel N]

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE=./pass2key.log

usage(){
  cat <<EOF
$SCRIPT_NAME - 将本地公钥安装到远程主机的 authorized_keys

用法:
  $SCRIPT_NAME --hosts hosts.txt [--user user] [--port 22] [--identity ~/.ssh/id_ed25519.pub] [--dry-run]

hosts.txt 格式：每行一个 host 或 host:port
优先使用 ssh-copy-id。仅在用户明确提供密码或需要时使用 sshpass（不推荐）。
EOF
}

require_cmd(){
  command -v "$1" >/dev/null 2>&1 || { echo "$1 not found, please install it" >&2; exit 2; }
}

DEFAULT_IDENTITY="$HOME/.ssh/id_ed25519.pub"
DEFAULT_PRIVATE="$HOME/.ssh/id_ed25519"

HOSTS_FILE=""
USER=""
PORT=""
IDENTITY=""
DRY_RUN=0
PARALLEL=1
USE_SSHPASS=0
PROMPT_PASSWORD=0
PASSWORD=""
INTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) HOSTS_FILE="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --identity) IDENTITY="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --sshpass) USE_SSHPASS=1; shift;;
    --ask-password) PROMPT_PASSWORD=1; shift;;
    --interactive) INTERACTIVE=1; shift;;
    --parallel) PARALLEL="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ -z "$HOSTS_FILE" ]]; then
  echo "Please provide --hosts hosts.txt" >&2
  usage
  exit 1
fi

# If interactive mode or no hosts provided, enter interactive prompt loop
if [[ $INTERACTIVE -eq 1 ]]; then
  echo "Interactive mode: enter host, user and optional port. Empty host to finish."
  while true; do
    read -p "Host (host or host:port): " in_host
    [[ -z "$in_host" ]] && break
    read -p "Username (leave empty for current user): " in_user
    read -p "Use password? (y/N): " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
      if [[ $PROMPT_PASSWORD -ne 1 ]]; then
        # if not already set to prompt, prompt now
        read -s -p "Password: " PASSWORD
        echo
      else
        read -s -p "Password: " PASSWORD
        echo
      fi
      USE_SSHPASS=1
    fi
    append_key_to_host "$in_host" "$in_user" ""
  done
  echo "Interactive session finished."
  exit 0
fi

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$DEFAULT_IDENTITY"
fi

if [[ ! -f "$IDENTITY" ]]; then
  echo "Public key $IDENTITY not found. Generating ed25519 keypair..."
  require_cmd ssh-keygen
  if [[ -f "$DEFAULT_PRIVATE" || -f "$DEFAULT_IDENTITY" ]]; then
    echo "Found existing keypair; backing up..."
    ts=$(date +%s)
    mv "$DEFAULT_PRIVATE" "$DEFAULT_PRIVATE.bak.$ts" || true
    mv "$DEFAULT_IDENTITY" "$DEFAULT_IDENTITY.bak.$ts" || true
  fi
  ssh-keygen -t ed25519 -f "$DEFAULT_PRIVATE" -N "" -C "pass2key@$(hostname)"
  IDENTITY="$DEFAULT_IDENTITY"
fi

PUBKEY_CONTENT=$(cat "$IDENTITY")

echo "Using public key: $IDENTITY"

require_cmd ssh
require_cmd ssh-copy-id || true
if [[ $USE_SSHPASS -eq 1 ]]; then
  require_cmd sshpass || { echo "sshpass required but not found" >&2; exit 3; }
fi

if [[ $PROMPT_PASSWORD -eq 1 ]]; then
  # read password without echo
  read -s -p "Password for remote hosts: " PASSWORD
  echo
fi

append_key_to_host(){
  host="$1"
  user_pref="$2"
  port_pref="$3"

  target_user="${user_pref:-$USER}"
  [[ -z "$target_user" ]] && target_user="$USER" || true
  [[ -z "$target_user" ]] && target_user="$USER" || true

  host_only="$host"
  host_port="$port_pref"
  if [[ "$host" == *":"* ]]; then
    host_only=${host%%:*}
    host_port=${host##*:}
  fi

  [[ -z "$host_port" ]] && host_port=${port_pref:-22}

  ssh_target="${target_user:+$target_user@}$host_only"

  echo "Processing $ssh_target (port $host_port)"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY RUN: would install key to $ssh_target"
    return 0
  fi

  # Try ssh-copy-id if available
  if command -v ssh-copy-id >/dev/null 2>&1; then
    echo "Using ssh-copy-id to install key"
    if [[ $USE_SSHPASS -eq 1 && -n "$PASSWORD" ]]; then
      if [[ -n "$PORT" || -n "$host_port" ]]; then
        sshpass -p "$PASSWORD" ssh-copy-id -i "$IDENTITY" -p "$host_port" "$ssh_target" || true
      else
        sshpass -p "$PASSWORD" ssh-copy-id -i "$IDENTITY" "$ssh_target" || true
      fi
    else
      if [[ -n "$PORT" || -n "$host_port" ]]; then
        ssh-copy-id -i "$IDENTITY" -p "$host_port" "$ssh_target" || true
      else
        ssh-copy-id -i "$IDENTITY" "$ssh_target" || true
      fi
    fi
  else
    echo "ssh-copy-id not available; using fallback via ssh and append"
    # make remote ~/.ssh and backup authorized_keys
    if [[ $USE_SSHPASS -eq 1 && -n "$PASSWORD" ]]; then
      sshpass -p "$PASSWORD" ssh -p "$host_port" "$ssh_target" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qF \"$PUBKEY_CONTENT\" ~/.ssh/authorized_keys || (cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak.$(date +%s) && echo '$PUBKEY_CONTENT' >> ~/.ssh/authorized_keys)"
    else
      ssh -p "$host_port" "$ssh_target" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qF \"$PUBKEY_CONTENT\" ~/.ssh/authorized_keys || (cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak.$(date +%s) && echo '$PUBKEY_CONTENT' >> ~/.ssh/authorized_keys)"
    fi
  fi
}

# Read hosts file
if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "Hosts file $HOSTS_FILE not found" >&2
  exit 2
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%%#*}
  line=$(echo "$line" | xargs)
  [[ -z "$line" ]] && continue
  append_key_to_host "$line" "$USER" "$PORT"
done < "$HOSTS_FILE"

echo "Done. Log: $LOG_FILE"
