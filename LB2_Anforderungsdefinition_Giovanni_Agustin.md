## Team

| Klasse | Team              |
| :----: | :---------------- |
| PE-24c | Giovanni, Agustin |

---

## Anforderungsdefinition mit KI-Einsatz (Meilenstein A)

| Projektname                 | Fachlicher Inhalt |
| :-------------------------- | :---------------- |
| **Wetter-Automation mit Bash** | Dieses Projekt automatisiert die Abfrage und Analyse von Wetterdaten mittels kostenloser APIs. Das System fragt täglich Wetterdaten für einen gewählten Standort ab, analysiert sie (z. B. Temperaturtrend, Regenwahrscheinlichkeit) und erzeugt daraus Logmeldungen oder Warnungen. Optional kann bei Grenzwerten auch eine E-Mail verschickt werden. |

---

### Kundennutzen

Das Skript liefert automatisch aktuelle Wetterinformationen und kann bei Bedarf Warnmeldungen ausgeben – ideal für Nutzer, die auf Wetterdaten angewiesen sind, etwa für Beruf, Freizeit oder automatisierte Abläufe (z. B. Gartenbewässerung, Kleidungsauswahl).

---

### Setup & Automation

* Freier Webservice **Open-Meteo**
* **Bash-Skript** läuft auf einem Linux-System (VM, Raspberry Pi u. a.)
* Täglicher **Cronjob** startet das Skript automatisch
* Funktionen: Daten holen, analysieren, ausgeben, Warnungen erzeugen

---

### Detaillierte Aspekte

| Baustein                      | Zweck |
| :---------------------------- | :---- |
| **Konfiguration (`.cfg`)**    | Standort, Grenzwerte, API-URL, E-Mail usw. |
| **Get-Prozedur (`curl`)**     | Wetterdaten abrufen, als JSON speichern |
| **Verarbeitung (`jq`)**       | Temperatur- & Regenanalyse, Grenzwerte prüfen |
| **Weiterreichung (Log/Warn)** | Ergebnisse in Log- bzw. Warn-Dateien schreiben |
| **Sicherheitsaspekte**        | Keine API-Keys im Code; Logs enthalten keine sensitiven Daten |

---

### Skizze / Mock-up

🗂️ [Systemdesign-Diagramm (Miro Board)](https://miro.com/app/board/uXjVIn7XoJ4=/?share_link_id=200344253516)

---

### Erkenntnisse der Machbarkeitsabklärung

* Wetter-API erfolgreich mit `curl` abgefragt  
* JSON-Verarbeitung mit `jq` getestet  
* String-Vergleiche in Bash funktionieren wie geplant  
* Cronjob-Test auf Linux war erfolgreich

---

### Kriterien

| **MUSS-Kriterien**                                 | **KANN-Kriterien**             |
| :------------------------------------------------- | :----------------------------- |
| API-Abfrage mit `curl`                             | E-Mail-Versand bei Warnung     |
| JSON-Verarbeitung mit `jq`                         | Export als ZIP oder JSON       |
| Nutzung einer `.cfg`-Datei                         | Vergleich mehrerer Städte      |
| Schreiben einer Logdatei                           | Darstellung in HTML/Web-GUI    |
| Ausgabe von Wetterwarnungen in separater Datei     |                                |
| Automatisierung durch Cronjob                      |                                |
| Tests: Regen/kein Regen, hohe/niedrige Temperaturen|                                |

---

### Hinweise

* Ein **UML-Aktivitätsdiagramm** zeigt den Ablauf.  
* KI-generierter Code wird klar kommentiert (z. B. `# GPT-4 erstellt`) und funktional getestet.

---

# ==============================================================================
# Dokumentstatus : Teilweise KI-generiert & manuell überarbeitet
# KI-Beteiligung : 6 / 10 (10 = vollständig KI-generiert · 0 = ausschließlich menschlich)
# Verwendetes Modell: OpenAI GPT-4o-latest (ChatGPT)
# ==============================================================================

