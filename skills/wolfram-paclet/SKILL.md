---
name: wolfram-paclet
description: Author a Wolfram Paclet Repository paclet's definition notebook (ResourceDefinition.nb) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to create, write, or publish a Wolfram Language paclet, a Paclet Repository resource, or a paclet ResourceDefinition - including its metadata, usage, examples, and hero image. Pair it with the Symbol, Guide, and TechNote skills, which author the paclet's documentation pages.
---

# Authoring a paclet definition in markdown

A paclet's `ResourceDefinition.nb` is the Paclet Repository's deployable definition
notebook. `MarkdownToNotebook` fills it from a literate-markdown document with the
`Paclet` template. The worked example is the AccessibleColors paclet definition at
https://github.com/sw1sh/AccessibleColors/blob/main/ResourceDefinition.md ; model
new paclets on it and read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md
and https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-guidelines.md
for the slot mapping and Paclet Repository rules.

A paclet is more than this one notebook: it also has documentation pages (guide,
symbol reference pages, tech notes) and a `PacletInfo.wl`. Author the pages with the
`wolfram-guide-page`, `wolfram-symbol-page`, and `wolfram-tech-note` skills; the
metadata here must agree with `PacletInfo.wl`.

Read first - the canonical guidelines:

- Paclet Repository, creating paclets (the build, deploy and submit workflow): https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines (the rules a paclet is reviewed against): https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

```
---
Template: Paclet
ResourceType: Paclet
Name: Publisher/PacletName
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
Description: WCAG color-contrast and accessibility utilities for the Wolfram Language
ContributedBy: Author Name
Keywords: [keyword one, keyword two]
MainGuide: Documentation/English/Guides/PacletName.nb
License: MIT
WolframVersion: 14.0+
Categories: [Visualization & Graphics]
Sources: ["A bibliographic citation"]
SourceControlURL: https://github.com/you/PacletName
Links: ["[label](https://example.com)"]
---
```

Notes that bite (see
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/subtleties.md):
`Name`/`Paclet` include the publisher
ID (`Publisher/PacletName`); `MainGuide` is the **relative** notebook path, not a
bare name; `Description` must match `PacletInfo.wl`'s `"Description"` exactly; each
`Sources` entry is one citation (commas inside it are preserved). `Categories` fills
a fixed checkbox group, so always set it to one or more **valid Paclet Repository
categories** (do not invent names) - an empty group is a submission hint.

## Sections

- `## Details & Options` - bullets become `Notes` cells; pipe tables become grids.
- `## Usage` - the symbols the paclet provides, as `<code>[`Symbol`]()</code>`
  inferred reference links (the `<code>` wrapper applies code styling, the empty
  parens make markdown viewers render it as a clickable link).
- Example sections (`## Basic Examples`, `## Scope`, `## Applications`, ...) - one
  computation per example; separate siblings with a `---` line.
- `## Hero Image` - the landing-page image. Its first executable cell is evaluated;
  show the image and keep the generating code in a closed group (the converter uses
  the `Cell[CellGroupData[{input, output}, {2}]]` idiom). The scraped image must be
  400-1500 px on each side with aspect ratio `h/w` in 0.5-1.25, or the build flags
  `HeroImageTooSmall`/`TooLarge`/`Squashed`.

## Code-cell options

`#|` lines at the top of a fenced `wl` cell: `eval`, `file`, `screenshot`, `tear`,
`flag` (one `key: value` per line). Inline math is `$...$`; to link a documented
symbol inline, wrap an inferred ref in `<code>`: `<code>[`Symbol`]()</code>`.

## Build and deploy

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["ResourceDefinition.md", "ResourceDefinition.nb"]
```

Build the documentation pages with `DocumentationBuild` (the Symbol/Guide/TechNote
notebooks the other skills produce). Deploy the paclet definition by scraping it
into a `ResourceObject` and `CloudDeploy`-ing it (a headless `DeployResource`
scrapes empty - see
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/subtleties.md); submit
with `ResourceSubmit`. Run
`DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` and clear its hints first.
