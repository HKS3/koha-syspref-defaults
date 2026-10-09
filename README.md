# Koha Syspref Defaults

[Deutsch](README.de.md) | English

Read-only tool plugin comparing stored system preferences with the installation
defaults shipped with the **running Koha code**, not the latest upstream release.
Version 0.2.0; targets Koha 24.11 and later. English and German interface.

## Use

Install `koha-syspref-defaults-0.2.0.kpz` using Koha's plugin manager, then
choose **Run tool**. Requires `plugins.tool` and `parameters.manage_sysprefs`,
or `superlibrarian`. Installation permission is separate.

The table displays stored/default values, changed/equal/missing/extra status,
and `OVERRIDE_SYSPREF_*` values visible to this staff request. The default
filter shows differences and overrides. Search includes names and displayed
values; links lead to Koha's normal preferences editor. This plugin itself
has no save, restore, export, migration or network operation.

The plugin follows the current Koha staff language (including regional variants
such as `de-DE` and `en-GB`) and falls back to English for unsupported languages.
**Deutsch / English** links override the plugin language for the current page,
without changing Koha's language settings or requiring installed German Koha
templates. Koha's surrounding navigation keeps its own language.

## Reference and limitations

- Reads `C4::Context->config('intranetdir')` +
  `installer/data/mysql/mandatory/sysprefs.sql` (older layout fallback:
  `installer/data/mysql/sysprefs.sql`). No bundled or downloaded default snapshot.
- Displays the source path, SHA-256 and both Koha code/database versions. A
  mismatch is prominently flagged. Local patches to the defaults file count
  as local defaults; its checksum documents provenance, not upstream authenticity.
- These are **base fresh-install defaults**, not a historical audit of who
  changed what. MARC flavour, language-specific installer customizations and
  generated runtime settings may legitimately differ. Preferences without a
  base default are identified, not assigned an invented default. `Version`
  is displayed separately and excluded from the preference counts.
- Exact string comparison, case-insensitive preference names. SQL NULL, empty
  text, zero, whitespace and newlines remain distinct. MySQL string escapes
  are decoded; the installer SQL is **never executed**, even in temporary tables.
  Both old five-column and new two-column INSERT formats are supported.
  Unsupported syntax, duplicates or unreadable files stop the comparison.
- Staff overrides are shown separately from stored-value status. Other
  virtual hosts, OPAC, SIP and background processes are not inspected.
- Known credential-like names/types and recognizable embedded secrets are
  masked before the template receives values. This is deliberately conservative
  and **not a complete secret scanner**. Custom free text can contain sensitive
  information: do not share the report without review. HTML/JS is escaped.
  Responses use `no-store`; there is no unmask option or hidden raw-value field.
- Opening the tool reads preferences. Normal Koha plugin registration records
  plugin metadata on install/upgrade; no plugin tables or sysprefs are created,
  modified or dropped by the lifecycle hooks.

## Build and tests

```sh
prove -lr t
node --test t/filter.test.cjs
KOHA_SOURCE=/path/to/koha prove -lv t/compare.t
perl scripts/build-kpz.pl
unzip -t dist/koha-syspref-defaults-0.2.0.kpz
```

Tests use fixtures/mocks, not a production database. `KOHA_SOURCE` only reads
installer data. Dependencies are Perl core modules, Modern::Perl and Template
Toolkit (already used by Koha); building also uses IO::Compress::Zip.
The filter test additionally uses Node.js (not needed to run the plugin).

For an existing development Koha environment, `scripts/smoke-readonly.pl`
loads the modules **without constructing/installing the plugin**, compares the
live defaults/preferences and renders with the real Koha includes inside a
read-only database transaction. Run as the instance user via `koha-shell`.
Set `PLUGIN_LANGUAGE=de` or `PLUGIN_LANGUAGE=en` to test either translation.

## Translations

UTF-8 JSON catalogs live in `Koha/Plugin/HKS3/SysprefDefaults/i18n/`.
`en.json` is the base catalog; `de.json` contains the complete German translation.
All plugin UI strings, including comparison placeholders and JavaScript counters,
come from these files. Preference names and actual stored/default values are
never translated. Plugin-list metadata stays in English as a stable identifier;
internal parser diagnostics are not displayed to users.

To add a language, copy `en.json` to `<language-code>.json`, translate the values
(not the keys), and keep `{count}` in both `visible_one` and `visible_other`.
The loader tries the normalized language code, then its primary language, then
English; missing keys inherit English. Add a language link in `tool.tt` if an
explicit switch is wanted, and extend the language lists in the tests. The current
counter rule is singular for 1, plural otherwise (English/German); languages with
other plural rules also need an adjustment to the counter and its tests.

Catalog strings are plain text, escaped in HTML. JavaScript reads translated
counter messages from escaped HTML data attributes, not executable source.
Catalogs ship inside the KPZ; no gettext compilation, Koha translation rebuild,
global locale changes or external translation service is needed.

## GitHub and releases

The repository is prepared for GitHub but creating a remote repository and pushing
are separate deployment steps. No organization or repository URL is hard-coded.

`.github/workflows/ci.yml` runs Perl/JavaScript tests, builds and validates the KPZ,
and uploads it as an Actions artifact on pushes, pull requests and manual runs.
A pushed tag `v<version>` additionally creates a GitHub Release with that KPZ and
its SHA-256 checksum. The tag must match `$VERSION` in the plugin module; a mismatch
fails before publication. Release write permissions are limited to the release job.
The workflow uses this repository's build script, not a third-party KPZ builder.

Before a release, update the plugin version/date, README package names and
`CHANGELOG.md`, run the checks above, commit and tag the matching version. Review
the generated package and documentation before the first public push. Build outputs
in `dist/` are intentionally not committed.

## Existing tools checked (2026-10-09)

No matching public plugin found in web and GitHub repository searches for
Koha, syspref, defaults and preference comparison, nor in the local plugin
collection. This is not a proof that no private/unlisted plugin exists.
The community wiki plugin page could not be retrieved during research.

- [Koha cmp_sysprefs.pl](https://perldoc.koha-community.org/misc/maintenance/cmp_sysprefs.html)
  compares/restores saved preference files; it is a CLI tool, not this
  version-default comparison in the staff interface.
- Koha's `Koha::Devel::Sysprefs` reads installer defaults for developer tools.
  The inspected implementation returns escaped SQL string contents without
  fully decoding them, so it cannot directly supply an exact value comparison.
- YAML `.pref` files describe the interface but do not consistently supply
  all installation defaults; they are not the baseline used here.

License: GPL-3.0-or-later.
