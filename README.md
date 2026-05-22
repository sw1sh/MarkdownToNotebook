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

## Layout

- [`MarkdownToNotebook.wl`](MarkdownToNotebook.wl) — the converter.
- [`MarkdownToNotebook.md`](MarkdownToNotebook.md) — its own Function Repository
  definition, authored in the very format it converts (self-hosting).
- [`bootstrap.wls`](bootstrap.wls) — defines the function from the markdown,
  converts it, and publishes it.
- [`docs/`](docs/) — the markdown ↔ notebook mapping, the palette/button catalog,
  formatting and resource-notebook references, hard-won [subtleties](docs/subtleties.md),
  and [`update-screenshots.wls`](docs/update-screenshots.wls).
- [`examples/AccessibleColors`](examples/AccessibleColors) — a complete worked
  example paclet (submodule), authored entirely in markdown and published as
  [Wolfram/AccessibleColors](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/):
  a guide, four symbol pages, a tutorial, and the Paclet Repository definition.

## Quick start

```wl
Get["MarkdownToNotebook.wl"];
MarkdownToNotebook["path/to/doc.md"]            (* writes doc.nb beside the source *)
MarkdownToNotebook[src, "Output" -> "Notebook"] (* return the Notebook expression *)
```

See [docs/README.md](docs/README.md) for the full conventions.
