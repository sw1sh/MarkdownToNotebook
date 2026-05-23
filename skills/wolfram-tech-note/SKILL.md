---
name: wolfram-tech-note
description: Author a Wolfram Language tech note / tutorial (a free-flowing prose-and-code documentation page, like the built-in tutorial/ pages) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate a tutorial, a tech note, a how-to or walkthrough, or narrative documentation for a Wolfram paclet - prose interleaved with runnable examples - rather than hand-editing the DocumentationTools tutorial authoring notebook.
---

# Authoring a tech note (tutorial) in markdown

`MarkdownToNotebook` fills the DocumentationTools tech-note authoring notebook (which
`DocumentationBuild` turns into a `tutorial/` page) from a literate-markdown document
with the `TechNote` template. Unlike a symbol or guide page, a tech note has **no
fixed sections** - it is free-flowing prose and code, like a tutorial. The worked
example is the AccessibleColors tutorial at
https://github.com/sw1sh/AccessibleColors/blob/main/docs/Tutorials/DesigningAccessibleColorSchemes.md ;
model new tech notes on it and read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/doc-pages.md .

## Frontmatter

```
---
Template: TechNote
Name: TechNoteName
Title: A Readable Tech Note Title
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
URI: Publisher/PacletName/tutorial/TechNoteName
Keywords: [keyword one, keyword two]
RelatedGuides: [GuideName]
RelatedTutorials: [OtherTechNote]
---
```

## Body

After the frontmatter, write the tutorial as ordinary markdown - the converter maps
it directly to documentation cell styles:

- `##` headings become `Section`s, `###` become `Subsection`s, `####` become
  `Subsubsection`s (a `#` Title is taken from the `Title` frontmatter).
- Blank-line-separated paragraphs become `Text`; `-`/`*`/`+` lines become items;
  pipe tables become grids; `![alt](path)` inlines an image.
- Fenced `wl` cells are evaluated and shown as `Input`/`Output`; record expected
  results in `<!-- => ... -->` comments. Give the `Context` frontmatter so the
  paclet loads and examples run.

Structure the note as a narrative: lead with the problem, show the simplest
approach, then build up. Use concrete, runnable examples throughout. Inline math is
`$...$`, inline code is `` `code` ``, and `` [`Symbol`] `` infers a documentation
link to a symbol's reference page.

## Build

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"];
mtn["TechNoteName.md", "Documentation/English/Tutorials/TechNoteName.nb"]
```

Then build the paclet docs with `DocumentationBuild`, and list the tech note under
the paclet's guide / related pages (author those with the `wolfram-guide-page` and
`wolfram-paclet` skills).
