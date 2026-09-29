#!/bin/bash
# Busca el umbral: a partir de cuantos registros revienta.
cd /mnt/c/Users/Usuario/arsenal-comunidad/clases/lunes_vulnhunt
for n in 100 101 120 150 200 300 400 500; do
  python3 gen.py "t_$n.slog" "$n" 2>/dev/null
  salida=$(./sensorlog "t_$n.slog" 2>&1)
  codigo=$?
  if [ $codigo -eq 0 ]; then
    printf "  %4d registros -> OK        (codigo %d)\n" "$n" "$codigo"
  else
    printf "  %4d registros -> REVIENTA  (codigo %d)  %s\n" "$n" "$codigo" "$(echo "$salida" | tail -1)"
  fi
done
