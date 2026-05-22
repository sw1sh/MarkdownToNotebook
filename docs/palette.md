# Palette & docked-cell button catalog

Every button in the Documentation Tools palette (`…/Palettes/DocumentationTools.nb`)
and in the definition-notebook / doc-page docked toolbars, with its markdown
equivalent. Status: **[done]**, **[partial]**, **[todo]**.

![Documentation Tools palette](images/palette.png)

## Documentation Tools palette

### Page

| Button | Action | Markdown | Status |
|---|---|---|---|
| New Function Page | new `Symbol` page | `Template: Symbol` + `Name:` | done |
| New Guide Page | new `Guide` page | `Template: Guide` | done |
| New Tech Note | new `TechNote` page | `Template: TechNote` | done |
| Sample Function Page | open a filled example | (the AccessibleColors docs) | n/a |
| Open Function Page List | list a paclet's pages | `build.wls` over `docs/` | done |

### Insert

| Button | Cell style | Markdown | Status |
|---|---|---|---|
| Section | `Section` / `ExampleSection` | `## Heading` | done |
| Subsection | `Subsection` / `ExampleSubsection` | `### Heading` | done |
| Subsubsection | `Subsubsection` | `#### Heading` | done |
| Insert Text | `Text` / `ExampleText` | prose paragraph | done |
| Double Usage Line | `Usage` (`ModInfo`+`InlineFormula`+text) | `## Usage` line led by `` `Call[a,b]` `` | done |
| Details & Options | `Notes` | `## Details & Options` prose | done |
| Note | `Notes` item | prose under Details | done |
| Options Table | `OptionsTable` grid | markdown table under `## Options` | done |
| Options For Function | options listing | markdown table | done |
| Inline Listing | `InlineGuideFunction` chips | `## Functions` list (guide) | done |

### Links

| Button | Produces | Markdown | Status |
|---|---|---|---|
| Link to Function Page | `paclet:Pub/Name/ref/Sym` | `SeeAlso:` / `[Sym](paclet:…/ref/Sym)` | done |
| Link to Guide | `paclet:…/guide/G` | `RelatedGuides:` / `[G](paclet:…/guide/G)` | done |
| Link to Tech Note | `paclet:…/tutorial/T` | `[T](paclet:…/tutorial/T)` | done |
| Link to System Guide/Tech Note | `paclet:guide/…` etc. | `[g](paclet:guide/…)` | done |
| Link to URL | `Hyperlink` `ButtonBox` | `[text](https://…)` | done |
| Custom URI | arbitrary `paclet:` link | `[text](paclet:…)` | done |
| Make Link | linkify selection | inline `` `Symbol` `` (build resolves) | done |
| Edit Link | edit a link target | re-author the markdown link | n/a |

### Formatting (inline)

| Button | Box | Markdown | Status |
|---|---|---|---|
| Template Input | `Cell[BoxData[…],"InlineFormula"]` | `` `code` `` | done |
| Make / Default Format | parse selection | (default for `` `code` ``) | done |
| Italic Input | `StyleBox[…,"TI"]` | `*arg*` | done |
| Code Inline | `InlineCode` | `` ``code`` `` (double) | done |
| Literal / Plain Text | literal string | `` `"literal"` `` | done |
| Traditional Math | `TraditionalForm` | `$math$` | done |
| Annotate | search/annotate | n/a (authoring aid) | n/a |

### Tables

| Button | Markdown | Status |
|---|---|---|
| Insert Custom Table | `\| a \| b \|` rows + `\|---\|---\|` separator | done |
| Add Row / Sort / Merge / Span First Column | edit the markdown table | done (re-author rows) |
| Table Text | table cell prose (`TableText`) | done |

## Docked toolbars

### Doc-page toolbar (authoring)

| Button | Markdown | Status |
|---|---|---|
| Template Input | `` `code` `` | done |
| Section Header | `##`/`###`/`####` | done |
| Text | prose | done |
| Links (Guide/Symbol/URL) | `[..](..)` / frontmatter | done |
| Traditional Math | `$math$` | done |
| Build | `DocumentationBuildNotebook` (via `UsingFrontEnd`) | done (separate step) |

### FunctionResource / Paclet definition toolbar

| Button | Action | Markdown | Status |
|---|---|---|---|
| Choose (file/dir) | the function/paclet source | `## Definition` (`#\| file:`) | done |
| Deploy | local/cloud deploy | acts on the filled `.nb` | n/a (button) |
| Submit | submit to repository | acts on the filled `.nb` | n/a (button) |
| Check | `CheckDefinitionNotebook` | validate the generated `.nb` | done (Function); Paclet clean but for the interactive Choose-directory step |

"n/a (button)" means the action runs on the generated notebook in the front
end; markdown supplies the metadata it operates on, not the click.
