---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a markdown approximation of a Wolfram notebook
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](), or a `.nb` file path, it walks the cells and emits a markdown approximation - recognising the standard cell styles MarkdownToNotebook itself emits (Title / Section / ... / Text / Notes / Item / Input / Code / etc.) plus their inline `TextData` formatting.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion
time via the `#| file:` option; the deployed resource therefore carries it
inline:

```wl
#| file: NotebookToMarkdown.wl
```

## Usage

<code>[NotebookToMarkdown]()[$nb$]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](), or a `.nb` file path).

<code>[NotebookToMarkdown]()[$nb$, "$file$.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook]() expression, a [NotebookObject]() open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Notes` / `Caption` / `Quote` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` to ```` ```wl ... ``` ```` fenced blocks; `Output` / `Message` are skipped (they regenerate on re-conversion).
- Inline `TextData` is converted back through the same backtick / bold / italic / link rules the forward parser accepts, so the produced markdown re-parses to an equivalent block sequence.
- The walker does not recover frontmatter or resource-template-specific slots from the rendered cells; the markdown it emits is the rendered body only.

## Basic Examples

Walk a small notebook and recover the markdown body:

```wl
NotebookToMarkdown @ Notebook[{
    Cell["Demo", "Title"],
    Cell["A paragraph.", "Text"],
    Cell[BoxData["Range[5]^2"], "Input"]
}]
```

<!-- => "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n" -->

## Scope

A `.nb` file path is read via `Get` and converted the same way:

```wl
NotebookToMarkdown[FileNameJoin[{$TemporaryDirectory, "no-such-file.nb"}]] === Null
```

<!-- => True (Null because the path does not exist; with a real file it returns the markdown) -->

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - frontmatter is dropped, code cell `#|` options are not recovered, and any decorative template cells the front end may have introduced are filtered out - but feeding the walker's output back through the forward path produces an equivalent notebook.

## Possible Issues

Round-trip is *approximate*. The walker reads the rendered cells, not the original source, so:

- Frontmatter is not recovered (it lives in `TaggingRules`, not in cells).
- Code cell options (`#| eval: false`, `#| screenshot: true`, ...) are gone.
- Inline math and decorative formatting may serialize back to a simpler form.

For an arbitrary notebook the walker emits its best guess at the prose / heading / code structure; for a notebook MarkdownToNotebook itself wrote, the body is close to the source but the frontmatter must be added back by hand if needed.

## Neat Examples

A round-trip smoke test: forward, walk, forward again, and check the second forward run produces a notebook with the same set of cell styles in the same order as the first - confirming the walker emits a faithful structural reduction even when byte-exact recovery is not possible:

```wl
With[{md = "# Demo\n\n## Section\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n"},
    Module[{nb1, md2, nb2, styles},
        nb1 = MarkdownToNotebook[md, "Evaluate" -> False];
        md2 = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[md2, "Evaluate" -> False];
        styles[nb_] := Cases[nb, Cell[_, s_String, ___] :> s, Infinity];
        styles[nb1] === styles[nb2]
    ]
]
```

<!-- => True -->
