# Cambios

## 0.3.0

- Nueva ventaja seleccionable: «Caza mayor (ciervos)» / «Big game (deer)», con
  el icono original y el mismo límite de dos ventajas regionales.
- Restaurada la generación nativa de ciervos ricos en la región inicial elegida.
- Ampliada la lógica de los cazadores para admitir ciervos y conejos, transportar
  el cadáver adecuado y utilizar las recetas propias de cada especie.
- Reactivadas la carne de venado como alimento y la producción de pieles.
- Adaptador nativo 0.1.2, con verificación de la función de caza y restauración
  de las tres entradas intervenidas. Se conserva el formato SR1 de preferencias.

## 0.2.2

- La opción sin recurso fijado se muestra como «Al azar» / «Random» para aclarar
  que el juego decide esa elección.
- El panel utiliza español o inglés según el idioma de los textos del juego,
  con inglés como alternativa para idiomas sin traducción.
- Títulos, recursos, opciones, ayudas y contador se actualizan si cambia el idioma
  durante la sesión, conservando las elecciones y su orden en los selectores.
- Separado el catálogo de traducciones del modelo de selección; añadidas pruebas
  de idiomas, traducciones incompletas y actualización de los controles.
- Se conservan la DLL nativa 0.1.1 y el formato SR1 de preferencias.

## 0.2.1

- Separadas la selección de ventajas, las preferencias, el adaptador nativo y
  la creación de la interfaz. El catálogo reúne nombres, identificadores e iconos.
- Al pulsar Jugar se guardan los cambios de selección pendientes de refrescar.
- La inicialización y los errores de interfaz restauran los hooks instalados;
  descargar varias veces el mod no repite la limpieza.
- Un error al escribir preferencias se registra y permite seguir usando la
  selección durante esa sesión.
- Añadidas pruebas de regresión y herramientas de compilación y empaquetado
  independientes de las carpetas de investigación locales.
- Documentada la comprobación controlada de fertilidad. Se conserva la DLL
  nativa 0.1.1 y el formato SR1 de preferencias.

## 0.2.0

- Fertilidad alta como una de las dos ventajas regionales.

## 0.1.2

- Corregida la animación del primer selector al modificar el segundo.
