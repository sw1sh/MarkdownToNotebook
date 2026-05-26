---
name: wolfram-prompt
description: Author a Wolfram Prompt Repository resource (a deployable LLM Persona, Function, or Modifier prompt) as a literate-markdown document and convert it to the official definition notebook with MarkdownToNotebook. Use this whenever the user wants to create, write, draft, or publish a Wolfram Prompt Repository resource, an LLMPrompt, an LLM persona / function / modifier - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add chat examples, options, or metadata to such a prompt.
---

# Authoring a Prompt Repository resource in markdown

`MarkdownToNotebook` fills the official Prompt Repository definition notebook (the
one `CreateNotebook["PromptResource"]` opens, with its docked Deploy/Submit toolbar)
from a literate-markdown document. A Prompt resource is one of three types -
**Persona** (a chat character), **Function** (an LLM-backed callable), or
**Modifier** (a post-processor that reshapes another LLM's output) - and each has
the same notebook layout, with type-specific slots becoming optional. The author
writes YAML frontmatter and `## section` headings; the converter chooses every
cell style. Use the `Prompt` template.

Model new documents on the worked example -
https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/AdaLovelace.md
(a Persona) - and read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md
(the "Prompt" section) for the slot-by-slot mapping.

Read first - the canonical guidelines:

- Prompt Repository submission guidelines: https://resources.wolframcloud.com/PromptRepository/guidelines
- Prompt Repository style guidelines (the rules a submission is reviewed against): https://resources.wolframcloud.com/PromptRepository/style-guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top:

```
---
Template: Prompt
ResourceType: Prompt
PromptType: Persona            # Persona | Function | Modifier
Name: CamelCaseName            # noun for Persona, verb for Function, past-tense verb for Modifier
Description: One-line summary that starts with a verb and has no trailing punctuation
ContributedBy: Author Name
Keywords: [keyword one, keyword two]
Categories: [Fictional Characters]    # type-specific list, see below
Topics: [History of Computing, Mathematics]
RelatedSymbols: [LLMPrompt, LLMSynthesize]
RelatedResources: [OtherPromptName]
Links: ["[label](https://example.com)"]
---
```

`Name` follows strict per-type grammar - the repository review enforces it:

- **Persona** - CamelCase noun phrase (`Yoda`, `Wolfie`, `MockInterviewer`, `AdaLovelace`)
- **Function** - CamelCase verb phrase (`Summarize`, `CodeWriter`, `TitleSuggest`)
- **Modifier** - CamelCase past-tense verb (`HaikuStyled`, `Translated`, `ELI5`)

`Categories` is checkbox-style and the allowed values depend on `PromptType`:

- **Persona categories**: Advisor Bots, Character Types, Fictional Characters,
  Purpose-Based, Roles, Writers, Writing Genres
- **Function categories**: AI Guidance, Chats, Content Derived from Text,
  Education, Entertainment, For Fun, General Text Manipulation, Linguistics,
  Prompt Engineering, Special-Purpose Text Manipulation, Text Analysis,
  Text Generation, Wolfram Language
- **Modifier categories**: Computable Output, For Fun, Output Formatting,
  Personalization, Text Styling

## Sections (each `## Heading` fills a slot)

**Required**:

- `## Prompt` - the actual prompt body, plain prose. For Function prompts, write
  named template slots as `` `{argName}` `` and they become `TemplateSlot` placeholders
  that `LLMResourceFunction` substitutes at call time. This is the most important
  part of the resource; the [Prompt Repository style guidelines](https://resources.wolframcloud.com/PromptRepository/style-guidelines)
  go into detail on writing it well.
- `## Chat Examples` - one or more `wl` cells using the chat-style invocation
  (`ChatEvaluate[..., LLMPrompt["MyPromptName"] ...]`) that exercise the
  persona in a Chat Notebook context. Mark these cells `#| eval: false`
  unless a deployed prompt + LLM connection is available at build time.
- `## Basic Examples` (and any of the usual `Scope`, `Applications`, `Properties and Relations`,
  `Possible Issues`, `Neat Examples` subsections) - programmatic examples that show
  the prompt working through [`LLMSynthesize`]() / [`LLMResourceFunction`]() rather
  than a chat session. Same example-section conventions as a Function Resource.

**Optional, Persona-only**:

- `## Persona Icon` - one `wl` cell that evaluates to an image; becomes the avatar
  shown in Chat Notebooks.
- `## Cell Processing Function` - one `wl` cell with a pure function applied to
  every user input cell *before* the model sees it.
- `## Cell Post Evaluation Function` - one `wl` cell with a pure function applied
  to the model's output cell *after* it lands.

**Optional, Function-only**:

- `## Output Interpreter` - one `wl` cell with the function applied to the model's
  textual reply to coerce it into a computable result (e.g. `ToExpression`, an
  [`Interpreter`]()).

**Optional, any type**:

- `## Usage` - usage statements, one paragraph per signature (see the Function
  Resource skill for the `` `signature` `` + prose convention).
- `## Details & Options` - bulleted notes on how the prompt is configured.
- `## LLM Tools` - one `wl` cell whose value is a list of [`LLMTool`]() instances
  the prompt should have access to.
- `## LLM Configuration` - one `wl` cell whose value is the extra
  [`LLMConfiguration`]() options (model, temperature, ...).

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line: `eval: false` (show code without running),
`file: path` (replace the body with a local file or URL), `screenshot: true`
(rasterize a produced `Notebook`), `tear: h` (torn-paper screenshot capped to `h`
points), `flag: future|excised|...`. Record an example's expected result in an
`<!-- => ... -->` comment after the cell. Inline math is `$...$`. To link a
documented symbol inline, wrap an inferred ref in `<code>`:
`<code>[Range]()</code>` - the empty parens make markdown viewers render it as a
clickable link, and the `<code>` wrapper applies code styling. The converter
routes the empty-URL link through `linkInferred` to a `paclet:` ref; the `-out.md`
twin further rewrites it to the public web URL.

Examples that load the *deployed* resource (`LLMPrompt["MyPromptName"]`)
cannot evaluate before the resource exists, and `LLMSynthesize` / `ChatEvaluate`
need an active LLM connection at evaluation time. Mark these cells
`#| eval: false` so the build does not error; once the prompt is published
and the LLM is configured, the cells run as written. (Do not use the
`LLMPrompt[ResourceObject[EvaluationNotebook[]]]` form - `EvaluationNotebook[]`
is the *user's* notebook at call time, not the deployed resource, so the
lookup fails both headlessly and at runtime in a chat session.)

## Build & deploy

```bash
wolframscript -f build.wls               # converts the .md to .nb
```

The notebook the converter writes carries the same docked Deploy/Submit toolbar a
hand-authored Prompt notebook has; click *Submit to the Prompt Repository* in the
toolbar, or `ResourceSubmit[NotebookOpen[\"MyPrompt.nb\"]]` from a session, to
publish. For a private cloud copy use `DeployResource[..., "CloudPublic"]`.

## Check

Before submission, run the docked *Check* button (top of every resource
definition notebook) - it lints the document against the submission
guidelines and reports hints by level. Headless, the same lint runs through
`DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` after stamping
CellIDs and saving (the headless build does not assign CellIDs, and the
scraper needs them to locate cells):

```wl
Needs["DefinitionNotebookClient`"]
UsingFrontEnd @ Block[{nbo = NotebookOpen[File["MyResource.nb"]]},
    CurrentValue[nbo, CreateCellID] = True;
    SelectionMove[nbo, All, Notebook];
    FrontEndTokenExecute[nbo, "Save"];
    Normal @ DefinitionNotebookClient`CheckDefinitionNotebook[nbo]
]
```

Each row is `<|"Level" -> ..., "Tag" -> ..., "Parameters" -> ...|>` with
`Level` one of `Suggestion` / `Warning` / `Error`. Common tags to address
before submission: `DescriptionTooLong` (shorten to under 128 chars),
`ExampleTextLastCharacter` (end an example caption with `:`),
`FoundUnformattedCode` (wrap a stray WL symbol in `` `backticks` `` or in
an inferred link with empty parens like `[Range]()` (substitute the actual symbol name for `Range`), `ThreeDotEllipsis` (use `…` not `...`),
`NotASystemSymbol` (link foreign function-repo names instead of formatting
them as system symbols), `LargeCellBounds/CellHeight` (rasterized output too
big - crop it with `#| tear: h` or shrink the source). The repo's
`check.wls` runs the same lint on every built `.nb` and prints a per-file
summary.
