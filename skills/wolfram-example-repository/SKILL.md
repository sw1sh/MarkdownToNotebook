---
name: wolfram-example-repository
description: Author a Wolfram Example Repository resource (a deployable Example with named content elements and worked examples) as a literate-markdown document and convert it to the official definition notebook with MarkdownToNotebook. Use this whenever the user wants to create, write, draft, or publish a Wolfram Example Repository resource, an Example resource, a curated dataset or example notebook exposed via ResourceData - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add content elements, examples, or metadata to such a resource.
---

# Authoring an Example Repository resource in markdown

`MarkdownToNotebook` fills the official Example Repository definition notebook (the
one `CreateNotebook["Example"]` opens, with its docked Deploy/Submit toolbar) from a
literate-markdown document. An Example resource exposes one or more named **content
elements** (data fetched with [`ResourceData`]) together with worked examples that
show how to use them. The author writes YAML frontmatter and `## section` headings;
the converter chooses every cell style. Use the `Example` template.

Model new documents on the worked examples - a minimal one at
https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/PrimeSpiralPoints.md
and a richer one (multiple content elements, `eval: false` content cells, inline
math, several plots, a hero) at
https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/QuantumWalk.md - and
read https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md
(the "Example" section) for the slot-by-slot mapping.

Read first - the canonical guidelines:

- Example Repository submission guidelines: https://resources.wolframcloud.com/ExampleRepository/guidelines
- Example Repository style guidelines (the rules a submission is reviewed against): https://resources.wolframcloud.com/ExampleRepository/style-guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top:

```
---
Template: Example
ResourceType: Example
Name: Prime Spiral Points
Description: One-line summary of what the content is
ContributedBy: Author Name
Keywords: [keyword one, keyword two]
Categories: [Visualization & Graphics]
RelatedSymbols: [RelatedSymbol, AnotherSymbol]
Links: ["[label](https://example.com)"]
---
```

`Categories` fills a fixed checkbox group, so each entry must be one of the official
Example Repository categories (pick the one or few that fit; do not invent names):
Algebra, Astronomy, Audio Processing, Calculus, Cellular Automata, Chemistry,
Complex Systems, Computer Science, Computer Vision, Control Systems, Creative Arts,
Data Science, Engineering, Finance & Economics, Finite Element Method,
Food & Nutrition, Geography, Geometry, Graphs & Networks, Image Processing,
Life Sciences, Machine Learning, Mathematics, Notebooks & User Interfaces,
Optimization, Physics, Presentation & Publication, Puzzles and Recreation,
Quantum Computation, Signal Processing, Social Sciences, System Modeling,
Text & Language Processing, Time-Related Computation, Video Processing,
Visualization & Graphics. Always set `Categories` - an empty group is a submission hint.

## Sections (each `## Heading` fills a slot)

- `## Content` - the resource's content elements. Each executable `wl` cell is the
  literal defining assignment, typically
  `ResourceData[ResourceObject[EvaluationNotebook[]], "name"] = value`; the converter
  turns it into an `Input` cell carrying the `"DefaultContent"` tag the scraper needs.
  Use one cell per named element.
- `## Examples` - intro prose plus runnable computations that demonstrate the content
  (the Example template has a single Examples slot, so this fills it directly - no
  named sub-sections like a Function resource). Separate sibling examples with a `---`
  line, which restarts the `In[]`/`Out[]` numbering.
- `## Hero Image` - the landing-page image. Its first executable cell is evaluated;
  the converter keeps the image with its generating code in a closed group
  (`Cell[CellGroupData[{input, output}, {2}]]`). The scraped image must be 400-1500 px
  on each side with aspect ratio `h/w` in 0.5-1.25.

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line: `eval: false` (show code without running),
`file: path` (replace the body with a local file or URL), `screenshot: true`
(rasterize a produced `Notebook`), `tear: h` (torn-paper screenshot capped to `h`
points), `flag: future|excised|...`. Record an example's expected result in an
`<!-- => ... -->` comment after the cell. Inline math is `$...$`. To link a
documented symbol inline, wrap an inferred ref in `<code>`:
`<code>[Symbol]()</code>` - the empty parens make markdown viewers render it as a
clickable link, and the `<code>` wrapper applies code styling. The converter routes
the empty-URL link through `linkInferred` to a `paclet:` ref; the twin rewrites it
to the public web URL.

Examples that fetch the *deployed* resource (`ResourceData[ResourceObject["Name"], ...]`)
cannot evaluate before the resource exists, so either compute the same expression
inline (so the example produces real output) or mark those cells `eval: false`.

## Convert and deploy

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["PrimeSpiralPoints.md", "PrimeSpiralPoints.nb"]
```

To deploy publicly, do **not** rely on a headless `DeployResource` (it scrapes an
empty definition); scrape the notebook into a `ResourceObject` and `CloudDeploy` the
result - see the deploy note in
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/subtleties.md . Submit to
the repository with the docked Submit button or `ResourceSubmit`. Before submitting,
run `DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` and clear its hints (that
doc lists the common ones and their fixes).
