# Koha Syspref Defaults

Deutsch | [English](README.md)

Nur lesendes Koha-Plugin zum Vergleich der gespeicherten Systemeinstellungen mit
den Installationsdefaults der **lokal installierten Koha-Version**.
Version 0.2.0; vorgesehen für Koha ab 24.11. Oberfläche auf Deutsch und Englisch.

## Installation und Verwendung

`koha-syspref-defaults-0.2.0.kpz` über die Koha-Pluginverwaltung installieren und
**Werkzeug ausführen** wählen. Benötigt `plugins.tool` und
`parameters.manage_sysprefs` oder `superlibrarian`. Die Berechtigung zur
Installation ist davon getrennt.

Die Tabelle zeigt gespeicherte Werte, Basisdefaults, Abweichungen und die im
aktuellen Staff-Webprozess sichtbaren `OVERRIDE_SYSPREF_*`-Werte. Standardmäßig
werden Abweichungen und Overrides angezeigt. Suche und Statusfilter grenzen die
Anzeige ein; Einstellungsnamen verlinken auf Kohas normalen Einstellungseditor.
Das Plugin selbst speichert, restauriert und exportiert keine Einstellungen.

Die Sprache folgt der gewählten Koha-Staff-Sprache; `de-DE`/`de-AT` werden Deutsch,
`en-GB`/`en-US` Englisch zugeordnet. Für nicht unterstützte Sprachen wird Englisch
verwendet. Die Links **Deutsch / English** wechseln nur die aktuelle Plugin-Seite,
ohne Koha-Einstellungen oder Cookies zu ändern. Dafür müssen keine deutschen
Koha-Templates installiert sein; die umgebende Koha-Navigation behält ihre Sprache.

## Quelle und Grenzen

- Liest `installer/data/mysql/mandatory/sysprefs.sql` unter Kohas `intranetdir`;
  ältere Pfadstruktur: `installer/data/mysql/sysprefs.sql`. Keine Downloads oder
  mitgelieferten Default-Snapshots. Die SQL-Datei wird niemals ausgeführt.
- Zeigt Quellpfad, SHA-256 sowie Code- und Datenbankversion. Bei unterschiedlichen
  Versionen erscheint eine Warnung. Lokale Änderungen der Quelldatei werden
  mitgelesen; die Prüfsumme belegt keine Übereinstimmung mit Upstream.
- Verglichen werden Basisdefaults einer Neuinstallation, nicht die ursprüngliche
  Bibliothekskonfiguration oder deren Änderungshistorie. Sprach-/MARC-Auswahl,
  Installer-Anpassungen und Laufzeitwerte können berechtigte Abweichungen erzeugen.
  `Version` wird separat angezeigt und nicht mitgezählt.
- Exakter Zeichenkettenvergleich: NULL, leerer Text, Null, Leerzeichen und
  Zeilenumbrüche bleiben verschieden. Einstellungsnamen werden ohne Beachtung
  der Groß-/Kleinschreibung zugeordnet. Unbekannte SQL-Syntax bricht den Vergleich ab.
- Overrides betreffen nur den aktuellen Staff-Webprozess, nicht OPAC, SIP oder
  Hintergrundprozesse. Ein Override ändert nicht den Status des gespeicherten Werts.
- Erkannte Zugangswerte werden vor Übergabe ans Template maskiert. Die Erkennung
  ist vorsorglich, aber nicht vollständig; Freitext kann weitere vertrauliche Daten
  enthalten. Anzeige vor Weitergabe prüfen. HTML/JavaScript wird escaped; die
  Antwort verwendet `no-store`. Keine Funktion zum Einblenden maskierter Werte.
- Installation/Upgrade registriert normale Koha-Plugin-Metadaten. Die
  Lifecycle-Hooks ändern keine Systemeinstellungen und legen keine Tabellen an.

## Übersetzungen

Alle Oberflächentexte liegen als UTF-8-JSON unter
`Koha/Plugin/HKS3/SysprefDefaults/i18n/`: Englisch in `en.json`, Deutsch in `de.json`.
Einstellungsnamen und tatsächliche Werte werden nicht übersetzt. Die Metadaten in
der Pluginliste bleiben Englisch. Interne Parserdiagnosen werden nicht angezeigt.

Für weitere Sprachen `en.json` nach `<sprachcode>.json` kopieren und die Werte
übersetzen, nicht die Schlüssel. `{count}` in `visible_one`/`visible_other`
beibehalten. Fehlende Schlüssel fallen auf Englisch zurück. Optional den
Sprachumschalter im Template ergänzen und die Tests erweitern. Die Pluralregel
lautet derzeit „Einzahl bei 1, sonst Mehrzahl“; andere Sprachregeln erfordern eine
Anpassung des Zählers. Kein Kompilieren von PO-Dateien oder Umbau der
Koha-Übersetzungen erforderlich.

## Tests und Paketbau

```sh
prove -lr t
node --test t/filter.test.cjs
KOHA_SOURCE=/pfad/zu/koha prove -lv t/compare.t
perl scripts/build-kpz.pl
unzip -t dist/koha-syspref-defaults-0.2.0.kpz
```

Die Tests verwenden Fixtures und Mocks, keine Produktionsdatenbank.
Benötigt werden Perl, Modern::Perl, Template Toolkit und IO::Compress::Zip;
Node.js nur für den JavaScript-Test. Der optionale Laufzeittest
`scripts/smoke-readonly.pl` arbeitet innerhalb einer Read-only-Transaktion und
installiert das Plugin nicht. Mit `PLUGIN_LANGUAGE=de` bzw. `en` beide Sprachen
prüfen; in einer vorhandenen Testinstanz über `koha-shell` ausführen.

## GitHub

Der vorbereitete Workflow führt Tests und Paketbau bei Pushes, Pull Requests und
manueller Auslösung aus. Das KPZ wird als Actions-Artefakt bereitgestellt. Ein
gepushter Tag `v<version>` erzeugt zusätzlich ein GitHub-Release mit KPZ und
SHA-256-Datei; Tag und Modulversion müssen übereinstimmen. Nur der Release-Job
erhält Schreibrechte. `dist/` wird nicht eingecheckt.

Remote-Repository, Veröffentlichung und Push sind separate Schritte.
Weitere technische Details und recherchierte Alternativen: [English README](README.md).

Lizenz: GPL-3.0-or-later.
