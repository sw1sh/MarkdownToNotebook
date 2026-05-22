# MarkdownToNotebook conventions

`MarkdownToNotebook[source]` turns a literate-markdown document (file path,
http(s) URL, or raw string) into a Wolfram notebook. The goal is that **the
markdown can express almost everything the Documentation Tools palette and the
definition-notebook docked toolbars provide**, without ever editing notebook
cell styles by hand.

A document is:

````md
---
<frontmatter: metadata, key: value>
---

## Section

prose, with `inline code`

```wl
example code
```
````

The `Template` frontmatter key selects the layout; everything else (sections,
inline code, cell options) maps onto that template. These docs describe the
mapping.

## Templates

| `Template:` | Notebook | Stylesheet / source |
|---|---|---|
| `Default` (or absent) | plain styled notebook | `Default.nb` |
| `Symbol` | function/symbol reference page | `FunctionBaseTemplateExt` -> `FunctionPageStylesExt` |
| `Guide` | guide page | `GuideBaseTemplateExt` -> `GuidePageStylesExt` |
| `TechNote` | tech note / tutorial | `TechNoteBaseTemplateExt` -> `TechNotePageStylesExt` |
| `FunctionResource` | Function Repository definition | `DefinitionTemplate["Function"]` |
| `Paclet` | Paclet Repository definition | `DefinitionTemplate["Paclet"]` |

- **Doc pages** (`Symbol`/`Guide`/`TechNote`) are *authoring* notebooks; the
  docked **Build** button (`DocumentationBuild`) turns them into the final
  pages (adding the anchor bar, footer, example counters, resolving links).
- **Resource notebooks** (`FunctionResource`/`Paclet`) keep the official
  template's stylesheet and docked **Deploy / Submit / Check** toolbar, so the
  output `.nb` is publishable as-is.

## The reference docs

- [doc-pages.md](doc-pages.md) - `Symbol`, `Guide`, `TechNote`: sections,
  frontmatter, and the palette features they cover.
- [resource-notebooks.md](resource-notebooks.md) - `FunctionResource` and
  `Paclet`: metadata slots, examples, and the Deploy/Submit/Check toolbar.
- [formatting.md](formatting.md) - inline `code`, code cells, file includes,
  links, and the palette's formatting buttons.
- [palette.md](palette.md) - every Documentation Tools palette and docked-cell
  button, with its markdown equivalent and status.
- [resource-guidelines.md](resource-guidelines.md) - a refined working copy of the
  official Function/Paclet Repository style guidelines, with how each maps to
  markdown. Re-fetch the linked sources when in doubt.
- [subtleties.md](subtleties.md) - hard-won gotchas encountered building the
  converter and the example paclet.

The screenshots in these pages (`images/*.png`) are regenerated from source by
[update-screenshots.wls](update-screenshots.wls): it converts the
AccessibleColors markdown, runs `DocumentationBuild` on the doc pages, loads the
live palette, and rasterizes each notebook. Run `wolframscript
docs/update-screenshots.wls` after changing the converter or the example docs.

## Frontmatter keys (all templates)

| Key | Meaning | Templates |
|---|---|---|
| `Template` | layout selector | all |
| `Name` | symbol / page / resource name | all |
| `Description` | one-line summary | Guide, resources (not Symbol; its summary is the `## Usage` line) |
| `Context` | `Pub`AccessibleColors`` (loads paclet symbols for examples) | doc pages |
| `Paclet` | `Pub/Name` (link base, metadata) | doc pages, Paclet |
| `PacletDirectory` | path to the paclet source (directory tagging rule) | Paclet |
| `URI` | `Pub/Name/ref/Symbol` (build metadata) | doc pages |
| `Keywords` | `[list]` of search terms | all |
| `Categories` | `[list]`; checkbox grid | resources |
| `SeeAlso` | `[list]` of related symbols -> linked | Symbol |
| `RelatedGuides` | `[list]` of guides -> More About / links | doc pages |
| `Links` | `[list]` of URLs | Guide, resources |
| `Sources` | `[list]` of citations | FunctionResource |
| `ContributedBy` | author | resources |
| `OperatingSystems`/`Environments`/`CloudSupport`/`Features` | compatibility checkboxes | FunctionResource |
| `WolframVersion` | e.g. `14.0+` | FunctionResource |
| `EntrySymbol` | the function symbol (self-hosting) | FunctionResource |

`MarkdownToNotebook` takes no options. The layout is the document's `Template`
frontmatter; the optional second argument selects the result (`"Notebook"`,
`"Association"`, or a file path to write); example outputs are cached with the
built-in persistence framework (`PersistentSymbol` at `"Local"`).
