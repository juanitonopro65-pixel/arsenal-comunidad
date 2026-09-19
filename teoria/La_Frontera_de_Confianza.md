# 🧱 La frontera de confianza

> La idea que explica casi todos los fallos web. Entender dónde está esa línea es
> la diferencia entre copiar comandos y saber por qué funcionan.
>
> **Versión con diagramas:** esta guía existe también como página visual — pedila
> en el Discord.

---

## Antes de empezar

Esta teoría no es abstracta: explica los dos retos que ya resolvimos.

- En **OpenSecret**, el servidor le pidió al navegador que firmara el carnet de
  sesión — y para eso tuvo que darle la llave.
- En **Bobby's Bistro**, el servidor guardaba sus claves de confianza en una
  carpeta donde el usuario podía escribir.

Son el mismo error con dos disfraces.

> ⚠️ Todo lo de aquí se practica contra **tu propio laboratorio**, HackTheBox, o
> un programa con permiso escrito. Nada más.

---

## Parte 1 — Qué es de verdad una petición

Cuando abrís una página no pasa magia: tu máquina le manda al servidor **un
texto**, y el servidor le devuelve **otro texto**. Nada más.

```
  ┌──────────────┐                                   ┌──────────────┐
  │  TU MÁQUINA  │ ───────── petición ─────────────► │ EL SERVIDOR  │
  │ navegador    │                                   │ la máquina   │
  │ o curl       │ ◄──────── respuesta ───────────── │ de ellos     │
  └──────────────┘                                   └──────────────┘
```

**Lo que va en la petición:**

| Parte | Ejemplo |
|---|---|
| método y ruta | `POST /login` |
| cabeceras | `User-Agent`, `Content-Type` |
| cookies | `Cookie: session=abc123` |
| cuerpo | `user=juan&pass=1234` |

**Lo que vuelve en la respuesta:**

| Parte | Ejemplo |
|---|---|
| código de estado | `200 OK`, `403`, `500` |
| cabeceras | `Set-Cookie: session=…` |
| cuerpo | `<html>…` o `{"ok":true}` |

**El texto de arriba lo escribe tu máquina entera.** Por eso `curl` puede mandar
cualquier cosa que mandaría un navegador — y también cosas que un navegador
nunca mandaría.

---

## Parte 2 — Quién controla qué

Dibujá una línea en el medio.

```
        LO DECIDE QUIEN TE VISITA      ┊      LO DECIDÍS VOS
                                       ┊
   la URL y sus parámetros             ┊   el código del servidor
   todas las cabeceras                 ┊   la base de datos
   las cookies                         ┊   los ficheros del disco
   el cuerpo de la petición            ┊   las claves privadas
   el nombre de un fichero subido      ┊   QUÉ DECIDÍS CREER
   el orden y el número de peticiones  ┊
   el JavaScript que corre             ┊   …lo que nunca sale
                                       ┊      de tu máquina
   …y cualquier cosa que viaje    ─────┊───►  llega
      en la petición                   ┊
                                       ┊
              ▲ FRONTERA DE CONFIANZA ▲
```

La lista de la izquierda no es "lo que un atacante **podría** tocar": es lo que
**cualquiera** toca, siempre, sin herramientas raras. Un navegador es solo un
programa que arma ese texto por vos — y podés armarlo a mano.

> ### La regla
> Todo lo que llega del cliente es **una afirmación sin comprobar**. Si el
> servidor la usa sin verificarla, ahí hay un fallo. Siempre.

Cuando alguien dice *"es que el campo está oculto"*, *"el botón está
deshabilitado"* o *"eso lo valida el JavaScript"*, está describiendo cosas que
viven **a la izquierda de la línea**. No son defensas: son sugerencias.

---

## Parte 3 — Cómo el servidor se acuerda de vos

HTTP no tiene memoria. Cada petición llega sola. Entonces te da un **carnet** y
se lo enseñás cada vez.

```
  TU MÁQUINA                                            EL SERVIDOR
      │                                                      │
  1.  │ ──────── POST /login   usuario + clave ────────────► │
      │                                                      │
  2.  │ ◄─────── 200 OK   Set-Cookie: session=abc123 ─────── │
      │                                                      │
      │   ┌────────────────────────────────────────────┐     │
      │   │ ENTRE MEDIAS, EL CARNET VIVE EN TU MÁQUINA │     │
      │   │ podés leerlo, copiarlo y cambiarlo         │     │
      │   │ antes de devolverlo                        │     │
      │   └────────────────────────────────────────────┘     │
      │                                                      │
  3.  │ ──────── GET /perfil   Cookie: session=abc123 ─────► │
      │                                                      │
  4.  │ ◄─────── 200 OK   "hola, juan" ───────────────────── │
```

**El paso 3 lo escribís vos. El servidor solo puede comprobarlo.**

### El JWT

Un **JWT** es ese carnet, pero autocontenido: lleva los datos dentro y una
**firma** que demuestra que lo emitió el servidor. Tres partes:

```
eyJhbGciOiJIUzI1NiJ9 . eyJ1c2VyIjoianVhbiJ9 . SGVsbG8gdGhlcmU
      cabecera              los datos            la firma
```

Las dos primeras **no están cifradas**. Compruébalo:

```bash
echo 'eyJ1c2VyIjoianVhbiJ9' | base64 -d
# {"user":"juan"}
```

> ⚠️ Un JWT **no protege lo que lleva dentro**. La firma no impide *leerlo* —
> impide **cambiarlo sin que se note**. Nunca metas nada privado en uno.

---

## Parte 4 — Dónde vive la llave

La firma se hace con una clave. Y aquí está el fallo de OpenSecret: **toda la
diferencia es una flecha.**

```
        COMO TIENE QUE SER                      OPENSECRET
   ┌────────────────────────┐          ┌────────────────────────┐
   │      TU MÁQUINA        │          │      TU MÁQUINA        │
   │   solo guarda el       │          │   ┌────────────────┐   │
   │   carnet               │          │   │     CLAVE      │   │
   └───────────┬────────────┘          │   └────────────────┘   │
               │ lo devuelve           └───────────▲────────────┘
               ▼                                   │ la clave viaja
   ┌────────────────────────┐                      │ en la página
   │     EL SERVIDOR        │          ┌───────────┴────────────┐
   │   ┌────────────────┐   │          │     EL SERVIDOR        │
   │   │     CLAVE      │   │          │  le pide al cliente    │
   │   └────────────────┘   │          │  que firme             │
   │  firma y comprueba     │          │  const SECRET_KEY="…"  │
   └────────────────────────┘          └────────────────────────┘

     la clave nunca cruza                la firma deja de probar nada
```

En cuanto la clave llega al cliente, la firma ya no demuestra quién emitió el
carnet — solo demuestra que alguien tenía la clave, y la tiene todo el mundo.

> Pedirle al cliente que firme es **darle la llave**. Y no hay forma de dársela
> sin dársela.

---

## Parte 5 — Los fallos son todos el mismo fallo

Una vez que ves la frontera, los nombres de las vulnerabilidades dejan de ser una
lista que memorizar.

| El servidor se creyó… | Y sale… |
|---|---|
| que el texto que mandás es solo texto | **Inyección SQL** — tu texto se ejecuta como parte de la consulta |
| que el nombre del fichero que subís es limpio | **Travesía de rutas** — `../` escribe fuera de la carpeta |
| que el texto que publicás no es código | **SSTI / XSS** — se ejecuta en el servidor o en otro navegador |
| que su clave no salió de su máquina | **Firma inútil** — cualquiera emite carnets válidos |
| que un fichero suyo no lo tocó nadie | **Confianza envenenada** — le cambiaste lo que usa para decidir |
| que el cliente elige sobre quién actúa | **IDOR** — leés o cambiás datos de otra persona |
| que el JavaScript ya validó los datos | **Validación saltada** — el cliente no valida, sugiere |

---

## Parte 6 — Las tres preguntas

Ante cualquier funcionalidad, en cualquier web:

1. **¿Qué parte de esto la decide el usuario?** Listá todo lo que viaja en la
   petición. Suele ser más de lo que parece.
2. **¿Dónde termina ese dato?** ¿Una consulta SQL? ¿Una ruta de fichero? ¿Una
   plantilla? ¿Una decisión de permisos? Ahí está el sumidero.
3. **¿Qué comprueba el servidor antes de creérselo?** Si la respuesta es "nada" o
   "lo valida el JavaScript", encontraste algo.

**Y una cuarta:** ¿este secreto **cruza la frontera**? Si el cliente necesita
saberlo para funcionar, entonces no es un secreto — y no puede proteger nada.

---

## Parte 7 — Compruébalo vos mismo

En cualquier web que sea **tuya o de un laboratorio**:

```bash
# 1. El texto entero de una respuesta, cabeceras incluidas
curl -s -i https://TU-LABORATORIO/

# 2. Leé un JWT sin herramientas: las dos primeras partes son texto
echo 'PEGA_LA_SEGUNDA_PARTE' | base64 -d

# 3. Mandá una cabecera que un navegador nunca mandaría
curl -s -H 'X-Soy-Admin: si' https://TU-LABORATORIO/

# 4. Mandá un campo que el formulario ni siquiera tiene
curl -s -X POST -d 'usuario=juan&rol=admin' https://TU-LABORATORIO/registro
```

Los dos últimos son la demostración práctica: **el formulario no es el límite.**
Es una sugerencia de lo que el servidor espera recibir, y no estás obligado a
seguirla.

---

## Ejercicios

Ninguno necesita computador.

**1 · La tienda.** Una tienda manda el precio en un campo oculto del formulario y
cobra lo que llegue. ¿Dónde está el fallo?

**2 · El descuento.** Una web valida el cupón con JavaScript y, si es válido,
manda `descuento=50`. ¿Qué probás?

**3 · La app móvil.** Una app lleva dentro la clave de la API. ¿Es segura porque
está compilada?

**4 · El reset.** Te llega un enlace `/reset?token=a3f9…` y el formulario manda
`token=a3f9…&email=vos@correo.com&password=nueva`. El servidor comprueba que el
token existe y no expiró. ¿Dónde está el fallo?

<details>
<summary>Respuestas — probá primero</summary>

**1.** El precio está a la izquierda. El servidor debe buscarlo en SU base por el
id del producto, nunca aceptarlo de la petición.

**2.** Mandar el descuento sin cupón. La validación vive en el navegador; el
servidor nunca la vio.

**3.** No. Compilado no es secreto: la app corre en el teléfono de otro, y ese
teléfono está a la izquierda. Es OpenSecret con otro envoltorio.

**4.** El token es válido y la comprobación es correcta — pero comprueba *que el
token sea válido*, no *de quién es*. Pedís un reset de tu propia cuenta y cambiás
el `email` por el de la víctima. El arreglo: sacar la cuenta **del token** e
ignorar el campo `email`.

</details>

---

> **Todo lo que llega del cliente es una afirmación. El trabajo del servidor es
> no creérsela.**
>
> Si te quedás con una sola idea, que sea ésa. El resto son variaciones.
