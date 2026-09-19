# 🛡️ Arsenal de la comunidad

Material de seguridad ofensiva escrito para gente que **empieza de cero**, desde
sesiones reales de una comunidad que aprende en vivo. Cada guía sale de un reto
que resolvimos juntos — incluidos los errores que cometimos resolviéndolo.

**No es una lista de trucos.** Es el orden de trabajo, el método y la teoría que
hace que los trucos tengan sentido.

---

## 📐 Método

| Guía | De qué trata |
|---|---|
| [El orden del ataque](metodo/El_Orden_del_Ataque.md) | Cómo se ataca un reto web con código fuente, paso a paso: inventario, leer el bot, montar el laboratorio, controles, sumideros, y **las seis recetas de sumidero a exploit** |
| [Leer antes de atacar](metodo/Leer_Antes_de_Atacar.md) | Un reto resuelto con cuatro comandos, `curl` y `grep`. Cada flag explicado pieza por pieza, para quien nunca abrió una terminal |

## 🧱 Teoría

| Guía | De qué trata |
|---|---|
| [La frontera de confianza](teoria/La_Frontera_de_Confianza.md) | La idea que explica casi todos los fallos web: qué controla el cliente, qué el servidor, cómo viajan las sesiones y por qué los JWT no son secretos. Con ejercicios |

## 🧰 Fundamentos

| Guía | De qué trata |
|---|---|
| [Una versión vieja no es una vulnerabilidad](fundamentos/Version_Vieja_No_Es_Vulnerabilidad.md) | Qué te dice un banner, cómo leer un CVE en 60 segundos, **cómo saber si un exploit es falso**, y cómo responder a una petición dudosa |
| [Kali Live con persistencia](fundamentos/Kali_Live_Persistencia.md) | Montar un entorno de trabajo desde cero |

---

## 🚦 Por dónde empezar

1. **[La frontera de confianza](teoria/La_Frontera_de_Confianza.md)** — sin esto,
   todo lo demás es copiar comandos.
2. **[Leer antes de atacar](metodo/Leer_Antes_de_Atacar.md)** — tu primer reto,
   con cuatro comandos.
3. **[El orden del ataque](metodo/El_Orden_del_Ataque.md)** — el método completo,
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
