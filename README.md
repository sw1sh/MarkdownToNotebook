# MarkdownToNotebook

`MarkdownToNotebook[source]` converts a literate-markdown document (a file path,
an `http(s)` URL, or a raw string) into a Wolfram notebook, choosing the layout
from a `Template` frontmatter key. The goal is that **the markdown can express
almost everything the Documentation Tools palette and the definition-notebook
docked toolbars provide**, so authors never hand-edit notebook cell styles.

One source format produces:

- **`Symbol`** / **`Guide`** / **`TechNote`** documentation pages (the authoring
  notebooks `DocumentationBuild` turns into reference/guide/tutorial pages);
- **`FunctionResource`** / **`Paclet`** definition notebooks (the official
  templates, with their docked Deploy / Submit / Check toolbar, publishable as-is);
- **`Default`** plain styled notebooks.

Frontmatter drives metadata; `## sections` and fenced ` ```wl ` cells become the
content; example cells are evaluated and cached. A `#| file: path` cell inlines a
`.wl` file or URL.

The function is deployed publicly in the Wolfram Cloud, so you can use it without
installing anything:

```wl
ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]["doc.md"]
```

> **Note:** official publication to the [Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository/)
> is pending review. Until then, use the public cloud link above (or the local
> `MarkdownToNotebook.wl`).

## Layout

- [`MarkdownToNotebook.wl`](MarkdownToNotebook.wl) - the converter.
- [`MarkdownToNotebook.md`](MarkdownToNotebook.md) - its own Function Repository
  definition, authored in the very format it converts (self-hosting).
- [`build.wls`](build.wls) - defines the function from the markdown,
  converts it, and publishes it. [`build-out.wls`](build-out.wls) regenerates
  the GitHub-renderable markdown twin.
- [`docs/`](docs/) - the markdown <-> notebook mapping, the palette/button catalog,
  formatting and resource-notebook references, hard-won [subtleties](docs/subtleties.md),
  and [`update-screenshots.wls`](docs/update-screenshots.wls).
- [`examples/`](examples/) - worked example documents (see below).

## Applications

End-to-end markdown-authored Wolfram artifacts built with `MarkdownToNotebook`:

- [`examples/AccessibleColors`](examples/AccessibleColors) - a complete
  paclet (submodule), authored entirely in markdown and published as
  [Wolfram/AccessibleColors](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/):
  a guide, four symbol pages, a tutorial, and the Paclet Repository definition.
- [`examples/IntroToQuantumComputing`](examples/IntroToQuantumComputing) - a
  two-chapter book using the new `Template: Chapter` (Wolfram Book Tools
  styles): exercises with solutions, vocabulary tables, Q&A, solved
  examples, theorem/proof blocks, tech notes, summary, and references.
  Generates a `Contents.nb` (using the WolframBookTools paclet's own
  inline TOC stylesheet and cell shape) plus a `Master.nb` that
  concatenates the chapters into one book-form notebook (mirroring
  `WBTCreateCorrespondingPrintDirectory`). Published to the cloud at:
  - [Master](https://www.wolframcloud.com/obj/nikm/IntroToQuantumComputing/Master.nb)
  - [Contents](https://www.wolframcloud.com/obj/nikm/IntroToQuantumComputing/Contents.nb)
  - [Chapter 1: What Is Quantum Computation?](https://www.wolframcloud.com/obj/nikm/IntroToQuantumComputing/01-what-is-quantum-computation.nb)
  - [Chapter 2: Building Blocks of Quantum Circuits](https://www.wolframcloud.com/obj/nikm/IntroToQuantumComputing/02-building-blocks-of-quantum-circuits.nb)
- Other markdown -> notebook samples under [`examples/`](examples/)
  (AdaLovelace, BlochSphereGates, PiIsMostlyRandom, PrimeSpiralPoints,
  QuantumWalk, ReverseAddSequence, WallpaperGroups) - each a single notebook
  rendered with the `Default` / `Essay` templates.

## Quick start

```wl
Get["MarkdownToNotebook.wl"];
MarkdownToNotebook["path/to/doc.md"]              (* returns the Notebook expression *)
MarkdownToNotebook["path/to/doc.md", "doc.nb"]   (* also writes doc.nb, returns the file *)
```

See [docs/README.md](docs/README.md) for the full conventions, and
[GUIDE.md](GUIDE.md) for the Wolfram Language coding style the `.wl` and
`.wls` sources follow.

## Implementation notes

Parsing is pure Wolfram, kept in the `## Definition` cells: there is no
paclet directory and no native (C/Rust) extension. If inline-markdown
fidelity ever needs a real CommonMark parser, swap only the inline layer
(comrak via LibraryLink, or a pandoc shell-out); the block parser and the
evaluate/cache engine are unaffected. Example outputs are evaluated once
and cached as `PersistentObjects` keyed by a cumulative content hash of
the example cells.

The official, submittable `FunctionResource` definition notebook is the one
`CreateNotebook["FunctionResource"]` (front end) or
`ResourceFunction["CreateResourceNotebook"]["Function"]` (kernel) opens. Its
template is `FunctionResource/Kernel/Templates/FunctionResourceDefinition.nb`;
the Deploy / Submit toolbar lives in docked cells
(`TemplateBox[{}, "MainGridTemplate"]`) of `FunctionResourceDefinitionStyles.nb`,
driven by the `DefinitionNotebookClient` paclet. The converter fills that
template directly, so publishing stays headless.
