# Radiation dosimetry

This offline prototype loads a deterministic 180-day mission for four fictitious
crewmembers from `DB/samples/radiation/`. All measurements are synthetic.

## Implemented

- Career effective dose: prior career dose plus mission daily doses, compared
  with the 600 mSv reference. The SPE component is already in each daily dose.
- Organ dose use: rolling 30-day and 365-day windows, and mission dose compared
  with applicable career organ limits. `highestFractionUsed` exposes the largest
  fraction for integration with the biological layer.
- SPE status: active, inactive, or unknown, using the explicit weather flag.
- Local asset loading, schema validation, crew selection, and mission-day selection.
- Cumulative career-dose chart: day zero contains the prior career dose; the curve
  includes only records through the selected day and a 600 mSv reference line.
  Values above the reference remain visible. No SPE dose is added a second time.
- Manual shelter drill during an SPE when the selected record is outside the
  shelter. Start/resume, pause, mark arrival, and reset controls are available.
  A sheltered crewmember receives an explanatory message instead of a drill.

## Shelter drill behavior

The default two-hour duration is a demonstration setting, not a clinically
validated deadline, safe exposure window, or NASA requirement. Viewing a
historical/simulated SPE day never starts a timer automatically. The timer uses
an absolute deadline so delayed callbacks or background suspension do not extend
the drill; it stops at zero without claiming that the crewmember is safe.
Changing crew/day or leaving the screen discards the drill. There is no persistent
incident log, remote notification, or operational emergency protocol in this demo.

## Structure

- `data/`: generator, CSV parser, and local asset repository.
- `models/`: crew profiles, daily organ doses, and space-weather readings.
- `providers/`: career/organ calculations, SPE detection, combined daily summary,
  cumulative history, and Riverpod loading.
- `widgets/`: cumulative chart and shelter drill.
- `presentation/`: radiation screen.
- `test/features/02_radiation/`: focused history and display/drill regression tests.

## Verification

Run from the repository root:

```sh
flutter test test/features/02_radiation/radiation_display_test.dart
flutter build web --no-web-resources-cdn
```

The focused tests cover history filtering/order, prior career dose, SPE counting,
duplicate and missing days, invalid prior dose, narrow/wide chart layouts, a dose
above the reference, deadline-based countdown, pause/resume, expiry, arrival,
reset, and disposal. They do not constitute validation of the entire dose engine.

## Integration and remaining scope

`RadiationDailySummary` provides the crew ID, mission day, career total, remaining
budget, organ-window comparisons, SPE status, and that day's SPE component.
The dated physical contract is now available as `DoseSummary` alongside `BioSummary`.
The combined dose/biology matrix, recommendations, organ traffic lights, and
clickable body remain shared work. Comprehensive core-engine tests are pending.

Prior organ-specific career history and separate CNS heavy-ion measurements are
not available in this dataset and are not inferred from effective dose.

Reference values and their units are documented in
`sources/medical/radiation_dosimetry.md`; the sample schema and limitations are in
`DB/samples/radiation/README.md`. The 250 mSv SPE design reference must not be
used as a standalone event detector or an individual clinical threshold.

## Biomarker branch integration

The combined screen uses the crew hub's ID/name and a shared
`selectedMissionDayProvider`. Production starts at day 1; a single mission slider
updates that shared state; the biological panel displays the selected day. The biological return day remains selectable. A missing
physical record on that day is shown as unavailable rather than repeating the
last in-flight dose.

`radiationIntegrationOverrides` is installed in the root `ProviderScope`.
`DoseLinkedBiomarkerRepository` adapts the existing biological simulator to the
loaded mission duration, SPE day, personal SPE dose contribution, and shelter
locations. The underlying biological simulator and score calculator are unchanged.
The extreme hypothetical scenario changes biology only and is labelled separately
from the physical mission measurements.

`DoseSummary` and `BioSummary` use the same astronaut ID and end-of-day timestamp.
`selectedDoseSummaryProvider` returns null when physical data are unavailable;
unknown SPE status stays distinct from an inactive SPE. These contracts do not
implement a combined clinical risk model.

The global roster has five members; dosimetry currently covers AST-01–AST-04.
AST-05 retains its own biological demo without borrowing another person's dose.
Its lack of dosimetry is explicitly shown. Without a personal event dose, the
realistic biological demo has no dose-dependent SPE input for that member; this
must not be read as a measured zero exposure or a combined assessment.

Sample profile names and ages match the global mock roster. Sex is marked
`unspecified` because that roster does not provide it. These metadata changes do
not alter the dose CSVs or prior career-dose values. No AST-05 dose is fabricated.

Dates use the biological simulator's fictitious UTC launch date (2027-01-01,
day zero); dosimetry supplies mission-day numbers, not actual calendar dates.
The duration is inferred from the last dosimetry day. The current biological
simulator requires at least seven days and supports at most one SPE; unsupported
inputs must be surfaced rather than silently converted to another scenario.

Integration regression tests cover dose input forwarding, biological algorithm
preservation, shared day/crew/date, missing personal records, return-day handling,
longer mission input, and hypothetical scenario separation. Standalone biomarker
tests retain their original mock defaults. Tests requiring the external
Inspiration4 source CSV may be skipped when that untracked file is absent.

## Clinical agent bridge

`agent/radiation_health_skills.dart` exposes this module to the clinical agent
(`lib/features/agent`) as the `radiation_health` skill, registered in
`agent_providers.dart`. Its three tools are read-only and use the same providers
as the Radiation screen, for the agent's current astronaut and the mission day
selected on the screen (or a `mission_day` argument):

| Tool | Returns |
| --- | --- |
| `get_radiation_dose` | Career effective dose, remaining margin to the 600 mSv NASA-STD-3001 limit, % of each organ's non-cancer limit used, SPE status |
| `get_radiation_biomarkers` | Biological score B, its level (normal / watch / alert), % change of each marker vs. baseline, sample pending |
| `get_radiation_symptoms` | Symptoms marked today, most urgent first, with when / why / what to do |

Missing data (no dosimetry, return day, astronaut without biomarkers) is reported
as `available: false`, never filled in.

When the LLM gateway is unreachable, `RadiationHealthOfflineFlow` answers
radiation questions deterministically: it reads the three tools, shows an
`alert_banner` and asks the crew to contact the flight surgeon if a symptom is
urgent, the score is in alert or an SPE is active. Thresholds are illustrative,
not clinical criteria. Space weather and pharmacy remain in Carlos's
`radiation_agent_skills.dart`.
