# Resource definition notebooks (FunctionResource / Paclet / Example)

These fill the official definition template from
`DefinitionNotebookClient`DefinitionTemplate[...]` and keep its stylesheet and
docked **Deploy / Submit / Check** toolbar, so the `.nb` is publishable as-is.
Each `TemplateSlot` in the template is replaced by cells built from the markdown
(`template //. TemplateSlot[name, …] :> fillSlot[name, …]`).

## FunctionResource (Wolfram Function Repository)

![FunctionResource definition notebook](images/resource-definition.png)

````md
---
Template: FunctionResource
Name: MyFunction
Description: ...
ContributedBy: Jane Doe
Keywords: [a, b]
Categories: [Notebook Documents & Presentation]
OperatingSystems: [Windows, MacOSX, Unix]
Environments: [Session, Script]
CloudSupport: true
WolframVersion: 14.0+
EntrySymbol: MyFunction
---

## Definition

```wl
#| file: MyFunction.wl
```

## Usage

`MyFunction[x]` does the thing.

## Details & Options

Notes prose.

## Basic Examples

```wl
MyFunction[1]
```
````

| Markdown / frontmatter | Template slot | Toolbar action it feeds |
|---|---|---|
| `Name` | `Name` (Title) | name |
| `Description` | `Description` | short description |
| `## Definition` `wl` cells | `Function` (Input) | the function source |
| `## Usage` prose | `Usage` | usage lines |
| `## Details & Options` | `Notes` | Details & Options |
| `## Basic Examples`/`## Scope`/... | `Examples` (Basic Examples, Scope, ...) | evaluated example cells |
| `Keywords` | `Keywords` | keyword items |
| `Categories` | `Categories` | category checkboxes (`CheckboxesCell`) |
| `OperatingSystems`/`Environments`/`CloudSupport`/`Features` | `Compatibility*` | compatibility checkboxes |
| `WolframVersion` | `CompatibilityWolframLanguageVersionRequired` | required version |
| `Sources` | `Source/Reference Citation` | citation items |
| `Links` | `Links` | external links |
| `ContributedBy` | `Contributed By` | author |
| (section) `## Author Notes` | `Author Notes` | reviewer notes |

The example-section taxonomy (`## Basic Examples`, `## Scope`, `## Options`,
`## Applications`, `## Properties and Relations`, `## Possible Issues`,
`## Neat Examples`) maps to the template's example subsections. Checkbox slots
are built with `DefinitionNotebookClient`CheckboxesCell` so the `"CheckboxData"`
blob (a `BaseEncode`d `Compress` of `<|"Property"->…,"Checked"->…|>`) is correct.

**Toolbar**: the docked `MainGridTemplate`/`ToolsGridTemplate` provide
**Deploy**, **Submit**, **Check** (= `DefinitionNotebookClient`CheckDefinitionNotebook`,
expects a `File[…]` or `NotebookObject`). The markdown only supplies the
metadata; the buttons act on the filled notebook.

**Check status**: `SeeAlso` fills the *Related Symbols* slot (so it no longer
leaves the placeholder string that `Check` flagged as `NotAValidSymbolName`).
`Check` run headless via `CheckDefinitionNotebook[File[…]]` may still report
`DefinitionMissing` for a definition that inlines a whole multi-symbol package;
the definition is in fact valid (running the scraper's own steps -
`evaluateCell` in `FunctionResource`$ResourceFunctionTempContext` then
`minimalDefinition`) yields a non-empty `DefinitionList`, and the interactive
Deploy/Submit path (what `bootstrap.wls` uses) builds it cleanly.

## Paclet (Paclet Repository)

Same mechanism with `DefinitionTemplate["Paclet"]`, but the slot names differ
from the Function template. The markdown maps as:

| Markdown | Paclet slot | Notebook |
|---|---|---|
| `Name` (publisher-prefixed, e.g. `Wolfram/AccessibleColors`) | `Name` | title |
| `Description` (must match `PacletInfo.wl`) | `Description` | short description |
| `## Usage` prose | `LongDescription` | landing-page text (inline `` `code` `` templated) |
| `## Details & Options` | `Details` | `Notes` |
| `## Basic Examples` / `## Scope` / ... | `ExampleNotebook` | `Subsection` + `Text` + `Input`/`Output` |
| `## Hero Image` | `HeroImage` | landing image (see below) |
| `Context` | `PrimaryContext` | primary context |
| `MainGuide` (guide page name) | `MainGuidePageString` -> `MainGuidePage` | main-guide chooser tagging rule |
| `License` (e.g. `MIT`) | `SelectedLicenseID` | license radio button |
| `Categories` (`[list]`, names must match the template) | `Categories` | category checkbox grid (`CheckboxesCell`, `ResourceType -> "Paclet"`) |
| `Sources` (`[list]`) | `Source/Reference Citation` | source / reference items |
| `WolframVersion` | `CompatibilityWolframLanguageVersionRequired` | required version |
| `SourceControlURL` | `SourceControlURL` | source link |
| `Links` (labeled `[text](url)`) | `Links` | related links |
| `RelatedResources` (`[list]`) | `Related Resource Objects` | related resource items |
| `Keywords`, `ContributedBy` | same | metadata |

Frontmatter: `Name`, `Description`, `Context`, `Paclet`, `PacletDirectory`,
`MainGuide`, `License`, `WolframVersion`, `Categories`, `Sources`,
`SourceControlURL`, `Keywords`, `Links`, `ContributedBy`. Examples load the
paclet (`Context`) via the `ExampleInitialization` cells and demonstrate it.

`Disclosures` (local files, external services, ...) stay unchecked by default,
which is correct for a self-contained library; `CheckboxesCell` cannot
auto-generate the Paclet disclosure grid, so asserting one needs a manual
checkbox toggle. `PrimaryContext`, `MainGuidePage` and the license radio are
driven through `TemplateExpression`/`TemplateIf` and scalar slots, resolved in
the first pass (see above). `MyPublisherID/MyPaclet` strings that remain are the
template's ⓘ help-tooltip examples, not unfilled slots.

The example sub-sections in `ExampleNotebook` are literal cells (not a slot), so
they are built rather than slot-filled; the `ExampleInitialization` group (the
`PacletDirectoryLoad` + `Needs` cells) is preserved from the template. The hero
image is the `## Hero Image` section's evaluated output, kept with its code in a
`CellGroupData[{code, image}, {2}]` group (shows the image, collapses the code).

The Paclet template wraps its directory / main-guide / context metadata in
`TemplateExpression` and `TemplateIf` (not plain `TemplateSlot`). These are
resolved in a first pass *before* the cell-based slot fill, in stages: slots
substituted first (so a `TemplateIf` condition like `StringQ[TemplateSlot[…]]`
tests the real value), then `TemplateIf` collapses, then `TemplateExpression`
unwraps and its body (`DeleteMissing` / `ToBoxes` / …) evaluates. The
`PacletDirectory` frontmatter key flows into the directory tagging rule, so the
notebook carries no unresolved template heads and `CheckDefinitionNotebook` runs
clean - except for `PacletDirectoryMissing`, which the docked **Choose**
toolbar button clears by scanning the directory to populate the manifest /
`PacletFiles` panel (an interactive publish-time step, not static metadata).

## Example (Wolfram Example Repository)

Same mechanism with `DefinitionTemplate["Example"]`. An Example resource exposes
named *content elements* (fetched with `ResourceData`) plus worked examples, so the
markdown maps as:

| Markdown | Example slot | Notebook |
|---|---|---|
| `Name` | `Name` | title |
| `Description` | `Description` | short description |
| `## Content` (executable cells) | `ContentElements` | `Input` cells tagged `DefaultContent` |
| `## Examples` (prose + code) | `Examples` | `Text` + `Input`/`Output` (filled directly, no subsection wrapper) |
| `## Hero Image` | `HeroImage` | landing image (`CellGroupData[{code, image}, {2}]`) |
| `Categories` (`[list]`; names must match the template) | `Categories` | category checkbox grid (`ResourceType -> "Example"`) |
| `RelatedSymbols` (`[list]`) | `RelatedSymbols` | related symbol items |
| `RelatedResources` (`[list]`) | `Related Resource Objects` | related resource items |
| `Sources` (`[list]`) | `Source/Reference Citation` | source / reference items |
| `Links` (labeled `[text](url)`) | `Links` | related links |
| `WolframVersion` | `CompatibilityWolframLanguageVersionRequired` | required version |
| `Keywords` | `Keywords` | metadata |
| `ContributedBy` | `ContributorInformation` | contributor |

The defining cells go under `## Content`: each `wl` cell becomes an `Input` cell
carrying the `DefaultContent` tag the scraper needs (content cells are included
whether or not they carry `#| eval: false`, since the assignment itself only resolves
in the deployed notebook). A common pattern is a helper definition (evaluated, so the
examples can reuse it) followed by the literal content assignments
(`ResourceData[ResourceObject[EvaluationNotebook[]], "name"] = value`, marked
`#| eval: false` because `ResourceObject[EvaluationNotebook[]]` has no meaning in a
headless convert session). Unlike the Function
template's named example sections, the Example template has a single `Examples` slot,
so a plain `## Examples` section fills it directly (intro prose as `Text`, computations
as `Input`/`Output`). The Example resource's category labels differ from the Function
ones (e.g. `Visualization & Graphics`, `Puzzles and Recreation`, `Machine Learning`);
set `Categories` to one or more of them - an empty grid is a submission hint.

## Self-hosting

A document whose frontmatter is `Template: FunctionResource`, whose `## Definition`
inlines its own `.wl`, and whose frontmatter is the resource metadata reproduces
its own definition notebook via `MarkdownToNotebook[file]` - see `build.wls` (the
converter publishing itself).
