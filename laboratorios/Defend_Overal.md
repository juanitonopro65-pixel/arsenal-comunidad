# 🛡️ Defend Overal — el manual del que defiende

> **Para quién:** el que recibe la [Máquina de Overwall](Maquina_de_Overwall.md)
> y tiene que encontrar lo que está mal **sin que nadie le diga qué es**.
>
> **Guía hermana:** [Attack Overal](Attack_Overal.md). Si te toca atacar, leé esa.
> No leas las dos antes del ejercicio o te quedás sin ejercicio.

---

## Por qué esta guía es la difícil

Hay una asimetría que conviene entender antes de empezar:

> **El que ataca necesita encontrar un camino. El que defiende tiene que
> encontrarlos todos.**

El atacante puede fallar diez veces y le basta acertar una. Vos podés acertar
diez veces y te basta fallar una. Por eso defender es más difícil, por eso se
paga mejor, y por eso casi nadie practica este lado: no da la satisfacción
inmediata de la bandera.

La buena noticia: **defender se puede hacer con método**, y el método cabe en
una página.

---

## Antes de empezar: entrá como quien puede arreglar

Defender no se hace desde una cuenta cualquiera. En la Máquina de Overwall tenés
una cuenta de administración, y **la contraseña te la da quien monta el
ejercicio** — el que ataca no la tiene:

```bash
ssh admin@<ip-de-la-maquina>
```

`admin` está en el grupo `sudo`. Varias de las órdenes de esta guía lo necesitan,
y se nota: sin privilegios, `ss` te oculta qué proceso abre cada puerto y
`sshd -T` directamente no corre.

> Si te dan la máquina y **no** podés llegar a root por ninguna vía legítima,
> eso ya es un hallazgo: un sistema que nadie puede administrar tampoco se puede
> arreglar.

---

## El método: cuatro barridos

No vayas buscando "el fallo". Vas a pasar cuatro barridos distintos, cada uno
mirando una cosa, y anotás todo lo que desentone. Al final ordenás.

```
1. ¿Qué está escuchando?          -> la superficie expuesta
2. ¿Quién puede entrar?           -> cuentas y credenciales
3. ¿Qué corre solo, y como quién? -> servicios y tareas
4. ¿Qué permisos no cuadran?      -> ficheros
```

Lo importante es **no mezclarlos**. Si mientras mirás puertos te ponés a leer un
script, perdés el hilo y terminás con un fallo encontrado y cuatro sin mirar.

---

## Barrido 1 — ¿Qué está escuchando?

Todo lo que acepta conexiones es una puerta. Empezá por el inventario.

```bash
sudo ss -tulnp
```

Leelo así: `-t` TCP, `-u` UDP, `-l` solo lo que escucha, `-n` sin resolver
nombres, `-p` qué proceso es.

> **El `sudo` no es opcional.** Sin él la columna `Process` sale **vacía**:
> ves los puertos abiertos pero no quién los abrió, que es justo el dato que
> necesitás. Comprobado — es el error más común de este barrido.

```
Netid  State   Local Address:Port    Process
tcp    LISTEN  0.0.0.0:22           sshd
tcp    LISTEN  0.0.0.0:80           nginx
tcp    LISTEN  0.0.0.0:8080         python3
```

Las preguntas que te tenés que hacer, en este orden:

1. **¿Reconozco todo lo que hay?** Un `python3` escuchando en un puerto alto no
   es un servicio del sistema. Alguien lo puso. ¿Quién, y para qué?
2. **¿Tiene que escuchar en `0.0.0.0`?** Eso significa *"en todas las interfaces,
   acepto de cualquiera"*. Si el servicio solo lo usa la propia máquina, debería
   estar en `127.0.0.1`. La diferencia entre las dos es toda la exposición.
3. **¿Lo necesito?** El servicio más seguro es el que no está.

> **Lo que se registra:** *qué* hay abierto, *quién* lo abrió y *si hace falta*.
> Esa lista es tu superficie. Todo lo que venga después entra por ahí.

---

## Barrido 2 — ¿Quién puede entrar?

### Las cuentas

```bash
awk -F: '$3 >= 1000 && $3 < 65534 {print $1, $3, $7}' /etc/passwd
```

Eso lista las cuentas de personas (los identificadores por debajo de 1000 son del
sistema). Por cada una: **¿sé quién es?** Una cuenta que nadie reclama es una
cuenta que nadie vigila.

```bash
sudo awk -F: '$2 ~ /^\$/ {print $1}' /etc/shadow
```

Las que tienen contraseña puesta. Un `!` o un `*` en vez del hash significa que
la cuenta no entra por contraseña — eso es bueno.

### Cómo se entra

```bash
sudo sshd -T | grep -Ei 'passwordauth|permitroot|pubkeyauth'
```

Ojo: `sshd -T` muestra la configuración **efectiva**, la que de verdad está
usando. No basta mirar `/etc/ssh/sshd_config`, porque puede haber ficheros
sueltos en `/etc/ssh/sshd_config.d/` que la pisen — y en `sshd` **gana el primer
valor leído**, así que un fichero incluido al principio manda sobre lo que diga
el config más abajo.

Es un sitio clásico donde esconder un cambio: el fichero principal dice una cosa
y la máquina hace otra.

| lo que querés ver | por qué |
|---|---|
| `passwordauthentication no` | solo claves; las contraseñas se adivinan, las claves no |
| `permitrootlogin no` | nadie entra directamente como root |

### Dónde se registra quién intentó entrar

Casi toda la documentación te manda a `/var/log/auth.log`. **En esta máquina ese
fichero no existe**, y en muchos sistemas modernos tampoco: ese fichero lo
escribe `rsyslog`, que en las imágenes mínimas no viene instalado. Solo está
`journald`.

```bash
# lo que SI funciona aqui:
sudo journalctl -u ssh -n 200 --no-pager | grep -Ei 'Accepted|Failed password|Invalid user'

# y si el sistema si tiene rsyslog:
sudo grep -Ei 'Accepted|Failed password' /var/log/auth.log
```

```
sshd[1736]: Accepted password for admin from 10.0.2.2 port 45440 ssh2
```

> **Comprobá primero dónde se registra, antes de concluir que no hay ataques.**
> Un `grep` sobre un fichero que no existe devuelve silencio, y el silencio se
> parece muchísimo a "aquí no ha pasado nada". Es la forma más fácil de que te
> entren sin que lo veas.

Para los intentos fallidos también sirve `sudo lastb`, que lee `/var/log/btmp`
— ese sí suele estar.

### Si hay contraseñas, ¿aguantan?

Esto es lo que hace el atacante, y por eso lo tenés que hacer vos primero. En
**tu propio laboratorio**:

```bash
sudo cp /etc/shadow /tmp/h.txt
john --wordlist=/usr/share/wordlists/rockyou.txt /tmp/h.txt
john --show /tmp/h.txt
rm /tmp/h.txt
```

Si `rockyou` —un diccionario público, el primero que prueba cualquiera— saca
alguna, esa contraseña ya está rota. No es "débil": está rota.

> **Y la pregunta que casi nadie hace:** ¿esa contraseña **se repite** en algún
> otro sitio de la máquina? Buscala en los ficheros de configuración. Una
> credencial filtrada abre una puerta; una reutilizada las abre todas.

---

## Barrido 3 — ¿Qué corre solo, y como quién?

### Servicios

```bash
systemctl list-units --type=service --state=running
```

Para cada uno que no reconozcas:

```bash
systemctl cat <servicio>
```

Y mirá **una línea en particular**:

```ini
[Service]
User=www-data        <- ¿está? ¿qué usuario?
ExecStart=...
```

**Si no hay `User=`, el servicio corre como root.** Un servicio que atiende la
red y corre como root convierte cualquier fallo suyo en un compromiso total de la
máquina. Si no hay `User=`, eso ya es un hallazgo, aunque el programa sea
perfecto.

```bash
ps -eo user,comm --sort=user | grep -v '^root' | head -20
```

Eso te dice quién está corriendo de verdad, que no siempre coincide con lo que
dice la configuración.

### Tareas programadas

```bash
cat /etc/cron.d/* /etc/crontab 2>/dev/null
ls -l /etc/cron.{hourly,daily,weekly,monthly}/
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u $u 2>/dev/null; done
```

Vas a ver tareas legítimas de Debian mezcladas con lo que puso alguien. **La
gracia es distinguir**, no leer una lista de uno.

Y ahora lo que de verdad importa, que casi nadie mira:

```bash
# por cada script que ejecute una tarea, ¿QUIEN PUEDE ESCRIBIRLO?
ls -l /ruta/del/script
```

> **La regla:** si una tarea corre como root, **solo root puede poder
> escribirla**. Un script `777` ejecutado por root no es un fallo de permisos: es
> una consola de root con retardo.

---

## Barrido 4 — ¿Qué permisos no cuadran?

### SUID y SGID

Un binario con **SUID** se ejecuta con los permisos de su dueño, no de quien lo
lanza. Si el dueño es root, ese programa corre como root para cualquiera.

```bash
find / -xdev -perm -4000 -type f 2>/dev/null | sort
```

> **El `-xdev` tampoco es opcional en esta máquina.** Un sistema en vivo monta su
> propio sistema de ficheros en varios sitios a la vez, así que sin `-xdev` cada
> binario te sale **tres veces**, con rutas como
> `/run/live/rootfs/filesystem.squashfs/usr/bin/...`. Pasás de 13 líneas legibles
> a 39 de ruido. `-xdev` le dice *"no te salgas de este sistema de ficheros"*.

El problema: la lista normal tiene unos 15-25 binarios y **no te la sabés de
memoria**. Por eso se compara, no se lee:

```bash
# en una maquina recien instalada, una sola vez:
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /root/suid.base

# cada vez que revises:
find / -xdev -perm -4000 -type f 2>/dev/null | sort | diff /root/suid.base -
```

Lo que aparece en el `diff` es lo que alguien añadió.

Si no tenés una línea base, la regla de bolsillo: **lo normal es `passwd`, `su`,
`sudo`, `mount`, `ping` y poco más.** Cualquier herramienta que sepa ejecutar
otros programas o leer ficheros arbitrarios —`find`, `vim`, `python`, `cp`,
`tar`, `nmap`— **no debería tener SUID jamás**. Si la tiene, es root para
cualquiera.

### Ficheros con secretos dentro

```bash
find / -name '*.env' -o -name 'config.*' -o -name '*.conf' 2>/dev/null \
  | xargs grep -lEi 'password|passwd|secret|api[_-]?key|token' 2>/dev/null
```

Y por cada uno que salga, lo que importa no es que exista — es **quién lo puede
leer**:

```bash
ls -l <fichero>
```

Un `-rw-r--r--` significa que **todo el mundo** en la máquina lo lee. Y "todo el
mundo" incluye al usuario del servidor web, que es exactamente con el que entra
alguien que explote una inyección.

### Escribibles por cualquiera

```bash
find / -xdev -type f -perm -0002 ! -path '/proc/*' 2>/dev/null | head -20
find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | head -20
```

El segundo busca directorios escribibles **sin** el *sticky bit* — ahí cualquiera
puede borrar ficheros de otro.

---

## Cómo se tapa cada familia

| familia | el arreglo de verdad |
|---|---|
| **contraseña adivinable** | contraseña única y larga; mejor, `PasswordAuthentication no` y entrar solo con clave. `fail2ban` para cortar las ráfagas |
| **inyección de comandos** | no construir órdenes pegando texto: pasar los argumentos como lista (`subprocess.run(["ping","-c","1",host])`), sin consola. Y validar la entrada |
| **SUID de más** | `chmod u-s`. Si alguien necesitaba de verdad ese permiso, se da con una regla concreta de `sudo` o con *capabilities* |
| **tarea escribible** | `chown root:root` y `chmod 755`. Lo que corre como root solo lo escribe root |
| **credencial expuesta** | `chmod 640` y dueño adecuado — y **cambiar la contraseña**, porque ya se filtró |
| **servicio como root** | `User=` en la unidad de systemd, y arrancarlo con el mínimo privilegio que funcione |

### El que casi nadie hace

Cuando tapás una credencial filtrada, **no basta con arreglar el permiso**. Esa
contraseña ya salió. Hay que cambiarla **y** cambiarla en todos los sitios donde
se repetía. Si solo arreglás el `chmod`, dejaste la llave fuera y pusiste la
puerta más bonita.

---

## El orden de arreglo, cuando hay varios

No todo vale lo mismo. Si tenés tiempo limitado:

1. **Lo que da root desde fuera, sin credenciales.** Un servicio expuesto como
   root es lo primero, siempre.
2. **Lo que da acceso con credenciales adivinables.** Segundo, porque el coste de
   intentarlo es cero para el atacante.
3. **Lo que escala de usuario a root** — SUID, tareas escribibles.
4. **Lo que filtra información** sin dar acceso directo.

Es orden de *exposición*, no de dificultad.

---

## Después de tapar: comprobalo

Un arreglo sin comprobar no es un arreglo, es una intención.

```bash
sudo sshd -t && sudo systemctl restart ssh      # valida ANTES de reiniciar
sudo sshd -T | grep -i passwordauth             # y confirma el valor efectivo
find / -xdev -perm -4000 -type f 2>/dev/null | diff /root/suid.base -
ls -l /opt/respaldo.sh /opt/app/config.env
```

Y la prueba de verdad: **pedile al que atacó que lo intente otra vez**. Lo que
todavía funcione es trabajo tuyo mal hecho, y se discute entre los dos.

> `sshd -t` antes de reiniciar no es manía. Un `sshd_config` roto más un reinicio
> es quedarte fuera de la máquina. En un laboratorio da risa; en un servidor de
> verdad, no.

---

## Lo que te llevás

1. **El que defiende tiene que encontrarlos todos.** Por eso se barre con método
   y no se busca "el fallo".
2. **Mirá lo efectivo, no lo escrito.** `sshd -T` sobre el fichero; `ps` sobre la
   unidad. La configuración y la realidad se separan más de lo que parece.
3. **La comparación vence a la memoria.** Nadie se sabe la lista de SUID; por eso
   se guarda una línea base y se mira el `diff`.
4. **Si corre como root, solo root lo escribe.** Vale para tareas, scripts y
   unidades.
5. **Cuatro de cada cinco fallos no son de código**, son permisos, contraseñas y
   configuración. Así es afuera también.
6. **Una credencial filtrada se cambia, no se esconde.**
7. **Un arreglo sin comprobar no existe.**

---

## Si te atascaste

- No empieces por el fallo más interesante. Empezá por el **Barrido 1**, que es
  el más aburrido y el que ordena todo lo demás.
- Si algo te parece raro pero no sabés por qué, **anotalo y seguí**. Volvés al
  final. La intuición suele tener razón pero interrumpe el barrido.
- Si no encontrás nada, no significa que no haya: significa que mirás donde ya
  miraste. Cambiá de barrido.

---

> **Recordatorio de siempre:** esto se practica contra tu propio laboratorio en
> red host-only, HackTheBox, o algo con permiso escrito.
