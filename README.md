# FIELD // KIT PRO

[Open the live catalog](https://fieldkit.pro/) · [Browse by category](docs/CATALOG-BY-GROUP.md) · [See what changed](https://github.com/Grimmieeee/FIELDKIT-PRO/commits/main/)

| I want to… | Go here |
| --- | --- |
| Find or download a PowerShell tool | [Live catalog](https://fieldkit.pro/) |
| Audit the full inventory | [Full catalog (plain text)](docs/FULL-CATALOG.txt) |
| See what’s live, what was tested, or how to roll back | [Project status](docs/README.md) |
| Build or add a script | [Build standard](docs/field-kit-build-standard.md) · [Script intake](docs/SCRIPT-INTAKE.md) |
| Review the site layout and behavior | [Site and catalog reference](docs/SITE-AND-CATALOG-SPEC.md) |
| Find an older revision | [Repository layout and archive index](docs/REPOSITORY-LAYOUT.md) |

## Repository map

- [scripts](scripts/) holds [BEC incident response](scripts/incident-response/) and [client connectivity checks](scripts/connectivity/).
- [dist](dist/) holds the catalog and downloadable assets tracked in GitHub. Production is hosted on Sites, with its own source history.
- [build](build/) holds the Worker builder and request router. [tests](tests/) holds GitHub release checks and their input records.
- [archive](archive/) holds historical assembly inputs, validator artifacts and QA records. Additional history is in [FIELDKIT-ARCHIVE](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE).

Start technical work with the [repository instructions](AGENTS.md) and [security guidance](SECURITY.md). Pin GitHub tests to a commit and establish byte parity with the relevant Sites release before claiming production coverage.
