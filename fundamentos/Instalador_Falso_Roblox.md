# ⚠️ El instalador falso del "trabajo de scripter"

> Caso real, de un amigo de la comunidad. Analizamos la muestra **sin
> ejecutarla** y quedó claro qué era en diez minutos.
>
> Si te llega algo parecido, esta guía te dice **cómo reconocerlo**, **cómo
> comprobar si tu equipo está afectado** y **qué hacer si lo está**.

---

## Cómo llega

El guion es casi siempre el mismo:

1. Alguien te escribe con una **oportunidad**: *"busco scripter para mi juego de
   Roblox"*, *"probá mi juego y te pago"*, *"sos parte del equipo, descargate
   esto"*. También aparece como sorteo, beta cerrada o herramienta privada.
2. Te pasa un **archivo comprimido con contraseña**, y la contraseña **en el
   mensaje**.
3. Dentro hay otro comprimido, y dentro un instalador.

Está diseñado para menores que programan. No es casualidad: es el público que
tiene cuentas de Roblox, Discord y a veces cripto, y que no suele tener el
reflejo de desconfiar de una oferta de trabajo.

---

## Las seis señales — y por qué cada una es una señal

Esto es lo que encontramos en la muestra real, leyendo sus bytes:

| Señal | Qué significa de verdad |
|---|---|
| **Comprimido con contraseña** | **Un antivirus no puede escanear un archivo cifrado.** No es para proteger nada: es para que el antivirus no vea el contenido hasta que ya esté en tu disco. Si la contraseña viene en el mismo mensaje, no protege de nadie — solo del escáner. |
| **Zip dentro de zip** | Cada capa hace más difícil el análisis automático. Un archivo legítimo no viene envuelto dos veces. |
| **`Хх-v.9.554.zip`** | Esa `Х` **no es una X latina**: es cirílica (U+0425). Se ve idéntica y es otro carácter. Sirve para saltarse filtros que buscan nombres por texto. |
| **Sin firma digital** | Todo instalador legítimo va firmado, y Windows te dice de quién es. El nuestro: `NotSigned`, firmante `NINGUNO`. |
| **Empresa que no existe** | Se declaraba *"Madium Installer"* de *"Madium"*. Búscalo: no existe. |
| **98,5% del archivo ilegible** | Lo más revelador, abajo. |

---

## Lo que se ve al abrir el ejecutable (sin ejecutarlo)

Un programa de Windows está dividido en secciones. Se pueden listar sin correr
nada:

```
.text      91.648 bytes   entropía 6.41    <- el código real
.rdata     52.224 bytes   entropía 4.69
.data       3.584 bytes   entropía 2.47
.rsrc  10.096.128 bytes   entropía 8.00    <- 98,5% del archivo
.reloc      2.048 bytes   entropía 5.26
```

**La entropía mide cuán impredecibles son los bytes.** Texto y código dan entre
4 y 7. **8.00 es aleatoriedad perfecta**, y eso solo lo produce algo **cifrado o
comprimido**.

O sea: de 10 MB, solo **91 KB son programa**. El resto es un bloque cifrado.

> Ese reparto tiene nombre: es un **dropper**. Los 91 KB no hacen el daño — solo
> descifran el bloque grande y lo lanzan en memoria, donde el antivirus lo tiene
> mucho más difícil.

Y por eso dentro **no hay ni una sola dirección web en texto plano**. En un
programa normal las hay a montones. Aquí están todas dentro del bloque cifrado.

---

## Cómo comprobar tu equipo

**Descargar un archivo no infecta.** El peligro empieza al **ejecutarlo**.
Preguntate: *¿hice doble clic y se abrió algo — un asistente, una barra, un
parpadeo negro?*

- **No lo abrí** → borrá el archivo y ya está.
- **Sí lo abrí, o no estoy seguro** → seguí abajo.

Hay un script de comprobación en la comunidad (`revisar_pc.ps1`). Solo **lee**:
no borra ni cambia nada. Busca seis cosas:

1. El archivo, por su **huella SHA-256** (no por el nombre, que se cambia fácil)
2. Programas que **arrancan solos** con Windows desde carpetas de usuario
3. La **carpeta de Inicio**
4. **Tareas programadas** creadas en los últimos días
5. **Ejecutables nuevos** en `AppData`, `Temp` y `ProgramData`
6. **Procesos y conexiones** hacia fuera

```powershell
powershell -ExecutionPolicy Bypass -File revisar_pc.ps1
```

---

## Si hay indicios

En este orden, y el orden importa:

**1 · Desconectá el equipo de internet.** Corta la salida de datos.

**2 · Desde OTRO dispositivo** — el teléfono sirve — cambiá contraseñas:
- **El correo primero.** Con el correo se recupera todo lo demás; si lo tienen,
  cambiar las otras no sirve de nada.
- Después: Discord, Roblox, Steam, banco, y cualquier sitio con tu tarjeta.
- **Cerrá todas las sesiones abiertas** en cada servicio. Cambiar la contraseña
  **no** cierra las sesiones ya robadas: hay que cerrarlas a mano.
- Activá **2FA** en todo lo que lo permita.

**3 · Si tenías cripto**, movés los fondos ya. Una frase semilla que estuvo en un
equipo infectado está quemada para siempre, aunque cambies la contraseña.

**4 · Reinstalá Windows.** Y acá va la parte que no gusta:

> **Quitar un ladrón de datos a mano no es fiable.** Dejan copias en varios
> sitios y basta con que sobreviva una. Ningún "limpiador" te da garantías.
> Copiá tus archivos personales —documentos, fotos, proyectos, **nunca
> ejecutables**— formateá y reinstalá.

Es un día de trabajo. Perseguir restos durante semanas, no.

**5 · Avisá a tus contactos.** Estas campañas se propagan desde la cuenta
robada: tus amigos van a recibir el mismo archivo *de tu parte*, y a vos te
creen.

---

## Lo que roban (para saber qué cambiar)

Los ladrones de datos de esta familia van a lo mismo, y saberlo hace tu lista
concreta en vez de "cambiá todo":

- **Contraseñas guardadas en el navegador** y **cookies de sesión** — con la
  cookie entran **sin necesitar tu contraseña ni el 2FA**. Por eso cerrar
  sesiones es tan importante como cambiar la clave.
- **Tokens de Discord** — acceso a tu cuenta sin contraseña
- **Billeteras de cripto** y extensiones del navegador
- **Archivos** con nombres como `contraseñas.txt`, `seed`, `wallet`, `backup`
- **Capturas de pantalla** y lo que haya en el portapapeles

---

## Cómo no volver a caer

- **Una oferta de trabajo no se acompaña de un ejecutable.** Nadie te contrata
  pidiéndote que corras un `.exe` de un desconocido.
- **Contraseña en un comprimido = bandera roja**, siempre. La única razón real
  es que el antivirus no lo pueda mirar.
- **Mirá el nombre con lupa.** Letras cirílicas que parecen latinas, dobles
  extensiones (`.pdf.exe`), espacios de más.
- **Si tenés que probar algo, probalo en una máquina virtual.** Y si no tenés
  una, no lo pruebes.
- **Subí el archivo a un analizador online antes de abrirlo**, nunca al revés.
- **La prisa es parte del ataque.** *"Es hoy"*, *"quedan dos cupos"*, *"se cierra
  el registro"*. Si te están apurando, ya sabés.

---

> **Descargar no infecta. Ejecutar sí.**
> Entre esas dos cosas siempre hay tiempo para pensar — y el que te mandó el
> archivo trabaja justo para que no lo uses.
