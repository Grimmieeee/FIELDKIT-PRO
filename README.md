# FIELD // KIT PRO

[Open the live catalog](https://fieldkit.pro/) · [Browse by category](<PROJECT SUMMARY/CATALOG-BY-GROUP.md>) · [See what changed](https://github.com/Grimmieeee/FIELDKIT-PRO/commits/main/)

## Find what you came for

| I want to… | Go here |
| --- | --- |
| Find or download a PowerShell tool | [Live catalog](https://fieldkit.pro/) |
| See what’s live or how to roll back | [Project status](<PROJECT SUMMARY/README.md>) |
| See what was tested | [QA handoff](qa/PROJECT-STATE.md) |
| Build or add a script | [Build standard](<PROJECT SUMMARY/field-kit-build-standard.md>) · [Script intake](<PROJECT SUMMARY/SCRIPT-INTAKE.md>) |
| Review the site layout and behavior | [Site and catalog reference](<PROJECT SUMMARY/SITE-AND-CATALOG-SPEC.md>) |
| Find an older revision | [FIELDKIT-ARCHIVE](https://github.com/Grimmieeee/FIELDKIT-ARCHIVE) |

## Repository map

- [PROJECT SUMMARY](<PROJECT SUMMARY/README.md>) holds the production pins, rollback targets, checksums, and operator handoff. It is the place to check current site versions, including the [entry site](https://field-kit-entry.delbert-hifield.chatgpt.site/).
- [dist](dist/) holds the catalog and downloadable assets tracked in GitHub. Production is hosted on Sites, with its own source history.
- [scripts](scripts/) holds standalone PowerShell files and the Worker build script. [worker](worker/) holds the request router.
- [qa](qa/) holds verification scripts and release evidence. The [QA disposition](<PROJECT SUMMARY/QA-DISPOSITION.md>) explains the scope of historical records.
- [release-baseline](release-baseline/) holds historical assembly inputs. Recover the pinned Sites source for the current production payload.

Start technical work with the [repository instructions](AGENTS.md) and [security guidance](SECURITY.md). Pin GitHub tests to a commit and establish byte parity with the relevant Sites release before claiming production coverage.
