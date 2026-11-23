# Punctual - App Store listing (v1.0.5, Spanish / es-ES, Spain storefront)

Version 1.0.5 adds a Spanish UI (one neutral catalog, "tú", for Spain and Latin America). UI words
quoted here match `es-1/2/3.json` exactly. Translated by Claude, **not checked by a native speaker**:
get one pass from a native speaker before relying on it. The description is shared between
`app-store-listing-es-ES.md` and `app-store-listing-es-MX.md`, except that es-MX uses Latin American terms
(cuenta regresiva, configuración, modo de enfoque); name, subtitle, promo and keywords differ.
Rules (guideline 2.3.7): no price, no discount, no "gratis"/"gratuito" outside the description, no other platform names.

Character limits: name 30 · subtitle 30 · promo 170 · keywords 100 · description 4000.
Counts measured with Python `len()`. Keywords in UTF-8 bytes (`len(s.encode())`).

## App Name (30/30)
Punctual: Alarma y despertador

## Subtitle (26/30)
Laborables sí, festivos no

<!-- 1.0.5 (16 Nov 2026), was "Omite un día, turnos, festivos". Same change as en-US: holidays skipped, workdays
     keep ringing, no shift promise. "Solo laborables, sin festivos" was rejected: it can read as "only workday alarms". -->

## Promotional Text (155/170 - editable anytime without review)
Cuenta atrás en vivo en cada alarma, un aviso previo antes de que suene y Omitir hoy con un toque: la de mañana sigue activa. Creada con AlarmKit de Apple.

## Keywords (100/100)
cuenta atrás,pausa,vacaciones,trabajo,madrugar,posponer,recordatorio,calendario,puente,reloj,turnos

<!-- Spain: 'puente' (the long weekend people plan around) and 'madrugar'; 'festivos' is in the subtitle so it is not repeated. 'cuenta atrás' is the Spain phrase (the shared UI says 'cuenta regresiva'). 'turnos' (shift work; "despertador turnos" is searched) moved here from the subtitle in 1.0.5, replacing 'dormir'. No word repeats name (punctual, alarma, despertador) or subtitle (laborables, sí, festivos, no). -->

## Description (3927/4000)
Punctual es la alarma inteligente que el Reloj de Apple nunca llegó a ser. Mira exactamente cuándo suena tu alarma, recibe un aviso previo antes de que lo haga y omite solo un día: la de mañana sigue activa.

EL PROBLEMA DE TODAS LAS APPS DE ALARMA
iOS solo puede omitir una alarma: la de despertar de tu Horario de sueño. Para cualquier otra alarma, un día libre te deja una sola opción: desactivarla y esperar que te acuerdes de volver a activarla. Punctual da a cada alarma el trato que Apple reservó para una sola.

OMITE HOY, SIN OLVIDAR MAÑANA
Un toque omite solo el sonido de hoy. La alarma sigue activa para mañana, lo ves confirmado en verde (“No sonará hoy: sigue activa”) y puedes Deshacer si cambias de idea. Omite desde la tarjeta de la alarma, desde la notificación de aviso previo o directamente desde la pantalla bloqueada.

SIEMPRE SABRÁS CUÁNDO SUENA
Cada alarma muestra una cuenta atrás en vivo (“Suena en 7h 42m”) que se actualiza en tiempo real, incluso mientras eliges la hora. Se acabó hacer cuentas a medianoche.

UN AVISO PREVIO ANTES DE QUE SUENE
Una notificación discreta antes de cada alarma, con un botón Omitir justo en ella. Decide desde la almohada, antes de que empiece a sonar.

SUENA CON EL MODO SILENCIO Y LA CONCENTRACIÓN
Creada con AlarmKit de Apple, Punctual suena igual que el Reloj integrado: incluso con el modo silencio y con la Concentración activados.

GRATUITA PARA SIEMPRE
La experiencia básica (alarmas ilimitadas, cuenta atrás en vivo, aviso previo, Omitir hoy y posposición con tu propia duración de hasta 15 minutos) es gratuita. Sin anuncios. Sin cuenta. Sin rastreo. Todo se queda en tu dispositivo.

PUNCTUAL PRO: CUANDO QUIERES MÁS
• Pausa por vacaciones: silencia las alarmas durante un intervalo de fechas; se reanudan solas
• Momento del aviso previo personalizado, varios avisos previos y tus propios mensajes
• Posposición más larga: hasta 60 minutos, más allá del límite de 15 del sistema
• Grupos de alarmas: omite o pausa un conjunto entero a la vez
• Omisión automática por calendario: los eventos de todo el día de los calendarios que elijas omiten la alarma, con un aviso antes y un botón Sonar de todos modos
• Confirmación de despertar: 5 minutos después de detener una alarma, una notificación discreta te pregunta si ya te levantaste. Toca “Ya me levanté” o la alarma suena una vez más.
• Temas, colores de acento e iconos de app alternativos
• Sonidos personalizados: importa tu propio audio para el aviso previo y la alarma

Paga como prefieras: mensual, anual o una compra única De por vida. Si odias las suscripciones, De por vida es tuya para siempre. Sin alquilar un despertador.

PRIVADA POR DISEÑO
Sin cuentas, sin analíticas, sin rastreo. Tus alarmas nunca salen de tu dispositivo.

UNA NOTA HONESTA SOBRE LA FIABILIDAD
Ninguna app de alarmas puede garantizar que suene: en última instancia, iOS decide cuándo se activan las alarmas, y un dispositivo apagado o sin batería no puede sonar en absoluto. Para cualquier compromiso que no puedas perderte, programa una segunda alarma independiente.

Requiere iOS 26 o posterior (Punctual está creada con el framework AlarmKit de Apple).

DETALLES DE LA SUSCRIPCIÓN
Punctual Pro está disponible como suscripción mensual o anual con renovación automática, o como compra única De por vida. El pago se carga a tu cuenta de Apple al confirmar la compra. Las suscripciones se renuevan automáticamente salvo que desactives la renovación automática al menos 24 horas antes de que termine el periodo actual; puedes gestionarlas o cancelarlas en cualquier momento en los ajustes de tu cuenta de Apple. Los precios actuales se muestran en la app antes de comprar.

Condiciones de uso: https://punctualalarm.com/terms.html
Política de privacidad: https://punctualalarm.com/privacy.html
Ayuda y preguntas frecuentes: https://punctualalarm.com/support.html

¿Preguntas? contact@arinitsolutions.com · punctualalarm.com

## What's New (v1.0.6)
• La cuenta atrás de los widgets de la pantalla de inicio y la pantalla bloqueada ahora se actualiza en vivo, minuto a minuto, sin abrir la app. Cuando suena una alarma, el widget pasa solo a la siguiente.
• En la pantalla bloqueada, el widget muestra la hora, la etiqueta y la cuenta atrás cada una en su línea, para que todo quepa.
• Pequeñas correcciones y mejoras.

## What's New (v1.0.5)
• Punctual ya está disponible en español.
• Novedad en Pro: la confirmación de despertar. 5 minutos después de tocar Detener, una notificación discreta te pregunta si ya te levantaste. Toca “Ya me levanté” o la alarma suena una vez más 2 minutos después.

## Screenshot captions (es)
1. Omite hoy, / sin olvidar mañana
   Sub: La alarma que te avisa antes de sonar.
3. Siempre sabrás / cuándo suena
   Sub: Una cuenta atrás en vivo en cada alarma. / “Suena en 6h 47m” / se actualiza en tiempo real.
4. Prográmala en segundos
5. Temas, iconos / y preferencias / a tu manera.
6. Un toque omite / hoy o / mañana.
7. Hazte Pro / cuando quieras
   Sub: Pausa por vacaciones, / grupos de alarmas, / avisos previos personalizados, / temas y tus propios sonidos.
