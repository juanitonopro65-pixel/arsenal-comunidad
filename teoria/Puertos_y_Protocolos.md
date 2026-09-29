# Puertos y protocolos

> La base de todo. Sin esto, `nmap` es un programa que escupe números.

Para quien nunca escaneó nada. No hace falta saber programar. Al final vas a
poder mirar la salida de un escaneo y decir qué hay ahí y por dónde se entra —
que es lo que hace un profesional antes de tocar una sola tecla más.

---

## 1 · La idea, en una frase

**La IP te lleva a la máquina. El puerto te lleva al programa.**

Pensalo así: la IP es la dirección del edificio. El puerto es el número de
oficina. Llegar al edificio no sirve de nada si no sabés a qué puerta tocar.

```
        190.85.12.40            :22
        ─────────────           ───
        ¿qué máquina?     ¿qué programa dentro de esa máquina?
```

Un ordenador corre muchos programas a la vez que hablan por red: un servidor
web, uno de correo, uno de acceso remoto. Todos comparten **una sola IP**. El
puerto es lo que decide a cuál de ellos le llega tu paquete.

Son 65.535 puertas por cada protocolo. La mayoría cerradas.

---

## 2 · TCP y UDP

Hay dos formas de mandar datos, y cambian lo que podés averiguar.

### TCP — con acuse de recibo

Antes de mandar nada, las dos partes se saludan. Es el **apretón de manos de
tres pasos**:

```
  vos  ──── SYN ────────►  servidor      "¿estás?"
  vos  ◄─── SYN/ACK ─────  servidor      "sí, dale"
  vos  ──── ACK ─────────►  servidor      "vamos"
```

Y a partir de ahí todo llega **en orden** y **completo**: si un paquete se
pierde, se reenvía. Por eso lo usan la web, el correo, SSH y cualquier cosa
donde perder un trozo lo rompe todo.

**Para vos lo importante es esto:** ese saludo es la razón por la que se puede
escanear con fiabilidad. Si mandás un `SYN` y te responden `SYN/ACK`, el puerto
está **abierto**, y lo sabés con certeza.

### UDP — sin acuse de recibo

Se manda y ya. Nadie confirma, no hay orden garantizado, no hay reenvío. Es más
rápido y más barato, y se usa donde llegar tarde es peor que no llegar: DNS,
voz, vídeo, juegos.

**Para vos lo importante:** escanear UDP es **lento y poco fiable**, porque el
silencio es ambiguo. Si no responde, puede ser que el puerto esté cerrado, o que
esté abierto pero al programa no le interese contestarte, o que un cortafuegos
se lo haya comido. Tres cosas distintas, una sola señal.

> Por eso casi todo el mundo escanea TCP primero. No es que UDP no importe: es
> que TCP te da respuestas claras y UDP te da dudas.

---

## 3 · Los tres barrios

| Rango | Nombre | Quién vive ahí |
|---|---|---|
| 0 – 1023 | bien conocidos | Los servicios de siempre. En Linux **hace falta ser root** para abrir uno |
| 1024 – 49151 | registrados | Bases de datos, paneles, aplicaciones |
| 49152 – 65535 | efímeros | Los que tu propio equipo usa **al salir**, y devuelve al terminar |

Ese último detalle explica algo que confunde a todo el mundo al principio:
cuando abrís una web, tu navegador **también** usa un puerto — uno cualquiera
de los altos, elegido al azar. La conexión son cuatro datos, no dos:

```
tu IP : tu puerto efímero   ──►   IP del servidor : 443
190.85.12.40 : 51234        ──►   142.250.78.14   : 443
```

Por eso podés tener veinte pestañas abiertas a la misma web sin que se mezclen:
cada una tiene su puerto de origen distinto.

---

## 4 · Los que de verdad te vas a encontrar

No memorices los 65.535. Estos son los que aparecen una y otra vez.

| Puerto | Servicio | Qué significa para vos |
|---|---|---|
| **21** | FTP | Transferencia de archivos. Mirá si acepta `anonymous` |
| **22** | SSH | Acceso remoto por consola. **A donde querés llegar** con credenciales |
| **23** | Telnet | Como SSH pero **sin cifrar**. Verlo es señal de equipo viejo u olvidado |
| **25** | SMTP | Envío de correo |
| **53** | DNS | Nombres → IPs. A veces deja listar todo el dominio |
| **80** | HTTP | Web sin cifrar. Empezá por aquí casi siempre |
| **110 / 143** | POP3 / IMAP | Lectura de correo |
| **139 / 445** | SMB | Carpetas compartidas de Windows. **Mina de oro**: a veces se leen sin contraseña |
| **443** | HTTPS | Web cifrada. El certificado te regala nombres de dominio |
| **3306** | MySQL | Base de datos |
| **3389** | RDP | Escritorio remoto de Windows |
| **5432** | PostgreSQL | Base de datos |
| **6379** | Redis | Base de datos en memoria. Históricamente **sin contraseña por defecto** |
| **8080 / 8000** | HTTP alternativo | Paneles de administración, aplicaciones de desarrollo |

**Lo que hay que sacar de esta tabla** no es la lista. Es que cada puerto abierto
es una **pregunta distinta**. Ver el 445 abierto no te dice "entrá por aquí": te
dice "andá a ver si hay carpetas compartidas legibles".

---

## 5 · Mirar los tuyos, primero

Antes de escanear nada ajeno, mirá tu propia máquina. Es gratis y es donde se
entiende.

```bash
ss -tlnp
```

Traducido: `-t` TCP, `-l` solo los que están **escuchando**, `-n` sin traducir
números a nombres, `-p` qué programa es.

```
State    Local Address:Port    Process
LISTEN   127.0.0.1:631         cupsd
LISTEN   0.0.0.0:22            sshd
```

Y acá hay algo que **mucha gente no ve nunca** y es de las cosas más útiles de
toda la guía:

| Dirección | Quién puede llegar |
|---|---|
| `127.0.0.1:631` | **Solo vos.** Nadie de la red puede tocarlo |
| `0.0.0.0:22` | **Cualquiera** que llegue a tu IP |

Mismo "puerto abierto", exposición completamente distinta. Cuando alguien te
diga "tengo el puerto X abierto", la pregunta correcta es *¿abierto a quién?*.

---

## 6 · Mirar los de la caja

Contra tu laboratorio, contra HackTheBox o DockerLabs, o contra algo con permiso
escrito. Nada más.

```bash
nmap -p- -sS --min-rate 2000 172.17.0.2 -oN puertos.txt
```

| Parte | Qué hace |
|---|---|
| `-p-` | Los 65.535, no solo los 1.000 más comunes |
| `-sS` | Manda `SYN`, mira si vuelve `SYN/ACK`, y **corta antes de completar** el saludo |
| `--min-rate 2000` | Al menos 2.000 paquetes por segundo. Sin esto tardás una eternidad |
| `-oN puertos.txt` | Guardarlo. **Siempre guardalo** — vas a volver |

Después, **solo sobre los que salieron abiertos**:

```bash
nmap -p 22,80,445 -sV -sC 172.17.0.2
```

`-sV` interroga a cada servicio para que diga qué es y qué versión. `-sC` lanza
los scripts básicos de reconocimiento.

### La trampa que cae todo el mundo

Sin `-sV`, nmap **adivina** el servicio mirando el número de puerto. Nada más.
Si alguien puso un servidor web en el 22, nmap sin `-sV` te va a decir "ssh",
tan tranquilo, y vos vas a perder media hora intentando conectarte por SSH a un
servidor web.

```
Sin -sV:   22/tcp  open  ssh          ← una SUPOSICIÓN
Con -sV:   22/tcp  open  http  nginx 1.18.0   ← lo que de verdad hay
```

> **Esto es el mismo error que ya conocés** si leíste el resto del repo:
> sospechá de tu medición antes que del objetivo. El puerto es una etiqueta; el
> servicio es un hecho. No los confundas.

---

## 7 · El banner

Cuando te conectás a un puerto, muchos servicios se presentan solos. Podés verlo
sin ninguna herramienta especial:

```bash
nc 172.17.0.2 22
```

```
SSH-2.0-OpenSSH_8.2p1 Ubuntu-4ubuntu0.5
```

Eso te acaba de decir el programa, la versión y hasta la distribución. Es la
información más barata que vas a conseguir nunca.

**Pero cuidado, y esto es importante:**

Un banner **no es una vulnerabilidad**. Que diga `OpenSSH 8.2p1` no significa
que sea explotable. Puede estar parcheado por la distribución sin que cambie el
número, o el fallo del que leíste puede necesitar una configuración que no tiene.

Hay una guía entera sobre esto y conviene leerla antes de emocionarse:
**[Una versión vieja no es una vulnerabilidad](../fundamentos/Version_Vieja_No_Es_Vulnerabilidad.md)**.

---

## 8 · Abierto, cerrado, filtrado

nmap usa tres palabras y la diferencia importa:

| Estado | Qué pasó | Qué significa |
|---|---|---|
| **open** | Respondió `SYN/ACK` | Hay un programa escuchando |
| **closed** | Respondió `RST` | Llegaste a la máquina, pero ahí no hay nadie |
| **filtered** | **No respondió nada** | Un cortafuegos se lo comió. No sabés qué hay detrás |

`closed` es información buena: confirma que la máquina está viva y te responde.
`filtered` es silencio, y el silencio no te dice nada sobre lo que hay al otro
lado.

---

## 9 · Un puerto abierto no es un fallo

Es lo más importante de toda la guía.

Un servidor web **tiene** que tener el 80 abierto. Eso es que funciona, no que
esté roto. Lo que buscás no es "hay puertos abiertos", es alguna de estas cuatro:

1. **Algo que no debería estar expuesto.** Una base de datos escuchando en
   `0.0.0.0` en vez de `127.0.0.1`.
2. **Algo sin autenticación.** Un Redis o un panel que abre sin pedir nada.
3. **Algo olvidado.** Un servicio de hace años que nadie mantiene.
4. **Algo mal configurado.** FTP con `anonymous`, SMB con lectura para todos.

Encontrar veinte puertos abiertos y no saber qué preguntarle a ninguno no te
acerca nada. Encontrar uno y saber exactamente qué comprobarle, sí.

---

## 10 · Ejercicios

1. Corré `ss -tlnp` en tu máquina. ¿Cuántos servicios escuchan en `127.0.0.1` y
   cuántos en `0.0.0.0`? Explicá con tus palabras por qué la diferencia importa.
2. Sin buscarlo: ¿por qué en Linux hace falta ser root para abrir el puerto 80,
   pero no el 8080? ¿Qué problema evita esa regla?
3. Montá un laboratorio de DockerLabs y escaneálo con `-p-` y sin `-p-`. Anotá
   cuántos puertos aparecen en cada caso y cuánto tardó cada uno.
4. Sobre un puerto abierto de ese laboratorio, sacá el banner con `nc`. Escribí
   qué aprendiste de esa única línea, y qué **no** podés afirmar todavía.
5. Un escaneo te da `filtered` en el 445. ¿Podés concluir que SMB no está
   corriendo? Justificá la respuesta.
6. Explicale a alguien, en tres frases y sin usar la palabra "puerto", por qué
   una sola IP puede tener una web y un SSH a la vez.

---

## Resumen

| | |
|---|---|
| La IP lleva a la máquina | El puerto lleva al programa |
| TCP saluda antes | Por eso se escanea bien |
| UDP no saluda | Por eso el silencio es ambiguo |
| `127.0.0.1` | Solo vos |
| `0.0.0.0` | Todo el mundo |
| Sin `-sV` | nmap **adivina** por el número |
| Con `-sV` | nmap **pregunta** al servicio |
| Puerto abierto | No es un fallo |
| Puerto expuesto que no debería | **Ahí sí** |

---

Todo esto se practica contra tu propio laboratorio, contra plataformas que
existen para eso, o contra un programa con permiso escrito. Si alguien te
pregunta *"¿cómo ataco esto?"* sin decir qué es, la primera respuesta es
**"¿dónde está la caja?"**.
