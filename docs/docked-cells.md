# Docked-cell toolbar catalog

Every button in the docked toolbars the various resource and documentation
templates attach to their notebooks - i.e. the *bar* across the top of the
notebook, not the Documentation Tools palette (covered in
[palette.md](palette.md)).

Two distinct toolbars are involved:

1. **The doc-page authoring toolbar** that the DocumentationTools paclet
   attaches to a `Symbol` / `Guide` / `TechNote` page (the `FunctionPage`,
   `GuidePage`, `TechNotePage` styles). Source:
   `<install>/AddOns/Applications/DocumentationTools/FrontEnd/StyleSheets/Wolfram/{Function,Guide,TechNote}PageStylesExt.nb`
   and `DockedCells` resource `"FunctionPageDockedCell"` (and the guide /
   technote variants) under `…/FrontEnd/TextResources/DocumentationTools.tr`.
2. **The resource definition toolbar** that every resource-system template
   attaches to its definition notebook: a per-resource-type `MainGridTemplate`
   defined in `<install>/SystemFiles/Components/<Type>Resource/FrontEnd/StyleSheets/Wolfram/<Type>ResourceDefinitionStyles.nb`,
   driven by `ResourceSystemClient`DefinitionNotebook`*` functions. The
   `Demonstration` template uses its own toolbar (a separate
   `DemonstrationsTools` paclet) with extra Demonstrations-specific buttons.

Per-section "MoreInfo opener" buttons (the **?** bubble next to every
heading inside the body) are also documented here - they look like
toolbar buttons but live inline with the cell, not in the docked bar.

Status: **[done]**, **[partial]**, **[todo]**.

## Doc-page authoring toolbar (`Symbol`, `Guide`, `TechNote` pages)

Sits across the top of a built `ref/` page in authoring mode. The whole
toolbar is the `"FunctionPageDockedCell"` resource (and its
`Guide*` / `TechNote*` siblings). Layout: paclet badge → Preview button
→ **?** help button → palette-opener button.

| Button | Action | Markdown equivalent | Status |
|---|---|---|---|
| Paclet badge | `Dynamic` lookup of `CurrentValue[EvaluationNotebook[], {TaggingRules, "Paclet"}]` | `Paclet: Publisher/PacletName` frontmatter | done |
| Preview | `DocumentationTools`BuildPreviewNotebook[]` | run `DocumentationBuild` over the paclet | done (separate step) |
| **?** Help | `FrontEndExecute[FrontEndToken["OpenHelpLink", {"paclet:DocumentationTools/tutorial/DocumentationToolsQuickStart#…", None}]]` | n/a (opens the tutorial) | n/a |
| Open Palette | `Needs["DocumentationTools`"]; DocumentationTools`OpenDocumentationToolsPalette[n]` | n/a (opens the palette - whose buttons are in [palette.md](palette.md)) | n/a |
| AUTHORING / WEB / PRINT switch | `CurrentValue[EvaluationNotebook[], {TaggingRules, "PageView"}]` toggle | n/a (preview mode toggle) | n/a |

## Resource definition toolbar (every resource-system template)

The bar across the top of a definition notebook
(`FunctionResource` / `Prompt` / `LLMTool` / `Example` / `Paclet` / `Data` /
`Demonstration` / etc.) is rendered by the per-template `"MainGridTemplate"`
in `<Type>ResourceDefinitionStyles.nb`. The buttons listed below appear on
*every* resource type (the `Demonstration` template adds its own buttons
below). Actions are in the `DefinitionNotebookClient`` context unless
noted.

### Top row (large action buttons)

| Button | Tooltip | Action | Markdown equivalent | Status |
|---|---|---|---|---|
| **Open Sample** | "View a completed sample definition notebook" | `NotebookOpen[<sample.nb>]` from the template's `SampleDefinition` resource | (`examples/ReverseAddSequence.md` etc. are the markdown samples) | n/a (sample) |
| **Style Guidelines** | "View general guidelines for authoring resource functions" | `SystemOpen[<guidelines URL>]` | the link in each skill's "Read first" section | n/a (sample) |
| **Check** | "Check notebook for potential errors" | `$ClickedButton = "Check"; CheckDefinitionNotebook[nbo]` | `check.wls` runs the same lint over every built `.nb` | done |
| **Preview** | "Generate a preview notebook" | `PreviewResource[nbo]` | the rendered `-out.md` twin (`build-out.wls`) | done |
| **Deploy** ▾ | "Deploy" | `CheckForUpdates[nbo]; $ClickedButton = "Deploy"; DeployResource[nbo, …]` | `examples/build.wls` `CloudDeploy`s each built `.nb` to a public `CloudObject` | done |
| Deploy → Publicly in the cloud | (same as Deploy default) | `DeployResource[nbo, "Public" -> True]` | `examples/build.wls` default | done |
| Deploy → For my cloud account | (private deploy) | `DeployResource[nbo, "Public" -> False]` | (omit `Permissions -> "Public"` from your `CloudDeploy`) | done |
| Deploy → Locally on this computer | (file-system deploy) | `DeployResource[nbo, Local -> True]` | `examples/build.wls` writes the `.nb` locally before deploying | done |
| Deploy → In this session only (without documentation) | one-shot in-kernel deploy | `DefineResourceFunction[ScrapeResource[nbo]]` | `ResourceFunction[ResourceObject[nbo]]` after a local build | done |
| **Submit to Repository** | "Submit your function to the Wolfram Function Repository" | `CheckForUpdates[nbo]; $ClickedButton = "Submit"; SubmitRepository[nbo]` | once the `.nb` validates, `ResourceSubmit` the scraped resource | done (manual `ResourceSubmit`) |
| **Submit Update** | "Submit changes to update your function submission" | `$ClickedButton = "SubmitUpdate"; SubmitRepositoryUpdate[nbo]` | re-`ResourceSubmit` an updated `ResourceObject` | done (manual) |

### Secondary row (cell-tools panel, togglable via "Toggle documentation toolbar")

The secondary row is the `"ToolsGridTemplate"`; it shows when `TaggingRules.ToolsOpen` is `True`. Per-cell editing buttons:

| Group | Button | Tooltip | Action | Markdown equivalent | Status |
|---|---|---|---|---|---|
| Cells | Mark/unmark as comments | "Mark/unmark selected cells as comments" | toggles `CellTags -> "Comment"` on selection | edit the markdown; no analogue (review-only) | n/a (authoring) |
| Cells | Mark/unmark as excluded | "Mark/unmark selected cells as excluded; Excluded cells will not appear anywhere in the published resource except for the definition notebook" | toggles `CellTags -> "ExcludedCell"` | `#\| eval: false` (or just omit the cell) | done |
| Cells | Mark/unmark as hidden | "Hidden input cells will be closed on the published web page but will remain open in the downloadable example notebook" | toggles `CellOpen -> False` on the input | (the converter does this automatically for Input/Output groups) | done |
| Cells | Insert comment for reviewer | "Insert comment for reviewer" | inserts a `Cell["", "ReviewerComment"]` | author the prose in the appropriate section | n/a (authoring) |
| Cells | Reply | "Reply »" | replies to a `ReviewerComment` | n/a (review) | n/a |
| Cells | Click for more information | "Click for more information" | opens the cell-tool tutorial | n/a | n/a |
| Tables | Insert table with two columns | "Insert table with two columns" | `DocumentationTools`TableInsert[2]` | a 2-column pipe table | done |
| Tables | Insert table with three columns | "Insert table with three columns" | `DocumentationTools`TableInsert[3]` | a 3-column pipe table | done |
| Tables | Add a row | "Add a row to the selected table" | `DocumentationTools`TableAddRow[]` | add a `\| … \| … \|` line | done (re-author) |
| Tables | Sort the selected table | "Sort the selected table" | `DocumentationTools`TableSort[]` | sort the rows by hand | done (re-author) |
| Tables | Merge selected tables | "Merge selected tables" | `DocumentationTools`TableMerge[]` | author one table | done (re-author) |
| Insert | Insert example delimiter | "Insert example delimiter" | `DocumentationTools`DocDelimiter["Reference"]` | `---` between siblings | done |
| Insert | Insert Delimiter | "Insert Delimiter" | (same) | `---` | done |
| Insert | Template Input | "Template Input" | `DocumentationTools`FunctionTemplateToggle` | `` `code` `` | done |
| Insert | Literal Input | "Literal Input" | `DocumentationTools`FunctionTemplate["Plain"]` | `` `"literal"` `` | done |
| Insert | Subscripted Variable | "Insert subscripted variable placeholder" | inserts `Cell[BoxData[SubscriptBox["x", "1"]], "InlineFormula"]` | `$x_1$` | done |
| Format | Format selection automatically | "Format selection automatically using appropriate documentation styles" | `DocumentationTools`RestoreDefault` | the converter applies the right cell style from the section | done |
| Format | Format selection as literal | "Format selection as literal Wolfram Language code" | `DocumentationTools`FunctionTemplate["Plain"]` | `` `"literal"` `` | done |
| Format | Toggle documentation toolbar | "Toggle documentation toolbar" | `CurrentValue[…, {TaggingRules, "ToolsOpen"}] = !$Current` | n/a (UI toggle) | n/a |
| Analysis | View suggestions | "View suggestions" | `CheckDefinitionNotebook[nbo]` → opens the analysis pod | run `check.wls` and read its output | done |
| Analysis | Notebook Analysis | "Notebook Analysis" | toggles the right-side analysis pod | the hint list `check.wls` prints | done |
| Analysis | Close analysis pod | "Close analysis pod" | hides the pod | n/a (UI) | n/a |
| Edit | Edit values | "Edit values" | opens the "edit slot defaults" panel | re-author the frontmatter `Name`/`Description`/etc. | done |
| Edit | Click to copy | "Click to copy to the clipboard" / "Copied" | `ClickToCopyButton[content]` - copies content to clipboard | n/a (UI) | n/a |

## Demonstration toolbar (extra buttons on top of the shared bar)

`DemonstrationsTools` adds Demonstration-specific buttons (no Submit, no
Check, since Demonstrations have their own UPLOAD flow). Source: the
`DockedCells` in `<install>/AddOns/Applications/DemonstrationsTools/FrontEnd/StyleSheets/Wolfram/Demonstration.nb`.

| Button | Tooltip | Action | Markdown equivalent | Status |
|---|---|---|---|---|
| **HELP** | "Go to the Demonstrations guidelines page." | `NotebookLocate[{URL["http://demonstrations.wolfram.com/guidelines.html"], None}]` | the guidelines link in `skills/wolfram-demonstration/SKILL.md` | n/a (link) |
| **EXAMPLE** | "Download a completed examples template." | `DemonstrationsTools`DemonstrationExampleOpen["http://demonstrations.wolfram.com/DemonstrationExample.nb"]` | `examples/BlochSphereGates.md` is the worked markdown sample | n/a (sample) |
| **SAVE** | "Save Demonstration" | `DemonstrationsTools`SaveBrowseWithMemory[…]` | author saves the `.md` directly | n/a (save) |
| **UPLOAD** | "Go to the Demonstrations upload page." | `DemonstrationsTools`PreflightCheck[]` → opens the upload page on success | not a market the `examples/build.wls` deploy targets; submit via the Demonstrations site | partial |
| **UPDATE THUMBNAIL & SNAPSHOTS** | (none) | `DemonstrationsTools`ErrorsToConsole[DemonstrationsTools`UpdateManipulateOutputs[InputNotebook[], True]]` | use a parameterised `Manipulate` helper + `#\| input: false` snapshots (see [computational-essay vs demonstration in MarkdownToNotebook.md](../MarkdownToNotebook.md)) | done |
| Test Image Size | (in TOOLS dropdown) | `DemonstrationsTools`DemonstrationTestMask[]` | n/a (visual sanity check at author time) | n/a |
| Check Spelling | (in TOOLS dropdown) | `FrontEndExecute[FrontEndToken["CheckSpelling"]]` | author spellcheck | n/a |
| Resize Notebook to Fit | (in TOOLS dropdown) | `SetOptions[InputNotebook[], WindowSize -> …]` | n/a (sizing) | n/a |

## Per-section MoreInfo opener (template-injected, inline)

Each section heading the resource template stamps into a definition
notebook (`## Caption`, `## Initialization`, `## Snapshots`, `## Source &
Additional Information → Contributed By`, ...) has a **?** opener
appended to its `TextData`, which pops a guidance bubble (a `Cell[…, "MoreInfoText"]`).
These are not docked cells but they look like toolbar buttons. The
converter and the walker both ignore them.

| Element | Action | Markdown equivalent | Status |
|---|---|---|---|
| **?** opener on a section heading | `Cell[BoxData[PaneSelectorBox[{True -> TemplateBox[{slot, helpCell}, "MoreInfoOpenerButtonTemplate"]}, Dynamic[CurrentValue[EvaluationNotebook[], {TaggingRules, "ResourceCreateNotebook"}]]]]]` | n/a (UI affordance) | dropped by both forward and walker |
| **?** bubble body | `Cell[…, "MoreInfoText", CellTags -> {"SectionMoreInfo<Slot>"}]` | the prose hint in the resource template's `MoreInfoCells` `RegisterHiddenString` table; for the markdown author the same prose lives in the per-skill `SKILL.md` and in `docs/resource-notebooks.md` | n/a |

## What the docked toolbars do that markdown doesn't yet have

- **In-FE Deploy / Submit / Upload buttons**: the action they take has a
  direct WL counterpart (`DeployResource` / `ResourceSubmit` /
  `CloudDeploy`), and `examples/build.wls` calls those. The buttons
  themselves are FE-only.
- **`ReviewerComment` / `Reply` cells**: a review workflow with no
  source-side equivalent. Skip them - they don't survive the markdown
  round trip.
- **Cell-tools "Hidden" / "Excluded" markers**: see
  `#| eval: false` (drops the input from the resource) and the
  `CellOpen -> False` the converter already applies to grouped
  Input/Output cells.
- **`Preview` / `Notebook Analysis` panels**: `build-out.wls` produces
  the same rendered preview as a markdown twin; `check.wls` runs the
  same `CheckDefinitionNotebook` linter the analysis pod displays.
