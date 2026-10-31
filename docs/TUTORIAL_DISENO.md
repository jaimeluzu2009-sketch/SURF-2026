# Escuela del Pacífico — propuesta de modo tutorial BARRELS

Estado actualizado: la ruta inicial «Mi primera ola» YA es jugable localmente,
con siete lecciones (1–6 y la ola completa), menú y progreso. Ver
VALIDACION_ESCUELA_PC.md para implementación y pruebas. Academia avanzada, tubo
y talleres continúan como diseño propuesto. El resto del documento conserva el
diseño objetivo completo; no implica que todos sus módulos estén implementados.

## Idea recomendada

Aprender surfeando, con una tarea por pantalla, instrucciones de una frase y
reintentos en la misma ola. Dos rutas: «Mi primera ola» y «Academia de maniobras».
Lecciones elegibles y repetibles; el usuario puede salir o saltar explicación.
Completar una lección requiere hacer la acción real, no solo pulsar un botón.
Evitar una introducción larga: al iniciar una lección, entrar al agua directamente.

## Navegación propuesta

Menú principal > ESCUELA DEL PACÍFICO > ruta > lección > práctica > resultado.
Tarjetas con nombre, objetivo y estado Pendiente/Practicada/Completada. Botones
«Continuar», «Elegir lección» y «Práctica libre». Resultados: objetivo conseguido,
un consejo de mejora, «Repetir», «Siguiente», «Salir». No publicar botones vacíos.
Las duraciones se decidirán tras pruebas con personas; no hay tiempos medidos aún.

## Contenido y criterio de éxito (objetivos iniciales a calibrar)

| Lección | Consigna visible | Validación propuesta con sistemas reales |
| --- | --- | --- |
| 1. Conoce tu tabla | Mira alrededor y cambia de cámara | Cambiar camera_view; comprobar selección, sin forzar primera persona |
| 2. Remada | Mantén REMAR y avanza hacia la marca | Estado PRONE, desplazamiento y velocidad acumulados durante remada |
| 3. Tomar una ola | Espera la señal y rema con la ola | Transición válida hacia can_stand; no basta mantener botón en seco |
| 4. Ponerse de pie | Pulsa PARARSE cuando esté listo | PRONE > POPUP > RIDING; conservar tiempo real del pop-up |
| 5. Equilibrio | Centra tu peso y sigue la pared | Permanecer RIDING unos segundos con balance en banda segura |
| 6. Giros | Traza un giro hacia la cara y vuelve | Cambio real de trayectoria manteniendo velocidad y equilibrio |
| 7. Bombeo | Alterna compresión y extensión | Incremento de pump_count ya validado por SurfTricks |
| 8. Impulso | Carga y suelta cuando aparezca SUELTA | Despegue real RIDING > AIRBORNE; usa launch_available y carga real |
| 9. Aéreo y recepción | Alinea la tabla antes de tocar el agua | Aterrizaje aprobado por mecánica actual; caída no completa lección |
| 10. Grab y 180° | Agarra, gira y aterriza alineado | Evento validado de maniobra completada, incluyendo aterrizaje |
| 11. Snap y floater | Usa TRUCO en el lugar correcto | Dos ejercicios separados; premio solo tras maniobra validada |
| 12. Encuentra el tubo | Mantente bajo el labio sin tocarlo | in_tube continuo; sin caída ni solo cruzar la entrada un instante |
| 13. Control del tubo | Agarra canto y frena con la mano | Acciones tube_rail y hand_drag verificadas en intentos separados |
| 14. Salida del tubo | Recupera velocidad y busca la salida | Señal tube_exit con duración mínima; caer al final no cuenta |
| 15. Encadena | Une dos maniobras diferentes | Combo real de ScoreKeeper; explicar repetición y pérdida por caída |
| 16. Tu primera línea | Recorre una ola completa | Resultado real de ola completada y sin caída |

Complementos opcionales dentro de la escuela:
- Taller de surfista/tabla: abrir personalización, cambiar ropa/color y confirmar
  que el perfil conserva la elección. No otorgar XP por repetir cambios.
- Configurar controles: tamaño, opacidad, zurdo, sensibilidad, zona muerta, teclas
  y mando. Las consignas deben mostrar la tecla reasignada o acción táctil actual.
- Calidad/accesibilidad: mostrar reducción de movimiento y alto contraste sin
  exigir activar ningún ajuste. El tutorial no debe bloquear por no usar táctil.
- Carrera/logros/récords: explicar usando datos reales; no inventar tiendas,
  monedas, equipos ni desbloqueos que el juego no tenga.

## Spots y dificultad

Montañita para primera ola y giros; La FAE para reconocer la izquierda y series;
La Rinconada para el bloque de tubo. Versiones de práctica suaves usarían una
copia de parámetros de sesión, nunca modificar los spots originales en disco.
Introducir izquierda/derecha explícitamente; no repetir la misma consigna para
todos los spots. Conservar WaveModel y las condiciones reales de despegue.

## Diseño de pantalla horizontal

- Arriba izquierda: ESCUELA / lección actual y progreso «4 de 16».
- Arriba centro: una sola instrucción, breve y de alto contraste.
- Arriba derecha: pausa y salida. Cámara conserva acceso sin tapar el objetivo.
- Centro: agua y surfista despejados; marca de destino discreta cuando haga falta.
- Abajo: joystick y los DOS botones contextuales existentes, sin nuevos botones
  de maniobra. Realzar solo el control necesario; no cambiar las áreas de toque.
- Durante la lección sustituir retos de carrera por objetivo tutorial. Mensajes
  secundarios se ocultan al aprender, y se muestran otra vez al salir del modo.
- Confirmación: «¡Lo tienes!» + objetivo cumplido; no abrir un panel que tape una
  maniobra en curso. Esperar a zona segura o final de intento para ofrecer siguiente.
- Tras una caída: causa concreta y «Reintentar», sin vidas ni penalización de carrera.

Colores: azul Pacífico para paneles, arena para texto, turquesa para objetivo y
coral solo para el momento de actuar. Motivos costeros existentes, sin nuevas
fuentes o dependencias. La indicación SUELTA aparece solo si la mecánica permite
despegar; porcentaje de carga no equivale a permiso para saltar.
Ayudas sin audio obligatorio, sin basarse solo en color y con reduce_motion.

## Flujo de cada ejercicio

PREPARAR > CONSIGNA > PRACTICAR > VALIDAR > COMPLETAR / REINTENTAR.
Reinicio de checkpoint debe restablecer ola, velocidades, timers, charge, combo y
acciones enclavadas; no solo teletransportar la malla. El tiempo de pausa no cuenta.
Si cambia el dispositivo de entrada, refrescar la consigna sin perder progreso.
Si se desconecta el mando, respetar la pausa del juego.

## Integración objetivo (ruta inicial implementada; academia/talleres pendientes)

- Un coordinador TutorialSession y datos de lecciones independientes, conectado a
  Game/Surfer/SurfTricks/ScoreKeeper, sin duplicar física ni controles.
- Guardado separado de progreso de tutorial en Perfil o archivo específico;
  definir migración segura y versión del formato. Nunca sobrescribir perfil existente.
- Sesiones tutorial fuera de récords competitivos y sin farming de XP. La lógica
  actual que registra resultados necesitará un contexto explícito de práctica.
- Reusar UI Kit, menús y controles; restaurar HUD/configuración al salir, reiniciar
  o cambiar spot. Mantener Modo PLAY como gameplay o extender de forma acotada.
- No leer campos privados de SurfTricks desde cada pantalla; exponer eventos o
  consultas de progreso cuando falten observables públicos.
- Sin voz generada, fantasmas, flechas de trayectoria complejas ni ayudas físicas
  automáticas en la primera implementación; se valorarían después.

## Orden recomendado de implementación

1. Ruta «Mi primera ola»: lecciones 1–6 y 16, menú, progreso y reintento seguro.
2. Academia: bombeo, impulso y maniobras, con validación de recepción real.
3. Tubo, combo y talleres; calibrar con el POCO F7 Pro y mando en web.

Pruebas necesarias: acción fuera de contexto no completa objetivos; caer no
concede maniobra; pausa/reintento/cambio de spot restauran estado; retomar progreso
tras cerrar; reasignación de teclas; zurdo y multitáctil; foco/desconexión de mando;
opacidad y distintas resoluciones; cero cambios involuntarios en récords/XP.
Las capturas de este modo deberán salir de Godot cuando esté implementado.
