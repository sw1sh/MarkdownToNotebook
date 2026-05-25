---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover the original markdown source from a Wolfram notebook
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](), or a `.nb` file path, it returns the markdown source that produced it. Every notebook MarkdownToNotebook itself writes carries the original source in its `TaggingRules`, so the round trip is exact - the same `Hash[markdown]` before and after. Notebooks without that stash get a best-effort cell walker that recognises the standard cell styles MarkdownToNotebook emits.

## Definition

The implementation lives across two plain `.wl` files - the shared
[MarkdownTools.wl](https://github.com/sw1sh/MarkdownToNotebook/blob/main/MarkdownTools.wl)
module that defines the stash protocol (its sibling forward converter loads
the same file), and the cell walker itself. Each cell below inlines one file
at conversion time via the `#| file:` option; the deployed resource therefore
carries both files inline.

```wl
#| file: MarkdownTools.wl
```

```wl
#| file: NotebookToMarkdown.wl
```

## Usage

<code>[NotebookToMarkdown]()[$nb$]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](), or a `.nb` file path).

<code>[NotebookToMarkdown]()[$nb$, "$file$.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook]() expression, a [NotebookObject]() open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- A notebook produced by [MarkdownToNotebook]() carries the original markdown source in `TaggingRules -> {... "MarkdownToNotebook" -> <|"Source" -> ..., "Template" -> ...|>}`. `NotebookToMarkdown` reads that entry first, so the round trip `nb -> md -> nb` is *exact* (same `Hash`).
- For an arbitrary notebook (no stash), the function falls back to a cell walker that handles the standard styles MarkdownToNotebook itself emits: `Title` / `Section` / `Subsection` / `Subsubsection` map to `#` / `##` / `###` / `####` headings; `Text` / `Notes` / `Caption` / `Quote` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` to ```` ```wl ... ``` ```` fenced blocks; `Output` / `Message` are skipped (they regenerate on re-conversion).
- Inline `TextData` is converted back through the same backtick / bold / italic / link rules the forward parser accepts, so the produced markdown re-parses to an equivalent block sequence.
- The fallback walker does *not* recover frontmatter (there is no place in a generic notebook for it) or resource-template-specific slots; for that, write through the forward converter so the stash is present.

## Basic Examples

A notebook built from a literate-markdown document with `"PreserveSource" -> True` is round-tripped byte-exactly:

```wl
With[{md = "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```"},
    md === NotebookToMarkdown @ MarkdownToNotebook[md, "PreserveSource" -> True]
]
```

<!-- => True -->

## Scope

A `.nb` file path is read via `Get` and converted the same way:

```wl
NotebookToMarkdown[FileNameJoin[{$TemporaryDirectory, "no-such-file.nb"}]] === Null
```

<!-- => True (Null because the path does not exist; with a real file it returns the markdown) -->

## Applications

Round-trip a literate document and assert the recovered source matches:

```wl
Module[{md = "# Demo\n\nText.\n", nb, recovered},
    nb = MarkdownToNotebook[md, "PreserveSource" -> True];
    recovered = NotebookToMarkdown[nb];
    recovered === md
]
```

<!-- => True -->

## Properties and Relations

The stash that makes the round trip exact is a `TaggingRules` entry the forward converter writes when `"PreserveSource" -> True` - both sides use the same key (`"MarkdownToNotebook"`) and protocol from the shared `MarkdownTools.wl` module:

```wl
First[
    Cases[
        MarkdownToNotebook["# Demo", "PreserveSource" -> True],
        ("MarkdownToNotebook" -> v_) :> v,
        Infinity
    ],
    <||>
]
```

<!-- => <|"Source" -> "# Demo", "Template" -> "Default"|> -->

## Possible Issues

A notebook never produced by [MarkdownToNotebook]() (or one written with `"PreserveSource" -> False`, the default) has no stash, so the inverse falls back to its cell walker - that walker is best-effort and may not reproduce every formatting detail. Round-trip for arbitrary notebooks is *not* guaranteed; round-trip for notebooks the converter wrote with the stash *is*:

```wl
NotebookToMarkdown @ Notebook[{Cell["Hello", "Text"]}]
```

<!-- => "Hello\n" (best-effort - no frontmatter, plain prose only) -->

## Neat Examples

The forward and the inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, and recover the modified source through the inverse. The stash carries the *original* markdown, so a hand edit of the rendered notebook does not survive the round trip - the inverse always re-emits the source that built the notebook. This is the right semantics for documentation tooling: the markdown is canonical.
