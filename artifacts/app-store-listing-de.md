# Punctual - App Store listing (v1.0.5, German / de)

Version 1.0.5 adds German (UI and listing). Translated by Claude, **not checked by a native
speaker**: get one pass from a native speaker before relying on it. UI words quoted here
match `artifacts/l10n-1.0.5/de-*.json` (Heads-up = Vorwarnung, Ring anyway = "Trotzdem klingeln",
Rings in = "Klingelt in", Are you up? check = Wach-Check, I'm up = "Ich bin wach", Snooze = Schlummern,
Lifetime = Einmalkauf). Rules (guideline 2.3.7): no price, no discount, no "kostenlos/gratis" outside
the description, no other platform names.

Character limits: name 30 · subtitle 30 · promo 170 · keywords 100 · description 4000.
Counts measured with Python `len()`. Keywords in UTF-8 bytes (`len(s.encode())`).

## App Name (24/30)
Punctual: Smarter Wecker

## Subtitle (29/30)
Feiertage aus, Arbeitstage an

<!-- 1.0.5 (16 Nov 2026), was "Feiertage, Schichten & Urlaub". Same change as en-US: holidays off, workdays keep
     ringing, no shift promise in the subtitle (the "Wecker & Schichten" apps in autocomplete sell rotations; Punctual has none). -->

## Promotional Text (166/170)
Sieh einen Live-Countdown zu jedem Wecker, erhalte eine Vorwarnung und überspringe mit einem Tipp nur heute – der Wecker für morgen bleibt aktiv. Mit Apples AlarmKit.

## Keywords (100/100)
Alarm,Aufstehen,Countdown,Schlummern,Snooze,Widget,Urlaub,Ferien,Kalender,Brückentag,Schicht,Schlaf

<!-- None repeats a word from the name or subtitle (Punctual, Smarter, Wecker, Feiertage, aus, Arbeitstage, an).
Singular forms. Picks: Alarm (common search word next to Wecker), Aufstehen/Schlaf (waking, sleep),
Schlummern (the iOS word) + Snooze (the word people say), Countdown, Widget ("wecker widget" is searched),
Urlaub/Ferien/Brückentag/Kalender (day-off long tail), Schicht (the one shift word; "wecker schicht" is searched).
1.0.5 (16 Nov 2026) dropped Timer (Punctual has no timer) and Erinnerung (reminder apps). No "App", no brands. -->

## Description (3955/4000)
Punctual ist der smarte Wecker, der Apples Uhr-App nie geworden ist. Sieh genau, wann dein Wecker klingelt, erhalte vorher eine Vorwarnung und überspringe nur einen einzelnen Tag – morgen bleibt der Wecker aktiv.

DAS PROBLEM JEDER WECKER-APP
iOS kann genau einen Wecker überspringen – den Wecker deines Schlafplans. Bei allen anderen Weckern bleibt dir an einem freien Tag nur eine Möglichkeit: ausschalten und hoffen, dass du daran denkst, ihn wieder einzuschalten. Punctual gibt jedem Wecker die Behandlung, die Apple nur einem vorbehalten hat.

HEUTE ÜBERSPRINGEN, MORGEN NIE VERGESSEN
Ein Tipp überspringt nur das heutige Klingeln. Der Wecker bleibt für morgen aktiv, du siehst die Bestätigung in Grün – „Klingelt heute nicht – bleibt aktiv“ – und mit „Widerrufen“ machst du es rückgängig. Überspringe über die Weckerkarte, über die Vorwarnung oder direkt vom Sperrbildschirm.

IMMER WISSEN, WANN ER KLINGELT
Jeder Wecker zeigt einen Live-Countdown – „Klingelt in 7 h 42 min“ –, der sich in Echtzeit aktualisiert, sogar während du noch die Uhrzeit einstellst. Kein Kopfrechnen mehr um Mitternacht.

EINE VORWARNUNG, BEVOR ES KLINGELT
Eine leise Mitteilung vor jedem Wecker, mit einer Schaltfläche zum Überspringen direkt darauf. Entscheide vom Kopfkissen aus, bevor das Klingeln beginnt.

KLINGELT IM STUMMMODUS UND BEI FOKUS
Punctual basiert auf Apples AlarmKit und klingelt genau wie die integrierte Uhr-App – auch im Stummmodus und bei aktivem Fokus.

KOSTENLOS FÜR IMMER
Die Grundfunktionen – unbegrenzt viele Wecker, Live-Countdown, Vorwarnung, „Heute überspringen“ und Schlummern mit eigener Dauer bis zu 15 Minuten – sind kostenlos. Keine Werbung. Kein Konto. Kein Tracking. Alles bleibt auf deinem Gerät.

PUNCTUAL PRO – WENN DU MEHR WILLST
• Urlaubspause: Wecker für einen Zeitraum stummschalten; danach laufen sie automatisch weiter
• Eigene Vorwarnzeit, mehrere Vorwarnungen und eigene Texte
• Längeres Schlummern: bis zu 60 Minuten, über das Systemlimit von 15 Minuten hinaus
• Wach-Check: 5 Minuten nachdem du einen Wecker stoppst, fragt eine leise Mitteilung, ob du wach bist. Tippe auf „Ich bin wach“, sonst klingelt der Wecker noch einmal.
• Weckergruppen: eine ganze Gruppe auf einmal überspringen oder pausieren
• Automatisches Überspringen per Kalender: Ganztägige Termine in den Kalendern, die du auswählst, überspringen den Wecker – mit einem Hinweis vorab und der Schaltfläche „Trotzdem klingeln“
• Designs, Akzentfarben, alternative App-Symbole
• Eigene Töne – importiere deine eigenen Audiodateien für die Vorwarnung und den Wecker

Bezahle, wie du willst: monatlich, jährlich oder einmalig. Wenn du Abos nicht magst, gehört dir Pro mit dem Einmalkauf für immer. Keine Miete für einen Wecker.

PRIVAT ENTWORFEN
Keine Konten, keine Analyse, kein Tracking. Deine Wecker verlassen dein Gerät nie.

EIN EHRLICHER HINWEIS ZUR ZUVERLÄSSIGKEIT
Keine Wecker-App kann garantieren, dass es klingelt – letztlich entscheidet iOS, wann Wecker ausgelöst werden, und ein ausgeschaltetes Gerät oder ein leerer Akku kann gar nicht klingeln. Stelle für alles, was du nicht verpassen darfst, bitte einen zweiten, unabhängigen Wecker.

Erfordert iOS 26 oder neuer (Punctual basiert auf Apples AlarmKit-Framework).

ABO-DETAILS
Punctual Pro ist als monatliches oder jährliches Abo mit automatischer Verlängerung oder als Einmalkauf erhältlich. Die Zahlung wird bei Bestätigung deinem Apple Account belastet. Abonnements verlängern sich automatisch, sofern die automatische Verlängerung nicht mindestens 24 Stunden vor Ende des aktuellen Zeitraums ausgeschaltet wird; du kannst sie jederzeit in den Einstellungen deines Apple Accounts verwalten oder kündigen. Aktuelle Preise werden vor dem Kauf in der App angezeigt.

Nutzungsbedingungen: https://punctualalarm.com/terms.html
Datenschutzerklärung: https://punctualalarm.com/privacy.html
Support & FAQ: https://punctualalarm.com/support.html

Fragen? contact@arinitsolutions.com · punctualalarm.com

## What's New (v1.0.5) (243)
• Punctual gibt es jetzt auch auf Deutsch.
• Neu in Pro: der Wach-Check. 5 Minuten nachdem du auf „Stoppen“ tippst, fragt eine leise Mitteilung, ob du wach bist. Tippe auf „Ich bin wach“, sonst klingelt der Wecker 2 Minuten später noch einmal.

## Screenshot captions (de)
Keep the line breaks (each caption is drawn large).
1. Heute überspringen,
   morgen nie vergessen
   Sub: Der Wecker, der dich warnt, bevor er klingelt.
3. Immer wissen,
   wann er klingelt
   Sub: Ein Live-Countdown bei jedem Wecker.
   „Klingelt in 6 h 47 min“
   aktualisiert sich in Echtzeit.
4. In Sekunden eingestellt
5. Designs, App-Symbole
   und Standards –
   ganz nach deinem Stil.
6. Ein Tipp überspringt
   heute oder
   morgen.
7. Mit Pro starten,
   wenn du so weit bist
   Sub: Urlaubspause, Weckergruppen,
   eigene Vorwarnungen,
   Designs und eigene Töne.
