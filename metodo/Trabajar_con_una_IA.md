# 🤖 Trabajar con una IA sin que te mienta

> Guía de método, no de trucos. Todos los ejemplos son reales y salen de una sola
> jornada de trabajo: la del 6 al 7 de octubre de 2026, analizando un binario.
> Qué binario no viene al caso, y además no se puede contar todavía.
>
> En esa jornada la IA escribió **ocho cosas falsas con total seguridad**. Las ocho
> salieron a la luz, y ninguna por ser lista: salieron por ejecutar lo que había
> escrito. Esta guía es ese método.

---

## El problema no es que se equivoque. Es que escribe bien.

Una calculadora rota da un número raro y lo notás. Una IA equivocada te da un
párrafo ordenado, con la terminología correcta, que encaja con lo que esperabas.

> **Siempre te va a responder. Y va a estar bien redactado.**
> Lo que no te va a decir por su cuenta es: *«esto que te acabo de contar lo
> deduje y no lo comprobé»*.

Eso lo tenés que preguntar vos. Cada vez.

---

## Las tres preguntas que no cuestan nada

Sirven igual para un modelo que para un compañero de equipo. Pedilas antes de
aceptar cualquier conclusión:

### 1. ¿Esto lo mediste o lo supusiste?

La más rentable de todas. Obliga a separar lo que salió de ejecutar algo de lo
que salió de razonar.

**Caso real.** La IA escribió que un cierto fichero de registro no existía en una
máquina, y montó la vigilancia sobre ese fichero. Cuando se le pidió la medición,
resultó que nunca lo había comprobado: el fichero efectivamente no estaba, pero
tampoco estaba el que había puesto en su lugar. Un `grep` sobre un fichero que no
existe devuelve **silencio**, y el silencio se parece muchísimo a «aquí no ha
pasado nada».

### 2. ¿Cuál es el control?

Un control es una prueba cuyo resultado ya sabés. Si la medición no lo pasa, la
medición no vale — ni esa ni ninguna de esa tanda.

**Caso real.** Se instrumentó un programa para ver cuántas veces pasaba por cierto
sitio. Durante horas salió «cero veces», y se construyeron conclusiones encima.
El depurador **imprimía la etiqueta al crear el punto de control**, así que
contarla no distinguía «ocurrió» de «lo pedí». Se arregló poniendo una sonda en
algo que seguro pasa — y esa tampoco disparaba. Cinco conclusiones a la basura.

### 3. ¿Qué verías si estuvieras equivocado?

Si la respuesta es «nada», no es una medición: es una creencia.

**Caso real, y el mejor de los tres.** Se midió hasta dónde llegaba un bucle que
escribía fuera de su sitio. Siempre paraba en el mismo número. Conclusión: «el
límite es ese número, el fallo es pequeño, no vale mucho».

Era mentira. La herramienta de depuración **mata el proceso en la primera
escritura fuera**. Ese número no era donde paraba el bucle — era donde moría el
programa. Se había leído el síntoma como si fuera el límite.

Midiendo la variable que gobernaba el bucle en vez del sitio del fallo, el límite
real era **miles de veces mayor**. El fallo pasó de «modesto» a serio.

> **Regla:** cuando el instrumento detiene la ejecución, lo que ves es el PRIMER
> síntoma, no el alcance.

---

## Cómo pedir las cosas

### Dale un criterio de terminado que se pueda comprobar

| ❌ vago | ✅ comprobable |
|---|---|
| «revisa esto» | «corré los 16 casos de prueba y pegame la salida» |
| «mejora la guía» | «seguí la guía paso a paso ejecutando cada comando, y anotá dónde falla» |
| «¿está listo?» | «¿qué falta para enviarlo, y qué de eso depende de mí?» |

El de la derecha no se puede responder con una opinión.

### Pedí ejecución, no descripción

«Explicame cómo se haría» produce un texto plausible. «Hacelo y mostrame la
salida» produce la verdad.

Es la diferencia entre las dos columnas de arriba, y es casi todo.

### La frase que cambia una sesión entera

> **«Seguí hasta terminar. Volvé solo si necesitás algo de mí.»**

Sin eso, una IA se detiene a cada paso a pedir permiso, o peor, te ofrece un menú
de opciones para que elijas. Con eso, trabaja sola y vuelve con el resultado.

Y el complemento, que es igual de importante:

> **«Dejá escrito dónde quedaste.»**

Un trabajo largo se corta: se acaba la sesión, se cierra el programa, pasa un día.
Si no hay un cuaderno en disco, cada corte borra todo. En la jornada del ejemplo,
ese cuaderno pasa de **7.000 líneas** y es lo único que hizo posible retomar.

### Interrumpí temprano y corto

Si va por el camino equivocado, dos palabras ahora valen más que un párrafo dentro
de diez minutos. «No, eso no» es una corrección perfectamente válida.

**Caso real:** la IA empezó a explicar un tema adyacente al que se le preguntaba.
La corrección fue literalmente *«te preguntaba por lo otro, buscalo»*. Eso costó
una línea; dejarlo correr habría costado tres respuestas largas.

### Las reglas se dicen una vez, en un fichero

Si repetís la misma instrucción en cada conversación, estás pagando por ella cada
vez. Casi todas las herramientas tienen un sitio donde poner reglas permanentes
(en Claude Code es un fichero `CLAUDE.md`).

Lo que conviene que esté ahí:

- **qué no se toca nunca** (datos reales, claves, casos bajo embargo)
- **cómo se verifica** en tu trabajo concreto
- **qué hacer al terminar** (dejar escrito, no inflar, decir qué falta)

Y una disciplina: **cada línea ahí se paga en cada conversación**. Solo entran las
reglas que ya te costaron algo.

---

## La otra mitad: que no te salga caro

Casi todo lo que hace mentir a una IA también la hace cara, porque **rehacer
trabajo mal verificado es lo que más se gasta de todo**. Pero hay cosas propias:

**Lo caro no es preguntar, es iterar a ciegas.** Una respuesta de doscientas
palabras cuesta poco. Veinte intentos a ver si pega, cuestan mucho. Por eso el
control positivo es también una técnica de ahorro: una medición mala se paga
entera otra vez.

**Decile qué NO hacer.** «No me des opciones, elegí vos» o «no me expliques lo que
ya sé» recorta respuestas enteras.

**Trabajos largos en un fichero, no en la conversación.** Un documento que va
creciendo en el chat se reenvía entero cada vez. En disco, se lee solo el trozo
que hace falta.

**Y lo que más rinde: que no repita callejones sin salida.** Si lo que se descartó
no queda escrito, lo vuelve a intentar. Por eso los **negativos se escriben** —
qué miraste, qué descartaste y por qué. En el cuaderno del ejemplo, la mayoría de
las líneas son negativos, y por eso sirve.

---

## Lo que te llevás

1. **El riesgo no es que sea tonta: es que es fluida.** Una respuesta equivocada
   llega bien escrita.
2. **¿Medido o supuesto?** — la pregunta más rentable que existe.
3. **Control positivo antes de creer una medida.** Si no salta en algo que seguro
   pasa, no vale nada.
4. **Cuando el instrumento para la ejecución, ves el primer síntoma, no el
   alcance.**
5. **Criterios de terminado comprobables**, no opiniones.
6. **Pedí ejecución, no descripción.**
7. **«Seguí hasta terminar» + «dejá escrito dónde quedaste»** — las dos frases que
   más cambian una sesión larga.
8. **Las reglas, una vez y en un fichero.** Y solo las que ya te costaron algo.
9. **Los negativos se escriben**, o se pagan dos veces.

---

## Y una cosa que conviene tener clara

Nada de esto sirve si no sabés lo suficiente para juzgar la respuesta. La IA
acelera a quien ya entiende; al que no, le da banderas sin comprensión, que es
exactamente lo contrario de aprender.

Por eso en este grupo la regla es la de siempre:

> **Si funcionó y no sabés por qué, no lo resolviste.**
