---

# Teilnehmer/innen des Teams

| **Klasse** | **Team**          |
| ---------- | ----------------- |
| PE-24c     | Giovanni, Agustin |

---

# Anforderungsdefinition mit KI-Einsatz (Meilenstein A)

| **Projektname**                | **Fachlicher Inhalt**                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Wetter-Automation mit Bash** | Dieses Projekt automatisiert die Abfrage und Analyse von Wetterdaten mittels kostenloser APIs. Das System fragt täglich Wetterdaten für einen gewählten Standort ab, analysiert sie (z. B. Temperaturtrend, Regenwahrscheinlichkeit) und erzeugt daraus Logmeldungen oder Warnungen. Optional kann bei Grenzwerten auch eine E-Mail verschickt werden. |

---

### Kundennutzen

Das Skript liefert automatisch aktuelle Wetterinformationen und kann bei Bedarf Warnmeldungen ausgeben – ideal für Nutzer, die auf Wetterdaten angewiesen sind, z. B. für Beruf, Freizeit oder automatisierte Abläufe (Gartenbewässerung, Kleidungsauswahl etc.).

---

### Setup und Automation

* Der Dienst basiert auf einem freien Webservice wie **Open-Meteo**.
* Das **Bash-Skript läuft auf einem Linux-System** (z. B. VM oder Raspberry Pi).
* Ein täglicher **Cronjob** startet das Skript automatisch.
* Funktionen: Rohdaten abfragen, analysieren, lesbar ausgeben und bei Bedarf warnen.

---

### Detaillierte Beschreibung der einzelnen Aspekte

* **Konfiguration (`.cfg`)**
  Enthält Standort, Grenzwerte, API-URL, E-Mail-Adresse etc.

* **Get-Prozedur (`.raw`)**
  Abfrage der Wetterdaten per `curl`, Speicherung als JSON.

* **Verarbeitung (`process`)**
  Analyse mit `jq` – Temperaturvergleich, Regencheck etc.

* **Weiterreichung (`.fmt`)**
  Zusammenfassung der Daten in einer Log- und einer Warn-Datei.

* **Sicherheitsaspekte**
  Kein API-Key im Code – nur in der `.cfg`-Datei; Logs enthalten keine sensiblen Daten.

---

### (Skizze / Mockup)

🗂️ [Systemdesign-Diagramm (Miro Board)](https://gitlab.com/ch-tbz-it/Stud/m122/-/blob/main/10_Projekte_LB2/m122-Projekte.rtb)

---

### Erkenntnisse aus der Machbarkeitsabklärung

* Wetter-API erfolgreich mit `curl` abgefragt
* Verarbeitung des JSONs mit `jq` getestet
* String-Vergleiche in Bash funktionieren wie geplant
* Cronjob-Test auf Linux-System war erfolgreich

---

### Kriterien

| **MUSS-Kriterien**                                            | **KANN-Kriterien**                       |
| ------------------------------------------------------------- | ---------------------------------------- |
| - API-Abfrage mit `curl`                                      | - E-Mail-Versand bei Wetterwarnung       |
| - JSON-Verarbeitung mit `jq`                                  | - Export als ZIP oder JSON               |
| - Nutzung einer `.cfg`-Konfigurationsdatei                    | - Vergleich mehrerer Städte              |
| - Schreiben einer Logdatei                                    | - Darstellung in HTML oder Web-Interface |
| - Ausgabe von Wetterwarnungen in separater Datei              |                                          |
| - Automatisierung durch Cronjob                               |                                          |
| - Tests mit Regen/kein Regen und hohen/niedrigen Temperaturen |                                          |

---

### Hinweise

* Ein **UML-Aktivitätsdiagramm** wird zur Darstellung des Ablaufs erstellt.
* Durch **KI generierter Code** wird im Skript kommentiert (z. B. `# GPT-4 erstellt`) und funktional getestet.

---

✅ **#GPT-4o erstellt** 

---
