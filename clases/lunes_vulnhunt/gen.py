#!/usr/bin/env python3
"""Genera ficheros .slog con el numero de registros que le pidas."""
import struct, sys

def hacer(ruta, cuantos, reales=None):
    if reales is None: reales = cuantos
    with open(ruta, "wb") as f:
        f.write(b"SLOG")
        f.write(struct.pack("<I", cuantos))      # lo que DECLARA
        for i in range(reales):                   # lo que TRAE de verdad
            f.write(b"sensor%-6d" % i)            # 12 bytes de nombre
            f.write(struct.pack("<i", i * 10))    # 4 bytes de valor

if __name__ == "__main__":
    hacer(sys.argv[1], int(sys.argv[2]))
