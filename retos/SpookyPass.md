# 👻 SpookyPass — tu primer reto de ingeniería inversa

> **HackTheBox · Reversing · Very Easy**
> Es el reto más resuelto de toda la lista de Very Easy: 29.000 personas antes
> que vos. No es casualidad — es el que todo el mundo usa para empezar.
>
> Si venís de OpenSecret y Bobby's Bistro: esos eran web. Este **no**. Aquí no
> hay servidor, no hay peticiones, no hay cookies. Hay un archivo y vos.

---

## Antes de empezar

**Ingeniería inversa** es agarrar un programa ya compilado —sin su código
fuente— y averiguar qué hace por dentro. El programa es un montón de bytes que
la máquina entiende y vos no. El trabajo es hacerlo hablar.

Sirve para mucho más que los CTF: es exactamente lo que hicimos con el
instalador falso de Roblox para saber qué le había pasado al PC de un amigo.
La diferencia es que ahí el binario era hostil de verdad.

> ⚠️ Todo esto se practica contra **tu laboratorio, HackTheBox, o algo con
> permiso escrito**. Nada más.

**Lo que necesitás:** una terminal Linux (WSL con Kali sirve). Nada más.

---

## Paso 0 — Bajar y abrir

En la página del reto, `Download Files`. Te baja un `.zip`.

**La contraseña de todos los zip de HackTheBox es `hackthebox`.** Está así a
propósito: el archivo va cifrado para que tu antivirus no lo abra ni lo borre
mientras lo descargás. En los retos de malware eso importa de verdad.

```bash
unzip -P hackthebox a12c739e-dddf-43d7-bbf0-c4389ea79b09.zip
cd rev_spookypass
ls -l
```

Un solo archivo: `pass`, unos 16 KB.

---

## Paso 1 — ¿Qué es esto?

**Nunca** empieces por ejecutar. Empezá por preguntar qué es.

```bash
file pass
```

```
pass: ELF 64-bit LSB pie executable, x86-64, dynamically linked,
      interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=3008...,
      for GNU/Linux 4.4.0, not stripped
```

Traducido, palabra por palabra:

| Lo que dice | Lo que significa |
|---|---|
| `ELF` | Ejecutable de Linux (el `.exe` de Windows sería `PE`) |
| `64-bit x86-64` | Para procesadores modernos de 64 bits |
| `dynamically linked` | Usa librerías del sistema, no las lleva dentro |
| **`not stripped`** | **Conserva los nombres de sus funciones y variables** |

Ese último es un regalo. `stripped` significa que borraron los nombres y solo
quedan direcciones de memoria. `not stripped` significa que el programa te va
a decir cómo se llama cada cosa. Guardate el dato: lo vamos a usar al final.

---

## Paso 2 — La regla que te va a salvar algún día

Tenés un ejecutable ajeno delante. La tentación es hacer doble clic.

**No.**

En un CTF el binario es inofensivo. Fuera del CTF, el archivo que estás
analizando es justo el que alguien mandó para hacer daño — y ejecutarlo es
exactamente lo que quiere. La costumbre correcta se agarra ahora, con el
inofensivo, no después con el que importa.

El orden es: **mirar por fuera → mirar por dentro → y solo entonces, quizá,
ejecutar** (y en una máquina que no te importe perder).

Vamos a sacar la flag de este reto **sin ejecutarlo**. Se puede.

---

## Paso 3 — `strings`: el 80% de los rev fáciles

Un ejecutable no es solo instrucciones: también lleva los textos que imprime.
"Error", "Bienvenido", rutas, URLs. `strings` los saca todos.

```bash
strings pass
```

Sale bastante. Filtremos a lo humano — cadenas de 6 caracteres o más:

```bash
strings -n 6 pass
```

Y entre el ruido, esto:

```
Welcome to the
SPOOKIEST
 party of the year.
Before we let you in, you'll need to give us the password:
s3cr3t_p455_f0r_gh05t5_4nd_gh0ul5
Welcome inside!
You're not a real ghost; clear off!
```

Leelo en orden. `strings` respeta el orden en que las cosas están guardadas en
el archivo, y el compilador las guardó en el orden en que aparecen en el
código. Entonces:

```
    "…give us the password:"               ← lo que te pregunta
    "s3cr3t_p455_f0r_gh05t5_4nd_gh0ul5"    ← 👀
    "Welcome inside!"                      ← lo que dice si acertás
    "You're not a real ghost…"             ← lo que dice si fallás
```

La contraseña está **físicamente entre la pregunta y la respuesta correcta**.
No hace falta adivinar cuál de todas es: la posición te lo dice.

---

## Paso 4 — Comprobarlo

Ahora sí, ejecutamos — sabiendo ya qué hace y que no toca nada del sistema.

Y lo hacemos **con dos pruebas, no con una**:

```bash
chmod +x pass
```

```bash
echo "cualquier_cosa" | ./pass
```

```bash
echo 's3cr3t_p455_f0r_gh05t5_4nd_gh0ul5' | ./pass
```

```
You're not a real ghost; clear off!      ← el malo falla
...
Welcome inside!                          ← el bueno entra
HTB{...}
```

**Por qué las dos.** Si solo probás la buena y sale la flag, no sabés si la
contraseña era correcta o si el programa le da la flag a cualquiera. Probando
las dos y viendo que **responden distinto**, ya sabés que estás midiendo algo
real. Esto no es manía de CTF: es la diferencia entre comprobar y creer.

---

## Interludio — ¿Y si `strings` no hubiera cantado?

Porque muchas veces no canta. Segunda herramienta, y es preciosa:

```bash
echo "xxx" | ltrace ./pass
```

`ltrace` te muestra **cada llamada a librería** que hace el programa, con sus
argumentos de verdad, mientras corre:

```
puts("Welcome to the \033[1;3mSPOOKIEST\033["...)
printf("Before we let you in, you'll nee"...)
fgets("xxx\n", 128, 0x74bab7cb28e0)
strchr("xxx\n", '\n')
strcmp("xxx", "s3cr3t_p455_f0r_gh05t5_4nd_gh0ul"...)   ← 🎯
puts("You're not a real ghost; clear o"...)
```

Mirá la línea de `strcmp`. `strcmp` compara dos textos. El programa te está
enseñando, en vivo, **contra qué está comparando lo que escribiste**.

Ahí ya no importa cuántas cadenas tenga el binario ni en qué orden: el
programa mismo te señala cuál es la buena, porque tiene que usarla para
comparar. No puede esconderla en el momento de usarla.

También leé las otras líneas, que cuentan el programa entero:
`fgets` (lee 128 bytes de tu teclado) → `strchr` (busca el `\n` para cortarlo)
→ `strcmp` (compara) → `puts` (imprime el resultado). Eso es todo el programa.

---

## Paso 5 — El misterio: la flag NO está en `strings`

Volvé arriba y mirá la lista de cadenas otra vez. Está la contraseña, están
los mensajes… **y la flag no está.** Comprobalo:

```bash
strings pass | grep -i htb
```

```
(nada)
```

Pero la flag salió cuando ejecutamos el programa. Entonces **está ahí dentro**.
¿Por qué no la ve `strings`?

Detengámonos, porque esta es la lección grande del reto.

`strings` busca **rachas de bytes imprimibles seguidos**. Si encuentra 4 o más
caracteres legibles pegados, lo considera texto. Es una heurística, no magia.

Miremos qué hay de verdad en la zona de datos del programa:

```bash
objdump -s -j .data pass
```

```
 4060 48000000 54000000 42000000 7b000000  H...T...B...{...
 4070 75000000 6e000000 30000000 62000000  u...n...0...b...
 4080 66000000 75000000 35000000 63000000  f...u...5...c...
```

Ahí está la flag. `48` es `'H'`, `54` es `'T'`, `42` es `'B'`, `7b` es `'{'`…

Pero mirá **los ceros**. Cada letra ocupa **4 bytes**: la letra y tres bytes
nulos. `H\0\0\0 T\0\0\0 B\0\0\0`. No hay ni una sola racha de dos caracteres
imprimibles seguidos. Para `strings`, ahí no hay texto — hay basura.

El programador guardó la flag como un array de **enteros de 32 bits** en vez
de caracteres de 8. No es cifrado, no es ofuscación de verdad: es solo un tipo
de dato distinto. Y con eso ya se cae la herramienta.

---

## Paso 6 — La lección

`strings` no dijo *"la flag no está"*. Dijo *"no encontré nada con la pregunta
que me hiciste"*. Son cosas distintas, y confundirlas es el error más caro que
podés cometer en esto.

La pregunta correcta era: *¿y si el texto no está en bytes de 8 bits?*
`strings` ya sabe hacer eso. Se lo tenés que pedir:

```bash
strings -e L pass
```

```
HTB{un0bfu5c4t3d_...}
```

Ahí está. **Mismo archivo, misma herramienta, un parámetro de diferencia.**

`-e` es la codificación. `-e s` (por defecto) = 8 bits. `-e L` = 32 bits
little-endian, justo como estaba guardada. Lo tenía delante todo el tiempo.

Y cuando la leas entera, fijate en lo que dice: la flag se llama a sí misma
*"cadenas sin ofuscar"*. El reto lleva su propia lección en el nombre. No
estaban ofuscadas; solo estaban guardadas de otra forma.

> **Llevate esto de acá:** cuando una herramienta no encuentra algo, tenés dos
> hipótesis — *no está* o *no sé buscarlo*. La segunda es casi siempre la
> correcta, y es la única que podés arreglar.

---

## Paso 7 — Sacarla a mano (sin ejecutar nada)

Por si querés entenderlo del todo, sin depender de que `strings` tenga la
opción justa. La sacamos leyendo bytes:

```bash
python3 -c "
import struct
d = open('pass','rb').read()
off = 0x3060
print(''.join(chr(struct.unpack('<I', d[off+4*i : off+4*i+4])[0]) for i in range(26)))
"
```

```
HTB{un0bfu5c4t3d_...}
```

¿De dónde salió `0x3060` y el `26`? De preguntarle al binario, que —acordate—
es `not stripped` y conserva los nombres:

```bash
nm pass | grep -i parts
```

```
0000000000004060 D parts
```

```bash
readelf -s pass | grep -i parts
```

```
16: 0000000000004060   104 OBJECT  GLOBAL DEFAULT  24 parts
```

Una variable global llamada `parts` ("partes"), de **104 bytes**, en la
dirección `0x4060`. Y 104 ÷ 4 = **26 caracteres**. Que son exactamente los que
mide `HTB{un0bfu5c4t3d_...}` contando el cierre.

El nombre de la variable ya te estaba diciendo qué era. Eso es lo que te
regala un binario `not stripped`.

---

## Bonus — Verlo en el ensamblador

Si querés ver el bucle que arma la flag, letra por letra:

```bash
objdump -d -M intel --no-show-raw-insn pass | sed -n '/<main>:/,/^$/p'
```

Las dos partes que importan:

```asm
124d:   mov    rdi,rax
1250:   call   1080 <strcmp@plt>            ; compara lo que escribiste
1255:   test   eax,eax                      ; ¿dio 0? (0 = iguales)
1257:   jne    12c2 <main+0x139>            ; si NO, saltá al mensaje de error
```

```asm
1284:   lea    rax,[rip+0x2dd5]             ; 4060 <parts>  ← nuestra variable
128b:   mov    eax,DWORD PTR [rdx+rax*1]    ; lee parts[i] como 4 bytes
1298:   mov    BYTE PTR [rbp+rax*1-0xb0],dl ; guarda SOLO el byte bajo
129f:   add    DWORD PTR [rbp-0xbc],0x1     ; i++
12ac:   cmp    eax,0x19                     ; ¿i <= 25?
12af:   jbe    1274 <main+0xeb>             ; si sí, repetí
```

Leelo despacio: lee 4 bytes, se queda **solo con el más bajo** (`dl`), lo
pone en un buffer, y repite 26 veces (`0x19` = 25, de 0 a 25). Al final hace
`puts` de ese buffer.

Eso es, exactamente, convertir el array de enteros en texto. El programa hace
en tiempo de ejecución lo mismo que nosotros hicimos con Python.

---

## Lo que te llevás

| Comando | Para qué |
|---|---|
| `file X` | Qué tipo de archivo es, antes de tocarlo |
| `strings X` | Textos legibles (8 bits) |
| `strings -e L X` | Textos guardados como caracteres anchos |
| `ltrace ./X` | Qué llamadas hace y **con qué argumentos**, en vivo |
| `nm X` / `readelf -s X` | Nombres y tamaños de variables y funciones |
| `objdump -s -j .data X` | Los datos en crudo, en hexadecimal |
| `objdump -d -M intel X` | El código en ensamblador |

Y tres ideas que valen más que los comandos:

1. **Mirar antes de ejecutar.** Siempre. La costumbre se agarra con el
   binario inofensivo.
2. **Dos controles, no uno.** Si no probaste algo que *tiene* que fallar, no
   sabés si tu prueba mide algo.
3. **"No encontré" ≠ "no está".** Casi siempre es la herramienta, o la
   pregunta.

---

## Preguntas que te pueden hacer

**¿Qué diferencia hay entre análisis estático y dinámico?**
Estático es mirar el archivo sin ejecutarlo (`strings`, `objdump`, `nm`).
Dinámico es verlo correr (`ltrace`, `gdb`). Estático es seguro pero se pierde
lo que se genera en ejecución; dinámico ve todo eso pero tenés que ejecutar
código ajeno. Aquí usamos estático para todo, y el dinámico solo para confirmar.

**¿Por qué `strings` no encontró la flag?**
Porque busca rachas de bytes imprimibles seguidos, y la flag estaba guardada
como enteros de 32 bits: cada letra iba con tres bytes nulos detrás. Se
resuelve con `strings -e L`.

**¿Qué significa que un binario esté `stripped`?**
Que le quitaron la tabla de símbolos: los nombres de funciones y variables.
Este no lo estaba, y por eso pudimos encontrar `parts` por su nombre. Uno
`stripped` es bastante más trabajo.

**Si esto fuera malware de verdad, ¿harías lo mismo?**
El análisis estático sí, igual. Ejecutarlo, no: iría en una máquina virtual
aislada, sin red, con un punto de restauración — o directamente no lo ejecuto.

**¿Guardar la contraseña dentro del programa es seguro?**
No, nunca. Cualquier cosa que le entregues al usuario —binario, app de móvil,
JavaScript— la puede leer. Es la misma frontera de confianza de los retos web:
lo que corre en la máquina del otro deja de ser secreto. Compilar no es cifrar.

---

## Errores comunes

- **Ejecutar primero.** Sale bien en el CTF y te sale carísimo el día que no
  es un CTF.
- **Probar solo la contraseña buena.** Sin el control negativo no sabés si
  acertaste o si el programa regala la flag.
- **Leer `strings` salteado.** El orden importa: la contraseña estaba justo
  entre la pregunta y la respuesta correcta.
- **Creerle a la herramienta cuando dice que no hay nada.** Ese fue el reto
  entero.
- **Olvidar `chmod +x`.** Si te dice `Permission denied`, es eso.

---

## Si te atascaste

<details>
<summary>La contraseña (clic para ver)</summary>

`s3cr3t_p455_f0r_gh05t5_4nd_gh0ul5`

</details>

<details>
<summary>La flag — no está aquí, y es a propósito</summary>

La flag no va en esta guía. Es la única parte que no enseña nada: es la
respuesta del examen.

Tenés **tres** caminos distintos para sacarla, y los tres están explicados
arriba con el comando exacto:

1. `strings -e L pass` — un comando.
2. El one-liner de Python del Paso 7 — sin ejecutar el binario.
3. Ejecutarlo con la contraseña del Paso 3.

Si los tres te dan lo mismo, es la buena. Empieza por `HTB{un0bfu5c4t3d_` —
con eso sabés que vas bien.

Y si llegaste hasta aquí sin ejecutar el binario ni una vez, lo hiciste mejor
que la mayoría.

</details>

---

*Guía del arsenal de la comunidad. Practicá solo contra objetivos autorizados.*
