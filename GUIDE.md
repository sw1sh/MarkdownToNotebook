# AISkills style guide

This repository is a single, self-hosting Wolfram Function Repository
function authored in literate markdown. The source of truth is
[MarkdownToNotebook.md](MarkdownToNotebook.md): its YAML
frontmatter is the Function Repository metadata, and its body holds the
function definition, usage, and examples. The function converts such a
document into a `ResourceObject`, so it can publish itself
([bootstrap.wls](bootstrap.wls) defines it from the markdown once, then
runs it on its own source).

The conventions below apply to the Wolfram code inside ` ```wl ` cells and
to the `*.wls` bootstrap/runner scripts.

## Rules the user has explicitly called out

These are non-negotiable. Strip on sight.

### No `Print`

Never call `Print` in a `.wl`, `.wlt`, or `.wls` file. If textual output
is needed, define a local helper `print` that wraps either
`WriteString[$Output, ...]` (notebook / kernel context) or
`WriteString["stdout", ...]` (`wolframscript -c` / `-f` context) and
call that.

```wolfram
print[args___] := WriteString["stdout", StringJoin @@ Map[ToString, {args}], "\n"]
```

`Print` also trips an IDE lint warning ("Suspicious use of session
symbol Print") and is noisy in batch test runs.

### No em dashes (`—`, U+2014) or `--`

Don't write em dashes in source files, docs, comments, or commit
messages, and don't use `--` (double hyphen) as a substitute. Use a
plain hyphen (`-`), a comma, a colon, or a sentence break.

### No Unicode box-drawing characters

Don't use `─` (U+2500) or related box-drawing chars (`┌ ┐ │ ┴ ─`) as
visual section banners in comments. Use plain ASCII:

```c
// === lifecycle ===     // good
// --- lifecycle ---     // good
// ─── lifecycle ───     // BAD
```

Same applies in `.wl` (`(* === lifecycle === *)`) and `.md`
(`## Lifecycle`).

### No decorative Unicode arrows in source

Use `->` (or `>` in shell prompt strings) instead of `→`, `←`, etc.
Same spirit as the rules above: ASCII-only in source files unless the
character carries meaning (mathematical typesetting in a comment is
fine when relevant).

### Dark mode + Standard colors

Always design WL output for both light and dark Wolfram themes from
the start.

- Use **Standard color names** (`StandardBlue`, `StandardRed`,
  `StandardGreen`, `StandardOrange`, `StandardYellow`,
  `StandardPurple`, `StandardGray`) instead of `RGBColor[...]` or
  `Darker[Blue, 0.4]`. They read correctly on light and dark
  backgrounds.
- Use `LightDarkSwitched[lightValue, darkValue]` when a value
  (color, opacity, thickness) genuinely needs to differ between
  modes. Avoid hard-coded `White`/`Black` for `Background`,
  `FaceForm`, etc.; either let the theme drive it, or wrap in
  `LightDarkSwitched`.
- Don't unconditionally pin `Background -> White` on a Graph or
  Graphics. If a static PNG export needs an explicit background,
  set it on the Export call, not on the Graph.

## Indentation and spacing

- 4-space indentation. Never 2.
- Spaces around infix operators and pattern tests: `t_ ? NumericQ`,
  not `t_?NumericQ`.
- Prefer structural indentation over column alignment.
- One semantic unit per line in long forms (`Which`, `Switch`,
  `Association`, `Table`, option lists).
- For multi-line `If`, put a space after the opening bracket so the
  test argument lines up with the branches:

  ```wolfram
  If[ Length[dirs] === 0,
      print["no examples to run"];
      Exit[1]
  ]
  ```

  Single-line `If[cond, then, else]` does not need the leading space.

### Never split a binary operator's operands across lines

Operators (`+`, `-`, `*`, `/`, `.`, `&&`, `||`, etc.) must have both
operands on the same line.  The Wolfram IDE flags split operands as
`DifferentLine` and the resulting form reads worse than a longer
single line.

```wolfram
(* BAD: trips DifferentLine lint *)
TSet[wTen, wTen - lrHat * mTen
                  / (Sqrt[vTen] * invSqrtB2cor + eps)];

(* GOOD: keep the whole arithmetic chain on one line, even if it's
   long; or factor an intermediate into a named binding first. *)
TSet[wTen, wTen - lrHat * mTen / (Sqrt[vTen] * invSqrtB2cor + eps)];

(* GOOD: factor when the line gets unreadably wide *)
denom = Sqrt[vTen] * invSqrtB2cor + eps;
TSet[wTen, wTen - lrHat * mTen / denom];
```

The lint rule is `wolfram lint(DifferentLine)`; if you see it,
either join the line or factor.

### Optional arguments

For functions that take Wolfram-style options, use
`opts : OptionsPattern[]`, not `opts___ ? OptionQ`.  The former
integrates with `Options[fn]` declarations and `OptionValue[fn, key]`,
which is the canonical Wolfram pattern.

```wolfram
Options[myFn] = {GraphLayout -> "LayeredDigraphEmbedding"};

myFn[args___, opts : OptionsPattern[]] :=
    With[{layout = OptionValue[GraphLayout]},
        ...
    ]
```

### Boolean options: `TrueQ[OptionValue[...]]`

Wrap boolean options in `TrueQ` so non-`True` values (unbound symbols,
typos, `Automatic`, etc.) collapse to `False` instead of propagating
into `If` as an unevaluated test.

```wolfram
(* GOOD *)
If[ TrueQ[OptionValue["Branchial"]], ..., ...]

(* BAD: if user passes "Branchial" -> Bogus, the If never evaluates *)
If[ OptionValue["Branchial"], ..., ...]
```

### First option wins - forced overrides go FIRST

When a wrapper needs to force certain options on the inner call but
also let the user pass through extras, put the forced overrides
FIRST and the user's filtered options LATER in the argument list.
Wolfram functions take the FIRST setting on collision (verify with
`Options[Graph[..., EdgeLabels -> "a", EdgeLabels -> "b"]]` -> `"a"`).
Don't `/. (Key -> _) -> Nothing` to scrub user options out - just
place the forced override first.

```wolfram
(* GOOD: our forced VertexLabels wins; user's GraphLayout /
   ImageSize / etc. pass through. *)
Graph[
    vs, es,
    VertexLabels -> myLabels,
    Background -> LightDarkSwitched[White, GrayLevel[0.13]],
    FilterRules[{opts}, Options[Graph]]
]

(* BAD: ceremonial stripping; harder to read, easy to forget a key *)
userOpts = FilterRules[{opts}, Options[Graph]] /.
    (VertexLabels -> _) -> Nothing;
Graph[vs, es, Sequence @@ userOpts, VertexLabels -> myLabels]
```

## Definitions

Prefer `Block` for local workspaces unless `Module`'s unique-symbol
guarantee is actually required. Don't add a trailing `;` to any
top-level assignment - `SetDelayed` (`:=`) AND `Set` (`=`).  Each
definition is a complete expression; line breaks separate them.

```wolfram
(* GOOD *)
Options[myFn] = {GraphLayout -> "LayeredDigraphEmbedding"}

myFn[x_] := x + 1

(* BAD *)
Options[myFn] = {GraphLayout -> "LayeredDigraphEmbedding"};
myFn[x_] := x + 1;
```

```wolfram
f[x_] := x + 1

g[args__] := Block[{
    x = ...,
    y
},
    body
]
```

The `Block`/`Module` variable list opens on the same line as the
head (`Block[{`), variable bindings are indented one level deeper,
and `}`, body, and the closing `]` all return to the column where
the line that opens `Block[` starts. This keeps the variable list
visually distinct from the body and matches IDE auto-formatting.

## Control flow

### No `For` loops

Don't write `For[i = 1, i <= n, i++, ...]`. It reads like C and
forces explicit counters and mutation. Use:

- `Do[body, {i, n}]` for side effects with a counter.
- `Table[expr, {i, n}]` to build a list.
- `Nest`, `NestList`, `NestWhile`, `Fold`, `FoldList` when there's
  iterative state to thread through a fixed transition.

```wolfram
(* BAD *)
For[i = 1, i <= n, i++,
    AppendTo[acc, f[i]]
]

(* GOOD *)
acc = Table[f[i], {i, n}]
```

### `Replace` over `Switch` for value-to-value mapping

When the cases are simple value patterns mapping to values (no
structural tests, no side effects), `Replace` with a rule list is
more concise and reads as data, not control flow.

```wolfram
(* GOOD *)
legend = Replace[OptionValue[PlotLegends], {
    None | False -> None,
    Automatic | True :> familyLegend[presentFamilies]
}]

(* BAD: same shape but pretends to be control flow *)
legendOpt = OptionValue[PlotLegends];
legend = Switch[legendOpt,
    None | False, None,
    Automatic | True, familyLegend[presentFamilies],
    _, legendOpt
]
```

Use `Switch` (or `Which`) when branches have side effects, dispatch
on richer patterns, or need fallthrough `_` to the original value.

### Comma-on-own-line between multi-line branches

When the branches of `If` (or args of `Block`, `Switch`, `With`,
etc.) are each multi-line, put the separating commas on their own
line at the head's indent column.  The comma reads as a branch
boundary, like a horizontal rule.

```wolfram
(* GOOD *)
branchial = If[ TrueQ[OptionValue["Branchial"]]
    ,
    DeleteDuplicates @ Catenate @ Map[
        s |-> ...,
        sliceKeys
    ]
    ,
    {}
]

(* GOOD: short branches keep commas inline *)
If[ Length[dirs] === 0,
    print["no examples"];
    Exit[1]
]

(* BAD: trailing comma after a multi-line branch hides the boundary *)
branchial = If[ TrueQ[OptionValue["Branchial"]],
    DeleteDuplicates @ Catenate @ Map[
        s |-> ...,
        sliceKeys
    ],
    {}
]
```

### No `Head[expr] === Foo` - use `MatchQ`

`Head[x] === Foo` is a structural test that doesn't compose with
patterns. `MatchQ[x, _Foo]` (or `MatchQ[x, Foo[args...]]` for a
shape check) is the canonical form, and it composes with patterns
when you need them.

```wolfram
(* BAD *)
If[ Head[expr] === Inactive[Equal] && expr[[1]] === expr[[2]],
    ...
]

(* GOOD *)
If[ MatchQ[expr, Inactive[Equal][x_, x_]],
    ...
]
```

## Mutation

### No `AppendTo` (or other list-growing mutation)

Don't grow a list with `AppendTo`/`PrependTo` inside a loop.
`AppendTo[xs, y]` is `xs = Append[xs, y]`, which copies on every
step. Build the result with `Table`, `Map`, or `Fold` so the
final list is allocated once.

```wolfram
(* BAD *)
out = {};
Do[ AppendTo[out, f[i]], {i, n} ];
out

(* GOOD *)
out = Table[f[i], {i, n}]

(* BAD: state threaded by mutating a local *)
acc = init;
Do[ acc = step[acc, x], {x, xs} ];
acc

(* GOOD: state threaded by Fold *)
acc = Fold[step, init, xs]
```

The same goes for incrementally building an Association: use
`Association[Table[k -> v, ...]]`, `AssociationMap`, or
`Fold[Append, <||>, kvPairs]` rather than `assoc[k] = v` inside
a `Do`.

### Bracket alignment

A closing `]` (or `}`, `|>`, `)`) goes on its own line, indented
to the same column as the opening head. Never end a multi-line
form with `...]` on the last expression's line.

```wolfram
(* GOOD *)
Module[{x, y, z},
    body1;
    body2
]

(* BAD *)
Module[{x, y, z},
    body1;
    body2]
```

This makes block boundaries scan-readable and matches what the IDE
auto-formatter expects.

## Composition

### `@` chain for unary right-application

For chains of unary calls, prefer `f @ g @ h[x]` over `f[g[h[x]]]`.
Less bracket nesting, reads top-down (apply `h`, then `g`, then `f`).
Use `[]` only where you need multiple args.

```wolfram
(* GOOD *)
DeleteDuplicates @ Catenate @ Map[fn, xs]

presentFamilies = DeleteCases[
    DeleteDuplicates @ Values[edgeFamilies],
    "WALK"
]

(* BAD: ceremonial nesting *)
DeleteDuplicates[Catenate[Map[fn, xs]]]
```

### `Lookup` is vectorized; prefer it over `Map[Lookup, ...]`

`Lookup[assoc, listOfKeys, default]` returns a list of values in
the order of the keys.  Use it directly when feeding a list-shaped
slot (e.g. `EdgeLabels -> {lbl1, lbl2, ...}`).

```wolfram
(* GOOD *)
EdgeLabels -> Lookup[edgeRules, edges, ""]

(* BAD *)
EdgeLabels -> Map[e |-> e -> Lookup[edgeRules, e, ""], edges]
```

### Don't name single-use intermediates

If a value is read exactly once, inline it.  Naming it adds a line
of bookkeeping without buying readability.

```wolfram
(* GOOD *)
legend = Replace[OptionValue[PlotLegends], {...}]

(* BAD: legendOpt is never used outside the next line *)
legendOpt = OptionValue[PlotLegends];
legend    = Replace[legendOpt, {...}]
```

Exception: name it when the expression is long enough that the
named form actually reads better, or when the name carries domain
meaning the inline expression doesn't.

## Naming

- Public symbols: `CamelCase` (e.g. `TLam`, `THeap`, `TWnf`).
- Internal helpers: `lowerCamelCase` (e.g. `print`, `loadFn`).
- Don't prefix internal helpers with `i...`.

## Tests

Use `VerificationTest` from the standard testing framework. Test specs
live in `*.wlt` files; the runner is a `.wls` script invoked by
`make wl-test`.

```wolfram
VerificationTest[
    expression,
    expectedOutput,
    TestID -> "human-readable id"
]
```

Don't put `Print` inside test bodies. The runner reports outcomes via
`TestReport`.

## File structure

When practical, organize a `.wl` file in this order:

1. Short file comment if needed.
2. `BeginPackage` declarations and public `::usage` strings.
3. `Begin["`Private`"]`.
4. Small general helpers (e.g. `print`).
5. Domain-specific helpers.
6. Main entry-point definitions near the end.
7. `End[]; EndPackage[];`

## Comments

- Comment non-obvious behavior, quirks, or external format
  constraints (LibraryLink calling conventions, paclet layout
  expectations, etc.).
- Don't narrate obvious code.
- Prefer one short section comment over many tiny inline comments.

## Project layout

- `MarkdownToNotebook.md` - the source of truth. YAML
  frontmatter = Function Repository metadata (keys mirror the
  `FunctionResourceDefinition.nb` template slots: `Name`, `Description`,
  `Usage`, `Keywords`, `Categories`, `ContributedBy`, ...). The
  `## Definition` cells hold the function's own code; `## Usage` and the
  `## Basic Examples` / `## Scope` / ... sections feed the resource's
  docs and are evaluated with caching.
- `bootstrap.wls` - extracts the `## Definition` cells, defines the
  function, then runs it on its own markdown (the self-hosting loop:
  markdown -> `ResourceObject` -> ready for `ResourceSubmit`).
- `*.examples.wxf` - per-document evaluation cache (gitignored), keyed
  by a cumulative content hash of the example cells.

There is no paclet directory and no native (C/Rust) extension: parsing
is pure Wolfram, kept in the `## Definition` cells. If inline-markdown
fidelity ever needs a real CommonMark parser, swap only the inline layer
(comrak via LibraryLink, or a pandoc shell-out); the block parser and the
evaluate/cache engine are unaffected.

### Function Repository targets (reference)

The official, submittable definition notebook is created with
`CreateNotebook["FunctionResource"]` (front end) or
`ResourceFunction["CreateResourceNotebook"]["Function"]` (kernel). Its
template is `FunctionResource/Kernel/Templates/FunctionResourceDefinition.nb`;
the Deploy/Submit toolbar lives in docked cells
(`TemplateBox[{}, "MainGridTemplate"]`) of `FunctionResourceDefinitionStyles.nb`,
driven by the `DefinitionNotebookClient` paclet. We target the
`ResourceObject` API directly instead, so publishing stays headless.
