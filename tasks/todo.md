# Skissrättning spår 2, omgång 2: importvyerna och ny delad lista (2026-10-12)

The previous plan in this file (delade listor, #757) is merged and finished; this branch carries
only this plan. Full table and rationale: `/mnt/project-files/plans/skiss-spar2-omgang2-plan.md`.
Malin's go: "Kör helt enligt dina rekommendationer på de nya vyerna" (2026-10-12 08.43).

## Scope

Seven views redrawn against the proposal images in `skiss-mot-app/omgang2/forslag/`, one PR after
#769, merged only after Malin has approved the images.

| View | File | Shared piece built or reused |
|---|---|---|
| 97 Ny delad inköpslista | `views/social/create_shared_shopping_list_view.dart` | new `PersonCheckRow`, `UnderlineTabs`, `LabeledField` |
| 74 Från sociala medier | `views/fran_sociala_medier_view.dart` | `TintedNote`, `LabeledField` |
| 76 Importera från arkiv | `views/importera_fran_arkiv_view.dart` | `ButlerySearchBox`, `ChoiceOption`, check rows |
| 73 Från fil | `views/file_import_view.dart`, `widgets/import/batch_import_preview.dart` | `TintedNote`, status row |
| 109 Röstimport | `views/voice_import_view.dart` | voice button (light), `LabeledField` |
| 85 Fotoimport | `views/photo_import_view.dart` | image-picker panel, `ButleryListRow` toggle |
| 96 Skriv själv | `views/skriv_sjalv_recept_view.dart` | `LabeledField`, form scaffold |

## Assumptions (no architecture-changing unknowns)

No architecture-changing unknowns — assumptions: no data model, repository, Firestore, rules or
Cloud Functions change; view and widget layer plus l10n additions only. The one VM touch is view 97:
`CreateSharedListViewModel` passes the permission choice to the existing `allowGuestEditing`
parameter of `createListAndInvite`, which already maps it to `edit`/`view` invitations.
`ButleryTopBar` belongs to track 6 and is not touched. Functions the sketch lacks stay (rule 2).

## Steps

- [ ] 97: `PersonCheckRow`, permission tabs through the VM, rewrite view, update tests and goldens
- [ ] 74, 76, 73: rewrite per proposal, tests
- [x] Voice, photo and Skriv själv: rewritten per proposal, tests
- [ ] screen register rows, decision log entry (next free number), workflow map, composites
- [ ] analyze, architecture tests, changed-file tests, goldens, workflow-map linter
- [ ] gate reviews one at a time, PR with `Skiss mot app:` images, drive CI green
