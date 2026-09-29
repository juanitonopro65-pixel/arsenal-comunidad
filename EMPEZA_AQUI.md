# Empezá aquí

Para quien acaba de entrar y no sabe por dónde agarrar esto.

No hace falta que sepas programar. Hace falta que sepas leer con atención y que
aguantes estar trabado un rato sin cerrar la pestaña. Eso es todo.

---

## Lo primero: una terminal

Si estás en Windows, abrí PowerShell y escribí:

```powershell
wsl --install
```

Reiniciá. Ya tenés Linux dentro de Windows. Cuando una guía diga "abrí una
terminal", es eso.

Si estás en Linux o Mac, ya la tenés.

> **No instales Kali todavía.** Todo el mundo empieza instalando Kali, se pasa
> tres días configurándolo y no resuelve nada. Ubuntu por WSL te sirve para los
> primeros dos meses. Cuando te falte una herramienta, la instalás.

---

## El camino, en orden

Está en este orden por una razón. Saltarte el primero es la forma más común de
quedarse estancado, porque después todo se siente como copiar comandos de
internet sin saber por qué funcionan.

### 1 · [La frontera de confianza](teoria/La_Frontera_de_Confianza.md)

**Una tarde.** La idea que explica casi todos los fallos web: qué controla el
cliente, qué controla el servidor, y por qué eso decide todo lo demás.

Es la única guía de la lista que es puramente teoría. Es también la que más
diferencia hace. Hacé los ejercicios del final; si no los hacés, no la leíste.

### 2 · [Leer antes de atacar](metodo/Leer_Antes_de_Atacar.md)

**Una hora.** Un reto resuelto entero con cuatro comandos. Cada flag explicado
pieza por pieza, para quien nunca abrió una terminal.

Acá es donde muchos descubren que "hackear" se parece bastante a leer con
cuidado.

### 3 · [SpookyPass](retos/SpookyPass.md)

**Una tarde.** Tu primer reto de ingeniería inversa: un archivo y vos, sin
servidor ni peticiones.

Trae la lección que más se repite después: por qué `strings` jura que la
respuesta no está cuando sí está, y qué parámetro lo arregla.

### 4 · [El orden del ataque](metodo/El_Orden_del_Ataque.md)

**Varias sesiones.** El método completo para un reto web con código fuente:
inventario, controles, sumideros, y las seis recetas que van de "encontré el
sumidero" a "tengo el exploit".

Volvés a esta guía muchas veces. No se lee una vez.

### 5 · [Aidor](retos/Aidor.md)

**Una tarde.** IDOR de punta a punta cambiando un número en la URL: enumerar
usuarios, romper un hash con diccionario, saltar a SSH.

Con esta ya estás resolviendo cosas de verdad.

---

## Después, según lo que te guste

No hay que hacerlas todas ni en orden. Mirá cuál te da curiosidad.

| Guía | Para cuándo |
|---|---|
| [Una versión vieja no es una vulnerabilidad](fundamentos/Version_Vieja_No_Es_Vulnerabilidad.md) | Cuando empieces a leer CVEs y a preguntarte si un exploit de GitHub es real o basura |
| [El instalador falso](fundamentos/Instalador_Falso_Roblox.md) | Cuando a alguien conocido le pase. Trae scripts para revisar el equipo |
| [Desempaquetar sin romperle el cifrado](fundamentos/desempaquetar_sin_romper/README.md) | Cuando quieras meterte en malware de verdad. Es el nivel más alto del repo |
| [Kali Live con persistencia](fundamentos/Kali_Live_Persistencia.md) | Cuando ya sepas qué herramienta te falta |

---

## Cómo preguntar acá

Esto no es cortesía, es que cambia la respuesta que te van a dar.

**Una pregunta que sirve tiene tres cosas:**

1. **Qué intentás conseguir.** No "no me funciona nmap", sino "quiero ver qué
   puertos tiene abiertos la máquina del lab".
2. **Qué hiciste exactamente.** El comando entero, copiado, no de memoria.
3. **Qué pasó.** La salida entera, no "me da error".

```
❌  "alguien sabe por que no me anda"

✅  "intento enumerar el lab de DockerLabs (172.17.0.2). Corri:
       nmap -sV 172.17.0.2
     y me devuelve 'Note: Host seems down'. El ping si responde.
     ¿Que estoy leyendo mal?"
```

La segunda la contesta cualquiera en dos minutos. La primera no la contesta
nadie.

**Y cuando algo no funcione, sospechá de tu medición antes que del objetivo.**
Es la regla que más tiempo ahorra en todo el repo. La mitad de los "no funciona"
son la herramienta mal usada, no el objetivo defendiéndose.

---

## Lo único que no se negocia

Todo lo que hay acá se practica contra **tu propio laboratorio**, contra
plataformas que existen para eso (HackTheBox, DockerLabs), o contra un programa
con **permiso escrito**. Nada más.

No por miedo al castigo — porque eso es exactamente lo que separa a un
investigador de seguridad de un delincuente, y **no es la técnica**. La técnica
es la misma. Lo único que cambia es si tenés permiso.

Si alguien te pregunta *"¿cómo ataco esto?"* sin decir qué es "esto", la primera
respuesta es **"¿dónde está la caja?"**.

---

## Dos cosas que te van a pasar

**Te vas a trabar.** Mucho, y pronto. Eso no es señal de que esto no es para
vos: es el trabajo. La diferencia entre quien avanza y quien deja no es el
talento, es cuánto aguanta sin respuesta antes de irse.

**Vas a copiar un comando sin entenderlo.** Está bien la primera vez. No está
bien la tercera. Cuando uses algo por tercera vez, pará y leé qué hace cada
parte — ahí es donde se aprende de verdad.

---

## Si encontrás un fallo en una guía

Decilo. Se corrigen. Los errores que ya están incluidos a propósito son otra
cosa: están ahí porque la hora perdida por una cookie mal mandada enseña más que
la cadena que salió limpia a la primera.
