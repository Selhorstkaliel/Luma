#!/usr/bin/env python3
"""Cliente mínimo do agente QEMU (qemu-guest-agent) usado por `lab.sh ga`.

Uso: qga.py SOCKET COMANDO_SHELL
Executa COMANDO_SHELL como root na VM via /bin/sh -c, repassa stdout/stderr e sai com o código do comando.

O agente só responde com a conexão aberta e pode guardar respostas de pedidos abandonados; por isso
tudo acontece numa única conexão, sincronizada antes com guest-sync e um id único (protocolo QGA).
"""
import base64
import json
import random
import socket
import sys
import time


def main():
    if len(sys.argv) != 3:
        print("uso: qga.py SOCKET COMANDO", file=sys.stderr)
        return 64
    sock_path, command = sys.argv[1], sys.argv[2]
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(10)
    try:
        s.connect(sock_path)
    except OSError as e:
        print(f"qga: sem conexão com {sock_path}: {e}", file=sys.stderr)
        return 2
    f = s.makefile("rwb", buffering=0)

    def send(obj):
        f.write(json.dumps(obj).encode() + b"\n")

    def recv():
        line = f.readline()
        if not line:
            raise ConnectionError("agente fechou a conexão")
        return json.loads(line)

    try:
        sync_id = random.randint(1, 2**31 - 1)
        send({"execute": "guest-sync", "arguments": {"id": sync_id}})
        while recv().get("return") != sync_id:
            pass  # descarta respostas antigas
        send({"execute": "guest-exec",
              "arguments": {"path": "/bin/sh", "arg": ["-c", command], "capture-output": True}})
        pid = recv()["return"]["pid"]
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            send({"execute": "guest-exec-status", "arguments": {"pid": pid}})
            st = recv()["return"]
            if st.get("exited"):
                sys.stdout.write(base64.b64decode(st.get("out-data", "")).decode(errors="replace"))
                sys.stderr.write(base64.b64decode(st.get("err-data", "")).decode(errors="replace"))
                return st.get("exitcode", 1)
            time.sleep(0.5)
        print("qga: comando não terminou em 120 s", file=sys.stderr)
        return 124
    except (OSError, ConnectionError, ValueError, KeyError) as e:
        print(f"qga: falha de protocolo: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
