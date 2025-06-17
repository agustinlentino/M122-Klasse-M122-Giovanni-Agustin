# Teilnehmer/innen des Teams:

| **Klasse**:  | **Team**: |
|--------------|----------|
| PE           | Giovanni, Agustin |

# Anforderungsdefinition mit KI-Einsatz (Meilenstein A)

| Projektname  | **Fachlicher Inhalt:** <br> (Allgemeine Beschreibung) |
|--------------|--------------------------------------------------------|
| Wetter-Automation mit Bash | Dieses Projekt automatisiert die Abfrage und Analyse von Wetterdaten mittels kostenloser APIs. Das System fragt täglich Wetterdaten für einen gewählten Standort ab, analysiert sie (z. B. Temperaturtrend, Regenwahrscheinlichkeit) und erzeugt daraus Logmeldungen oder Warnungen. Optional kann bei Grenzwerten auch eine E-Mail verschickt werden. |

| **Kundennutzen**: | Das Skript liefert automatisch aktuelle Wetterinformationen und kann bei Bedarf Warnmeldungen ausgeben – ideal für Nutzer, die auf Wetterdaten angewiesen sind, z. B. für Beruf, Freizeit oder automatisierte Abläufe (Gartenbewässerung, Kleidungsauswahl, etc.). |
| **Setup und Automation:** | Der Kundendienst ist ein freier Webdienst wie Open-Meteo. Das Bash-Skript läuft auf einem Linux-System (VM oder Raspberry Pi) und wird täglich über einen Cronjob gestartet. Es speichert Rohdaten, analysiert sie, erstellt ein lesbares Ausgabeformat und meldet bei Bedarf Wetterwarnungen. |
| **Detailierte Beschreibung der einzelnen Aspekte:** | - **Konfiguration (.cfg):** Enthält Einstellungen wie Standort, Grenzwerte für Warnungen, API-URL und Mailadresse. <br> - **Get-Prozedur (.raw):** Abfrage der Wetterdaten per `curl`, Antwort wird als JSON gespeichert. <br> - **Verarbeitung (process):** Analyse mit `jq`, z. B. Temperaturvergleich, Regencheck. <br> - **Weiterreichung (.fmt):** Zusammenfassung in Klartext zur Log-Datei und Warn-Datei. <br> - **Sicherheitsaspekte:** API-Key nicht im Code, nur in Konfigdatei; Logs ohne sensible Daten. |
| **(Skizze / Mockup)**:  | [Systemdesign-Diagramm (Miro Board)](https://gitlab.com/ch-tbz-it/Stud/m122/-/blob/main/10_Projekte_LB2/m122-Projekte.rtb) |
| **Erkenntnisse aus der Machbarkeitsabklärung in Bash (oder Python):** | Es wurde erfolgreich getestet, dass Wetter-APIs mit `curl` abgefragt und mit `jq` verarbeitet werden können. JSON-Parsing und String-Vergleiche in Bash sind machbar. Ein Cronjob-Test auf einem Linux-Testsystem war erfolgreich. |

| Kriterien | Angaben|
|-----------|--------|
| **MUSS Kriterien:** <br> (Konkrete Features, die umzusetzen sind) | - API-Abfrage mit `curl` <br> - JSON-Verarbeitung mit `jq` <br> - Konfigurationsdatei verwenden <br> - Logdatei schreiben <br> - Wetterwarnung in Datei ausgeben <br> - Automatisierung über Cronjob <br> - Tests mit verschiedenen API-Ergebnissen (z. B. Regen ja/nein, Temperatur hoch/niedrig) |
| **KANN Kriterien:** <br> (Konkrete Features, die optional sind) | - E-Mail-Versand bei Wetterwarnung <br> - Export als ZIP oder JSON-Datei <br> - Mehrere Städte vergleichen <br> - Darstellung in HTML-Datei oder Web-Interface |

---

**Hinweise:**

-   Ein **UML Aktivitätsdiagramm** wird zur Darstellung des Ablaufs erstellt.
-   Durch **KI** generierter Code wird im Skript dokumentiert (z. B. `# GPT4 erstellt`) und auf Funktion getestet.