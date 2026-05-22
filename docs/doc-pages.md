# Documentation pages (Symbol / Guide / TechNote)

These compile to the same authoring notebooks the Documentation Tools palette
produces, then build with `DocumentationBuild`. The palette's job (insert
sections, format inline code, make links) is done from markdown structure.

## Symbol (function reference page)

![Symbol reference page](images/symbol-page.png)

````md
---
Template: Symbol
Name: WCAGContrastRatio
Context: Wolfram`AccessibleColors`
Paclet: Wolfram/AccessibleColors
URI: Wolfram/AccessibleColors/ref/WCAGContrastRatio
Keywords: [contrast, WCAG]
SeeAlso: [WCAGLevel, AccessibleTextColor]
RelatedGuides: [AccessibleColors]
---

## Usage

`WCAGContrastRatio[c1, c2]` gives the ratio between colors `c1` and `c2`.

## Details & Options

Prose, possibly referencing `ColorConvert` and option `c1`.

## Basic Examples

Prose lead-in:

```wl
WCAGContrastRatio[Black, White]
```
````

| Markdown | Palette / cell | Notebook |
|---|---|---|
| `# Name` / `Name:` | New Function Page | `ObjectName` |
| `## Usage` line, leading `` `Call[a,b]` `` | Double Usage Line | `Usage` cell: `ModInfo` + linked-call `InlineFormula` + description |
| `## Details & Options` prose | Details & Options / Note | `Notes` |
| `## Basic Examples` + `wl` cells | Insert Text + Input | `PrimaryExamplesSection`, `ExampleText`, `Input`/`Output` |
| `Context:` | (load paclet) | `ExamplesInitializationSection` -> `Needs["Context`"]` |
| `SeeAlso: [..]` | Links ▸ Link to Function Page | `SeeAlsoSection` with `paclet:Pub/Name/ref/X` links |
| `RelatedGuides: [..]` | Links ▸ Link to Guide | `MoreAboutSection` |
| `URI:` / `Keywords:` | Metadata / Keywords sections | build metadata + `Keywords` |

Examples are evaluated (cached) and spliced as `Output` cells. The first `wl`
example lands under `PrimaryExamplesSection`. A `wl` cell may be followed by an
`<!-- => ... -->` comment recording the expected output; comments are stripped
on conversion, so they document the source without affecting the build.

A Symbol page has **no** `Description:` field. Unlike a Guide, the function
summary comes from the `## Usage` line, so frontmatter carries only metadata
(`Name`, `Context`, `Paclet`, `URI`, `Keywords`, `SeeAlso`, `RelatedGuides`).

Extended example sections (`## Scope`, `## Options`, `## Applications`,
`## Properties and Relations`, `## Possible Issues`, `## Neat Examples`) are
populated under the "More Examples" group: each maps to its `ExampleSection`
title (an `InterpretationBox` counter cell that resets the `In[]`/`Out[]`
numbering), wrapped in a `CellGroupData` with the section's prose, examples and
tables. Sections with no content are dropped (built pages omit empty sections).

## Guide

![Guide page](images/guide-page.png)

```md
---
Template: Guide
Name: AccessibleColors
Paclet: Wolfram/AccessibleColors
URI: Wolfram/AccessibleColors/guide/AccessibleColors
Keywords: [...]
RelatedGuides: [...]
Links: [...]
---

## Abstract

One paragraph.

## Functions

- `WCAGContrastRatio` the contrast ratio between two colors
- `WCAGLevel` the conformance level of a color pair
```

| Markdown | Notebook |
|---|---|
| `Name:` / `Title:` | `GuideTitle` |
| `## Abstract` (or `Description:`) | `GuideAbstract` |
| `## Functions` list | `GuideFunctionsSection` with one `GuideText` per item, led by an `InlineGuideFunction` chip |
| `RelatedGuides:` | `GuideMoreAbout` |
| `Links:` | `GuideRelatedLinks` |
| `Keywords:` | `Keywords` |

The `## Functions` list (the palette's *Inline Listing*) renders one `GuideText`
cell per `- `` `Symbol` `` description` item: the leading inline-code symbol
becomes a linked `InlineGuideFunction` chip and the rest is its description.

## TechNote (Tutorial)

![Tutorial page](images/tutorial-page.png)

Built from `TechNoteBaseTemplateExt` (-> `TechNotePageStylesExt`). A tech note is
free-flowing, so the body is mapped directly rather than into fixed sections:

```md
---
Template: TechNote
Name: DesigningAccessibleColorSchemes
Title: Designing Accessible Color Schemes
Context: Wolfram`AccessibleColors`
Paclet: Wolfram/AccessibleColors
URI: Wolfram/AccessibleColors/tutorial/DesigningAccessibleColorSchemes
Keywords: [...]
RelatedGuides: [AccessibleColors]
---

Intro paragraph.

## Measuring Contrast

prose, then a `wl` cell.
```

| Markdown | Notebook |
|---|---|
| `Title:` (falls back to `Name:`) | `Title` |
| `## Heading` / `###` / `####` | `Section` / `Subsection` / `Subsubsection` |
| prose | `Text` |
| `wl` cells | `Input` / evaluated `Output` |
| tables / lists | `GridBox` / `Item` |
| `RelatedGuides:` | `TutorialMoreAbout` (Related Guides) |
| `RelatedTutorials:` | `RelatedTutorials` (Related Tech Notes) |
| `Keywords:` | `Keywords`; `URI:` -> `tutorial/...` |

`Name` is the file/URI id (no spaces); `Title` is the displayed heading.

## Building

```wl
Needs["DocumentationBuild`"];
UsingFrontEnd @ DocumentationBuildNotebook[None, Get["…/Symbols/X.nb"]]
```

`UsingFrontEnd` is required: the Build/Preview path reads metadata via
`CurrentValue` and resolves links in the front end. Running it inside
`LocalSubmit` (a separate kernel) isolates the front-end session.
