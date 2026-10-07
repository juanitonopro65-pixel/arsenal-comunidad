# 🎯 Clase del miércoles — Ataque y defensa en vivo sobre Overwall

> **Formato:** Juancho y Kaiju atacan. Ciel defiende. Juan arbitra.
> **Objetivo real:** que vean que un fallo encontrado no es lo mismo que un
> fallo **explotado**, y que un fallo tapado no es lo mismo que un fallo
> **tapado bien**.

---

## 0. Antes de nada: por dónde llegan a la máquina

La Máquina de Overwall tiene **cinco agujeros a propósito** y una contraseña en
claro dentro de un fichero. Eso obliga a una decisión y solo hay una respuesta
correcta:

| opción | veredicto |
|---|---|
| Exponerla a internet con port-forwarding | ❌ **No.** Es poner una máquina rota en la red pública. Lo encuentra un escáner automático antes que Juancho |
| Que cada uno la corra en su PC | ⚠️ Vale para practicar, pero **no hay ejercicio**: no hay nadie defendiendo |
| **Red privada entre los tres** (Tailscale / ZeroTier) | ✅ **Esto.** Gratis, diez minutos, y la máquina solo existe para quien invitás |

Con la red privada, la máquina corre en el equipo de Juan y los demás la ven con
una dirección que solo funciona dentro de esa red. Nadie más llega.

**Lo que hace falta antes de empezar:** los tres instalan el cliente, Juan los
invita a su red, y se comprueba que `ping` llega. Eso se hace **antes** de la
clase, no durante.

---

## 1. Los papeles

| quién | papel | qué recibe |
|---|---|---|
| **Juancho y Kaiju** | atacan | la dirección IP. **Nada más.** |
| **Ciel** | defiende | la cuenta `admin` y su contraseña |
| **Juan** | arbitra | todo, y decide cuándo se sube de nivel |

Los atacantes **no leen** [Defend Overal](../../laboratorios/Defend_Overal.md) ni
el guion de construcción de la máquina. Su guía es
[Attack Overal](../../laboratorios/Attack_Overal.md).

---

## 2. Las reglas del que defiende

Esto es lo más importante del diseño, y es lo que hace que la clase enseñe algo.

> **Un defensor sin reglas siempre gana.** Puede apagar el servicio web, cerrar
> el SSH y poner un cortafuegos que lo bloquee todo. Gana, no entra nadie, y
> nadie aprende nada. Por eso el defensor juega con un **repertorio declarado**.

### Los cuatro niveles de Ciel

Se empieza en el 0 y **solo se sube cuando los atacantes agotan el nivel actual**.

| nivel | qué hace el defensor |
|---|---|
| **0 — ciego** | nada. Solo observa y narra lo que ve llegar |
| **1 — contención** | corta ráfagas de fuerza bruta (bloqueo por IP tras N fallos). **No tapa ningún fallo** |
| **2 — parche dirigido** | tapa **un solo** fallo: el que ya explotaron y supieron explicar. Hay que volver a entrar por otro sitio |
| **3 — defensa completa** | tapa los cinco. Esta es la ronda final |

### Lo que el defensor NO puede hacer, nunca

- apagar el servicio web o el SSH — eso es cerrar la tienda, no defenderla
- mover la bandera de sitio o cambiarle el contenido
- cambiar contraseñas en mitad de una ronda
- bloquear la red entera de los atacantes
- tapar un fallo **antes** de que lo encuentren

Esa última es la que convierte el ejercicio en una clase: **el defensor va
siempre un paso por detrás**, igual que en la vida real.

### Sobre "déjate hackear"

No hace falta fingir. La regla del repertorio ya lo resuelve: si los atacantes
están yendo bien, **el defensor no sube de nivel**. No pierde a propósito —
simplemente deja de añadir defensas nuevas mientras ellos trabajan en lo que ya
hay delante.

Fingir un fallo sería lo peor que podríamos hacer, porque entonces lo que
aprenden es falso.

---

## 3. El guion de la clase

```
 0:00  Preparación
       - red privada arriba, los tres hacen ping a la máquina
       - Ciel arranca la vigilancia y dice "foto tomada, vigilando"
       - a los atacantes solo se les da la IP

 0:05  RONDA 1 — reconocimiento (nivel 0)
       - puertos, servicios, qué responde cada uno
       - Ciel narra en voz alta lo que ve llegar, SIN decir si van bien
       - acaba cuando tengan el mapa completo de la superficie

 0:25  RONDA 2 — entrar (nivel 0 -> 1)
       - objetivo: ejecutar algo en la máquina
       - si tiran fuerza bruta, Ciel sube a nivel 1 y los bloquea
       - ahí aprenden por qué el ruido se paga

 0:55  Parada técnica (10 min)
       - cada atacante cuenta QUÉ DESCARTÓ, no qué encontró
       - Ciel enseña su panel: qué vio, a qué hora, qué lo delató
       - esta parada es la mitad del valor de la clase

 1:05  RONDA 3 — escalar a root (nivel 1 -> 2)
       - objetivo: leer /root/flag.txt
       - cuando lo consigan y sepan EXPLICARLO, Ciel tapa ese camino
       - hay que volver a entrar por otro. Hay tres

 1:35  RONDA 4 — la máquina defendida (nivel 3)
       - Ciel tapa los cinco fallos delante de ellos, explicando cada uno
       - los atacantes lo intentan otra vez
       - lo que TODAVÍA funcione es trabajo mal hecho de la defensa

 1:55  Cierre
       - los tres escriben: atacantes su camino, defensor su detección
       - se comparan los dos relatos de los mismos hechos
```

Ese último punto es el que más sorprende: el atacante cree que entró a las 17:42
y el registro del defensor dice 17:39. **Los dos relatos nunca cuadran**, y
entender por qué es media carrera.

---

## 4. Lo que ve el defensor

Ciel vigila cuatro cosas, y solo cuatro, con una herramienta que da una línea por
evento:

```
[SSH] sshd: Failed password for operador from 10.0.2.2
[SSH] sshd: Invalid user pepito from 10.0.2.2
[SSH] sshd: Accepted password for operador from 10.0.2.2     <- ENTRARON
[INYECCION] "GET /?host=9.9.9.9%3Bwhoami HTTP/1.1" 200
[PERM CAMBIO] < -rwxrwxrwx 63 /opt/respaldo.sh  > -rwxrwxrwx 68 /opt/respaldo.sh
```

Dos cosas de esa herramienta que valen como lección por sí solas:

**El que vigila es la primera fuente de ruido de su propia vigilancia.** La
primera versión abría seis conexiones por ciclo, y como cada entrada queda
registrada, mis propias conexiones **expulsaban del registro los eventos del
atacante**. De 104 eventos, 104 eran míos. Se arregló con una sola conexión por
ciclo y descartando al propio usuario.

**El estado se compara contra una foto, no contra una lista de cosas malas.** No
se vigila "que pase algo malo" —eso solo encuentra lo que ya sabés— sino que la
máquina **deje de parecerse a como la dejaste**. Así se detecta también lo que no
previste.

---

## 5. Cómo se puntúa

No por quién llega antes. Por esto:

**Atacantes**

| punto | se gana cuando |
|---|---|
| encontrar | señalás el fallo |
| **explotar** | lo usás de verdad y mostrás la salida |
| **explicar** | decís por qué funciona, sin leer la guía |
| **reproducir** | el otro lo repite leyendo **solo tu escrito** |

Los dos últimos valen el doble. Encontrar sin explicar no es un hallazgo: es una
corazonada con suerte.

**Defensor**

| punto | se gana cuando |
|---|---|
| detectar | viste el intento mientras pasaba |
| **atribuir** | sabés qué fallo usaron y por dónde |
| tapar | el arreglo aguanta el segundo intento |
| **no romper** | la máquina sigue funcionando después del arreglo |

Ese último es el que más gente suspende en la vida real: se arregla el agujero y
se rompe el servicio.

---

## 6. Deberes para después

Cada uno escribe lo suyo **antes de leer lo del otro**:

- **atacantes:** el camino completo, con las órdenes exactas, **y lo que NO
  funcionó**
- **defensor:** la línea de tiempo de lo detectado y qué lo delató

Y después se cruzan. Lo que el atacante hizo y el defensor no vio es un agujero
de vigilancia. Lo que el defensor vio y el atacante no recuerda haber hecho es
ruido que no sabía que estaba haciendo.

> La regla del grupo sigue valiendo aquí: **un hallazgo no existe hasta que otro
> lo reproduce leyendo solo el escrito.**

---

## 7. Lista de comprobación antes de empezar

- [ ] red privada montada, los tres se hacen `ping`
- [ ] la máquina arrancada (acordate: **el ISO espera ENTER** en el menú)
- [ ] el servicio web responde desde fuera
- [ ] Ciel entra con `admin` y su panel dice "foto tomada, vigilando"
- [ ] los atacantes tienen **solo la IP**
- [ ] nadie que ataca ha leído Defend Overal ni el guion de construcción
- [ ] alguien con un reloj para cerrar las rondas a su hora

---

> **Recordatorio de siempre:** laboratorio propio en red privada. Lo que se
> aprende aquí se practica contra tu propio equipo, HackTheBox, o algo con
> permiso escrito.
