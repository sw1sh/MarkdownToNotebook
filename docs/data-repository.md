# Data Repository definition notebooks

A Wolfram Data Repository resource (`ResourceType: Data`) packages a curated dataset
together with its statistical metadata, content elements (the data itself, plus any
named accessors), and worked examples. `MarkdownToNotebook` fills the official
`DefinitionNotebookClient`DefinitionTemplate["Data"]` template's 26 slots from a
literate-markdown document with `Template: Data`.

The template is part of the Wolfram resource-system family (alongside
`FunctionResource`, `Paclet`, and `Example`), so the same machinery the
[resource-notebooks.md](resource-notebooks.md) page describes applies: each
`TemplateSlot` is replaced by cells built from the markdown, the docked
Deploy / Submit / Check toolbar stays intact, and the `.nb` is publishable as-is.

Official sources to keep in view (and re-read when in doubt):

- [Wolfram Data Repository](https://datarepository.wolframcloud.com/) - the catalog itself.
- [Wolfram Data Repository guide page](https://reference.wolfram.com/language/guide/WolframDataRepository.html) - the Wolfram Language reference for fetching from it.
- [Write Data Resource Examples](https://reference.wolfram.com/language/workflow/WriteDataResourceExamples.html) - the official workflow for the example cells, including the special `$$Object` / `$$Data` convention.
- [Use Data from the Wolfram Data Repository](https://reference.wolfram.com/language/workflow/UseDataFromTheWolframDataRepository.html) - retrieval patterns the examples should demonstrate.
- [Launching the Data Repository (Wolfram blog)](https://blog.wolfram.com/2017/04/20/launching-the-wolfram-data-repository-data-publishing-that-really-works/) - background on the format and its computability goals.

## Markdown to slot

| Markdown | Data slot | Notebook |
|---|---|---|
| `Name` | `Name` | title |
| `Description` | `Description` | short description |
| `## Details` (prose + bullets + tables) | `Details` | `Notes` |
| `## Content` (executable cells) | `ContentElements` | `Input` cells tagged `DefaultContent` (one primary `ResourceData[ro] = value`, plus any number of `ResourceData[ro, "name"] = value` additional accessors) |
| `## Basic Examples` / `## Scope & Additional Elements` / `## Visualizations` / `## Analysis` | `ExampleNotebook` | one `Subsection` group per section, with the markdown's prose and (`eval: true`) `Input` / `Output` cells |
| `Citation` (or `## Citation`) | `Citation` | citation text |
| `Author` (or `SMDAuthor`) | `SMDAuthor` | statistical-metadata author (falls back to `ContributedBy`) |
| `Title` (or `SMDTitle`) | `SMDTitle` | statistical-metadata title (falls back to `Name`) |
| `Date` (or `SMDDate`) | `SMDDate` | original publication date |
| `Publisher` (or `SMDPublisher`) | `SMDPublisher` | original publisher |
| `GeographicCoverage` | `SMDGeographicCoverage` | place coverage |
| `TemporalCoverage` | `SMDTemporalCoverage` | time coverage |
| `Language` | `SMDLanguage` | dataset language |
| `Rights` | `SMDRights` | licensing / rights statement |
| `ContentTypes` (`[list]`; names must match the template) | `ContentTypes` | content-type checkbox grid (`ResourceType -> "Data"`): `Audio`, `Image`, `Numerical Data`, `Time Series`, `Text`, `Graphs`, `Video`, `Entity Store`, `Geospatial Data`, `Vector Database` |
| `Categories` (`[list]`) | `Categories` | category checkbox grid (`ResourceType -> "Data"`) |
| `Keywords` (`[list]`) | `Keywords` | metadata |
| `ContributedBy` | `Contributed By` | contributor name |
| `RelatedSymbols` (`[list]`) | `RelatedSymbols` | related symbol items |
| `SeeAlso` | (alias for `RelatedSymbols`) | as above |
| `Links` (labeled `[text](url)`) | `Links` | related links |
| `SubmissionNotes` | `SubmissionNotes` | private notes to the reviewer (only visible pre-submission) |

The frontmatter accepts the cleaner alias for each statistical-metadata field
(`Author`, `Date`, `Publisher`, ...); the SMD-prefixed key (`SMDAuthor`, ...) works
too if you want to match the slot name directly.

## Content elements

The Data template's `ContentElements` section is structured as **Primary Content**
(a single `ResourceData[ResourceObject[EvaluationNotebook[]]] = value` assignment -
no string key, that *is* the resource's data) followed by **Additional Data
Elements** (named accessors: `ResourceData[ResourceObject[EvaluationNotebook[]],
"name"] = value`). Author both inside `## Content`; each `wl` cell becomes an `Input`
cell carrying the `DefaultContent` tag the scraper needs. Mark them `#| eval: false`
because `ResourceObject[EvaluationNotebook[]]` only resolves in the deployed notebook
(headless conversion has no notebook context).

## Examples

Per the [official example-writing guide](https://reference.wolfram.com/language/workflow/WriteDataResourceExamples.html),
the Data Repository injects two special variables into the example cells of the
definition notebook:

- `$$Object` is the `ResourceObject` the notebook defines.
- `$$Data` is its primary `ResourceData`.

Use these in the example sections rather than hard-coding `ResourceObject[...]` /
`ResourceData[...]`, so the examples remain correct as the deployed name and version
change. Mark cells that reference `$$Object` / `$$Data` with `#| eval: false` (they
won't resolve in a headless convert); for runnable demonstrations, compute the same
expression inline.

The Data template's `ExampleNotebook` slot has four canonical subsections, in this
order: **Basic Examples**, **Scope & Additional Elements**, **Visualizations**,
**Analysis**. Each is filled by the same-named `##` heading in the markdown; absent
sections are simply skipped.

## Frontmatter

```
---
Template: Data
ResourceType: Data
Name: Periodic Polygon Symmetries
Description: Dihedral symmetry group data for regular polygons up to 12 sides
ContributedBy: Author Name
Keywords: [symmetry, polygon, group theory]
Categories: [Mathematics]
ContentTypes: [Numerical Data, Entity Store]
Author: First Last
Date: 2026
Publisher: Original Publisher
Language: English
Rights: CC0
Citation: "Last, F. (2026). Periodic Polygon Symmetries. ..."
GeographicCoverage: Global
TemporalCoverage: 2026
RelatedSymbols: [DihedralGroup, RegularPolygon]
Links: ["[Dihedral group (Wikipedia)](https://en.wikipedia.org/wiki/Dihedral_group)"]
---
```

`Categories` and `ContentTypes` are fixed checkbox groups - use only labels the
template defines (do not invent names). Always set both; an empty grid is a
submission hint.

## Convert and deploy

```wl
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["PeriodicPolygonSymmetries.md", "PeriodicPolygonSymmetries.nb"]
```

Deploy the resulting `.nb` via the docked **Deploy** button (or scrape into a
`ResourceObject` and `CloudDeploy` it, the way [build.wls](../build.wls) does);
submit with the **Submit** button or `ResourceSubmit`. Before submitting, run
`DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` and clear its hints -
[subtleties.md](subtleties.md) lists the common ones and their fixes.
