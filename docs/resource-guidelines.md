# Resource style guidelines (refined)

A working copy of the official Wolfram resource guidelines, refined for authoring
in markdown with `MarkdownToNotebook`. Each rule notes how the markdown source
satisfies it (frontmatter key, section, or inline syntax). Re-fetch the sources
when in doubt - they are the authority:

- Function Repository - <https://resources.wolframcloud.com/FunctionRepository/style-guidelines>
- Paclet Repository, creating paclets - <https://resources.wolframcloud.com/PacletRepository/creating-paclets>
- Paclet Repository, guidelines - <https://resources.wolframcloud.com/PacletRepository/guidelines>

## Shared conventions (all resource types)

- **Name** - specific, reflects the functionality, minimal overlap with existing
  names. A single common word ("Step", "Turn") is usually too generic. -> `Name`
  frontmatter.
- **Short description** - a brief, standalone, plain-text line that begins with an
  imperative verb and has **no ending punctuation**. -> `Description` frontmatter.
- **Usage statements** - one per supported input syntax; each (input pattern +
  text) forms a complete sentence ending with a period. Argument/variable names are
  italic (the "Template Input" transform). -> `## Usage`, one paragraph per
  signature beginning with a `` `code` `` span; arguments written `*name*`.
- **Details & Options** - short notes, each its own bullet (its own `Notes` cell).
  Options go in a three-column table (no header): option name | default | brief
  description; built-in option names link to their docs; string option names may be
  written as symbols. Straight quotes (`"`) only, never curly quotes. -> `## Details
  & Options`, a markdown list (one note per `-` item) plus an options table.
- **Examples** - clear, **reproducible**, runnable; each example independent (a
  later example must not depend on an earlier one's variables). Lead each with a
  brief caption (≈ one sentence) ending in a colon. Separate sibling examples with a
  delimiter. -> `## Basic Examples` and the extended sections; the converter inserts
  delimiters and resets `In[]`/`Out[]` per example.
- **Strings** - straight quotes; **code** uses `SetDelayed` (`:=`) for definitions,
  `OptionsPattern`/`OptionValue` for options, only the documented symbol(s) facing
  the user.
- **Links** - make real hyperlinks, not bare URLs. -> `[label](url)` for prose
  links; `` [`Symbol`]() `` (or `` [`Symbol`]() ``) to infer a reference link;
  `` [`Symbol`](url) `` to link explicitly; `SeeAlso` / `Links` / `RelatedGuides`
  frontmatter for the metadata lists.

## Function Repository

- One **definition notebook** (`Template: FunctionResource`). Only the entry
  symbol(s) interface with the user; include every definition, load nothing
  external. -> `## Definition` (optionally `#| file:` to inline a `.wl`),
  `EntrySymbol` frontmatter.
- **Example sections**, in order: Basic Examples, then the extended ones - Scope,
  Generalizations & Extensions, Applications, Properties & Relations, Possible
  Issues, Neat Examples, Requirements.
  - Basic Examples: start with the **simplest** use.
  - Scope: demonstrate the breadth, including every documented input pattern.
  - Applications / Neat Examples: richer or surprising uses.
- **Author Notes** / **Submission Notes** - optional background and reviewer info.
- Deploy publicly by scraping the notebook into a `ResourceObject` and
  `CloudDeploy`-ing the resulting `ResourceFunction` (a headless `DeployResource`
  scrapes an empty definition - see [subtleties](subtleties.md)); submit to the
  repository with the docked Submit button / `ResourceSubmit`.

## Paclet Repository

### Paclet, publisher, contexts

- A **publisher ID** owns the paclet; format `PublisherID/PacletBaseName`. Check
  with `$PublisherID`. -> `Paclet` frontmatter is `PublisherID/PacletBaseName`.
- **Contexts**: every declared symbol lives under `` PublisherID` ``; user-facing
  symbols under `` PublisherID`PacletBaseName` ``; private code under deeper
  contexts (e.g. `` PublisherID`PacletBaseName`Internal` ``). Creating symbols
  outside the publisher context is prohibited. -> `Context` frontmatter.
- A `PacletInfo.wl` (Name, Version, publisher-prefixed contexts, primary context)
  is required for building/installing; it must agree with the definition notebook
  (the Check button verifies this).

### Definition notebook (`Template: Paclet`)

- Fill **every** field; run **Check -> All** and resolve all errors before
  publishing. Save as `ResourceDefinition.nb` beside `PacletInfo.wl`.
- Keep the notebook's **Examples** section a concise feature overview - full
  examples belong on the documentation pages.
- **Licensing** is required (a default is assigned if none chosen). -> `License`
  frontmatter.
- **Disclosures**: any external effect (writes files, network, modifies an
  unprotected `System`` symbol) must be disclosed; modifying protected `System``
  symbols is prohibited.
- Autoloading paclets (`Loading -> Automatic`) must set `HiddenImport -> True`;
  `Updating -> Automatic` is prohibited.
- Desktop Wolfram Language 13.0+ is required to author paclets.

### Documentation pages (every user-level feature is documented)

- **Guide page** (at least one, the paclet homepage). -> `Template: Guide`.
  - The text under the title gives context - several sentences (`## Abstract`).
  - The body is mostly **lists of linked symbols**, each with a brief phrase (the
    "1-Line Function" listing). -> `## Functions` list of `` `Symbol` description ``.
  - Minimize prose; no worked examples on the guide.
- **Symbol / function reference page**, one per user symbol. -> `Template: Symbol`.
  - Summary is the `## Usage` line (a symbol page has no separate description).
  - `## Details & Options`, then `## Basic Examples` and the extended example
    sections (Scope, Options, Applications, Properties & Relations, Possible Issues,
    Neat Examples). Each example independent and captioned.
- **Tech note / tutorial** - free-flowing prose + code. -> `Template: TechNote`.
- Build the pages with `DocumentationBuild`; the converter fills the authoring
  templates so the author never edits cell styles.

### Versioning

- Semantic `XX.YY.ZZ`: `XX` major/incompatible, `YY` minor, `ZZ` patch.

## How `MarkdownToNotebook` maps these

- Frontmatter = the resource metadata; `Template` picks the layout.
- `## Definition` (with `#| file:`) = the implementation; `## Usage`,
  `## Details & Options`, and the `## Example` sections = the documentation.
- A `### heading` inside an example section becomes a subsubsection
  (`ExampleSubsection` on a doc page) - one per option / sub-topic, as on reference
  pages in the wild.
- Example outputs are evaluated and cached (built-in persistence), so a reproduced
  notebook carries real `Out[]` cells.
