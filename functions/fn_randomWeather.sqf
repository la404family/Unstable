#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Randomise la météo et l'heure de début de mission à chaque run.
      Garantit des conditions jouables : brouillard plafonné à 0.15,
      vent cohérent avec les nuages, six presets pondérés.

      Presets disponibles (probabilité) :
        0 — Clair          (28%) : ciel dégagé, brise légère
        1 — Nuageux        (22%) : couverture partielle, calme
        2 — Couvert        (20%) : ciel chargé, vent modéré
        3 — Pluie légère   (15%) : averse fine, vent soutenu
        4 — Tempête        (10%) : forte pluie, vent violent, éclairs
        5 — Brume matinale  (5%) : brume basse, calme absolu

      Heure : 04h00 → 19h30 (aléatoire)
      Fog   : max 0.15 — jamais excessif      Éclairs : gérés automatiquement par le moteur (preset Tempête = overcast + rain élevés).
              setLightnings n'est PAS utilisé — commande non reconnue de façon fiable.
    Locality:
      Serveur uniquement (isServer guard).
      La météo Arma 3 est synchronisée automatiquement vers tous les
      clients par le moteur — aucun remoteExec nécessaire.
      Les joueurs JIP reçoivent les conditions au moment de leur connexion.
*/

if (!isServer) exitWith {};

// ── Heure de mission aléatoire ──────────────────────────────────────────────
private _d      = date;                         // [year, month, day, hour, minute]
private _hour   = 4 + floor (random 16);        // 4–19
private _minute = floor (random 60);            // 0–59
if (_hour == 19) then { _minute = floor (random 31); }; // plafond 19:30

setDate [_d select 0, _d select 1, _d select 2, _hour, _minute];

diag_log format ["[LL][Weather] Heure de mission : %1h%2", _hour, _minute];

// ── Sélection pondérée du preset météo ─────────────────────────────────────
// [overcast_min, overcast_max, fog_max, rain_max, wind_max, label]
private _presets = [
    [0.00, 0.25, 0.04, 0.00,  4.0, "Clair"         ],  // 0 — 28%
    [0.30, 0.60, 0.07, 0.00,  7.0, "Nuageux"        ],  // 1 — 22%
    [0.60, 0.85, 0.10, 0.05, 10.0, "Couvert"        ],  // 2 — 20%
    [0.75, 0.92, 0.12, 0.35, 14.0, "Pluie légère"   ],  // 3 — 15%
    [0.90, 1.00, 0.15, 0.80, 25.0, "Tempête"        ],  // 4 — 10%  (éclairs auto moteur)
    [0.00, 0.30, 0.15, 0.00,  2.0, "Brume matinale" ]   // 5 —  5%
];

private _roll = floor (random 100);  // 0–99
private _idx  = switch true do {
    case (_roll < 28): { 0 };
    case (_roll < 50): { 1 };
    case (_roll < 70): { 2 };
    case (_roll < 85): { 3 };
    case (_roll < 95): { 4 };
    default            { 5 };
};

private _p           = _presets select _idx;
private _overcastMin = _p select 0;
private _overcastMax = _p select 1;
private _fogMax      = _p select 2;
private _rainMax     = _p select 3;
private _windMax     = _p select 4;
private _label       = _p select 5;

// ── Valeurs finales aléatoires dans la plage du preset ─────────────────────
private _overcast = _overcastMin + random (_overcastMax - _overcastMin);
private _fog      = random _fogMax;
private _rain     = random _rainMax;

// Vecteur vent : angle aléatoire + vitesse dans [0, windMax]
private _windAngle = random 360;
private _windSpeed = random _windMax;
private _windX     = _windSpeed * sin _windAngle;
private _windY     = _windSpeed * cos _windAngle;

// ── Application immédiate (transition 0 s) ─────────────────────────────────
0 setOvercast _overcast;
0 setFog      _fog;
0 setRain     _rain;         // setRain est binaire uniquement en Arma 3 : transitionTime setRain value
setWind       [_windX, _windY];
// setLightnings omis : éclairs automatiques moteur (overcast/rain élevés suffisent)
forceWeatherChange;

diag_log format [
    "[LL][Weather] Preset=%1 | overcast=%2 | fog=%3 | rain=%4 | vent=%5 m/s @%6 deg",
    _label, _overcast, _fog, _rain, _windSpeed, _windAngle
];
