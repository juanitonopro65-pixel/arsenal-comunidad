# 🧩 Cómo se reparte el trabajo entre varios

> Guía para cuando dejamos de buscar cada uno por su lado y empezamos a mirar
> **un mismo objetivo entre varios**. No es un organigrama: es el reparto que
> hace que seis personas encuentren más que seis personas sueltas, que no es lo
> mismo ni pasa solo.
>
> Los ejemplos de error son reales y son nuestros. Hay un caso de los de pago
> del que **no puedo contar los detalles aquí** — regla del grupo, ningún caso
> vivo entra — pero sí puedo contar los números, que es lo que enseña.

---

## La idea que ordena todo lo demás

Hay una tentación obvia: "somos seis, que cada uno busque en un sitio y
juntamos". Suena bien y funciona mal.

El dato que lo explica, de una jornada real de esta semana: de **cuatro**
hallazgos que parecían buenos, **tres se cayeron** al comprobarlos a fondo. No
los tumbó un revisor externo. Los tumbamos nosotros, siguiendo el dato hasta el
final.

Lo importante no es el 3 de 4. Es **dónde se fue el tiempo**: no en encontrar,
en **verificar**.

Y hay una razón por la que eso es así siempre, y no mala suerte:

> **El que encuentra algo es el peor juez de su propio hallazgo.**
> Ya está enamorado. Ya se lo contó a alguien. Ya se imagina el pago.

Así que el reparto no separa "zonas del objetivo". Separa **buscar** de
**matar**.

---

## Los seis puestos

### Cuatro en superficies

Un objetivo real no se parte en "fácil / difícil". Se parte en **reflejos
distintos**, porque cada superficie se mira con otros ojos:

| puesto | de qué va |
|---|---|
| **perímetro y recon** | subdominios, **vhosts**, servicios expuestos, puertos, lo que asoma |
| **web y aplicación** | autenticación, IDOR, inyección, lógica de negocio |
| **infraestructura** | AD, SMB, servicios internos, movimiento lateral |
| **cliente pesado y ficheros** | binarios, parsers, formatos propios, corrupción de memoria |

**El de recon no es el puesto del más nuevo.** Es el que más gente subestima y
el que más caro sale. En *Nimbus* perdimos el acceso que faltaba por saltarnos
la enumeración de vhosts: estaba en `aws.nimbus.htb` y no lo miramos. Un reto
entero por un paso de recon.

### Uno verificando

Su único trabajo es **intentar destruir** lo que encontraron los otros cuatro.
No ayudar a confirmarlo: destruirlo.

**Y rota en cada encargo.** Por dos razones: porque es el puesto donde más se
aprende, y porque nadie debe librarse de aprender a matar un hallazgo.

### Uno en informe y coordinación

Ve todo, decide qué entra y qué no, y escribe. Es desde donde se lidera de
verdad, no desde el teclado.

---

## Las tres reglas, que valen más que los puestos

### 1. Nadie verifica lo suyo

Siempre cruzado. Si lo encontraste tú, lo comprueba otro. Sin excepciones, y
tampoco cuando haya prisa — sobre todo cuando haya prisa.

### 2. Un hallazgo no existe hasta que otro lo reproduce leyendo solo el escrito

Ojo al "solo el escrito". No vale explicarlo de palabra, ni echar una mano, ni
"ah, es que también hay que...". Le das tus notas y te callas.

Si el segundo no lo levanta con eso, **el cliente tampoco** y el revisor de la
plataforma menos. Ese filtro habría matado tres hallazgos de la jornada que
conté, antes de que nadie abriera la boca.

### 3. Los negativos se escriben

Esta es la que nadie hace y la que más cuesta.

Cuando cierras una línea sin hallazgo, lo escribes: **qué miraste, qué
descartaste y por qué**. Con seis personas, si no lo haces, se paga cuatro veces
el mismo callejón sin salida.

El cuaderno del caso que no puedo detallar tiene casi **6.000 líneas**, y la
mayoría son negativos. Por eso sirve: la próxima vez nadie vuelve a entrar ahí.

---

## Dos mecánicas, contra dos errores clásicos

**Ventana de tiempo fija por superficie, y luego sincronización.**
Contra el túnel. Si no le pones reloj, alguien se obsesiona con una idea bonita
y se lleva por delante el encargo entero.

**Sincronización diaria corta, y se cuenta lo DESCARTADO, no lo encontrado.**
Esto cambia la conversación por completo. Deja de ser una competencia por quién
trae el trofeo y pasa a ser **cobertura**: qué parte del objetivo ya está
mirada.

---

## Cuándo está alguien listo para tocar un cliente

"Cuando tenga experiencia" no significa nada. Tres cosas medibles, por persona:

1. Ha **reproducido** el hallazgo de otro a partir del escrito, sin ayuda.
2. Ha escrito un informe que **sobrevivió** a la revisión.
3. Tiene **negativos documentados** — o sea, sabe cerrar una línea sin hallazgo
   y dejarla cerrada para los demás.

El tercero es el que de verdad distingue. Quien solo sabe encontrar no sirve en
un equipo: repite el trabajo de otros y no cierra nada.

---

## Un día, para que se vea

```
 09:00  reparto: cada uno su superficie, ventana de 4 horas
 13:00  sincronización (15 min): qué descartó cada uno
        -> el de recon encontró un vhost que nadie esperaba
        -> se reasigna: dos a esa superficie nueva, las otras siguen
 13:15  el que verifica recibe dos hallazgos candidatos
        y se pone a destruirlos
 18:00  sincronización: uno de los dos NO sobrevivió
        (y se escribe POR QUÉ, que es la parte que vale)
        el otro pasa a informe
```

Al cliente se le entregan los que sobrevivieron **y** el registro de todo lo que
se miró y no estaba. Eso segundo es la mitad del valor del trabajo, y casi nadie
lo cobra porque casi nadie lo escribe.

---

## Y ahora que vais a tener Claude Code: lo que más os puede costar

Esto es nuevo y es importante, porque el error que viene es muy fácil de
cometer.

En la jornada que conté, **cinco trampas distintas de la herramienta de
depuración fallaron en silencio**. No daban error: daban una respuesta
*plausible y falsa*. Durante horas se midieron cosas que no existían y se
construyeron conclusiones encima.

Las cinco, para que las reconozcáis:

- el depurador **repetía mi propia orden** en su salida, así que contar mi
  etiqueta no distinguía "ocurrió" de "el eco de lo que pedí"
- puse el punto de control en una función que era **un reenvío**, y su código
  nunca se ejecutaba
- un módulo **empezaba por un dígito** y la dirección no se interpretó como
  dirección
- otro módulo se llamaba con letras que son **dígitos hexadecimales válidos**, y
  el nombre se leyó como un número
- esperé un "evento de carga" de algo que **ya estaba cargado**

Ninguna dio un mensaje de error. Todas dieron un cero tranquilo.

**La regla que sale de ahí:**

> Desconfía de tu instrumento antes que del objetivo.
> Un instrumento que no imprime nada está roto hasta que demuestres lo
> contrario.

En la práctica: **control positivo siempre**. Antes de creerte una medida, pon
una sonda en algo que **seguro** pasa. Si esa no salta, la medición no vale nada
— ni esa ni ninguna otra de esa tanda.

Vale igual para la herramienta de IA. Te va a dar una respuesta siempre, y va a
estar bien escrita. Lo que no te va a decir por su cuenta es "esto que te acabo
de contar lo deduje y no lo comprobé". Eso lo preguntas tú, cada vez:

- ¿esto lo **mediste** o lo **supusiste**?
- ¿cuál es el **control** que descarta que sea casualidad?
- ¿qué **vería** si estuviera equivocado?

La pregunta que mató aquellos tres hallazgos fue siempre la misma, y la dejo
escrita porque es la más rentable de todas:

> "El límite sale del dato" **no significa nada por sí solo.**
> Hay que seguir el dato **hasta donde se reserva la memoria**.

En los tres casos el límite venía del fichero *y la reserva también*, así que no
había nada que vender. En el que sobrevivió, la reserva era una **constante
escrita en el código**, y eso ya no se puede discutir.

---

## Resumen de una pantalla

- cuatro en superficies, **uno destruyendo**, uno escribiendo
- **el verificador rota**: nadie se libra de aprender a matar un hallazgo
- nadie verifica lo suyo
- un hallazgo no existe hasta que **otro lo reproduce leyendo solo el escrito**
- **los negativos se escriben**, siempre
- en la sincronización se cuenta lo descartado, no lo encontrado
- control positivo antes de creerse cualquier medida
- y la pregunta de siempre: ¿medido o supuesto?
