# Desempaquetar sin romperle el cifrado

> Cómo abrir un programa malicioso que está cifrado de verdad, sin tener la
> clave y sin atacar el cifrado. Caso real, anonimizado.

Esta guía sale de una muestra que le llegó a alguien de la comunidad. No hay
nombres, ni el dominio, ni los endpoints: esos están reportados y no se publican
hasta que las plataformas actúen. Lo que sí está entero es **la técnica**, que es
lo que te vas a llevar.

**Lo que vas a aprender:** por qué a veces atacar el cifrado es el camino
equivocado, cuáles son los tres puntos por los que un programa no puede escapar,
y cómo montar un laboratorio donde equivocarte no cuesta nada.

**Lo que hace falta:** saber qué es una función en JavaScript. Nada más.

---

## 1 · El problema

Llega un instalador de 86 MB que dice ser un launcher de mods de Minecraft.
VirusTotal: **0 de 47**. Ningún antivirus dice nada.

Dentro, después de desempaquetar el instalador, hay un solo fichero de
JavaScript de 4,2 MB con nombre aleatorio. Y dentro de ese fichero, un bloque
gigante de texto que no se parece a nada.

La primera pregunta que hay que hacerse no es "¿cómo lo descifro?". Es **"¿esto
está cifrado o solo codificado?"**. Y eso se mide.

### La entropía te lo dice en un segundo

```python
import math, collections
def entropia(b):
    if not b: return 0.0
    c = collections.Counter(b)
    n = len(b)
    return -sum((k/n) * math.log2(k/n) for k in c.values())
```

Interpretación, y aprendétela porque la vas a usar siempre:

| bits/byte | Qué es |
|---|---|
| ~4,5 | texto normal, código fuente |
| ~6,0 | base64 (solo usa 64 símbolos de 256) |
| **~8,0** | **cifrado o comprimido: todos los bytes salen igual de probables** |

El bloque daba **6,00**. Se descodificó como base64 → salió otra cosa con
**8,00**.

Eso cierra una puerta y abre otra. Cierra: no hay codificación que deshacer, hay
cifrado de verdad. Abre: si está cifrado, **la clave tiene que estar en algún
sitio**, porque el programa se descifra solo cada vez que arranca.

---

## 2 · La idea

Encontrás esto en el fichero:

```js
const clave = crypto.pbkdf2Sync(pass, Buffer.from(salt, 'base64'), 100000, 32, 'sha512');
const dec   = crypto.createDecipheriv('aes-256-cbc', clave, iv);
const codigo = dec.update(BLOB, 'base64', 'utf8') + dec.final('utf8');
new Function('exports', 'require', 'module', '__filename', '__dirname', codigo)(...);
```

Podrías intentar sacar `pass`, `salt` e `iv` de la tabla de cadenas ofuscada.
Es posible y es lento, y yo lo intenté primero: monté un ataque de texto
conocido probando 1.300 claves numéricas contra 31 entradas. **Falló.** Mi
hipótesis sobre cómo estaba codificada la tabla era falsa.

Y entonces cae la ficha. Mirá la última línea otra vez:

```js
new Function(..., codigo)(...)
```

El programa **te está entregando el texto en claro**. Lo mete en `Function` para
ejecutarlo. Si yo cambio qué es `Function`, el programa descifra, me da el
resultado, y no ejecuta nada.

```js
const Original = Function;

function interceptor(...args) {
  const cuerpo = args[args.length - 1];      // el ultimo argumento es el codigo
  if (typeof cuerpo === 'string' && cuerpo.length > 500) {
    require('fs').writeFileSync('/tmp/capturado.js', cuerpo);
    console.log('>>> CAPTURADO: ' + cuerpo.length + ' bytes');
    process.exit(0);                          // y NO lo ejecuto
  }
  return Original.apply(this, args);
}
interceptor.prototype = Original.prototype;
globalThis.Function = interceptor;
```

Toda su protección —el PBKDF2 de 100.000 iteraciones, el AES, el
anti-depurador— trabaja para vos. No la rompiste: la dejaste terminar.

> **La idea general, que sirve para todo:** un programa protegido tiene que
> desprotegerse para funcionar. Buscá el punto donde está obligado a hacerlo, y
> esperalo ahí.

---

## 3 · Casi nunca hay una capa. Hay capas

Capturé 2.394.244 bytes. Los miré. Empezaban así:

```js
const crypto = require('crypto');
function decrypt(encdata, masterkey, salt, iv) {
  const key = crypto.pbkdf2Sync(masterkey, Buffer.from(salt, 'base64'), 100000, 32, 'sha512');
  ...
```

**Otro desempaquetador.** Muñecas rusas.

Mi `process.exit(0)` al primer acierto me paró una capa antes de tiempo, y por
poco concluyo que el desempaquetador era el programa. Corregido:

```js
function esDesempaquetador(t) {
  return t.includes('createDecipheriv') || t.includes('pbkdf2Sync');
}
// ...dentro del interceptor:
if (!esDesempaquetador(cuerpo)) {
  // ya no descifra nada mas: esto es el programa final
  analizar(cuerpo);
  process.exit(0);
}
// si SI lo es, se deja correr para que entregue la siguiente capa
```

Dejás correr mientras siga siendo envoltorio, y frenás en seco cuando deja de
serlo. Ahí está el programa de verdad, y no se ejecuta.

---

## 4 · El gancho que no se puede esquivar

`Function` funciona, pero tiene una pega: solo lo pillás si el programa usa
`Function`. Puede usar `eval`, puede usar `vm.runInThisContext`, puede
simplemente ejecutar el resultado en línea.

Hay un punto por el que **no puede escapar**: para descifrarse, tiene que llamar
al descifrador.

```js
const crypto = require('crypto');
const original = crypto.createDecipheriv;
let n = 0;

crypto.createDecipheriv = function (...a) {
  const dec = original.apply(crypto, a);
  const partes = [];
  const u = dec.update.bind(dec), f = dec.final.bind(dec);

  dec.update = function (...x) {
    const r = u(...x);
    partes.push(typeof r === 'string' ? r : r.toString('latin1'));
    return r;
  };
  dec.final = function (...x) {
    const r = f(...x);
    partes.push(typeof r === 'string' ? r : r.toString('latin1'));
    require('fs').writeFileSync('/tmp/descifrado' + (++n) + '.js', partes.join(''));
    console.log('>>> DESCIFRADO ' + n + '  algoritmo=' + a[0]);
    return r;
  };
  return dec;
};
```

Con esto cae **cada** descifrado, pase por donde pase después. Es el gancho que
pondrías primero si volvieras a empezar.

---

## 5 · Convertir lo que falta en un espía

La carga útil dependía de módulos que no estaban (`fs-extra`, `axios`,
`archiver`, `sqlite3`...). Reventaba con `Cannot find module 'fs-extra'`.

Podías instalarlos. O podías darte cuenta de que **un módulo que falta es una
oportunidad**: lo sustituís por algo que apunte todo lo que le pidan.

```js
const Module = require('module');

function espia(nombre) {
  const base = function () {};
  const p = new Proxy(base, {
    get(t, k) {
      if (k === 'then' || k === 'toJSON') return undefined;   // que no parezca promesa
      if (k === 'default') return p;
      return espia(nombre + '.' + String(k));
    },
    apply(t, th, a) {
      console.log('[LLAMADA] ' + nombre + '(' + a.map(resumir).join(', ') + ')');
      return espia(nombre + '()');
    },
    construct(t, a) {
      console.log('[NUEVO] new ' + nombre + '(' + a.map(resumir).join(', ') + ')');
      return espia('new ' + nombre);
    }
  });
  return p;
}

const cargaOriginal = Module._load;
Module._load = function (peticion, padre, esMain) {
  try { return cargaOriginal.apply(this, arguments); }
  catch (e) { return espia(peticion); }        // no existe -> espia
};
```

Y de golpe, cuando el programa llama a `axios.post(URL, datos)`, **la URL queda
escrita**. No hizo falta descifrar nada: el programa la descifró él solo para
poder usarla.

> El detalle del `then`: si un `Proxy` devuelve algo para la propiedad `then`,
> JavaScript lo trata como una promesa y un `await` se queda colgado para
> siempre. Devolvé `undefined`.

---

## 6 · Mentile sobre dónde está

Nada de lo anterior sirve si el programa mira `process.platform`, ve `linux` y
se va sin hacer nada. La muestra era para Windows.

```js
Object.defineProperty(process, 'platform', { value: 'win32' });
process.env.APPDATA       = '/fakewin/Users/juan/AppData/Roaming';
process.env.LOCALAPPDATA  = '/fakewin/Users/juan/AppData/Local';
process.env.USERPROFILE   = '/fakewin/Users/juan';
process.env.TEMP          = '/fakewin/Temp';
require('os').homedir = () => '/fakewin/Users/juan';
```

Y los comandos se apuntan, no se ejecutan:

```js
const cp = require('child_process');
for (const m of ['execSync', 'exec', 'execFileSync', 'spawnSync', 'spawn']) {
  cp[m] = function (...a) {
    console.log('[COMANDO ' + m + '] ' + String(a[0]).slice(0, 400));
    return m.endsWith('Sync') ? '' : { on: () => {}, stdout: { on: () => {} } };
  };
}
```

Con eso salieron 36 comandos del sistema, en claro, **escritos por el propio
programa**. Entre ellos, cómo cierra 19 navegadores distintos para desbloquear
sus bases de datos de credenciales, y cómo enumera el antivirus antes de
empezar.

---

## 7 · El laboratorio

Todo lo anterior se hace dentro de una máquina virtual. Tres decisiones que
importan:

**Orden de arranque.** Este orden no es un detalle, es lo único que hace que
sea seguro:

```sh
# 1. red ARRIBA, solo para instalar lo que haga falta
rc-service networking start; udhcpc -i eth0 -n -q
apk add nodejs

# 2. red ABAJO, y se comprueba
ip link set eth0 down
ip addr show eth0 | grep -c 'inet '        # tiene que dar 0
ping -c1 -W2 1.1.1.1 && echo RED=SI || echo RED=NO

# 3. AHORA se toca la muestra
node arnes.js muestra.js
```

La muestra nunca ve una interfaz levantada. Y **se comprueba**, no se supone.

**Nada de carpetas compartidas.** Las carpetas compartidas de VirtualBox
necesitan Guest Additions, que es código corriendo dentro de la máquina con un
canal directo al anfitrión. Justo lo que no querés. Un disco `ext2` de 24 MB no
tiene canal de vuelta: se enchufa, se lee, se desenchufa.

```sh
dd if=/dev/zero of=entrada.img bs=1M count=24
mkfs.ext2 -L ENTRADA entrada.img
# copiar dentro la muestra y el arnes, y luego:
VBoxManage convertfromraw entrada.img entrada.vdi --format VDI
```

**Sin ventanas.** La máquina arranca con `--type headless` y se maneja así:

```sh
VBoxManage controlvm lab keyboardputstring "ls -la"
VBoxManage controlvm lab keyboardputscancode 1c 9c   # 1c=Intro, 9c=soltar
VBoxManage controlvm lab screenshotpng pantalla.png
```

Teclado y ojos, sin abrir nada en tu escritorio.

---

## 8 · Los dos errores que cometí

Van aquí porque los vas a cometer vos también.

**El instrumento antes que el objetivo.** Dos veces seguidas el "no funciona"
era mío. Primero: estuve escribiendo órdenes por la consola serie **a ciegas**,
dando por hecho que llegaban; una captura de pantalla mostró el `login:`
intacto, sin una sola tecla recibida. Después: `mount` fallaba con *Invalid
argument* sobre un disco perfectamente válido —`blkid` decía `TYPE="ext2"`—
porque el kernel `virt` de Alpine no trae ese driver cargado. `modprobe ext4` y
entró.

> **Regla:** cuando algo no funciona, sospechá de tu medición antes que del
> objetivo. Y buscate una forma de *ver*, no de suponer.

**La carga útil anula `console.log`.** Los ficheros se seguían escribiendo pero
la salida por pantalla se cortaba en seco a mitad, y el proceso terminaba con
código 0 como si todo hubiera ido bien. Si tu instrumentación habla por consola,
te quedás ciego sin enterarte.

```js
// capturá la referencia ANTES de cargar la muestra, y escribí a fichero
const fs = require('fs');
function log(t) { try { fs.appendFileSync('/mnt/ent/log.txt', t + '\n'); } catch (e) {} }
```

---

## 9 · Y el final: no afirmes negativos

La pregunta que de verdad importaba a la víctima era **¿deja algo instalado?**,
porque de eso dependía si tenía que formatear el equipo.

El primer barrido no encontró `schtasks` ni claves `Run`. **Eso no es una
respuesta**, porque las cadenas seguían cifradas: "no encontré la palabra" no es
"no está". Para poder afirmarlo hicieron falta dos vías independientes:

1. **Estática.** Extraje del binario la maquinaria de cadenas —la tabla, los dos
   descifradores base y 817 funciones envoltorio—, la ejecuté en un fichero
   aparte y obtuve **1.185 cadenas en claro**. Barrido sobre todas: ni
   `schtasks`, ni `CurrentVersion\Run`, ni `RunOnce`, ni `Startup`, ni
   `sc create`, ni `.lnk`, ni `.vbs`.
2. **Dinámica.** De los 36 comandos ejecutados, las únicas operaciones de
   registro son `reg query` — lectura.

Con una sola vía no lo habría afirmado. Con las dos, sí: **no persiste**. Y esa
conclusión cambió el consejo — en vez de formatear, rotación dirigida de
credenciales y cierre de sesión en todos los dispositivos.

> Que no encuentres algo dice tanto de tu búsqueda como del objetivo. Antes de
> decir "no está", preguntate si tu búsqueda podía haberlo encontrado.

---

## 10 · Ejercicios

1. Escribí la función `entropia()` y pasásela a: un `.py` tuyo, ese mismo
   fichero en base64, y un `.zip`. Anotá los tres números y explicá por qué el
   del zip se parece al de un cifrado.
2. Hacé un fichero `prueba.js` que meta un `console.log('hola')` dentro de un
   `new Function(...)` y ejecutalo. Después escribí el gancho de la sección 2 y
   comprobá que capturás el texto sin que se imprima nada.
3. Escribí el `espia()` de la sección 5 y usalo para cargar un módulo que no
   exista. Llamalo con `modulo.algo.otraCosa(1, 'dos')` y mirá qué registra.
4. ¿Por qué el `Proxy` tiene que devolver `undefined` para `then`? Probá a
   devolver el espía y hacé `await` sobre él. (Ojo: cortalo con Ctrl+C.)
5. Montá la VM de la sección 7 y comprobá el paso 2: que `ping` falla **antes**
   de tocar nada. Si no comprobás eso, no tenés un laboratorio, tenés una
   esperanza.

---

## Resumen

| Problema | Lo que no funciona | Lo que sí |
|---|---|---|
| Bloque cifrado, entropía 8,0 | Atacar el cifrado sin la clave | Dejar que el programa se descifre y esperarlo en `createDecipheriv` |
| El código se ejecuta al descifrarse | Ejecutarlo y ver qué pasa | Sustituir `Function` y quedarse el texto sin ejecutarlo |
| Hay varias capas | Parar en el primer acierto | Seguir mientras el texto siga siendo desempaquetador |
| Faltan dependencias | Instalar el árbol entero | `Proxy` que registra cada llamada con sus argumentos |
| Es para Windows y estás en Linux | Rendirse | Falsear `process.platform` y `%APPDATA%` |
| ¿Persiste? | Buscar una palabra y no encontrarla | Dos vías independientes, y solo entonces afirmarlo |
