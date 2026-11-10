# Revisión y validación

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
automática para navegación con mando, otros idiomas ni otras compilaciones.
