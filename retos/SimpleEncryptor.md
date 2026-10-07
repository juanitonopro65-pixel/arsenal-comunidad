# 🔐 Simple Encryptor — cuando `strings` no canta

> **Reto:** Simple Encryptor · HackTheBox · Reversing · Very Easy
> **Lo que vas a aprender:** a leer un programa que no te quiere contar nada, y a
> darle la vuelta a su algoritmo.

Esta guía es la continuación directa de [SpookyPass](SpookyPass.md). Allí
`strings` cantó la flag y se acabó el reto. Aquí no canta nada, y esa es
exactamente la gracia.

Si SpookyPass te enseñó a **mirar**, este te enseña a **leer**.

---

## Antes de empezar

Lo que hace falta:

- una terminal de Linux (en Windows, WSL — está explicado en SpookyPass)
- una cuenta en HackTheBox, para bajar el reto
- un rato sin prisa

Lo que **no** hace falta: saber programar en C. Vas a leer código C sin haberlo
escrito nunca, y eso se puede. Leer un idioma siempre es más fácil que hablarlo.
Donde haga falta escribir algo, te lo damos hecho para pegar.

**Todas las salidas que aparecen en esta guía están copiadas de la terminal tal
cual salieron**, con el ruido incluido. Si limpiáramos las salidas te
enseñaríamos a esperar una pantalla que no vas a ver nunca.

---

## El escenario

HackTheBox lo plantea así:

> En una revisión rutinaria del servidor donde guardábamos la flag descubrimos
> que nos había entrado un ransomware. El fichero original ya no está, pero por
> suerte conservamos **el fichero cifrado y el programa que lo cifró**.

Leé esa última frase otra vez, porque es todo el reto:

**Tenemos el programa que cifró.** Si tenemos el programa, tenemos el algoritmo.
Y si tenemos el algoritmo, podemos darlo vuelta.

Esto no es un ejercicio artificial: es literalmente lo que hace un analista
cuando aparece un ransomware nuevo. Si el cifrado está mal hecho, se escribe el
descifrador y se recupera todo sin pagar nada.

---

## Paso 0 — Abrir el paquete

El zip de HackTheBox viene con contraseña, y la contraseña es siempre la misma:
`hackthebox`.

El nombre del zip es distinto para cada uno — es un identificador largo con
guiones. **Poné el tuyo**, no copies el de abajo:

```bash
unzip -P hackthebox TU_FICHERO.zip -d simple_encryptor
cd simple_encryptor/rev_simpleencryptor
```

Dentro hay dos ficheros:

```
encrypt     17120 bytes
flag.enc       32 bytes
```

`encrypt` es el ransomware. `flag.enc` es la víctima.

---

## Paso 1 — Mirar antes de tocar

Primera orden siempre, en cualquier reto de ingeniería inversa:

```bash
file encrypt
```

```
encrypt: ELF 64-bit LSB pie executable, x86-64, dynamically linked,
         interpreter /lib64/ld-linux-x86-64.so.2, ... not stripped
```

Traducción, palabra por palabra:

| lo que dice | qué significa |
|---|---|
| **ELF 64-bit** | ejecutable de Linux, de 64 bits |
| **x86-64** | para procesadores de PC normales |
| **dynamically linked** | usa librerías del sistema (`libc`), no se las lleva dentro |
| **not stripped** | 🎉 **conserva los nombres de las funciones** |

Ese último es un regalo. `not stripped` quiere decir que el programador no borró
los nombres, así que cuando abramos el programa vamos a ver `main` y no
`FUN_00101289`. En retos más duros te lo encontrás `stripped` y tenés que deducir
qué es cada cosa.

Y ahora el otro fichero:

```bash
od -A x -t x1z flag.enc
```

`od` ("octal dump", aunque aquí lo usamos en hexadecimal) muestra un fichero byte
a byte. Los flags: `-A x` numera las posiciones en hexadecimal, `-t x1` muestra
cada byte en hex, y `z` añade a la derecha el texto, para ver si hay algo
legible.

```
000000 5a 35 b1 62 00 f5 3e 12 c0 bd 8d 16 f0 fd 75 99  >Z5.b..>.......u.<
000010 fa ef 39 9a 4b 96 21 a1 43 16 23 71 65 fb 27 4b  >..9.K.!.C.#qe.'K<
```

32 bytes de ruido. Ahí no se lee nada, y no se va a leer por mucho que lo mires.

> **Acordate de estos 32 bytes.** Dentro de un rato van a significar algo.

### Antes de seguir: ¿y si lo ejecuto?

Es la pregunta que todo el mundo se hace. Probemos, que además enseña algo:

```bash
./encrypt
```

```
Segmentation fault
```

Se rompe. No es que esté protegido: es que el programa busca un fichero llamado
`flag` que **no viene en el zip** (lo vas a ver en el Paso 5), no lo encuentra, y
no comprueba el error. Un fallo de programación, por cierto.

> **Detalle de seguridad, no de este reto pero sí de la vida:** este binario es
> inofensivo y viene de una plataforma de prácticas. Un ejecutable que te llega
> por otro camino **no se ejecuta para ver qué hace**. Se lee primero, y si hay
> que ejecutarlo, en una máquina virtual aislada.

---

## Paso 2 — Probar `strings`, y que falle

En SpookyPass la flag estaba escrita dentro del binario y `strings` la encontró.
Probemos lo mismo:

```bash
strings encrypt | grep -i htb
```

**Nada.** Ni una línea.

Veamos entonces qué sí hay. **Ojo con el filtro:** `strings -n 5` solo muestra
cadenas de 5 caracteres o más, y se dejaría fuera `flag` y `time`, que tienen 4.
Usamos el valor por defecto (4):

```bash
strings encrypt | head -20
```

Esto es lo que sale **de verdad**, sin limpiar:

```
/lib64/ld-linux-x86-64.so.2
libc.so.6
srand
fopen
ftell
__stack_chk_fail
fseek
fclose
malloc
fwrite
fread
__cxa_finalize
__libc_start_main
GLIBC_2.4
GLIBC_2.2.5
_ITM_deregisterTMCloneTable
__gmon_start__
_ITM_registerTMCloneTable
dH3<%(
[]A\A]A^A_
```

Acostumbrate a esta pinta, porque es la normal. Hay de todo:

- **nombres de funciones** que el programa usa: `srand`, `fopen`, `malloc`...
- **ruido de la libc**, que sale en *todos* los programas de C y no dice nada del
  nuestro: `__stack_chk_fail`, `__cxa_finalize`, `__libc_start_main`,
  `GLIBC_2.4`, `_ITM_*`, `__gmon_start__`
- **basura binaria** que casualmente parecía texto: `dH3<%(`, `[]A\A]A^A_`

Aprender a **tachar el ruido de un vistazo** es media habilidad del oficio.

¿Y los nombres de fichero? Están, pero más abajo:

```bash
strings encrypt | grep -n flag
```

```
23:flag
24:flag.enc
```

Dos nombres de fichero. **La flag no aparece.**

**Y está bien que no esté.** Pensalo: la flag nunca vivió dentro de este
programa. El programa *leyó* un fichero que estaba fuera, lo revolvió y escribió
el resultado. La flag original nunca fue parte del ejecutable.

Esta es la primera lección de verdad:

> `strings` encuentra lo que alguien **escribió** en el programa.
> No encuentra lo que el programa **calcula**.

A partir de acá hay que leer.

---

## Paso 3 — Leer el índice antes que el libro

Antes de abrir nada pesado hay una pregunta barata que da muchísima información:
**¿qué funciones del sistema usa este programa?**

```bash
objdump -T encrypt | grep UND
```

`objdump -T` lista la tabla de símbolos dinámicos. `UND` es *undefined*: "esto lo
uso pero no lo tengo, que me lo dé otro al arrancar". O sea, exactamente lo que
el programa le pide al sistema.

Salida real, 16 líneas con columnas:

```
0000000000000000  w   D  *UND*	0000000000000000              _ITM_deregisterTMCloneTable
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) fread
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) fclose
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.4)  __stack_chk_fail
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) __libc_start_main
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) srand
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) ftell
0000000000000000  w   D  *UND*	0000000000000000              __gmon_start__
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) time
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) malloc
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) fseek
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) fopen
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) fwrite
0000000000000000  w   D  *UND*	0000000000000000              _ITM_registerTMCloneTable
0000000000000000      DF *UND*	0000000000000000 (GLIBC_2.2.5) rand
0000000000000000  w   DF *UND*	0000000000000000 (GLIBC_2.2.5) __cxa_finalize
```

Para quedarte solo con los nombres:

```bash
objdump -T encrypt | grep UND | awk '{print $NF}'
```

**De esas dieciséis, seis son maquinaria de arranque** y salen en cualquier
programa de C: `__libc_start_main`, `__cxa_finalize`, `__gmon_start__`, los dos
`_ITM_*` y `__stack_chk_fail` (el canario de pila, una protección del
compilador). Tacharlas.

**Quedan diez, y esas diez son el programa:**

- `fopen` / `fseek` / `ftell` / `fread` / `fclose` → **abre un fichero, mide
  cuánto ocupa y se lo lleva entero a memoria**
- `malloc` → reserva sitio en memoria para eso
- `time` → consulta la hora
- `srand` + `rand` → **genera números pseudoaleatorios**, sembrados con algo
- `fwrite` → escribe un fichero de salida

Ya tenemos la hipótesis antes de ver una sola línea de código: *lee la flag,
genera números al azar a partir de la hora, los mezcla con el contenido y escribe
`flag.enc`*.

Y también la primera preocupación: si la semilla es la hora exacta en que se
ejecutó, **¿cómo vamos a saber qué hora era?**

Guardá esa pregunta. Tiene una respuesta muy bonita.

> **Hábito que conviene tomar:** la lista de funciones importadas es gratis y te
> orienta en treinta segundos. Hacelo siempre antes de meterte en el código.

---

## Paso 4 — Medio paso de teoría: XOR

El algoritmo usa dos operaciones sobre bits. Esta es la primera, y es la más
importante de toda la seguridad informática.

**XOR** (`^` en C y en Python) compara dos bits y responde *"¿son distintos?"*:

| a | b | a ^ b |
|---|---|---|
| 0 | 0 | **0** |
| 0 | 1 | **1** |
| 1 | 0 | **1** |
| 1 | 1 | **0** |

Iguales → 0. Distintos → 1. Con bytes enteros se hace bit por bit:

```
  dato   0100 1000      ('H')
  clave  0011 1010
  ^      ---------
         0111 0010
```

**Y acá está la propiedad que lo hace mágico:** aplicá la misma clave otra vez al
resultado.

```
         0111 0010
  clave  0011 1010
  ^      ---------
         0100 1000      ('H' otra vez)
```

> **XOR es su propio inverso.** Ciframos y desciframos con la misma operación y
> la misma clave. No hay "operación contraria" que buscar.

Probalo:

```bash
python3 -c "print(chr(ord('H') ^ 0x3A ^ 0x3A))"
```

```
H
```

Toda la seguridad de un cifrado XOR está en que la clave sea impredecible. Si la
clave se puede adivinar, el cifrado no vale nada. Acordate de esta frase.

---

## Paso 5 — El descompilador

Acá entra la herramienta nueva de esta guía.

Un **descompilador** agarra el código máquina y te lo devuelve como código C
aproximado. No es el fuente original — los nombres de las variables se perdieron
y la forma no es idéntica — pero **la lógica sí es la misma**. Y leer C es
muchísimo más fácil que leer ensamblador.

El estándar libre es **Ghidra**, hecho por la NSA y publicado gratis en 2019.

### Instalarlo

**En Kali** está en los repositorios:

```bash
sudo apt install ghidra
```

Unos 500 MB de descarga y unos 830 MB en disco. Tomate un café.

**En Ubuntu o Debian** (que es lo que recomienda `EMPEZA_AQUI.md` para empezar)
**no está en los repos**. Hay que bajar el zip oficial del proyecto, desde su
página de *releases* en GitHub — `NationalSecurityAgency/ghidra`, y de ningún
otro sitio. Comprobá el SHA256 que publican antes de descomprimirlo. Necesita
Java 21 o superior (`sudo apt install default-jdk`).

### Abrirlo con ventanas

⚠️ **El comando depende de cómo lo instalaste:**

| cómo lo instalaste | el comando es |
|---|---|
| `apt install ghidra` en Kali | **`ghidra`** |
| zip oficial descomprimido | `./ghidraRun` dentro de esa carpeta |

Si escribís `ghidraRun` en Kali te va a decir `command not found`: el paquete
deja el lanzador en `/usr/share/ghidra/ghidraRun`, sin enlazar. Si te pasa:

```bash
ls /usr/share/ghidra/ghidraRun     # está, pero hay que llamarlo por su ruta
```

Con ventanas: creás un proyecto, arrastrás el binario, decís que sí al análisis
automático, y cuando termina hacés doble clic en `main`. El panel de la derecha
te muestra el C.

> En WSL, la interfaz necesita servidor gráfico (WSLg en Windows 11 lo trae de
> serie; en Windows 10 hay que montarlo). Si no te abre nada, usá la vía de
> abajo, que no necesita pantalla.

### Usarlo sin ventanas

Ghidra también funciona **en la terminal**. Es más rápido, se puede meter en un
script, y si trabajás por SSH es la única opción.

Hace falta un script que recorra las funciones y escriba el C. Está en este mismo
repositorio: [`scripts/DumpDecomp.java`](scripts/DumpDecomp.java). Copialo a una
carpeta propia:

```bash
mkdir -p ~/ghidra_scripts
cp scripts/DumpDecomp.java ~/ghidra_scripts/
```

Y ahora el análisis. **Los dos `mkdir` no son opcionales**: `analyzeHeadless` no
crea el directorio del proyecto y aborta si no existe.

```bash
mkdir -p ~/proyecto
/usr/share/ghidra/support/analyzeHeadless ~/proyecto se -import ./encrypt -scriptPath ~/ghidra_scripts -postScript DumpDecomp.java ~/salida.c -deleteProject
```

Qué es cada cosa:

| trozo | qué es |
|---|---|
| `~/proyecto` | la **carpeta** donde Ghidra guarda su proyecto |
| `se` | el **nombre** del proyecto (inventalo) |
| `-import ./encrypt` | el binario a analizar |
| `-scriptPath` | dónde está tu script |
| `-postScript` | el script a correr al terminar, y su argumento |
| `~/salida.c` | dónde escribe el C — **poné ruta absoluta**, o lo buscarás a ciegas |
| `-deleteProject` | borra el proyecto al salir, para no acumular basura |

Tarda un minuto largo y escupe mucho texto. Al final:

```bash
grep -A 40 "===== main" ~/salida.c
```

### ⚠️ La regla de oro con cualquier herramienta nueva

**Antes de creerle a Ghidra, probala con algo cuya respuesta ya sepas.** Te lo
damos hecho:

```bash
cat > prueba.c <<'FIN'
#include <stdio.h>
int comprobar(int x) { return (x ^ 0x5a) == 1337; }
int main(void) { printf("%d\n", comprobar(42)); return 0; }
FIN
gcc -O0 -o prueba prueba.c
```

Descompilá `prueba` igual que arriba y buscá `comprobar`. Tienen que aparecer
**el `^ 0x5a` y el número 1337** (que Ghidra escribe en hexadecimal: `0x539`). Si
aparecen, el descompilador está diciendo la verdad. Si no, lo que te cuente del
reto tampoco vale.

Esto no es paranoia de más. Es la regla que más tiempo ahorra a largo plazo:

> Desconfiá de tu instrumento antes que del objetivo.
> Una herramienta que no imprime nada está rota hasta que demuestres lo
> contrario.

---

## Paso 6 — Leer el `main`

Esto es lo que te va a devolver el descompilador. Le puse nombres legibles a las
variables y comenté los bloques; la lógica es literal:

```c
undefined8 main(void)
{
  // ---- 1. leer el fichero "flag" entero a memoria ----
  fichero = fopen("flag", "rb");
  fseek(fichero, 0, 2);          // ir al final
  tam = ftell(fichero);          // ¿en qué posición estoy? -> ese es el tamaño
  fseek(fichero, 0, 0);          // volver al principio
  buf = malloc(tam);
  fread(buf, tam, 1, fichero);
  fclose(fichero);

  // ---- 2. sembrar el generador con la hora ----
  semilla = (uint) time(NULL);
  srand(semilla);

  // ---- 3. cifrar byte a byte ----
  for (i = 0; i < tam; i++) {
      buf[i] = buf[i] ^ (byte) rand();          // (a) XOR con un número al azar
      s = rand() & 7;                           // (b) otro al azar, de 0 a 7
      buf[i] = buf[i] << s | buf[i] >> (8 - s); // (c) rotar los bits s lugares
  }

  // ---- 4. escribir flag.enc ----
  salida = fopen("flag.enc", "wb");
  fwrite(&semilla, 1, 4, salida);   // <-- MIRÁ ESTA LÍNEA
  fwrite(buf, 1, tam, salida);
  fclose(salida);
  return 0;
}
```

**Compará lo que te salió a vos con esto.** Si no se parece, algo falló en el
Paso 5 y hay que volver — no sigas con mi copia, que entonces la herramienta no
te sirvió de nada.

### Las palabras raras

Antes de analizarlo, cuatro cosas que no son C normal:

- **`undefined8`** no existe en C: se lo inventa Ghidra para decir *"ocupa 8
  bytes y no sé de qué tipo es"*. Cuando veas `undefined4`, `undefined8`,
  ignoralos.
- **`(uint)` y `(byte)`** son *conversiones de tipo*: "tratá esto como si fuera
  de este otro tipo". **`(byte) rand()` es importante**: `rand()` devuelve un
  número grande y `(byte)` se queda **solo con los 8 bits de abajo**. Por eso en
  el descifrador vas a ver un `& 0xFF`: es la misma operación.
- **`buf`** es un *puntero*: `malloc` no devuelve el sitio, devuelve **la
  dirección** del sitio. `buf[i]` significa "el byte número `i` contando desde
  ahí".
- **`&semilla`** es *la dirección de* la variable. `fwrite` necesita saber de
  dónde copiar los bytes, así que le pasás dónde vive. Los `4` de al lado son su
  tamaño: un entero ocupa 4 bytes.

El truco para leer código descompilado sin marearte: **no intentes entenderlo
todo a la vez**. Buscá primero la forma general — aquí es *abrir, bucle, cerrar*
— y recién después entrá en el bucle.

---

## Paso 7 — Los tres clavos

Todo el reto se sostiene en tres observaciones. Las tres están en el código de
arriba.

### Clavo 1 — La semilla parece imposible de adivinar

```c
semilla = (uint) time(NULL);
srand(semilla);
```

`time(NULL)` devuelve los segundos transcurridos desde el 1 de enero de 1970.
O sea: **el momento exacto en que se ejecutó el programa**, al segundo.

Si no sabemos ese segundo, no sabemos la semilla. Y sin la semilla, los números
"al azar" son imposibles de reproducir.

Parece un muro. Guardalo.

### Clavo 2 — La semilla está dentro del fichero 🤯

```c
fwrite(&semilla, 1, 4, salida);   // escribe 4 bytes: LA SEMILLA
fwrite(buf, 1, tam, salida);      // y después el texto cifrado
```

El programa **guarda la semilla en los primeros cuatro bytes de `flag.enc`**.

Volvé al Paso 1. `flag.enc` eran 32 bytes:

```
5a 35 b1 62 | 00 f5 3e 12 c0 bd ... 27 4b
^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^
 la semilla        28 bytes cifrados
```

Esos cuatro bytes son un número guardado **al revés**: el byte que vale menos va
primero. Se llama *little-endian* y es como guardan los números los procesadores
de PC. Comprobalo:

```bash
python3 -c "print(int.from_bytes(bytes.fromhex('5a35b162'), 'little'))"
```

```
1655780698
```

Y eso, como es un `time()`, es una fecha:

```bash
date -u -d @1655780698
```

```
Tue Jun 21 03:04:58 AM UTC 2022
```

El muro del Clavo 1 no existía. Estaba la puerta al lado.

> **Por qué pasó esto:** el programador necesitaba que el cifrado fuera
> reversible *para él*. Como la semilla era aleatoria, tenía que guardarla en
> algún lado. Y la guardó en el único sitio que tenía a mano: el propio fichero.
>
> Es un fallo de diseño clásico, y ha pasado en ransomware de verdad.

### Clavo 3 — `rand()` no es aleatorio

Y acá está la base de todo lo demás:

> **`rand()` no genera números al azar. Genera siempre la misma secuencia para la
> misma semilla.**

Se llaman *pseudo*aleatorios por eso. `srand(1655780698)` seguido de cinco
`rand()` te da hoy exactamente los mismos cinco números que daba en 2022, en tu
máquina y en la mía.

Comprobalo vos, que es más convincente que creerme:

```bash
python3 -c "
from ctypes import CDLL
libc = CDLL('libc.so.6')
libc.srand(1655780698)
print([libc.rand() & 0xff for _ in range(5)])"
```

Corrélo dos veces. Sale lo mismo. Siempre.

(`libc.so.6` es un fichero de verdad que está en tu disco. `encrypt` lo abre para
usar su `rand()`, y ese Python de ahí arriba abre **el mismo fichero**. Por eso
los números coinciden: no es un parecido, es el mismo código.)

**Los tres clavos juntos:** tenemos la semilla → podemos reproducir la secuencia
exacta de `rand()` → podemos deshacer el cifrado.

---

## Paso 8 — La otra operación: rotar bits

Nos falta entender la línea (c):

```c
buf[i] = buf[i] << s | buf[i] >> (8 - s);
```

Primero, lo básico: **un byte son 8 casillas que valen 0 o 1**. El mismo número
se puede escribir de tres formas, y conviene verlas juntas:

```bash
python3 -c "print(bin(0xD2), hex(0xD2), 0xD2)"
```

```
0b11010010 0xd2 210
```

`1101 0010` (binario) = `0xD2` (hexadecimal) = `210` (decimal). Son el mismo
byte.

Eso de arriba es una **rotación de bits a la izquierda**: correrlos todos hacia
la izquierda, y **los que se caen por un lado vuelven a entrar por el otro**.

Con `s = 3` y el byte `1101 0010`:

```
original     1101 0010
             ^^^
             estos tres se caen por la izquierda...
                            ...y vuelven a entrar por la derecha

resultado    1001 0110
             ^^^^^ ^^^
             los que quedaban   los que dieron la vuelta
```

Las dos mitades de la fórmula:

- `buf[i] << s` → corre los bits a la izquierda (los de arriba se pierden)
- `buf[i] >> (8 - s)` → recupera justo esos y los pone abajo
- `|` → las junta

Es un giro, no un desplazamiento. **No se pierde ningún bit**, solo cambian de
sitio. Por eso se puede deshacer. (Un desplazamiento a secas tira los bits a la
basura, y lo que se perdió no vuelve.)

### Por qué `& 7`

`rand()` devuelve un número enorme, y rotar 500 lugares no tiene sentido. El
`& 7` lo recorta. Mirá el 7 en binario:

```
  numerote  ???? ????
  7         0000 0111
  &         ---------
            0000 0???     <- solo sobreviven los 3 bits de abajo
```

Un `&` con 7 deja pasar únicamente los tres últimos bits, o sea un número de
**0 a 7**. Rotar 8 sería dar la vuelta entera y quedar igual, así que el rango es
justo el correcto.

Lo mismo hace `& 0xFF` (`1111 1111`): deja pasar 8 bits, o sea un byte.

> **Caso borde que conviene mirar:** si `s` vale 0, la segunda mitad es
> `buf[i] >> 8`, que en un byte da 0. Resultado: el byte no cambia. La fórmula
> aguanta el 0 sin romperse — y pasa de verdad: ocurre 4 veces en el `flag.enc`
> de este reto.

---

## Paso 9 — Dar la vuelta

El cifrado hace, en este orden:

```
1. XOR con rand1
2. rotar a la IZQUIERDA s lugares
```

Para deshacerlo se recorre al revés, **y cada operación se cambia por su
contraria**:

```
1. rotar a la DERECHA s lugares
2. XOR con rand1          (el XOR es su propio inverso, Paso 4)
```

### ⚠️ El detalle donde se cae casi todo el mundo

Las **operaciones** se invierten. Las **llamadas a `rand()` no**.

En cada vuelta del bucle, el cifrador pide dos números: primero el del XOR,
después el de la rotación. Vos tenés que pedirlos **en ese mismo orden**, porque
`rand()` va devolviendo su secuencia hacia adelante y no sabe retroceder.

O sea, por cada byte:

```python
r1 = rand() & 0xff   # primero el del XOR       (igual que el cifrador)
s  = rand() & 7      # después el de la rotación (igual que el cifrador)

b = rotar_derecha(b, s)   # pero las operaciones, al revés
b = b ^ r1
```

Pedís en el mismo orden, aplicás en orden contrario. Si invertís también las
llamadas, te sale basura y vas a pensar que entendiste mal el algoritmo cuando en
realidad entendiste mal el generador.

---

## Paso 10 — El `rand()` auténtico

Falta una pieza: necesitamos **el mismo `rand()`** que usó el programa, no uno
parecido. El `random` de Python es un algoritmo completamente distinto y da otros
números.

Dos caminos:

1. **Reimplementar el generador de glibc.** Se puede — está documentado — pero es
   trabajo y es fácil equivocarse en un detalle.
2. **Llamar a la libc de verdad**, con el módulo `ctypes`.

La segunda es tres líneas y es exacta:

```python
from ctypes import CDLL
libc = CDLL("libc.so.6")
libc.srand(semilla)
libc.rand()
```

Estás llamando literalmente al mismo código que llamó el cifrador.

> **Truco para guardar:** siempre que tengas que reproducir el `rand()` de un
> programa en C, usá `ctypes` antes de ponerte a reimplementar nada.

---

## Paso 11 — El descifrador

Guardalo como `solve.py` **en la misma carpeta que `flag.enc`**:

```python
#!/usr/bin/env python3
import struct, sys
from ctypes import CDLL

def rotar_derecha(b, s):
    s &= 7
    return ((b >> s) | (b << (8 - s))) & 0xFF

datos   = open(sys.argv[1] if len(sys.argv) > 1 else "flag.enc", "rb").read()
semilla = struct.unpack("<I", datos[:4])[0]   # "<I" = entero de 4 bytes, little-endian
cifrado = datos[4:]

libc = CDLL("libc.so.6")
libc.srand(semilla)

claro = bytearray()
for b in cifrado:
    r1 = libc.rand() & 0xFF    # el del XOR        (mismo orden que el cifrador)
    s  = libc.rand() & 7       # el de la rotación
    claro.append(rotar_derecha(b, s) ^ r1)

print(claro.decode())
```

```bash
python3 solve.py flag.enc
```

```
HTB{vRy_s1MplE_...}
```

(Censurada a propósito. Sacala vos, que para eso está la guía.)

---

## Paso 12 — Dos comprobaciones, no una

Tenés la flag. **No cierres la terminal todavía.**

Que salga un texto legible es buena señal, pero no demuestra que entendiste el
algoritmo: podrías haber acertado por un camino raro.

### Comprobación 1 — fabricate tu propio caso

El cifrador está en tus manos. Usalo:

```bash
mkdir prueba && cd prueba
cp ../encrypt .
printf 'HTB{prueba_mia}' > flag
./encrypt
python3 ../solve.py flag.enc
```

```
HTB{prueba_mia}
```

Acabás de cifrar algo cuyo contenido ya sabías y recuperarlo. Si esto sale, tu
descifrador funciona de verdad — no "funcionó una vez".

### Comprobación 2 — el camino de ida

Y la definitiva: agarrá la flag que recuperaste, **ciframela vos** con la misma
semilla, y mirá si te sale el `flag.enc` original byte a byte. Guardalo como
`verificar.py`:

```python
#!/usr/bin/env python3
import struct, sys
from ctypes import CDLL

orig    = open("flag.enc", "rb").read()
semilla = struct.unpack("<I", orig[:4])[0]
claro   = sys.argv[1].encode()          # la flag que te salió en el Paso 11

libc = CDLL("libc.so.6")
libc.srand(semilla)

out = bytearray()
for b in claro:
    b ^= libc.rand() & 0xFF
    s = libc.rand() & 7
    out.append(((b << s) | (b >> (8 - s))) & 0xFF)

rehecho = struct.pack("<I", semilla) + bytes(out)
print("original:", orig.hex())
print("rehecho :", rehecho.hex())
print("IDENTICOS" if rehecho == orig else "NO COINCIDE")
```

```bash
python3 verificar.py 'HTB{la_que_te_salio}'
```

```
IDENTICOS
```

Eso sí es prueba. Si los 32 bytes coinciden exactamente, tu modelo del programa
es correcto — no aproximado: correcto.

Es la misma regla que usamos cuando buscamos fallos de verdad en software real:
**un hallazgo no existe hasta que lo reproducís de forma independiente.** Acá te
cuesta treinta segundos y te acostumbra al reflejo.

---

## Lo que te llevás

Lo que importa de este reto no es la flag.

1. **`strings` encuentra lo escrito, no lo calculado.** Cuando el programa
   *genera* el dato, hay que leer el código.
2. **La lista de funciones importadas te da la forma del programa en treinta
   segundos** — y la mitad de lo que sale es ruido de la libc que hay que
   aprender a tachar.
3. **Un descompilador convierte un muro de ensamblador en C legible.** No es el
   fuente original, pero la lógica es fiel.
4. **XOR es su propio inverso**, y toda su seguridad está en que la clave sea
   impredecible.
5. **`rand()` no es azar.** Misma semilla, misma secuencia, para siempre y en
   cualquier máquina.
6. **Si el cifrado guarda su propia semilla, no es cifrado.** Es ofuscación con
   la llave pegada en la puerta.
7. **Para invertir una cadena de operaciones**: recorrer al revés y cambiar cada
   operación por su contraria — pero **el generador se consume hacia adelante**.
8. **Comprobalo dos veces**: con un caso que fabricaste vos, y re-cifrando. Eso
   separa "me salió" de "lo entendí".

El punto 6 es el que más vale fuera del CTF. Ese error existe en productos reales
que la gente compra.

---

## Preguntas que te pueden hacer

Si algún día contás este reto en una entrevista, o se lo explicás a alguien del
grupo, estas son las preguntas que vienen. Respondelas en voz alta antes de
seguir.

**— ¿Por qué `strings` no encontró la flag?**
Porque la flag nunca estuvo dentro del binario. El programa la leyó de un fichero
externo en tiempo de ejecución. `strings` solo ve constantes guardadas dentro del
ejecutable.

**— El programa siembra con `time(NULL)`. ¿Cómo sabés qué hora era?**
No hace falta saberlo: el programa escribe la semilla en los primeros cuatro
bytes del fichero de salida. Está servida.

**— Suponé que NO la hubiera guardado. ¿Estarías perdido?**
No necesariamente. `time(NULL)` son segundos, así que si sabés aproximadamente
cuándo se ejecutó, el espacio de búsqueda es chico: un día son 86.400 semillas, y
se prueban todas en un momento. El criterio para saber cuál es la buena: que el
resultado empiece por `HTB{`. Eso se llama *ataque de semilla débil* y es un
clásico real.

**— ¿Por qué `ctypes` y no el `random` de Python?**
Porque son generadores distintos. Python usa Mersenne Twister; glibc usa un
generador aditivo con retroalimentación. Misma semilla, números completamente
distintos. `ctypes` llama al mismo código que usó el binario, así que coincide
por construcción.

**— ¿Por qué una rotación se puede deshacer y un desplazamiento no?**
Porque la rotación no pierde información: los bits que salen por un extremo
entran por el otro. Un desplazamiento los tira a la basura, y lo que se perdió no
se recupera.

**— ¿Por qué invertís las operaciones pero no las llamadas a `rand()`?**
Porque `rand()` es una secuencia que solo avanza. Hay que consumirla en el mismo
orden que el cifrador; lo que se invierte es el orden en que *aplicás* las
operaciones, no el orden en que *pedís* los números.

**— ¿Cómo arreglarías este programa?**
Con criptografía de verdad: una función de derivación de clave a partir de una
contraseña (Argon2, PBKDF2), un cifrado autenticado tipo AES-GCM o
ChaCha20-Poly1305, y un *nonce* aleatorio. El nonce sí puede ir en el fichero —
no es secreto. Lo que nunca puede ir en el fichero es **el material del que sale
la clave**, y eso es exactamente lo que hacía este.

---

## Errores comunes

**"`ghidraRun: command not found`."**
En Kali el comando es `ghidra`, sin el `Run`. Ver el Paso 5.

**"`Directory not found: /home/.../proyecto`."**
`analyzeHeadless` no crea la carpeta del proyecto. `mkdir -p ~/proyecto` primero.

**"`SCRIPT ERROR: DumpDecomp.java : Script not found`."**
El script no está en la carpeta que le pasaste con `-scriptPath`. Copialo desde
[`scripts/DumpDecomp.java`](scripts/DumpDecomp.java) a `~/ghidra_scripts/`.

**"No encuentro el `salida.c`."**
Pasale ruta absoluta (`~/salida.c`), no un nombre suelto.

**"Me sale basura ilegible."**
Revisá el orden. Lo más probable es que estés rotando a la izquierda en vez de a
la derecha, o aplicando el XOR antes de la rotación.

**"Los primeros caracteres salen bien y después se rompe."**
Clásico de pedir los `rand()` en orden equivocado: si invertiste también las
llamadas, desincronizás el generador y todo lo que sigue se corrompe.

**"Uso `random.randint` de Python y no funciona."**
No es el mismo generador. Hay que usar el de la libc con `ctypes`.

**"Intenté descifrar los 32 bytes enteros."**
Los primeros cuatro son la semilla, no texto cifrado. El mensaje son 28 bytes y
empieza en la posición 4.

**"`solve.py` me dice que no encuentra `flag.enc`."**
El script lo busca en la carpeta desde la que lo ejecutás. O te ponés en la
carpeta del reto, o le pasás la ruta: `python3 solve.py /ruta/al/flag.enc`.

**"`CDLL('libc.so.6')` no encuentra la librería."**
Estás en macOS, donde se llama `libc.dylib`. Dentro de WSL, `libc.so.6` funciona
sin tocar nada — es Linux de verdad.

---

## Si te atascaste

En orden, y parando en cuanto se destrabe:

1. Volvé a leer el `main` descompilado y buscá a mano **dónde se escribe la
   semilla**. Está en una sola línea.
2. Imprimí los primeros cinco `rand()` con la semilla del fichero. Si no te salen
   siempre iguales, el problema está ahí y no en el descifrado.
3. Hacé primero la **Comprobación 1** del Paso 12, con tu propio `flag`. Si esa
   falla, el problema es tu script y no el fichero del reto.
4. Probá tu descifrador **con un solo byte** y mirá si el primero te da `H`.
   Depurar un byte es mucho más fácil que depurar veintiocho.
5. Si el primero da `H` y el segundo no, es el orden de los `rand()`.

Y si sigue sin salir, preguntá en el canal. Para eso está.

---

## El siguiente escalón

Este reto tenía la llave dentro del fichero. El paso natural es un binario donde
**no** esté: donde la comprobación se haga dentro del programa y haya que seguir
la lógica hasta el final, o directamente invertir una transformación sin que
nadie te regale la semilla.

Ahí es donde el descompilador deja de ser una comodidad y pasa a ser la
herramienta principal.

---

> **Recordatorio de siempre:** esto se practica contra tu propio laboratorio,
> HackTheBox, o algo con permiso escrito. Si encontrás un fallo así en software
> real, no se publica: se reporta y se espera el parche.
