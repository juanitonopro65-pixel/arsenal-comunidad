#!/bin/bash
# Corre TODOS los comandos de la guia y comprueba que dan lo que la guia dice.
# Si esto falla, la guia miente. Correr antes de dar la clase.
cd "$(dirname "$0")"
ok=0; mal=0
chk() { if [ "$2" = "$3" ]; then echo "  OK   $1"; ok=$((ok+1)); else echo "  MAL  $1  (esperaba $3, dio $2)"; mal=$((mal+1)); fi; }

gcc -g -fno-stack-protector -o sensorlog sensorlog.c 2>/dev/null
chk "compila" "$?" "0"

python3 gen.py sano.slog 50 2>/dev/null
salida=$(./sensorlog sano.slog 2>/dev/null)
chk "sano: codigo 0" "$?" "0"
echo "$salida" | grep -q "registros declarados: 50" && chk "sano: imprime 50" "si" "si" || chk "sano: imprime 50" "no" "si"

for n in 99 100 101; do
  python3 gen.py x.slog $n 2>/dev/null
  ( ./sensorlog x.slog >/dev/null 2>&1 )
  chk "$n registros pasa" "$?" "0"
done
for n in 102 103 500; do
  python3 gen.py x.slog $n 2>/dev/null
  ( ./sensorlog x.slog >/dev/null 2>&1 )
  chk "$n registros revienta" "$?" "139"
done

python3 gen.py p.slog 113 2>/dev/null
for i in 1 2 3 4 5; do ( ./sensorlog p.slog >/dev/null 2>&1 ); chk "repro roto $i/5" "$?" "139"; done
for i in 1 2 3 4 5; do ( ./sensorlog sano.slog >/dev/null 2>&1 ); chk "repro sano $i/5" "$?" "0"; done

rm -f x.slog p.slog
echo
echo "  $ok bien, $mal mal"
[ $mal -eq 0 ] && echo "  La guia dice la verdad." || echo "  LA GUIA MIENTE. Arreglar antes de darla."
