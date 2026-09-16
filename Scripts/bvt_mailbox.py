#!/usr/bin/env python3
"""Tiny HTTP mailbox for two-simulator BVT (Layer C)."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
import urllib.parse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4739
state = {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("mailbox: " + (fmt % args) + "\n")

    def _send(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {"ok": True})
            return
        if parsed.path == "/state":
            self._send(200, state)
            return
        key = parsed.path.lstrip("/")
        self._send(200, {"value": state.get(key)})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            payload = {}
        key = urllib.parse.urlparse(self.path).path.lstrip("/")
        if key == "reset":
            state.clear()
            self._send(200, {"ok": True})
            return
        state[key] = payload.get("value", True)
        self._send(200, {"ok": True, "key": key})


if __name__ == "__main__":
    ThreadingHTTPServer.allow_reuse_address = True
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"BVT mailbox listening on 127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
