# 🔓 Clase del lunes — cómo se encuentra un bug que se paga

> **Vuln hunting · desde cero · no hace falta saber C**
>
> Kaijulele pidió Windows internals, vuln hunting, reversing o malware dev.
> Esta clase es vuln hunting, pero toca las tres primeras: vas a mirar un
> programa por dentro, entender cómo usa la memoria, y encontrarle un fallo.
>
> No es un ejercicio de mentira. El patrón que vas a aprender hoy es
> **literalmente** el mismo que hay detrás de los casos que tengo abiertos
> ahora mismo en Zero Day Initiative. El mismo. Cambia el programa, no el bug.

---

## ⚠️ Antes de nada

Todo esto se practica contra **tu propio laboratorio, HackTheBox, o algo con
permiso escrito**. El programa de hoy lo escribimos nosotros justamente para
eso: es nuestro, podés romperlo todo lo que quieras.

Y una regla que vale para siempre: **si encontrás un fallo en software real,
no se publica.** Se reporta al fabricante y se espera al parche. Publicarlo
antes deja a gente expuesta — y además quema el hallazgo, que es lo único que
se paga.

---

## ⛔ Si estás en Windows, leé esto primero

Los comandos son de Linux. Si los pegás en PowerShell te va a decir que no
reconoce `gcc`, y no es que el comando esté mal: se lo estás pidiendo al
programa equivocado.

Abrí WSL una vez y quedate ahí toda la clase:

```powershell
wsl
```

Si te dice que no encuentra la distro, probá `wsl -d kali-linux`.

---

## Qué vas a aprender

Al final de la clase vas a poder responder estas tres, que son las que separan
un reporte que se paga de uno que se tira:

1. ¿Dónde empieza el fallo, y dónde empieza el crash? **No son el mismo sitio.**
2. ¿Cómo se prueba que un fallo es real y no casualidad?
3. ¿Por qué este bug concreto vale dinero y otros no?

---

# Parte 1 — el programa

Tenemos `sensorlog`, un visor de registros de sensores. Lee ficheros `.slog`.
El formato es sencillo a propósito:

```
bytes 0-3    la magia: las letras SLOG
bytes 4-7    cuántos registros hay (un número de 32 bits)
desde el 8   los registros, 16 bytes cada uno
```

Compilalo:

```bash
gcc -g -fno-stack-protector -o sensorlog sensorlog.c
```

> **¿Qué es `-fno-stack-protector`?** Los compiladores modernos meten una
> defensa automática que detecta algunos desbordamientos. La apagamos para ver
> el fallo desnudo. En el software real esa defensa a veces está y a veces no
> — y aprender a distinguir "no hay bug" de "hay bug pero la defensa lo tapa"
> es media carrera.

Ahora generá un fichero normal y abrilo:

```bash
python3 gen.py sano.slog 50
./sensorlog sano.slog
```

Deberías ver:

```
registros declarados: 50
leidos. primer registro: sensor0      = 0
```

**Esto es tu control sano.** Guardalo. Si más adelante algo raro pasa, volvés
a correr esto: si el sano también falla, el roto no es el programa — es tu
medición.

---

# Parte 2 — rompelo

El fichero dice cuántos registros trae. ¿Qué pasa si dice muchos?

```bash
python3 gen.py roto.slog 500
./sensorlog roto.slog
```

```
registros declarados: 500
Segmentation fault
```

**Segmentation fault** quiere decir que el programa tocó memoria que no era
suya y el sistema operativo lo mató. Es la señal de que algo se salió de su
sitio.

Comprobá el código de salida, que es lo que vas a mirar cuando esto corra
automatizado y no puedas leer la pantalla:

```bash
./sensorlog roto.slog; echo "codigo: $?"
```

```
codigo: 139
```

> **139 = 128 + 11.** El 11 es SIGSEGV. Por convención, cuando un programa
> muere por una señal, el código de salida es 128 más el número de la señal.
> Vas a ver ese 139 mil veces en tu vida.

---

# Parte 3 — ¿dónde empieza exactamente?

Aquí es donde la mayoría se queda corta. Ya sabemos que 500 revienta y 50 no.
**¿Dónde está la frontera?**

Esto se llama **bisección** y es lo que convierte "encontré un crash" en un
reporte que alguien paga. Probá uno por uno:

```bash
for n in 99 100 101 102 103; do
  python3 gen.py x.slog $n
  ./sensorlog x.slog >/dev/null 2>&1
  echo "$n registros -> codigo $?"
done
```

```
 99 registros -> codigo 0
100 registros -> codigo 0
101 registros -> codigo 0
102 registros -> codigo 139
```

**El umbral es 102.** Con 101 pasa, con 102 revienta.

## Y ahora la parte que importa de verdad

Abrí el código y mirá esta línea:

```c
#define MAX_REGISTROS 100
struct registro tabla[MAX_REGISTROS];
```

La tabla tiene capacidad para **100** registros. En C se numeran desde cero,
así que las posiciones válidas son **0 a 99**.

Entonces:

| declarás | escribe hasta la posición | ¿está dentro? | ¿revienta? |
|---:|---:|---|---|
| 100 | 99 | sí | no |
| **101** | **100** | **NO — ya está fuera** | **no** |
| 102 | 101 | no | **sí** |

**Con 101 el programa ya está escribiendo fuera de la tabla. Y no revienta.**

Eso es lo más importante de toda la clase:

> **"Fuera de límites" y "crash" no son lo mismo.**
> El fallo empieza en 101. El crash empieza en 102.

¿Por qué? Porque justo después de la tabla hay más memoria que sí está
asignada al programa — otras variables, restos de la pila. Escribir ahí es un
error grave, pero el sistema operativo no se entera: sigue siendo memoria del
proceso. Solo cuando te alejás lo suficiente tocás algo que importa y ahí sí
te mata.

**Si solo buscás crashes, reportás 102 y estás equivocado.** El defecto
empieza en 101, y esa diferencia de uno es exactamente lo que un revisor mira
para decidir si entendiste el bug o solo tropezaste con él.

---

# Parte 4 — el patrón

Mirá las dos líneas juntas:

```c
struct registro tabla[MAX_REGISTROS];        /* ① el tamaño es FIJO: 100 */

for (unsigned int i = 0; i < cuantos; i++) { /* ② el bucle lo manda el FICHERO */
    if (fread(&tabla[i], 1, 16, f) != 16) break;
}
```

Ahí está todo:

> **Una cantidad decide el tamaño del sitio. OTRA cantidad decide cuánto se
> escribe. Y nadie las compara.**

La comprobación que falta es de una línea:

```c
if (cuantos > MAX_REGISTROS) cuantos = MAX_REGISTROS;
```

Eso es todo. Un bug que puede valer miles de dólares es, casi siempre, **una
comparación que nadie escribió**.

## Por qué esto se paga

Este patrón aparece en todas partes porque es fácil de cometer:

- el programador que reservó la memoria y el que escribió el bucle **no son
  la misma persona**, o son la misma persona con seis meses de diferencia
- el formato de fichero se diseñó cuando 100 parecía muchísimo
- funciona perfecto con todos los ficheros normales, y nadie prueba con uno raro

Y se paga porque si controlás **qué** se escribe fuera y **hasta dónde**, en
algunos casos podés hacer que el programa ejecute lo que vos quieras. Ahí deja
de ser "se cerró el programa" y pasa a ser "alguien entró".

---

# Parte 5 — probalo como un profesional

Un crash que pasa una vez no vale nada. Podría ser tu máquina, un cable, la
luna. Hay que demostrar que **siempre** pasa:

```bash
python3 gen.py prueba.slog 113
for i in 1 2 3 4 5; do ./sensorlog prueba.slog >/dev/null 2>&1; echo "codigo $?"; done
```

Los cinco tienen que dar 139. Y después el sano, otras cinco veces:

```bash
python3 gen.py sano.slog 50
for i in 1 2 3 4 5; do ./sensorlog sano.slog >/dev/null 2>&1; echo "codigo $?"; done
```

Los cinco tienen que dar 0.

> **Los dos controles, siempre.** Si solo probás el roto, no sabés si el
> programa está roto o si TODO se rompe en tu máquina. El control sano es el
> que te dice que tu medición funciona.

---

# Errores comunes

**"Me dice `gcc: command not found`"**
Estás en PowerShell. Escribí `wsl` y volvé a intentar.

**"No revienta en mi máquina"**
Comprobá que compilaste con `-fno-stack-protector`. Sin eso, el compilador
mete una defensa que puede matar el programa antes con un mensaje distinto
(`stack smashing detected`) — que también es un hallazgo, pero es otro.

**"Me da un umbral distinto"**
Puede pasar, y no está mal. El número exacto depende de cómo tu compilador
ordenó las variables en la pila. Lo que NO cambia es la forma: hay un tramo
donde ya escribe fuera sin reventar, y después revienta. Reportá **tu** número
medido, no el mío.

**"¿Y si el `break` del `fread` salva el programa?"**
Buena pregunta, y es la trampa del ejercicio. El `break` corta cuando el
fichero se acaba — pero para entonces ya escribió. Y si el fichero **sí** trae
los 500 registros, no corta nunca.

---

# Qué hacer ahora

1. **Cambiá `MAX_REGISTROS` a 20** y volvé a buscar el umbral. ¿Se movió lo
   que esperabas?
2. **Agregá la comprobación que falta** y comprobá que 500 ya no revienta.
   Ese es el parche. Escribir el parche es parte del reporte: en ZDI lo piden.
3. **Buscá el mismo patrón en otro sitio.** Cualquier programa que lea un
   formato de fichero con un campo de cantidad es candidato. La pregunta es
   siempre la misma: *¿quién dimensiona el sitio, y quién manda el bucle?*

---

## Para la próxima

Esto fue el bug en la **pila** (la memoria de las variables locales). El mismo
patrón existe en el **montón** (`malloc`), y ahí es más interesante porque hay
más cosas alrededor que corromper.

Y la pregunta que abre la siguiente clase: cuando no tenés el código fuente
—que es el caso real— **¿cómo encontrás este mismo bucle mirando solo el
binario?** Eso es reversing, y es lo que pidió Kaijulele.

---

*Arsenal de la comunidad · el programa y los scripts están en esta misma carpeta*
