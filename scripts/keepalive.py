#!/usr/bin/env python3
"""
Paperspace Keepalive - Prevents idle shutdown by sending terminal commands.

Paperspace monitors:
- Terminal activity (stdin input)
- Kernel execution
- WebSocket messages

Simple HTTP requests don't count as activity. This script creates a JupyterLab
terminal session and periodically sends commands via WebSocket.
"""

import json
import os
import sys
import time

import requests
import websocket


def log(message: str) -> None:
    """Print timestamped log message."""
    print(f"[KEEPALIVE] {message}", flush=True)


def wait_for_jupyter(base_url: str, timeout: int = 300) -> bool:
    """Wait for JupyterLab to become available."""
    log(f"Waiting for JupyterLab at {base_url}...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            resp = requests.get(f"{base_url}/api", timeout=5)
            if resp.status_code == 200:
                log("JupyterLab is ready")
                return True
        except requests.RequestException:
            pass
        time.sleep(2)
    log("Timeout waiting for JupyterLab")
    return False


def create_terminal(base_url: str) -> str | None:
    """Create a new terminal session and return its name."""
    try:
        resp = requests.post(f"{base_url}/api/terminals", timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            name = data.get("name")
            log(f"Created terminal: {name}")
            return name
        log(f"Failed to create terminal: HTTP {resp.status_code}")
    except requests.RequestException as e:
        log(f"Failed to create terminal: {e}")
    return None


def get_websocket_url(base_url: str, terminal_name: str) -> str:
    """Convert HTTP URL to WebSocket URL for terminal."""
    ws_url = base_url.replace("http://", "ws://").replace("https://", "wss://")
    return f"{ws_url}/terminals/websocket/{terminal_name}"


def run_keepalive(
    base_url: str, interval: int, command: str
) -> None:
    """Main keepalive loop - connect to terminal and send commands."""
    while True:
        terminal_name = create_terminal(base_url)
        if not terminal_name:
            log("Retrying terminal creation in 30s...")
            time.sleep(30)
            continue

        ws_url = get_websocket_url(base_url, terminal_name)
        log(f"Connecting to {ws_url}")

        try:
            ws = websocket.create_connection(ws_url, timeout=30)
            log("WebSocket connected")

            while True:
                # Send command to terminal stdin
                message = json.dumps(["stdin", f"{command}\n"])
                ws.send(message)
                log(f"Sent command: {command}")

                # Drain any output (don't care about content)
                ws.settimeout(2)
                try:
                    while True:
                        ws.recv()
                except websocket.WebSocketTimeoutException:
                    pass
                ws.settimeout(30)

                time.sleep(interval)

        except websocket.WebSocketException as e:
            log(f"WebSocket error: {e}")
        except Exception as e:
            log(f"Unexpected error: {e}")

        log("Reconnecting in 10s...")
        time.sleep(10)


def main() -> None:
    # Check if keepalive is enabled
    if os.environ.get("ENABLE_KEEPALIVE", "false").lower() != "true":
        log("Disabled (set ENABLE_KEEPALIVE=true to enable)")
        while True:
            time.sleep(86400)  # Sleep forever

    # Configuration from environment
    base_url = os.environ.get("JUPYTER_URL", "http://localhost:8888")
    interval = int(os.environ.get("KEEPALIVE_INTERVAL", "300"))  # 5 minutes
    command = os.environ.get("KEEPALIVE_COMMAND", "date")

    log(f"Starting (interval: {interval}s, command: {command})")

    # Wait for JupyterLab to be ready
    if not wait_for_jupyter(base_url):
        sys.exit(1)

    # Run keepalive loop
    run_keepalive(base_url, interval, command)


if __name__ == "__main__":
    main()
