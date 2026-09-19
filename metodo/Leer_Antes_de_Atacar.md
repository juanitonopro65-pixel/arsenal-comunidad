# 🔑 Leer antes de atacar

> Resolvimos un reto web **sin usar una sola herramienta de hacking**. Solo
> `curl` y `grep`, cuatro comandos, leyendo lo que el servidor nos daba gratis.
>
> Esta guía explica **qué hizo cada comando y para qué sirvió** — pieza por
> pieza, para quien nunca usó una terminal.
>
> Reto: **OpenSecret** (HackTheBox, *Very Easy*, web). Sin bandera: sigue activo.

---

## De qué iba

Un portal de soporte donde la gente manda tickets. La descripción decía:

> *"La aplicación usa tokens JWT para las sesiones, pero **algo parece raro** en
> cómo están implementados."*

Un **JWT** es un carnet digital: el servidor te lo da al entrar, tu navegador lo
guarda, y lo enseñás en cada petición. Lleva una **firma** hecha con una clave
secreta, para que no puedas fabricarte uno falso.

El plan obvio era conseguir un token, estudiar la firma y buscar cómo
falsificarla. *Nunca hizo falta.*

> ⚠️ Esto se hace **solo** contra máquinas que son tuyas o de una plataforma como
> HackTheBox, que existe justo para esto.

---

## Comando 1 · Mirar la portada

```bash
curl -s -i http://OBJETIVO/ | head -40
```

**Qué hace cada parte**

| Trozo | Qué hace |
|---|---|
| `curl` | Pide una página web, como un navegador — pero devuelve el texto crudo, sin dibujar nada |
| `-s` | *silent.* Sin esto, curl imprime una barra de progreso que ensucia la salida |
| `-i` | *include.* Muestra también las **cabeceras** de la respuesta, no solo el contenido |
| `\|` | La **tubería**. Pasa lo que sale de la izquierda al comando de la derecha |
| `head -40` | Las **primeras 40 líneas**. Una página entera son cientos |

**Qué devolvió**

```
HTTP/1.1 200 OK
X-Powered-By: Express          ← esto
Content-Type: text/html; charset=utf-8
...
<title>OpenSecret Helpdesk - Support Portal</title>
```

**Para qué sirvió.** Esa cabecera dice que el servidor corre **Express**, o sea
**Node.js**. Eso orienta todo lo demás. Una cabecera te dijo de qué está hecha la
caja sin abrirla.

---

## Comando 2 · Buscar las rutas… y no encontrarlas

```bash
curl -s http://OBJETIVO/ | grep -oE 'href="[^"]*"|/api/[a-zA-Z/-]*' | sort -u
```

**Qué hace cada parte**

| Trozo | Qué hace |
|---|---|
| `grep` | Filtra líneas que contengan algo. El colador de la terminal |
| `-o` | *only.* En vez de la línea entera, imprime **solo el trozo que coincidió** |
| `-E` | *extended.* Permite patrones con `\|` (esto **o** aquello) y `[^"]*` |
| `sort -u` | Ordena y quita repetidos. Si algo sale 30 veces, lo ves una |

**Qué devolvió**

```
href="#"
href="https://cdn.jsdelivr.net/npm/bootswatch@5/..."
href="/static/css/main.css"
```

**Para qué sirvió.** Tres enlaces y ninguno interesante. **Eso también es
información**: significa que los botones no son enlaces normales — la página los
maneja con **JavaScript**, y lo que buscamos está dentro de un `<script>`, más
abajo en el mismo archivo.

> **Lo importante de este paso:** un comando que "no encuentra nada" **no es un
> comando perdido**. Te descartó una posibilidad y te dijo dónde mirar ahora. La
> gente que empieza se frustra aquí; la que lleva tiempo lo anota y sigue.

---

## Comando 3 · Leer el JavaScript

```bash
curl -s http://OBJETIVO/ | tail -70
```

`tail -70` es lo contrario de `head`: las **últimas 70 líneas**. El `<script>`
casi siempre va al final del documento.

**Qué devolvió**

```javascript
const header = { alg: "HS256", typ: "JWT" };
const payload = { username: username };
...
// Sign with SECRET_KEY using HMAC-SHA256          ← esto
const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SECRET_KEY),          ← y esto
    { name: "HMAC", hash: "SHA-256" }, ...
);
document.cookie = `session_token=${token}; path=/;`;
```

**Para qué sirvió.** Aquí se acabó el reto, aunque todavía no se vea.

**El token se firma en el navegador**, no en el servidor. Y para firmar hace
falta la clave secreta… así que **la clave tiene que estar en el navegador**. Y
todo lo que llega al navegador te lo mandó el servidor a vos, en texto plano.

> No es un descuido. Es una **contradicción de diseño**: pedirle al cliente que
> firme es darle la llave, y no hay forma de dársela sin dársela.

---

## Comando 4 · Ir a por la clave

```bash
curl -s http://OBJETIVO/ | grep -n -i -A2 -B2 "SECRET_KEY|role|admin"
```

**Qué hace cada parte**

| Trozo | Qué hace |
|---|---|
| `-n` | *number.* Te dice **en qué línea** está cada coincidencia |
| `-i` | *ignore case.* Encuentra `SECRET`, `Secret` y `secret` por igual |
| `-A2 -B2` | *after / before.* Dos líneas de contexto a cada lado. El contexto suele valer más que la línea |
| `"…\|…\|…"` | Tres palabras a la vez, por si aparecía otro camino |

**Qué devolvió**

```
108-        <script>
109-            // JWT Secret Key
110:            const SECRET_KEY = "HTB{...la bandera estaba aquí...}";
```

**Para qué sirvió.** La clave secreta **era la bandera**. Ni hubo que falsificar
un token, ni entender la firma, ni tocar nada del servidor. Estaba escrita, con
un comentario encima que dice qué es, en la página que cualquiera recibe al
entrar.

*(La bandera no va aquí: el reto sigue activo, y es la única parte de un writeup
que no enseña nada.)*

---

## El mismo trabajo en un solo comando

```bash
curl -s http://OBJETIVO/ | grep -oE 'HTB.[^"]*.'
```

Pero **ese comando no habría funcionado primero.** Solo se puede escribir
*después* de saber que la bandera está en el texto de la página. Los cuatro
comandos no fueron un rodeo: son el camino que te permite escribir el atajo.

---

## Chuleta

| Trozo | Qué hace |
|---|---|
| `curl -s URL` | Descarga una página y la escupe como texto, sin ruido |
| `-i` | Añade las cabeceras de la respuesta |
| `\|` | Pasa la salida de un comando al siguiente |
| `head -N` / `tail -N` | Las primeras / últimas N líneas |
| `grep texto` | Deja solo las líneas que contienen *texto* |
| `-o` | Imprime solo el trozo que coincide |
| `-i` | Ignora mayúsculas y minúsculas |
| `-n` | Muestra el número de línea |
| `-E` | Patrones avanzados: `\|`, `[^"]*`, `+` |
| `-A2 -B2` | Dos líneas de contexto después y antes |
| `sort -u` | Ordena y elimina duplicados |

---

## Las cuatro cosas que enseña

**1 · Si el navegador puede hacerlo, vos podés verlo.** Todo lo que ejecuta tu
navegador te lo mandó el servidor. No existe el "código del cliente escondido":
ver el fuente no es hackear, es leer lo que te dieron.

**2 · El enunciado era la distracción.** Hablaba de JWT y de firmas. Nunca hizo
falta falsificar un token: el error estaba una capa antes, en **decidir que el
cliente firmara**.

**3 · Esto pasa en producción, mucho.** Claves de API en el JavaScript del front,
secretos dentro de apps móviles, tokens en el código del cliente. Es uno de los
hallazgos más comunes que existen.

**4 · No usamos ninguna herramienta.** Ni escáneres, ni fuerza bruta, ni
automatización. `curl` y `grep`. Lo que hicimos fue **leer**, que es la parte que
casi nadie hace primero.

> Antes de atacar algo, **leé lo que te está dando gratis.** Los retos fáciles se
> caen ahí enteros — y en los difíciles, ahí está la pista para lo que viene
> después.

---

## Practicalo vos

Agarrá cualquier reto web y hacé estos cuatro pasos antes de tocar nada:

- [ ] **Portada con cabeceras** — ¿con qué está hecho? (`curl -s -i`)
- [ ] **Enlaces y rutas** — ¿a dónde habla? (`grep -oE`)
- [ ] **El JavaScript** — ¿qué hace por dentro? (`tail`)
- [ ] **Palabras que delatan** — `secret`, `key`, `token`, `admin`, `password`,
      `api`, `flag`

Si después de eso no encontraste nada, **ya sabés muchísimo más** que cuando
empezaste, y recién ahí tiene sentido sacar herramientas.
