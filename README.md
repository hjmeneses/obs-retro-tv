# obs-retro-tv

*Retro TV effects for OBS: time tunnel, and more to come.*

Shaders para **OBS Studio** inspirados en los efectos de las series de televisión de los 60: túneles del tiempo, cambios de escena con emblemas giratorios, pasillos de puertas…

*[English below](#english)*

## Requisitos

- OBS Studio
- Plugin [obs-shaderfilter](https://github.com/exeldro/obs-shaderfilter)

## Shaders

| Archivo | Qué hace |
|---|---|
| `tunel.shader` | Túnel del tiempo: anillos que se hunden sin fin hacia un punto de fuga y la fuente cae girando y encogiéndose hacia el fondo, o llega desde él. Con grano y parpadeo de película. |
| `emblema.shader` | **Transición** de escena: un emblema sale girando sobre un fondo de rayos y se lanza contra la cámara; por dentro ya se ve la escena nueva. Estrella por defecto o tu propio PNG. |

## Instalación

1. Descarga los archivos `.shader` (o clona el repo).
2. En OBS, clic derecho sobre la fuente o escena → **Filtros** → **+** → **User-defined shader**.
3. Activa **Load shader text from file** y elige el archivo `.shader`.
4. Ajusta los parámetros.

## Túnel del tiempo (`tunel.shader`)

Aplícalo a la fuente que debe caer al túnel. Se ve mejor si la fuente tiene **transparencia** (cámara con quitado de fondo, chroma key o un PNG): el túnel aparece detrás de la figura. Sin transparencia cae el rectángulo completo, como un recorte.

| Progreso | Caer al túnel | Salir del túnel |
|---|---|---|
| 0–10 % | El túnel aparece detrás de la fuente | Solo el túnel |
| 10–88 % | La fuente gira y se encoge hacia el centro | La fuente llega girando desde el fondo |
| 88–100 % | Solo el túnel | El túnel se desvanece y queda la fuente tal cual |

| Parámetro | Efecto |
|---|---|
| Reproducir en bucle | Repite la secuencia sola. Apágalo para controlar el Progreso a mano o con el script |
| Duración | Segundos que dura la secuencia completa |
| Salir del túnel | Invierte la secuencia: sirve como entrada en vez de salida |
| Centro del túnel X/Y | Dónde queda el punto de fuga |
| Bamboleo del túnel | Qué tanto se mueve el punto de fuga en una órbita lenta |
| Densidad de anillos / Espiral | Cuántos anillos se ven y si forman brazos de espiral (0 = anillos concéntricos) |
| Velocidad del túnel | Qué tan rápido avanzan los anillos hacia el fondo (negativo = hacia afuera) |
| Contraste de los anillos / Pulsación de luz | Bordes suaves o duros, y ondas de brillo que viajan por el túnel |
| Color del túnel | Blanco = blanco y negro; cualquier otro color lo tiñe |
| Vueltas / Vaivén del viajero | Cuántas vueltas da la fuente al caer y cuánto se balancea |
| Grano / Parpadeo | Aspecto de película de los 60 |

## Disparar el efecto con un hotkey (script)

Por sí solo, el shader solo puede correr en bucle porque no sabe cuándo "empieza" el efecto. `retro-control.lua` apaga el bucle y mueve el Progreso de 0 a 100 en la duración del filtro.

1. **Herramientas → Scripts → +** y elige `retro-control.lua`.
2. En **Filtro** elige tu filtro de túnel (si no aparece, **Actualizar lista**).
3. Presiona **Reproducir**, o asigna un atajo en **Configuración → Atajos de teclado → Reproducir efecto (obs-retro-tv)**.

## Emblema giratorio (`emblema.shader`)

Este es una **transición**, no un filtro: se dispara sola al cambiar de escena.

1. En el panel **Transiciones de escena** → **+** → **User-defined shader**.
2. Activa **Load shader text from file** y elige `emblema.shader`.
3. Pon una duración de 1.5–2.5 s.

| Tiempo | Qué pasa |
|---|---|
| 0–35 % | Un círculo de rayos se abre desde el centro sobre la escena actual |
| 3–55 % | El emblema aparece girando, con rebote, y se queda girando |
| 55–90 % | El emblema se lanza contra la cámara; por dentro ya se ve la escena nueva |
| 90–100 % | Fundido final a la escena nueva |

| Parámetro | Efecto |
|---|---|
| Imagen del emblema | Si eliges un PNG, se usa en lugar de la estrella (vacío = estrella). Usa uno **cuadrado con transparencia** y una forma sólida al centro, porque por ese hueco se ve la escena nueva |
| Tamaño del emblema | Diámetro, en % de la altura de la pantalla |
| Vueltas del emblema | Cuántas vueltas da durante la transición (negativo = al revés) |
| Puntas / Picos de la estrella | Forma de la estrella por defecto |
| Color del emblema / del contorno | Colores de la estrella |
| Rayos del fondo / Giro de los rayos / Colores de rayos | El fondo de rayos detrás del emblema |

No incluye ningún logotipo: si usas uno, asegúrate de tener derecho a usarlo.

No está afiliado ni respaldado por ninguna serie, estudio o franquicia.

---

## English

Shaders for **OBS Studio** inspired by 1960s TV effects: time tunnels, spinning-emblem scene changes, corridors of doors…

### Requirements

- OBS Studio
- [obs-shaderfilter](https://github.com/exeldro/obs-shaderfilter) plugin

### Shaders

| File | What it does |
|---|---|
| `tunel.shader` | Time tunnel: rings sinking endlessly toward a vanishing point while your source tumbles, spinning and shrinking, into it (or out of it, with *Salir del túnel*). Film grain and flicker included. |
| `emblema.shader` | Scene **transition**: an emblem spins out over a sunburst and flies into the camera, revealing the next scene through its shape. A star by default, or your own square PNG with transparency. |

Parameter labels are in Spanish. Add the filter with **User-defined shader → Load shader text from file**. The effect looks best on a source with transparency (background removal, chroma key or PNG).

`emblema.shader` is a transition: add it under **Scene Transitions → + → User-defined shader**, load the file and set 1.5–2.5 s. No logos are included; only use one you have the rights to.

To play the tunnel once with a hotkey, load `retro-control.lua` (**Tools → Scripts**), pick the filter and press *Reproducir*, or bind *Reproducir efecto (obs-retro-tv)* under **Settings → Hotkeys**.

Not affiliated with or endorsed by any series, studio or franchise.

## License

MIT
