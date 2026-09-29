#!/bin/bash
cd /mnt/c/Users/Usuario/arsenal-comunidad/clases/lunes_vulnhunt
echo "Biseccion fina entre 101 y 120:"
for n in $(seq 101 120); do
  python3 gen.py "b.slog" "$n" 2>/dev/null
  ./sensorlog "b.slog" > /dev/null 2>&1
  if [ $? -eq 0 ]; then printf "  %3d OK\n" "$n"; else printf "  %3d <<< REVIENTA\n" "$n"; fi
done
echo
echo "Estabilidad: el umbral 5 veces seguidas (tiene que dar lo mismo siempre)"
python3 gen.py "u.slog" 113 2>/dev/null
for i in 1 2 3 4 5; do
  ./sensorlog "u.slog" > /dev/null 2>&1
  printf "  intento %d -> codigo %d\n" "$i" "$?"
done
echo
echo "Control sano: el fichero de 100, tambien 5 veces"
python3 gen.py "s.slog" 100 2>/dev/null
for i in 1 2 3 4 5; do
  ./sensorlog "s.slog" > /dev/null 2>&1
  printf "  intento %d -> codigo %d\n" "$i" "$?"
done
rm -f b.slog t_*.slog
