---
name: wolfram-overview-page
description: Author a Wolfram Language paclet overview page (the high-level table-of-contents page a paclet's Documentation index links to, like the built-in Overview pages, with TOCChapter / TOCSection / TOCSubsection heading hierarchy) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate an overview page, a TOC page, a documentation index, or a paclet landing-page TOC for a Wolfram paclet - especially when the paclet has more than one guide / several tutorials / a large set of symbol pages and needs a navigable index.
---

# Authoring a paclet Overview page in markdown

`MarkdownToNotebook` fills the DocumentationTools overview page (which
`DocumentationBuild` turns into the `tutorial/Overview` page the paclet's
docs index links to) from a literate-markdown document with the `Overview`
template. An overview page is a paclet's documentation table of contents:
nested clickable headings that drill into the paclet's Guide, its symbol
ref pages, and its tutorials. The worked example is the AccessibleColors
overview at
https://github.com/sw1sh/AccessibleColors/blob/main/docs/Tutorials/Overview.md ;
model new overviews on it.

An Overview page is a *peer of TechNotes* (shares the `tutorial/` URI
namespace - `DocumentationTools`PreCreateNewPageDialog["Overview"]` writes
its files under `$TutorialDirectory`), so the built `.nb` lives in
`Documentation/English/Tutorials/Overview.nb` alongside the paclet's
tutorial notebooks.

Read first - the canonical guidelines (an overview page lives inside a
paclet, so the Paclet Repository rules apply to it):

- Paclet Repository, creating paclets: https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines: https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

```
---
Template: Overview
Name: PacletDisplayName
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
URI: Publisher/PacletName/tutorial/Overview
Keywords: [keyword one, keyword two]
---
```

`Name` is the display title that fills the `TOCDocumentTitle` cell at the
top of the rendered overview - typically the paclet's pretty name
("AccessibleColors"). `URI` ends in `tutorial/Overview` (Overview lives in
the tutorial namespace). `Paclet` and `Context` mirror the values used by
the paclet's Guide and Symbol pages.

The file basename (the `.md` name) must be `Overview.md` - it becomes the
output `.nb` basename and the URI's last segment, and the build script
maps the file path to the URI through that name. `Name:` is the display
title, distinct from the basename.

## Body: the TOC hierarchy

Heading depth picks the TOC cell style:

| Markdown | Cell style |
|---|---|
| `#` | `TOCDocumentTitle` (silently dropped - the title cell is filled from frontmatter `Name:`) |
| `##` | `TOCChapter` |
| `###` | `TOCSection` |
| `####` | `TOCSubsection` |
| `#####` | `TOCSubsubsection` |

A bulleted list under a heading becomes TOC leaves *one level deeper than
the heading* - the natural pattern for grouping page links under each
chapter:

```
## Symbols

- [WCAGContrastRatio](paclet:Wolfram/AccessibleColors/ref/WCAGContrastRatio)
- [WCAGLevel](paclet:Wolfram/AccessibleColors/ref/WCAGLevel)

## Tutorials

- [Designing Accessible Color Schemes](paclet:Wolfram/AccessibleColors/tutorial/DesigningAccessibleColorSchemes)
```

renders as:

- *TOCChapter* "Symbols"
  - *TOCSection* clickable "WCAGContrastRatio" → ref page
  - *TOCSection* clickable "WCAGLevel" → ref page
- *TOCChapter* "Tutorials"
  - *TOCSection* clickable "Designing Accessible Color Schemes" → tutorial

Each `[Label](paclet:Pub/Pkg/<kind>/Name)` link in a TOC entry renders as a
clickable `ButtonBox`. The inferred-link form `[Name]()` is treated as a
tutorial in the documented paclet (the conventional shape for an overview
entry), so `[DesigningAccessibleColorSchemes]()` resolves to
`paclet:<Paclet>/tutorial/DesigningAccessibleColorSchemes`. Use the
explicit `paclet:Pub/Pkg/ref/Name` for symbol links and
`paclet:Pub/Pkg/guide/Name` for guide links.

A heading without a link (a section grouping, not a leaf entry) renders
as a plain TOC heading. Backticks / italic / math in the heading text
parse through the same inline rules prose uses, so
`## `MyFn` overview` renders the `MyFn` as an `InlineFormula` span in the
TOC chapter.

## Conventional structure

The typical layout an overview author follows is one chapter per
documentation kind:

```
# PacletDisplayName

## Guide

- [PacletDisplayName](paclet:Pub/Pkg/guide/PacletDisplayName)

## Symbols

- [SymA](paclet:Pub/Pkg/ref/SymA)
- [SymB](paclet:Pub/Pkg/ref/SymB)
- ...

## Tutorials

- [TutorialA](paclet:Pub/Pkg/tutorial/TutorialA)
- [TutorialB](paclet:Pub/Pkg/tutorial/TutorialB)
```

For a larger paclet you may further group symbols by topic with `###`
subheadings:

```
## Symbols

### Color contrast
- [WCAGContrastRatio](paclet:Wolfram/AccessibleColors/ref/WCAGContrastRatio)
- [WCAGLevel](paclet:Wolfram/AccessibleColors/ref/WCAGLevel)

### Color adjustment
- [AdjustForContrast](paclet:Wolfram/AccessibleColors/ref/AdjustForContrast)
- [AccessibleTextColor](paclet:Wolfram/AccessibleColors/ref/AccessibleTextColor)
```

`###` becomes `TOCSection`, and its leaves become `TOCSubsection` -
clickable links indented under the section name.

## Build

The paclet's `build.wls` maps `Template: Overview` to the same
`Documentation/English/Tutorials/` directory the TechNote pages live in.
The output `.nb` basename is the source `.md`'s basename:

```
docs/Tutorials/Overview.md  ->  Documentation/English/Tutorials/Overview.nb
```

`DocumentationBuild` (run as the next step of the paclet build) picks up
the Overview alongside the tutorials and writes it into the paclet's
final documentation tree under
`Documentation/English/Tutorials/Overview.nb`.

```wl
(* In the paclet's build.wls, add Overview to the subdir map: *)
subdir["Symbol"] = {"Documentation", "English", "ReferencePages", "Symbols"}
subdir["Guide"] = {"Documentation", "English", "Guides"}
subdir["TechNote"] = {"Documentation", "English", "Tutorials"}
subdir["Overview"] = {"Documentation", "English", "Tutorials"}
```

If the paclet's build script picks the output file name from the
frontmatter `Name:` (the common pattern for Symbol / Guide / TechNote),
update it to use `FileBaseName[srcFile]` - the Overview's display `Name:`
is the paclet title (different from the URI tail `Overview`), so it must
not become the file name.

## Check

Doc-tools pages (`Symbol` / `Guide` / `TechNote` / `Overview`) are NOT
resource definitions, so the `DefinitionNotebookClient`CheckDefinitionNotebook`
lint that resource templates use does not apply (it returns
`::charg` / `::nbortype` for any doc-tools `.nb`). The page is validated
by `DocumentationBuild` itself - a missing URI, broken paclet reference,
or unresolvable See Also entry shows up there.

Author's checklist for an Overview:

- Frontmatter `URI: Pub/Pkg/tutorial/Overview` is correct.
- The source file is named `Overview.md` (so the output is `Overview.nb`,
  matching the URI tail).
- Every TOC entry under a `## Chapter` is a clickable
  `[Label](paclet:Pub/Pkg/<kind>/Name)` link; bare strings render as
  unclickable headings (still valid, just not navigable).
- The link targets exist: every `ref/SymA` resolves to a built symbol
  page, every `guide/G` to a built guide, every `tutorial/T` to a built
  tutorial. `DocumentationBuild` warns when a See Also or TOC link does
  not resolve in the local doc tree.
