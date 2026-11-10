# Revisión y validación

## Caza mayor en 0.3.0

Se verificaron en la instalación compatible los tipos nativos `Deer=4`,
`SmallGame=10`, las unidades `VAMP_Deer_C` y las recetas de los objetos
`Stag Carcass=2`, `Venison=331` y `Hides=3`. La carne genérica antigua, objeto
147, no se utiliza. La receta conservada por el juego produce una unidad de
venado y una de pieles por cadáver; el mod clasifica el venado como alimento.

El generador conserva la rama que crea ciervos, pero su entrada de despacho está
deshabilitada. El adaptador 0.1.2 la habilita únicamente durante la región inicial
cuando se elige esa ventaja, y restaura la entrada al pasar a otra región y al
terminar. La prueba generó un nodo rico de ciervos junto con hierro rico, con
15 ciervos iniciales y una sola región personalizada. No aparecieron nodos de
ciervos en las demás regiones; `deer_dispatch=0` confirmó la restauración.

La lógica actual del campamento restringe a conejos la búsqueda de zonas, la
recogida de cadáveres y la receta de carne. Se amplía una copia de esa función,
obtenida de la instalación verificada al arrancar. El perfil distribuido contiene
su huella SHA-256 y metadatos de reubicación y desenrollado de pila; no contiene
una copia de sus instrucciones. Se conservan el resto de decisiones nativas,
incluidas distancias, población de reserva, áreas de trabajo y transporte.
Una tercera entrada de código dirige al campamento a esa copia. Descargar el
mod restaura las tres entradas originales mediante intercambio atómico.

En una partida aislada se construyó y completó un campamento mediante las
funciones del juego y se le asignó una familia. Sin generar ni conceder venado
o pieles por comandos, los cazadores produjeron dos unidades de venado y dos
de pieles. El mismo campamento también produjo carne de caza menor y pieles de
conejo. Se confirmó `isResourceFood(331)=true`. Se concedió comida de caza menor
solo para sostener el asentamiento de prueba; sus cifras regionales podían
disminuir por el consumo, por lo que se comprobaron también el inventario del
campamento y los subproductos.

Guardar y cargar conservó el nodo rico y su posición, los 14 ciervos vivos de ese
momento y las dos unidades de venado y pieles. La sesión acabó con código 0 y
`installed=0`; las huellas y fechas de las partidas personales no cambiaron y
se restauraron las preferencias previas. Las sesiones utilizaron un perfil
separado, prioridad mínima y límite de 15 FPS.

Una última sesión cargó ese guardado con el adaptador definitivo, que obtiene
la función de caza de la memoria de la instalación verificada. Se conservó la
clasificación de venado como alimento y se construyó una curtiduría nativa:
su familia produjo tres unidades de cuero a partir de las pieles. La cadena
ciervo → pieles → cuero quedó comprobada también después de cargar.

Las pruebas automatizadas de 0.3.0 pasan 3.522 comprobaciones y compilan nueve
scripts Lua. Cubren las nuevas combinaciones y preferencias, ambos idiomas y
la instalación/restauración de las recetas, incluidas modificaciones ajenas y
fallos parciales. La DLL se compila con `-Wall -Wextra -Werror`; la herramienta
verifica también la huella de la función nativa de caza.

`tools/generate_hunting_profile.py --exe ...` regenera los metadatos revisables;
requiere `pefile` y `capstone`, además de verificar el ejecutable compatible.
La compilación habitual y las pruebas Lua usan el perfil ya incluido.

Quedan fuera de esta prueba el equilibrio de los ciervos a largo plazo, el
comercio de venado y otras compilaciones del juego. El mod debe permanecer
activo para usar la cadena de producción en partidas con ciervos.

## Alcance de la revisión

Se revisaron el Lua instalado, el adaptador C, el perfil del ejecutable y la
evidencia de las pruebas de generación y fertilidad. La refactorización 0.2.1
conserva la DLL nativa 0.1.1; no altera sus trampolines ni sus direcciones.

Hallazgos corregidos:

1. Una excepción al registrar la interfaz después de inicializar el adaptador
   podía dejarlo activo sin devolver un objeto que pudiera descargarlo.
2. Una excepción al leer el estado del adaptador después de `Init` tampoco
   deshacía su inicialización.
3. Jugar antes del siguiente sondeo aplicaba la selección, pero podía perder
   el guardado de preferencias al actualizar el estado antes de persistirlo.
4. Un error de interfaz detenía el sondeo, pero conservaba hooks y controles
   parcialmente funcionales. Ahora se ejecuta la misma limpieza que al descargar.
5. El repositorio dependía de herramientas externas a él para pruebas y
   compilación. Ahora contiene sus propias herramientas de desarrollo.

## Pruebas automatizadas

`python tests/run.py` compila todos los scripts Lua y comprueba:

- Todas las parejas de opciones, valores no admitidos y límite de dos ventajas.
- Compatibilidad del formato SR1, incluida la selección de fertilidad.
- Exclusión de duplicados sin reconstruir el primer selector.
- Pulsar Jugar antes del sondeo y persistencia inmediata de la selección.
- Limpieza tras fallos de inicio, registro parcial de hooks y lectura de UI.
- Descarga repetida, callbacks posteriores a la descarga y protección de cargas.
- Fallos de escritura de preferencias y del adaptador.

Los objetos de Unreal se sustituyen por dobles en estas pruebas. La presentación
de los widgets y los hooks del ejecutable requieren comprobación dentro del juego.

Resultado de la revisión 0.2.1: 2.366 comprobaciones y siete scripts Lua
compilados, incluida la coincidencia de identificadores entre el catálogo Lua
y los tipos admitidos por el adaptador C.

La herramienta de compilación verificó la huella y las firmas del ejecutable
instalado y compiló el C original con Zig y `-Wall -Wextra -Werror`, escribiendo
el resultado en `build/`. La DLL instalada no fue sustituida.

## Prueba de integración de 0.2.1

Se inició una instancia con perfil separado, prioridad mínima y límite de 15 FPS.
Se verificaron las preferencias existentes, el guardado al pulsar Jugar antes
del sondeo, las flechas nativas, la exclusión de duplicados, el modo aleatorio,
el icono de fertilidad y el contador. Se revisó una captura real a 1536 × 864.

El evento real de Jugar generó una partida con hierro rico y fertilidad en la
región inicial, con un único yacimiento rico de hierro. El adaptador registró
una sola región personalizada. Descargar el mod dos veces dejó los dos puntos
nativos restaurados (`installed=0`). La sesión terminó con código 0; las huellas
y fechas de las partidas personales se conservaron y se restauraron las
preferencias del usuario.

## Localización de 0.2.2

La interfaz consulta `MLGameInstance.Settings.lang_txt`, la clave utilizada por
las tablas de traducción de Manor Lords. Se comprobó que Unreal puede devolver
`en` en `GetCurrentLanguage` mientras el juego muestra los menús en español;
por eso esa función no determina el idioma del panel.
Las variantes de español utilizan el catálogo español; el
resto utiliza inglés. Cada texto también dispone de alternativa inglesa si
falta una entrada en otro catálogo. Los mensajes de diagnóstico conservan su
idioma original.

Las pruebas automatizadas verifican la cobertura de ambos catálogos, las variantes
de idioma, los errores de detección y la alternativa inglesa. Se comprueba la
vista real con dobles de widgets que reinician la selección al reconstruir sus
opciones: traducir conserva los identificadores, el orden visible, el modo y el
formato SR1. También se comprueban los cambios pendientes de sondear, la exclusión
de duplicados y que modificar el segundo selector no reconstruya el primero.

Resultado de 0.2.2: 2.763 comprobaciones y ocho scripts Lua compilados. La DLL
nativa permanece sin cambios.

En una sesión aislada se observó `lang_txt=es_ES` con `GetCurrentLanguage=en`,
y el panel se construyó en español. Usando `MLGameInstance.SetLanguage` se cambió
a `en_US`, `de_DE`, `fr_FR` y de nuevo `es_ES`. El sondeo de producción actualizó
la cabecera, las etiquetas, las opciones, las ayudas y el contador sin perder
las elecciones ni cambiar las preferencias guardadas. También se verificaron
las flechas nativas, la exclusión de duplicados y el modo aleatorio.

Se revisaron capturas reales en español e inglés a 1536 × 864. La sesión usó un
perfil separado, prioridad mínima y límite de 15 FPS, terminó con código 0 y
restauró el adaptador (`installed=0`). Las huellas y fechas de las partidas
personales se conservaron y se restauró el archivo de preferencias previo.

## Fertilidad: evidencia anterior a la refactorización

La prueba se realizó sobre el ejecutable SHA-256
`560451df38cd91134026c25b69539449c570f3163e33bc8c45b4dc20b6952cee`.
Una copia de diagnóstico del adaptador capturó la cuadrícula antes de procesar
la región inicial y al terminar la generación. Se compararon los mismos 708
puntos de Mandlach, clasificados mediante `getRegionByPos`.

En todos esos puntos, los cuatro componentes de la cuadrícula cumplieron
`después = min(antes + 0,35, 1)`. Las medias de los tres componentes consumidos
directamente por trigo, lino y cebada fueron:

| Cultivo | Antes | Después |
| --- | ---: | ---: |
| Trigo | 43,47 % | 78,03 % |
| Lino | 20,49 % | 55,49 % |
| Cebada | 20,44 % | 55,44 % |

La función nativa de fertilidad media de los campos lee esta cuadrícula.
La función auxiliar `hasWeakFertility` consulta una etiqueta antigua; su resultado
no impidió que el generador aplicase la mejora a los datos medidos.

Esta prueba no mide cosechas ni permite afirmar que aumentará la producción
exactamente un 35 %. El diagnóstico no forma parte de la DLL distribuida.

## Compatibilidad

Las partidas y preferencias personales se verifican por separado de la partida
de prueba. Un cambio de ejecutable requiere analizar de nuevo las direcciones,
no modificar únicamente la huella del perfil. El mod no dispone de cobertura
automática para navegación con mando ni otras compilaciones. Las traducciones
del panel cubren español e inglés; los demás idiomas utilizan la alternativa
inglesa.
