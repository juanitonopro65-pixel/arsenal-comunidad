# 🏰 Máquina de Overwall — construí tu propio objetivo

> **Qué vas a tener al final:** un fichero `.iso` arrancable, hecho por vos, que
> levanta un sistema con **cinco fallos puestos a propósito** — uno de cada
> familia — y la guía para **atacarlo y para taparlo**.
>
> **Para quién:** alguien que ya hizo algún reto y quiere entender el otro lado.
> Construir el objetivo enseña más que atacarlo.

---

## ⚠️ Lo primero, porque no es negociable

Vas a fabricar una máquina **con agujeros a propósito**. Eso significa:

1. **Red host-only.** Nunca puente, nunca NAT hacia internet. La máquina habla
   con tu PC y con nadie más. Si la exponés, el agujero es tuyo y es real.
2. **Nada de datos de verdad.** Ni una contraseña que uses en otro sitio, ni un
   correo real, ni una clave de API. Todo inventado.
3. **No la uses de plantilla para nada que vaya a producción.** Esto está roto
   a propósito; es un muñeco de prácticas.

Si no podés cumplir las tres, no sigas.

---

## La distinción que te ahorra semanas

Cuando alguien dice *"quiero hacer mi propio sistema operativo"*, suele querer
una de dos cosas muy distintas:

| lo que suena igual | lo que es en realidad |
|---|---|
| **Escribir un SO desde cero** — kernel, arranque, gestión de memoria | meses de trabajo, y enseña **compiladores y arquitectura**, no seguridad |
| **Armar tu propia distribución** — tus paquetes, tus servicios, tus usuarios, tus fallos | una tarde, y es **exactamente** lo que necesitás para atacar y defender |

Vamos por la segunda. Nadie empieza escribiendo un kernel, igual que nadie
aprende a cocinar criando la vaca.

La herramienta se llama **`live-build`**: es con lo que se construye el propio
Debian, y está en los repositorios de Kali. Le describís un sistema con ficheros
de configuración y te devuelve un `.iso` que arranca.

---

## Paso 1 — Las herramientas

```bash
sudo apt install live-build xorriso isolinux syslinux-common debootstrap grub-efi-amd64-bin mtools
```

Qué hace cada una, para que no sea magia:

| paquete | para qué |
|---|---|
| `live-build` | el director de orquesta: `lb config` y `lb build` |
| `debootstrap` | baja un Debian mínimo y lo deja en una carpeta |
| `squashfs-tools` | comprime ese sistema en un solo fichero |
| `xorriso` | mete todo en un `.iso` que un BIOS/UEFI sabe arrancar |
| `isolinux` / `syslinux-common` | el arranque en modo BIOS antiguo |
| `grub-efi-amd64-bin` / `mtools` | el arranque en modo UEFI (los PC modernos) |

> **Dónde construirlo.** El proceso monta y desmonta sistemas de ficheros. Va
> mejor en una máquina virtual Linux o en WSL2 que en entornos raros. Si algo
> falla con mensajes de `mount` o de bucle, es casi siempre eso.

---

## Paso 2 — La configuración

```bash
mkdir -p ~/overwall && cd ~/overwall

lb config \
  --distribution bookworm \
  --binary-images iso-hybrid \
  --debian-installer none \
  --archive-areas "main contrib non-free non-free-firmware"
```

Qué le estás diciendo:

- **`--distribution bookworm`** → la base es Debian 12. Estable y con todo lo que
  necesitás.
- **`--binary-images iso-hybrid`** → un `.iso` que sirve igual grabado en USB que
  montado en una máquina virtual.
- **`--debian-installer none`** → no queremos instalador: queremos que arranque
  y funcione, sin instalar nada.

Te crea un árbol de carpetas. Las dos que importan:

```
config/package-lists/     <- qué programas lleva dentro
config/includes.chroot/   <- tus ficheros, tal cual, dentro del sistema
config/hooks/             <- scripts que corren mientras se construye
```

La idea es simple: **`includes.chroot/` es la raíz del sistema que vas a
fabricar**. Si ponés un fichero en `config/includes.chroot/etc/motd`, en la
máquina terminada aparece en `/etc/motd`.

---

## Paso 3 — Qué lleva dentro

```bash
mkdir -p config/package-lists
cat > config/package-lists/overwall.list.chroot <<'FIN'
openssh-server
nginx
python3
sudo
net-tools
iproute2
vim-tiny
cron
FIN
```

Eso es el sistema: SSH para entrar, nginx para servir algo, Python para el
servicio con fallo, cron para la tarea programada, y lo mínimo para moverse.

---

## Paso 4 — Los cinco fallos

Acá está el diseño, y es la parte que de verdad enseña.

**Los fallos no se improvisan.** Si ponés cinco variantes de lo mismo, el que
ataca aprende una técnica y repite. Queremos **cinco familias distintas**, porque
en un objetivo real las superficies son distintas (eso es lo mismo que decimos en
[Cómo se reparte el trabajo](../metodo/Repartir_El_Trabajo.md)).

| # | familia | el fallo |
|---|---|---|
| 1 | **credenciales** | usuario con contraseña adivinable, y SSH escuchando |
| 2 | **inyección** | un servicio web que pasa tu texto a la consola |
| 3 | **escalada por permisos de fichero** | un binario con SUID que no debería tenerlo |
| 4 | **escalada por tarea programada** | un script que corre como root y cualquiera puede editar |
| 5 | **exposición de información** | credenciales guardadas en un fichero que todos pueden leer |

Todo esto se crea con un *hook*: un script que `live-build` ejecuta dentro del
sistema a medio construir.

```bash
mkdir -p config/hooks/normal
cat > config/hooks/normal/9000-overwall.hook.chroot <<'FIN'
#!/bin/sh
set -e

# ---------- 0. La cuenta del DEFENSOR (no es un fallo: es necesaria) ----------
# Sin esto el ejercicio no se puede jugar: la imagen no trae consola ni nadie
# con sudo, asi que el que defiende no podria arreglar NADA. La contrasena se
# le da SOLO a quien defiende, y es larga a proposito -- no esta en rockyou,
# asi que no cae por diccionario. El contraste con la de abajo es la leccion.
useradd -m -s /bin/bash admin
echo 'admin:C0rr3-3l-V13nt0-Sobre-Aincrad' | chpasswd
usermod -aG sudo admin

# ---------- 1. CREDENCIALES: usuario con contraseña adivinable ----------
useradd -m -s /bin/bash operador
echo 'operador:verano2024' | chpasswd
# OJO: el sistema en vivo REHACE la configuracion de SSH al arrancar (live-config
# genera las claves de host y escribe sshd_config con 'PasswordAuthentication no').
# Por eso NO sirve editar sshd_config aqui: tu cambio se pierde en el arranque.
# Lo que si sobrevive es un fichero suelto en sshd_config.d/, porque el 'Include'
# esta en la linea 12 del config -- y en sshd GANA EL PRIMER VALOR LEIDO, no el
# ultimo. Sin esto, el fallo de la contrasena debil es INALCANZABLE.
mkdir -p /etc/ssh/sshd_config.d
printf 'PasswordAuthentication yes
' > /etc/ssh/sshd_config.d/99-laboratorio.conf
chmod 644 /etc/ssh/sshd_config.d/99-laboratorio.conf
systemctl enable ssh || true

# ---------- 5. EXPOSICION: credenciales legibles por cualquiera ----------
mkdir -p /opt/app
cat > /opt/app/config.env <<'EOF'
DB_HOST=127.0.0.1
DB_USER=root
DB_PASS=verano2024
EOF
chmod 644 /opt/app/config.env     # <-- el fallo: todo el mundo puede leerlo

# ---------- 2. INYECCION: servicio web que llama a la consola ----------
mkdir -p /opt/web
cat > /opt/web/ping.py <<'EOF'
#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        q = parse_qs(urlparse(self.path).query)
        host = q.get("host", ["127.0.0.1"])[0]
        # EL FALLO: el texto del usuario entra entero en la consola
        salida = os.popen("ping -c 1 " + host).read()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(salida.encode())

HTTPServer(("0.0.0.0", 8080), H).serve_forever()
EOF
chmod 755 /opt/web/ping.py

cat > /etc/systemd/system/pingweb.service <<'EOF'
[Unit]
Description=Servicio de diagnostico
[Service]
# IMPORTANTE: sin esto el servicio corre como root y la inyeccion te da root
# directo, lo que deja sin sentido los fallos 3 y 4. Tiene que entrar como
# usuario sin privilegios para que haya algo que escalar.
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /opt/web/ping.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable pingweb.service || true

# ---------- 3. ESCALADA: SUID donde no toca ----------
chmod u+s /usr/bin/find        # <-- el fallo

# ---------- 4. ESCALADA: tarea programada escribible ----------
cat > /opt/respaldo.sh <<'EOF'
#!/bin/sh
tar -czf /tmp/respaldo.tgz /opt/app 2>/dev/null
EOF
chmod 777 /opt/respaldo.sh    # <-- el fallo: cualquiera lo edita
echo '* * * * * root /opt/respaldo.sh' > /etc/cron.d/respaldo
chmod 644 /etc/cron.d/respaldo

# La bandera final, solo para root
echo 'OVERWALL{el_que_defiende_tambien_tiene_que_saber_atacar}' > /root/flag.txt
chmod 600 /root/flag.txt
FIN
chmod +x config/hooks/normal/9000-overwall.hook.chroot
```

> **Leé el script entero antes de usarlo.** No porque sea peligroso —lo escribís
> vos y corre dentro de tu propia imagen— sino porque **entender dónde pusiste
> cada fallo es la mitad del ejercicio**. Si lo pegás sin leerlo, cuando te toque
> defender no vas a saber qué buscás.

---

## Paso 5 — Construir

```bash
sudo lb build
```

Tarda. Baja un Debian entero, instala los paquetes, corre tu hook, comprime todo
y arma el `.iso`. La primera vez pueden ser veinte minutos o más, según tu
conexión.

Cuando termina, el fichero está en la misma carpeta — un `.iso` de varios cientos
de megas.

### Repetir la construcción con cambios

Acá hay una trampa que cuesta un rato descubrir. Esto **no** funciona:

```bash
sudo lb clean
sudo lb build        # E: the following stage is required to be done first: config
```

`lb clean` conserva tu carpeta `config/` —tu hook y tu lista de paquetes siguen
ahí— pero borra la marca interna que dice "la configuración ya está hecha". Hay
que volver a pasar por `lb config`, **con las mismas opciones de antes**:

```bash
sudo lb clean
sudo lb config --distribution bookworm --binary-images iso-hybrid --debian-installer none --archive-areas "main contrib non-free non-free-firmware"
sudo lb build
```

Tranquilo, `lb config` no te pisa los ficheros: los tuyos siguen intactos. Y la
segunda construcción es más rápida, porque el sistema base queda en caché.

---

## Paso 6 — Arrancarla, con la red bien puesta

**Esto es lo único que no se puede hacer de memoria.** Repasá el aviso del
principio.

> **El ISO arranca en un menú y se queda esperando.** No tiene temporizador: hay
> que pulsar **ENTER** sobre *Live system (amd64)*. Si lo arrancás sin pantalla y
> no ves nada funcionar, no está roto — está esperando esa tecla.

**VirtualBox:** máquina nueva, tipo Linux / Debian 64-bit, 1 GB de RAM, sin disco
duro (arranca desde el ISO). En *Red* → **Adaptador solo-anfitrión**
(*host-only*). Montás el `.iso` como unidad óptica y arrancás.

**QEMU**, si preferís la terminal:

```bash
qemu-system-x86_64 -m 1024 -cdrom live-image-amd64.hybrid.iso \
  -netdev user,id=n0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 \
  -device e1000,netdev=n0
```

Eso te deja el SSH de la máquina en `localhost:2222` y el web en
`localhost:8080`, **sin exponerla a la red**.

---

## ✅ Estado de verificación (6-oct-2026)

Todo lo que dice esta guía está **ejecutado**, no supuesto. Se construyó el ISO,
se arrancó en QEMU y se recorrió la cadena entera:

| comprobación | resultado |
|---|---|
| el ISO se construye y arranca | Debian 12, 566 MB |
| los cinco fallos están dentro de la imagen | ✅ |
| inyección web, y entra **sin privilegios** | `uid=33(www-data)` |
| credenciales expuestas leídas por la inyección | `DB_PASS=verano2024` |
| **SSH con la contraseña reutilizada** | `uid=1000(operador)` |
| **root por el SUID de `find`** | bandera leída |
| **root por la tarea programada** | bandera copiada por cron |
| la bandera NO es legible sin escalar | ✅ |
| los comandos de **detección** encuentran lo plantado | ✅ |
| `admin` entra y puede usar `sudo` | `uid=0(root)` |
| `operador` entra y **no** tiene sudo | el camino de ataque sigue intacto |
| `sudo ss -tlnp` muestra el proceso | `users:(("python3",pid=788))` |
| `sudo sshd -T` | `passwordauthentication yes` |

**Tres caminos distintos a root**, que es lo que se buscaba: por la web y el
SUID, por SSH y el SUID, y por SSH y la tarea programada.

### Tres cosas se rompieron, y solo se vieron al arrancarla

Las dejo escritas porque son la lección más cara de la guía:

1. **El servicio web corría como root.** La inyección daba `uid=0` directo, lo
   que dejaba sin sentido los dos fallos de escalada. Arreglado con `User=www-data`.
2. **SSH no aceptaba contraseñas.** El sistema en vivo rehace `sshd_config` al
   arrancar y lo deja en `PasswordAuthentication no`; editarlo en el hook no
   sirve de nada. Solo sobrevive un fichero suelto en `sshd_config.d/`.
3. **El ISO se queda en el menú de arranque** esperando ENTER, sin temporizador.
   Sin pantalla, parece que no funciona.
4. **Nadie podía administrar la máquina.** El grupo `sudo` estaba vacío, la
   imagen no levanta consola y `operador` no tiene privilegios: el que defiende
   no tenía forma legítima de arreglar nada. De ahí la cuenta `admin`.

Ninguna de las tres se ve leyendo el script. Las tres habrían costado una tarde.

---

## Paso 7 — El ejercicio

Y acá es donde deja de ser un tutorial y pasa a ser entrenamiento.

### Ronda 1 — atacar (45 min)

El que ataca empieza sin saber nada salvo la IP. El objetivo: leer
`/root/flag.txt`.

El camino existe y tiene varios ramales. Pistas en orden, para no regalar nada:

1. ¿Qué puertos hay abiertos? Empezá por ahí.
2. El servicio del 8080 hace algo con lo que vos escribís. ¿Qué hace exactamente?
3. Una vez dentro como usuario sin privilegios: ¿qué ficheros del sistema tienen
   permisos que no les corresponden?
4. ¿Qué corre solo, cada tanto, y con qué permisos?

**Se escribe todo**: qué probaste, qué funcionó y **qué no**. Los negativos
también.

### Ronda 2 — defender (45 min)

Otra persona, que **no vio el ataque**, recibe la máquina y tiene que:

1. **Encontrar** los cinco fallos — sin que nadie se los diga
2. **Taparlos**
3. **Escribir** cómo detectó cada uno

Esta es la ronda que la gente se salta y es la que más vale.

### Ronda 3 — volver a atacar

El primero vuelve a intentarlo contra la máquina ya defendida. Lo que todavía
funcione es trabajo mal hecho de la defensa, y se discute entre los dos.

**Los papeles rotan** en cada sesión. Nadie se libra de defender, igual que en el
método del grupo nadie se libra de verificar.

---

## Las cinco respuestas (para quien defiende)

No las leas si te toca atacar.

<details>
<summary>Desplegar</summary>

### 1 · Contraseña adivinable

- **Cómo se detecta:** `/var/log/auth.log` se llena de `Failed password`; `lastb`
  lista los intentos fallidos. Una ráfaga de decenas por minuto desde una sola IP
  no es un usuario despistado.
- **Cómo se tapa:** contraseña larga y única; mejor todavía,
  `PasswordAuthentication no` en `/etc/ssh/sshd_config` y entrar solo con clave.
  `fail2ban` para cortar la ráfaga.

### 2 · Inyección de comandos

- **Cómo se detecta:** los accesos al servicio llevan caracteres que no pintan
  nada en un nombre de máquina: `;`, `|`, `` ` ``, `$(`, o sus versiones
  codificadas (`%3B`). Y en el sistema aparecen procesos hijos del servicio que
  no son `ping`.
- **Cómo se tapa:** no construir la orden pegando texto. En Python,
  `subprocess.run(["ping", "-c", "1", host])` — una lista, sin consola de por
  medio. Y validar que `host` sea una IP o un nombre, rechazando todo lo demás.
- **La regla general:** el problema nunca es el carácter raro; es **mezclar datos
  con instrucciones**. Separalos y el agujero desaparece.

### 3 · SUID de más

- **Cómo se detecta:**
  `find / -perm -4000 -type f 2>/dev/null` y comparar con la lista de un sistema
  recién instalado. `find` con SUID no es normal en ningún sitio.
- **Cómo se tapa:** `chmod u-s /usr/bin/find`. Si alguien necesitaba de verdad
  esa capacidad, se da con una regla concreta de `sudo` o con *capabilities*, no
  marcando el binario entero.

### 4 · Tarea programada escribible

- **Cómo se detecta:** mirar **qué** ejecuta cada tarea y **con qué permisos está
  ese fichero**. `cat /etc/cron.d/*` y después `ls -l` de cada script. Un `777`
  en algo que corre como root es una puerta abierta.
- **Cómo se tapa:** `chown root:root /opt/respaldo.sh && chmod 755
  /opt/respaldo.sh`. Lo que corre como root solo lo puede escribir root.

### 5 · Credenciales legibles

- **Cómo se detecta:** buscar ficheros de configuración con permisos amplios:
  `find / -name '*.env' -o -name 'config.*' | xargs ls -l 2>/dev/null`, y mirar
  si alguno tiene algo que parezca una contraseña.
- **Cómo se tapa:** `chmod 640` y dueño adecuado, para que solo lo lea quien lo
  necesita. Y lo más importante, que no es un permiso: **esa contraseña estaba
  repetida** — era la misma del usuario `operador`. Una credencial filtrada abre
  una puerta; una credencial **reutilizada** las abre todas.

</details>

---

## Lo que te llevás

1. **Construir el objetivo enseña más que atacarlo.** Cuando ponés el fallo con
   tus manos, entendés por qué aparece en software real: nadie lo pone a
   propósito, aparece por comodidad.
2. **Un objetivo serio tiene superficies distintas, no el mismo fallo cinco
   veces.**
3. **Defender es más difícil que atacar**, y por eso casi nadie practica esa
   mitad. El que ataca necesita un camino; el que defiende tiene que encontrar
   todos.
4. **Casi ningún fallo es un fallo de código.** Cuatro de los cinco son permisos,
   contraseñas y configuración. Así es afuera también.
5. **La contraseña reutilizada es el fallo más barato y el más caro.**

---

## Si querés seguir

- Añadí un sexto fallo vos, de una familia que no esté: una condición de carrera,
  una ruta relativa en un script de root, un servicio que confía en una cabecera
  HTTP.
- Hacé una **segunda versión ya defendida** y pasásela a alguien para que intente
  entrar. Si no puede, escribiste bien las defensas.
- Llevá registro de cuánto tarda cada persona en cada ronda. Esa cifra, a lo
  largo de un mes, es la única medida honesta de si están mejorando.

---

> **Recordatorio de siempre:** esta máquina vive en tu laboratorio y en red
> host-only. Lo que aprendas acá se practica contra tu propio equipo,
> HackTheBox, o algo con permiso escrito.
