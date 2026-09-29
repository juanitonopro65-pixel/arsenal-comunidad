# 🛡️ Arsenal de la comunidad

Material de seguridad ofensiva escrito para gente que **empieza de cero**, desde
sesiones reales de una comunidad que aprende en vivo. Cada guía sale de un reto
que resolvimos juntos — incluidos los errores que cometimos resolviéndolo.

**No es una lista de trucos.** Es el orden de trabajo, el método y la teoría que
hace que los trucos tengan sentido.

---

## 🚪 ¿Primera vez aquí?

**[Empeza aqui](EMPEZA_AQUI.md)** — que instalar, en que orden leer, cuanto tarda cada cosa, y como preguntar de forma que te contesten.

---

## 📐 Método

| Guía | De qué trata |
|---|---|
| [El orden del ataque](metodo/El_Orden_del_Ataque.md) | Cómo se ataca un reto web con código fuente, paso a paso: inventario, leer el bot, montar el laboratorio, controles, sumideros, y **las seis recetas de sumidero a exploit** |
| [Leer antes de atacar](metodo/Leer_Antes_de_Atacar.md) | Un reto resuelto con cuatro comandos, `curl` y `grep`. Cada flag explicado pieza por pieza, para quien nunca abrió una terminal |

## 🧱 Teoría

| Guía | De qué trata |
|---|---|
| [Puertos y protocolos](teoria/Puertos_y_Protocolos.md) | **La base de todo.** La IP lleva a la maquina, el puerto lleva al programa. TCP frente a UDP y por que uno se escanea bien y el otro no, los puertos que de verdad vas a encontrar, leer un banner — y las dos cosas que casi nadie ve: la diferencia entre `127.0.0.1` y `0.0.0.0`, y por que nmap sin `-sV` **adivina**. Con ejercicios |
| [La frontera de confianza](teoria/La_Frontera_de_Confianza.md) | La idea que explica casi todos los fallos web: qué controla el cliente, qué el servidor, cómo viajan las sesiones y por qué los JWT no son secretos. Con ejercicios |

## 🎯 Retos paso a paso

| Guía | De qué trata |
|---|---|
| [SpookyPass](retos/SpookyPass.md) | **Tu primer reto de ingeniería inversa.** Sin servidor y sin peticiones: un archivo y vos. `file`, `strings`, `ltrace`, `objdump`, `nm`. Y la lección grande — por qué `strings` jura que la flag no está cuando sí está, y qué parámetro lo arregla |
| [Aidor](retos/Aidor.md) | **IDOR de principio a fin**, cambiando un número en la URL. Enumerar usuarios, romper un SHA-256 con `rockyou`, saltar a SSH — y la idea fina: cómo una función **bien escrita** acaba siendo explotable porque otra le envenenó la sesión |

## 🧰 Fundamentos

| Guía | De qué trata |
|---|---|
| [Una versión vieja no es una vulnerabilidad](fundamentos/Version_Vieja_No_Es_Vulnerabilidad.md) | Qué te dice un banner, cómo leer un CVE en 60 segundos, **cómo saber si un exploit es falso**, y cómo responder a una petición dudosa |
| [El instalador falso del "trabajo de scripter"](fundamentos/Instalador_Falso_Roblox.md) | Caso real analizado sin ejecutarlo: cómo reconocer un dropper empaquetado, cómo comprobar tu equipo y qué hacer si cayó. Incluye [`revisar_pc.ps1`](fundamentos/revisar_pc.ps1) para detectar, [`limpiar_caso.ps1`](fundamentos/limpiar_caso.ps1) para eliminar y [`barrido_persistencia.ps1`](fundamentos/barrido_persistencia.ps1) para comprobar que no vuelva |
| [Kali Live con persistencia](fundamentos/Kali_Live_Persistencia.md) | Montar un entorno de trabajo desde cero |
| [Desempaquetar sin romperle el cifrado](fundamentos/desempaquetar_sin_romper/README.md) | Caso real: un instalador falso con **0/47 en VirusTotal** y el codigo cifrado de verdad (entropia 8,0). Como medir si algo esta cifrado o solo codificado, y los tres puntos por los que un programa **no puede escapar**: `Function`, `createDecipheriv` y los modulos que le faltan. Monta el laboratorio aislado y termina con la regla que decide el caso: **no afirmes negativos** |

---

## 🚦 Por dónde empezar

1. **[Puertos y protocolos](teoria/Puertos_y_Protocolos.md)** — la base: que hay
   al otro lado antes de tocar nada.
2. **[La frontera de confianza](teoria/La_Frontera_de_Confianza.md)** — sin esto,
   todo lo demás es copiar comandos.
3. **[Leer antes de atacar](metodo/Leer_Antes_de_Atacar.md)** — tu primer reto,
   con cuatro comandos.
4. **[El orden del ataque](metodo/El_Orden_del_Ataque.md)** — el método completo,
   para cuando el reto tenga código fuente.

---

## ⚖️ Lo único que no se negocia

Todo lo que hay aquí se practica contra **tu propio laboratorio**, contra
plataformas que existen para eso (HackTheBox, DockerLabs), o contra un programa
con **permiso escrito**. Nada más.

No por miedo al castigo — porque eso es exactamente lo que separa a un
investigador de seguridad de un delincuente, y **no es la técnica**.

Si alguien te pregunta *"¿cómo ataco esto?"* sin decirte qué es "esto", la
primera respuesta es **"¿dónde está la caja?"**. No es vigilancia: es que nadie
puede dar una buena respuesta sobre un objetivo que no conoce.

---

## 📌 Notas

- **Sin banderas de retos activos.** La bandera es la única parte de un writeup
  que no enseña nada: es la respuesta del examen. Todo lo demás está entero.
- **Los errores están incluidos a propósito.** La hora perdida por una cookie mal
  mandada enseña más que la cadena que salió limpia a la primera.
- Las guías se corrigen cuando alguien encuentra un fallo. Si ves uno, decilo.
