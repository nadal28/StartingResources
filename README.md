# Starting Resources 0.2.2

Selector de recursos ricos para la región inicial de una partida nueva de Manor Lords.

## Uso

1. Abre **Nueva partida** y elige mapa, región y posición como siempre.
2. Al final de la lista de ajustes está **Recursos de inicio**.
3. Cambia **Distribución** de **Aleatoria** a **Personalizada** usando las flechas.
4. Elige uno o dos recursos con las flechas y comienza la partida.

Opciones: sal, hierro, arcilla, pesca, bayas, piedra, setas, caza menor y
fertilidad alta. La fertilidad alta ocupa una de las dos elecciones y activa la
ventaja regional de fertilidad del juego.
Se ha comprobado que esa ventaja se conserva al cargar y que suma 35 puntos
porcentuales a la fertilidad inicial del terreno, con un máximo del 100 %, en
la compilación compatible. La comprobación midió los datos utilizados por los
campos; no simuló una cosecha completa.
La pesca utiliza el tipo adecuado para el agua de la región. No permite colocar
pesca en una región donde el juego no encuentra una ubicación válida.
El segundo selector excluye el recurso elegido en el primero. Si cambias el
primero para elegir el recurso que ya estaba en el segundo, el segundo se vacía.
La opción **Al azar** deja esa elección en manos del juego.
El selector recuerda tus preferencias entre sesiones. En modo aleatorio utiliza
la distribución del juego y oculta las dos filas de recursos. Elegir el modo personalizado sin ningún recurso
seleccionado también utiliza la distribución del juego.

## Alcance

- Reutiliza la generación nativa para crear los recursos, sus cantidades y sus
  posiciones. Puede incluir un tipo que no habría salido en la tirada aleatoria.
- Personaliza únicamente la región inicial del jugador, una vez por partida.
- Los demás recursos y regiones siguen las reglas de generación del juego.
- Los recursos creados se guardan con el formato habitual de la partida. Cargar
  una partida conserva lo guardado, aunque hayas cambiado tus preferencias.
- No ofrece previsualización de posiciones ni edición detallada de fertilidad.
- Interfaz con ratón; no incorpora navegación específica de mando.

La interfaz utiliza la cabecera, los selectores con flechas, la tipografía y los
iconos originales del juego. Las etiquetas y los controles se alinean en filas,
con un contador de selecciones y ayuda al pasar el ratón.

El panel sigue el idioma de los textos del juego: español para cualquier variante
de español e inglés para inglés y los idiomas todavía sin traducción. Los títulos,
opciones, ayudas y contador se actualizan también al cambiar el idioma durante la
sesión, conservando las elecciones. Las traducciones están en
`Scripts/resource_setup_locale.lua`; los mensajes de diagnóstico no se traducen.

## Compatibilidad e instalación

Preparado y probado con la instalación Steam pre_release build **26185246** y
su UE4SS actual. El adaptador verifica la huella SHA-256 del ejecutable y los
dos puntos de intervención. En otra compilación se desactiva y lo registra en
`status.txt` / `native-status.txt`.

La carpeta `StartingResources` debe estar en `ue4ss/Mods`, con `enabled.txt`.
No requiere cambiar `mods.txt`. Para desactivarlo, retira `enabled.txt` con el
juego cerrado. Los recursos de partidas ya creadas permanecen guardados.

## Configuración y diagnóstico

`Scripts/config.lua` permite desactivar el mod y establecer las selecciones
iniciales. `preferences.txt`, creado por la interfaz, tiene prioridad sobre esos
valores iniciales. El estado de la sesión se registra en `status.txt` y el del
adaptador nativo en `native-status.txt`.

El adaptador cambia dos puntos de código solo en memoria durante la sesión y
restaura el código al descargarse. No modifica el ejecutable en disco, los
paquetes originales ni los archivos de partidas existentes.

## Desarrollo

Trabaja desde una copia del [repositorio de código](https://github.com/nadal28/StartingResources).
Las pruebas usan Python 3.11 o posterior y Lua 5.4 mediante Lupa:

```powershell
python -m pip install -r requirements-dev.txt
python tests/run.py
```

Para verificar las direcciones y las firmas del ejecutable antes de compilar:

```powershell
python tools/build_native.py --exe "ruta/ManorLords-Win64-Shipping.exe" --verify-only
```

Para compilar, añade `--zig "ruta/zig.exe"` y omite `--verify-only`. El resultado
se escribe en `build/` para poder revisarlo antes de sustituir la DLL instalada.
El perfil solo admite la huella de ejecutable indicada; no se deben reutilizar
las direcciones con otra versión del juego.

`python tools/package.py` genera el ZIP instalable en `dist/`, incluyendo
únicamente los archivos de producción. Las herramientas se ejecutan con prioridad
baja. Consulta [la revisión y validación](docs/VALIDATION.md) para conocer la
cobertura y los límites de las pruebas.
