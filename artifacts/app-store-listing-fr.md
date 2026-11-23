# Punctual - App Store listing (v1.0.5, French / fr)

Version 1.0.5 adds French (UI and listing). Translated by Claude, **not checked by a native speaker**:
get one pass from a native speaker before relying on it beyond a first test. UI words quoted here
match `fr-1/2/3.json` (Ignorer aujourd’hui, Sonner quand même, Sonne dans, Je suis debout, Vérification du réveil).
Rules (guideline 2.3.7): no price, no discount, no "gratuit" outside the description, no other platform names.
No-break space (U+00A0) before : ; ? ! and inside « ».

Character limits: name 30 · subtitle 30 · promo 170 · keywords 100 · description 4000.
Counts below were measured with Python `len()`. Keywords in UTF-8 bytes (`len(s.encode())`).

## App Name (27/30)
Punctual - Réveil et alarme

## Subtitle (30/30)
Ignorer jours fériés et congés

## Promotional Text (170/170)
Compte à rebours en direct sur chaque alarme, pré-alerte avant qu’elle sonne et un toucher pour ignorer aujourd’hui : celle de demain reste programmée. Basé sur AlarmKit.

## Keywords (94/100)
matin,lever,vacances,semaine,rappel,snooze,sommeil,sonnerie,week-end,travail,posté,calendrier

<!-- Name/subtitle words not repeated: réveil, alarme, ignorer, jour, férié, congé (singular forms; Apple matches accents loosely).
     Picks: matin/lever (waking), vacances/semaine/travail/week-end (holiday and work-week long tail), rappel/snooze
     (Apple's « Rappel d’alarme » and the English word people type), sommeil (sleep), sonnerie.
     1.0.5 (16 Nov 2026): coucher → posté + calendrier. « posté » pairs with « travail » for « travail posté », the
     shift-work search (many apps in autocomplete); calendrier is for calendar auto-skip. The subtitle stays: it has no
     shift promise, and « réveil jours fériés » is a real search.
     "minuteur" dropped: Punctual has no timer (F29). No "app", no brand names. -->

## Description (3997/4000)
Punctual est le réveil intelligent que l’app Horloge d’Apple n’a jamais été. Voyez exactement quand votre alarme sonne, recevez une pré-alerte avant qu’elle ne sonne, et ignorez un seul jour : demain reste programmé.

LE PROBLÈME DE TOUTES LES APPS D’ALARME
iOS ne sait ignorer qu’une seule alarme : celle de réveil de votre programme de sommeil. Pour toutes les autres, un jour de congé ne laisse qu’une option : la désactiver, en espérant penser à la réactiver. Punctual offre à chaque alarme le traitement qu’Apple n’a réservé qu’à une seule.

IGNOREZ AUJOURD’HUI, N’OUBLIEZ PAS DEMAIN
Un toucher ignore uniquement la sonnerie d’aujourd’hui. L’alarme reste activée pour demain, confirmée en vert – « Ne sonnera pas aujourd’hui – reste activée » – et vous pouvez annuler. Ignorez depuis la carte, la pré-alerte ou l’écran verrouillé.

SACHEZ TOUJOURS QUAND ELLE SONNE
Chaque alarme affiche un compte à rebours en direct – « Sonne dans 7 h 42 min » – mis à jour en temps réel, même pendant que vous choisissez l’heure. Fini le calcul mental.

UNE PRÉ-ALERTE AVANT QU’ELLE SONNE
Une notification discrète avant chaque alarme, avec un bouton Ignorer directement dessus. Décidez depuis votre oreiller.

SONNE MÊME EN MODE SILENCIEUX ET AVEC UN MODE CONCENTRATION
Conçu avec AlarmKit d’Apple, Punctual sonne exactement comme l’app Horloge intégrée – malgré le mode silencieux et les modes de concentration.

L’ESSENTIEL, GRATUIT POUR TOUJOURS
Le cœur de l’app – alarmes illimitées, compte à rebours en direct, pré-alerte, « Ignorer aujourd’hui » et rappel d’alarme avec la durée de votre choix jusqu’à 15 minutes – est gratuit. Sans publicité. Sans compte. Sans suivi. Tout reste sur votre appareil.

PUNCTUAL PRO – QUAND VOUS EN VOULEZ PLUS
• Pause vacances : mettez les alarmes en silence sur une période ; elles reprennent automatiquement
• Pré-alerte personnalisée, pré-alertes multiples et vos propres messages
• Rappel d’alarme plus long : jusqu’à 60 minutes, au-delà de la limite système de 15 minutes
• Vérification du réveil : 5 minutes après avoir arrêté une alarme, une notification discrète demande si vous êtes debout. Touchez « Je suis debout », sinon l’alarme sonne encore une fois.
• Groupes d’alarmes : ignorez ou mettez en pause tout un groupe d’un coup
• Saut automatique avec le calendrier : un événement sur toute la journée dans les calendriers choisis ignore l’alarme – avec un avis la veille et un bouton « Sonner quand même »
• Thèmes, couleurs d’accent, icônes d’app alternatives
• Sons personnalisés : importez votre propre audio pour la pré-alerte et l’alarme

Payez au mois, à l’année ou une seule fois à vie. Si vous détestez les abonnements, À vie est à vous pour toujours.

PRIVÉ PAR CONCEPTION
Pas de compte, pas d’analyse, pas de suivi. Vos alarmes ne quittent jamais votre appareil.

UNE REMARQUE HONNÊTE SUR LA FIABILITÉ
Aucune app d’alarme ne peut garantir une sonnerie : c’est iOS qui décide en définitive du déclenchement des alarmes, et un téléphone éteint ou sans batterie ne peut pas sonner du tout. Pour tout ce que vous ne pouvez pas vous permettre de manquer, réglez une seconde alarme indépendante.

Nécessite iOS 26 ou version ultérieure (Punctual repose sur le framework AlarmKit d’Apple).

DÉTAILS DE L’ABONNEMENT
Punctual Pro est disponible en abonnement mensuel ou annuel à renouvellement automatique, ou en achat unique À vie. Le paiement est débité de votre compte Apple à la confirmation. Les abonnements se renouvellent automatiquement, sauf si le renouvellement automatique est désactivé au moins 24 heures avant la fin de la période en cours ; vous pouvez gérer ou résilier à tout moment dans les réglages de votre compte Apple. Les prix actuels sont affichés dans l’app avant l’achat.

Conditions d’utilisation : https://punctualalarm.com/terms.html
Politique de confidentialité : https://punctualalarm.com/privacy.html
Assistance et FAQ : https://punctualalarm.com/support.html

Une question ? contact@arinitsolutions.com · punctualalarm.com

## What's New (v1.0.6)
• Le compte à rebours des widgets de l’écran d’accueil et de l’écran verrouillé se met maintenant à jour en direct, minute par minute, sans ouvrir l’app. Après la sonnerie, le widget passe tout seul à l’alarme suivante.
• Sur l’écran verrouillé, le widget affiche l’heure, le libellé et le compte à rebours chacun sur sa ligne, pour que tout tienne.
• Petites corrections et améliorations.

## What's New (v1.0.5)
• Punctual est maintenant disponible en français.
• Nouveau dans Pro : la vérification du réveil. 5 minutes après avoir touché Arrêter, une notification discrète demande si vous êtes debout. Touchez « Je suis debout », sinon l’alarme sonne encore une fois 2 minutes plus tard.

## Screenshot captions (fr)
Figma slices 1, 3-7 (slice 2 unchanged). Line breaks ( / ) kept.
1. Ignorez aujourd’hui, / sans oublier demain
   Sous-titre : L’alarme qui vous prévient avant de sonner.
3. Sachez toujours / quand elle sonne
   Sous-titre : Un compte à rebours en direct sur chaque alarme. / « Sonne dans 6 h 47 min » / se met à jour en temps réel.
4. Réglez-la en quelques secondes
5. Thèmes, icônes d’app / et réglages par défaut, / à votre façon.
6. Un appui ignore / aujourd’hui ou / demain.
7. Passez à Pro / quand vous voulez
   Sous-titre : Pause vacances, groupes d’alarmes, / pré-alertes personnalisées, thèmes / et vos propres sons.
