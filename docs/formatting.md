# Inline formatting, code cells, includes, links

This maps the Documentation Tools palette's Formatting / Insert / Links tools to
markdown. Legend: **[done]** supported now, **[todo]** recognized direction.

## Inline `code`  ->  Template Input  [done]

Every backtick span becomes the palette's **Template Input**: the text is parsed
to boxes and wrapped as `Cell[BoxData[<boxes>], "InlineFormula"]`.
`DocumentationBuild` then linkifies known symbols at build time, exactly as if a
human had selected the text and pressed Template Input.

```md
the `WCAGContrastRatio` of two colors `c1` and `c2`
```
-> three `InlineFormula` cells; `WCAGContrastRatio` resolves to its ref page,
`c1`/`c2` render as code.

The palette offers other inline conversions on the same selection; proposed
markdown for each (most **[todo]**):

| Palette button | Style | Markdown |
|---|---|---|
| Template Input | `InlineFormula` | `` `code` `` **[done]** |
| Code (Inline) | `InlineCode` | `` ``code`` `` (double) **[done]** |
| Italic / argument | `StyleBox[…,"TI"]` | `*italic*` or `_italic_` **[done]** |
| Bold | `StyleBox[…,FontWeight->"Bold"]` | `**bold**` or `__bold__` **[done]** |
| Bold italic | `StyleBox[…,"TI",FontWeight->"Bold"]` | `***both***` **[done]** |
| Strikethrough | `StyleBox[…,FontVariations->{"StrikeThrough"->True}]` | `~~struck~~` **[done]** |
| Subscript | `SubscriptBox["",s]` in an `InlineFormula` cell | `H<sub>2</sub>O` (also `H~2~O`) **[done]** |
| Superscript | `SuperscriptBox["",s]` in an `InlineFormula` cell | `2<sup>10</sup>` (also `2^10^`) **[done]** |
| Plain Text / Literal | `InlineFormula` literal string | `` `"literal"` `` (a string parses to itself) **[done, implicit]** |
| Traditional Math | `FormBox[…,TraditionalForm]` | `$math$` inline, `$$math$$` centered display **[done]** |
| Inline image | embedded graphic (or link fallback) | `![alt](src)` mid-text **[done]** |

Underscore emphasis is matched only at word boundaries, so `snake_case` in prose is
left alone (use `*…*` if a single word ever needs emphasis). A backslash escapes the
next punctuation character (`\*`, `` \` ``, `\_`, ...) so it renders literally.

Prefer the HTML `<sub>` / `<sup>` form: every markdown renderer (CommonMark, GFM,
Pandoc with its default `markdown` flavor and almost every other) treats these as
literal HTML and renders them as subscripts / superscripts. The `~i~` / `^i^` Pandoc
shorthand needs the `subscript` / `superscript` extension, which not every flavor
turns on. Neither form renders inside a markdown code span, because markdown forbids
nested formatting there.

A `## Usage` signature should therefore be written wrapped in an inline `<code>`
tag - GitHub and Pandoc *do* process markdown inside an inline HTML element, so the
nested formatting (head as inferred link, args as math or italic) all renders, while
the whole span gets code-styling from the `<code>` wrapper:

```
<code>[`SymbolName`]()[$x_1$, $x_2$]</code> gives the foo, computed from $x_1$ and $x_2$.
```

Renders in pandoc / GitHub as a code-styled clickable link to the symbol's ref page,
then literal brackets with italic *x*₁, *x*₂ from the inline math. The converter
strips the `<code>` wrapper, peels the `[`Name`](…)` link down to the name, drops
`*…*` italics around args, and rewrites each `$x_i$` to the template form `x$i`
before handing the signature to `ParseTextTemplate`. Bare backtick forms (`` `f[x]` ``,
`` `f`[$x$] ``, plain `f[$x$]`) still work for the converter as fallbacks.

## Code cells  [done]

A fenced `wl` (or `wolfram`/`mathematica`) cell becomes an `Input` cell. In the
example sections it is evaluated and the result is spliced as an `Output` cell;
outputs are cached (see below).

````
```wl
WCAGContrastRatio[Black, White]
```
````

### Cell options (`#|`)  [done]

Quarto-style option lines at the top of a cell:

````
```wl
#| eval: false
#| file: Kernel/MyFunction.wl
SomeCode
```
````

| Option | Effect |
|---|---|
| `file: path` | replace the cell body with the contents of that file or URL (the **include** mechanism), resolved relative to the document |
| `eval: false` | keep the input cell, do not evaluate / no `Output` |

## Caching  [done]

Every executable cell is evaluated in document order in a private context, so a
cell's cache key is a cumulative hash of all preceding cells (whole-notebook
sequential evaluation). Re-converting an unchanged document reuses cached outputs,
stored with the built-in persistence framework as a `PersistentSymbol` per cell at
the `"Local"` location (`PersistentObjects["MarkdownToNotebook/ExampleOutput/*"]`
to list, `DeleteObject` to clear).

## Links  [partial]

- `SeeAlso` / `RelatedGuides` frontmatter -> resolved `paclet:` reference links
  (the palette's *Link to Function Page* / *Link to Guide*). **[done]**
- Symbols inside `` `code` `` -> linkified by `DocumentationBuild`. **[done]**
- Inline markdown links `[text](url)` -> `Hyperlink` `ButtonBox`, and
  `[sym](paclet:Pub/Name/ref/Sym)` -> a reference `Link` (palette *Link to URL*
  / *Custom URI*). **[done]**
- Inferred-reference forms `` [`Symbol`] `` and `` [`Symbol`]() `` -> a code-styled
  `Link` button to the resolved `paclet:` URL in the notebook; in the `-out.md`
  twin the same forms are expanded to the public HTTPS URL
  (`reference.wolfram.com/language/ref/Symbol.html` for System symbols,
  `resources.wolframcloud.com/PacletRepository/resources/Pub/Name/ref/Symbol` for
  paclet ones), so GitHub renders them as clickable links. Unresolvable names and
  non-paclet URLs are left untouched. **[done]**

## Structure  [done / partial]

| Palette insert | Markdown | Status |
|---|---|---|
| Section / Subsection / Subsubsection | `##` / `###` / `####` headings | done |
| Insert Text / Example Text | prose paragraphs | done |
| Double Usage Line | `## Usage` line led by `` `Call[args]` `` | done |
| Details & Options / Note | `## Details & Options` prose | done |
| Examples (Basic) | `## Basic Examples` + cells | done |
| Examples (Scope/Options/...) | `## Scope`, `## Options`, ... | done |
| Inline Listing (guide functions) | `## Functions` list | done |
| Options Table | a markdown table under `## Options` | done |

## Lists  [done]

Consecutive `- `, `* ` or `+ ` lines become a list block. In a guide's
`## Functions` section each item renders as an `InlineGuideFunction` chip (the
leading `` `Symbol` `` linked to its ref page) followed by the description; in
the default template list items become `Item` cells.

Ordered lists (`1.`, `2.`, ... or `1)`, `2)`) become a numbered list (`ItemNumbered`
cells). Task-list items (`- [ ]` / `- [x]`) render with a ballot-box glyph (☐ / ☑)
in place of the marker.

## Blockquotes  [done]

Consecutive `> ` lines become a `Quote`: a `Text` cell set off by a left rule and
indent (self-styled, so it works in every template's stylesheet).

## Tables  [done]

A GitHub-flavored table (a `| a | b |` header row followed by a `|---|---|`
separator) becomes a `GridBox` with gridlines: the header row is bold, short
rows are padded to the column count, and each cell's text gets the usual inline
formatting (so `` `Symbol` `` in a cell still links). Under `## Options` this is
the palette's *Options Table*; elsewhere it is *Insert Custom Table*. Requires a
blank line before the table.

## Math  [done]

`$math$` -> `Cell[BoxData[FormBox[<boxes>, TraditionalForm]], "InlineFormula"]`,
matching the palette's Traditional Math button. `$$math$$` on its own line (or
fenced across lines) -> a centered `DisplayFormula` cell, the standard style for a
displayed equation.
