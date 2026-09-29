#!/bin/bash
cd /mnt/c/Users/Usuario/arsenal-comunidad/clases/lunes_vulnhunt
exec 2>/dev/null
for n in 99 100 101 102 103; do
  python3 gen.py "x.slog" "$n"
  ( ./sensorlog "x.slog" >/dev/null 2>&1 )
  c=$?
  if [ $c -eq 0 ]; then r="OK"; else r="REVIENTA (SIGSEGV)"; fi
  printf "  %3d registros -> %s\n" "$n" "$r"
done
rm -f x.slog u.slog s.slog
