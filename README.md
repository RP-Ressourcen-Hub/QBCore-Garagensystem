# Fortschrittliches QBCore Garagensystem

Ein umfassendes Garagensystem für FiveM-Server mit QBCore-Framework, das eine leistungsstarke Fahrzeugverwaltung bietet.

## Features

- **Vielfältige Fahrzeugunterstützung**: Verwaltet alle Fahrzeugtypen (Autos, Motorräder, Boote, Flugzeuge, Helikopter)
- **Intuitive Benutzeroberfläche**: Moderne, responsive UI mit Fahrzeugfilterung und Kategorien
- **Garagentypen**: Öffentliche, private, job-spezifische und Gang-Garagen
- **Fahrzeugtransfers**: Übertrage Fahrzeuge zwischen verschiedenen Garagen
- **Beschlagnahmungssystem**: Vollständiges System für polizeiliche Beschlagnahmung und Auslösung
- **Fahrzeugvorschau**: 3D-Vorschau der Fahrzeuge vor dem Ausparken
- **Zustandsspeicherung**: Speichert und stellt Fahrzeugschäden, Kraftstoffstand und Tuning wieder her
- **Zugriffskontrollen**: Job- und Gang-basierte Berechtigungen für spezielle Garagen

## Installation

1. Kopiere den `[qbcore]/[garage]` Ordner in dein Serverressourcen-Verzeichnis
2. Stelle sicher, dass du die "[framework_bridge]" installiert hast
3. Füge `ensure [qbcore]/[garage]` zu deiner `server.cfg` hinzu
4. Starte deinen Server neu

## Voraussetzungen

- QBCore Framework
- [framework_bridge] (für Kompatibilität zwischen ESX und QBCore)
- MySQL oder MariaDB Datenbank

## Konfiguration

Die Konfiguration der Garagen erfolgt in der Datei `config/config.lua`. Hier kannst du:

- Garagenstandorte und -typen festlegen
- Job-/Gang-Berechtigungen konfigurieren
- Fahrzeugtypen für spezifische Garagen einschränken
- Gebühren für Transfer und Beschlagnahme anpassen
- UI-Einstellungen ändern
- Blips und Marker anpassen

### Beispiel für eine Garage-Konfiguration:

```lua
["legion_square"] = {
    label = "Legion Square Garage",
    type = "public",                                     -- public, job, gang
    allowed_jobs = {},                                   -- Nur für bestimmte Jobs (leer = für alle)
    allowed_gangs = {},                                  -- Nur für bestimmte Gangs (leer = für alle)
    allowed_vehicles = {"car", "bike", "bicycle"},       -- Erlaubte Fahrzeugtypen
    max_slots = 0,                                       -- Maximale Stellplätze (0 = unbegrenzt)
    blip = true,                                         -- Blip auf der Karte anzeigen
    spawn_points = {                                     -- Spawn-Punkte für Fahrzeuge
        {
            coords = vector3(215.55, -810.21, 30.73),
            heading = 339.27,
            radius = 6.0                                 -- Radius um zu prüfen, ob Spawn-Punkt frei ist
        }
    },
    parking_point = {                                    -- Punkt zum Einparken von Fahrzeugen
        coords = vector3(230.78, -797.45, 30.58),
        radius = 15.0                                    -- Radius um Fahrzeuge zu erkennen
    },
    menu_point = {                                       -- Punkt zum Öffnen des Garagenmenüs
        coords = vector3(230.78, -797.45, 30.58),
        radius = 3.0                                     -- Interaktionsradius
    }
}
```

## Verwendung

### Spielerbefehle

- `/garage` - Öffnet die Garage, wenn du in der Nähe einer Garage bist, oder parkt dein aktuelles Fahrzeug ein

### Fahrzeuge einparken

Um ein Fahrzeug einzuparken:
1. Fahre das Fahrzeug zum Parkpunkt einer Garage
2. Drücke `E` (oder die konfigurierte Taste) oder verwende den `/garage` Befehl

### Fahrzeuge ausparken

Um ein Fahrzeug auszuparken:
1. Gehe zum Menüpunkt einer Garage
2. Drücke `E` (oder die konfigurierte Taste) oder verwende den `/garage` Befehl
3. Wähle das gewünschte Fahrzeug aus der Liste aus
4. Klicke auf "Ausparken"

### Fahrzeuge übertragen

Um ein Fahrzeug in eine andere Garage zu übertragen:
1. Öffne die Garage, in der sich das Fahrzeug aktuell befindet
2. Wähle das Fahrzeug aus
3. Klicke auf "Übertragen"
4. Wähle die Zielgarage aus und bestätige

### Fahrzeuge aus der Beschlagnahme auslösen

Um ein beschlagnahmtes Fahrzeug auszulösen:
1. Gehe zur Beschlagnahmestation
2. Öffne das Beschlagnahmemenü
3. Wähle das beschlagnahmte Fahrzeug aus
4. Bezahle die Auslösegebühr

## Integration mit anderen Ressourcen

### Framework Bridge

Dieses Garagensystem verwendet die Framework Bridge, um sowohl mit ESX als auch mit QBCore kompatibel zu sein. Die Bridge abstrahiert die framework-spezifischen Aufrufe, so dass das Garagensystem unabhängig vom verwendeten Framework funktioniert.

### Exports

Das Garagensystem bietet verschiedene Exports, die von anderen Ressourcen verwendet werden können:

```lua
-- Client-seitige Exports
exports['qb-garage']:OpenGarage(garageName)               -- Öffnet eine bestimmte Garage
exports['qb-garage']:StoreVehicle(garageName)             -- Parkt ein Fahrzeug in einer bestimmten Garage
exports['qb-garage']:GetPlayerVehicles()                  -- Gibt alle Fahrzeuge des Spielers zurück

-- Server-seitige Exports
exports['qb-garage']:AddVehicle(plate, props, owner)      -- Fügt ein Fahrzeug zur Datenbank hinzu
exports['qb-garage']:RemoveVehicle(plate)                 -- Entfernt ein Fahrzeug aus der Datenbank
exports['qb-garage']:SetVehicleStatus(plate, status)      -- Setzt den Status eines Fahrzeugs
exports['qb-garage']:IsVehicleOwned(plate)                -- Prüft, ob ein Fahrzeug einem Spieler gehört
```

## Events

Das Garagensystem verwendet und sendet verschiedene Events, die von anderen Ressourcen genutzt werden können:

```lua
-- Client-Events
TriggerEvent('qb-garage:hasEnteredMarker', zoneData)     -- Ausgelöst, wenn ein Spieler einen Marker betritt
TriggerEvent('qb-garage:hasExitedMarker', zoneData)      -- Ausgelöst, wenn ein Spieler einen Marker verlässt
TriggerEvent('qb-garage:vehicleSpawned', vehicleData)    -- Ausgelöst, wenn ein Fahrzeug gespawnt wird

-- Server-Events
TriggerEvent('qb-garage:vehicleStored', vehicleData)     -- Ausgelöst, wenn ein Fahrzeug eingepark wird
TriggerEvent('qb-garage:vehicleTransferred', data)       -- Ausgelöst, wenn ein Fahrzeug übertragen wird
```

## Support und Updates

Dieses Garagensystem wird regelmäßig aktualisiert und verbessert. Für Support, Fehlermeldungen oder Funktionsanfragen besuche bitte unseren Discord.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert. Es steht dir frei, es für deinen Server zu verwenden und zu modifizieren.