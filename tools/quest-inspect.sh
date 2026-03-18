#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSPECT_DIR="${ROOT_DIR}/.inspect"
INSPECT_HOST="${INSPECT_HOST:-127.0.0.1}"
INSPECT_PORT="${INSPECT_PORT:-9102}"
INSPECT_TIMEOUT="${INSPECT_TIMEOUT:-10}"

usage() {
    cat <<'EOF'
Usage:
  bash tools/quest-inspect.sh tree [path] [--depth N]    Query scene tree
  bash tools/quest-inspect.sh node <path> [prop1 prop2]  Inspect node properties
  bash tools/quest-inspect.sh help                       Show this help

Examples:
  bash tools/quest-inspect.sh tree
  bash tools/quest-inspect.sh tree /root/QuestMain/XROrigin3D
  bash tools/quest-inspect.sh tree --depth 5
  bash tools/quest-inspect.sh node /root/QuestMain/XROrigin3D visible global_transform

The PC Godot app must be running with the Quest connected. The inspect
server listens on port 9102 by default (override with INSPECT_PORT).

Results are saved to .inspect/latest.json.
EOF
}

log() {
    printf '==> %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

ensure_inspect_dir() {
    mkdir -p "${INSPECT_DIR}"
}

# Single python3 invocation handles: build request, send TCP, receive response,
# parse result, print summary. Arguments passed via sys.argv to avoid injection.
run_inspect_query() {
    local query_type="$1"
    shift
    python3 - "${INSPECT_HOST}" "${INSPECT_PORT}" "${INSPECT_TIMEOUT}" "${query_type}" "$@" <<'PYTHON'
import socket, sys, json, uuid, os

host = sys.argv[1]
port = int(sys.argv[2])
timeout = int(sys.argv[3])
query_type = sys.argv[4]
args = sys.argv[5:]

# Build request
if query_type == "tree":
    path_prefix = "/root"
    max_depth = 3
    i = 0
    while i < len(args):
        if args[i] == "--depth" and i + 1 < len(args):
            max_depth = int(args[i + 1])
            i += 2
        elif args[i].startswith("--depth="):
            max_depth = int(args[i].split("=", 1)[1])
            i += 1
        elif args[i].startswith("/"):
            path_prefix = args[i]
            i += 1
        else:
            print(f"Unknown argument: {args[i]}", file=sys.stderr)
            sys.exit(1)
    request = {
        "type": "inspect_tree",
        "request_id": uuid.uuid4().hex[:8],
        "path_prefix": path_prefix,
        "max_depth": max_depth,
    }
elif query_type == "node":
    if not args:
        print("Usage: quest-inspect.sh node <path> [prop1 prop2 ...]", file=sys.stderr)
        sys.exit(1)
    node_path = args[0]
    properties = args[1:] if len(args) > 1 else ["visible", "global_transform", "process_mode"]
    request = {
        "type": "inspect_node",
        "request_id": uuid.uuid4().hex[:8],
        "node_path": node_path,
        "properties": properties,
    }
else:
    print(f"Unknown query type: {query_type}", file=sys.stderr)
    sys.exit(1)

# Send TCP query
try:
    sock = socket.create_connection((host, port), timeout=timeout)
except (ConnectionRefusedError, OSError) as e:
    response = {"ok": False, "error": f"Cannot connect to inspect server at {host}:{port} - is the PC Godot app running? ({e})"}
else:
    try:
        sock.settimeout(timeout)
        sock.sendall((json.dumps(request) + "\n").encode())
        buf = b""
        while b"\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                break
            buf += chunk
        sock.close()
        response = json.loads(buf.decode().strip()) if buf else {"ok": False, "error": "Empty response"}
    except socket.timeout:
        sock.close()
        response = {"ok": False, "error": "Timeout waiting for response"}
    except json.JSONDecodeError:
        response = {"ok": False, "error": "Invalid JSON response"}

# Save result
inspect_dir = os.environ.get("INSPECT_DIR", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0]))), ".inspect"))
os.makedirs(inspect_dir, exist_ok=True)
output_path = os.path.join(inspect_dir, "latest.json")
with open(output_path, "w") as f:
    json.dump(response, f, indent=2)
print(f"==> Saved: {output_path}", file=sys.stderr)

# Print summary and exit
if response.get("ok"):
    r = response.get("result", {})
    if query_type == "tree":
        print(f"Tree: {r.get('root_path', '?')} ({r.get('node_count', 0)} nodes, truncated={r.get('truncated', False)})", file=sys.stderr)
    elif query_type == "node":
        print(f"Node: {r.get('path', '?')} ({r.get('type', '?')})", file=sys.stderr)
        for k, v in r.get("properties", {}).items():
            print(f"  {k}: {json.dumps(v)}", file=sys.stderr)
    print(output_path)
else:
    print(f"ERROR: {response.get('error', 'Unknown error')}", file=sys.stderr)
    sys.exit(1)
PYTHON
}

main() {
    local command="${1:-help}"
    shift || true

    case "${command}" in
        tree)
            ensure_inspect_dir
            log "Querying scene tree"
            INSPECT_DIR="${INSPECT_DIR}" run_inspect_query tree "$@"
            ;;
        node)
            ensure_inspect_dir
            log "Inspecting node"
            INSPECT_DIR="${INSPECT_DIR}" run_inspect_query node "$@"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Unknown command: ${command}" >&2
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
