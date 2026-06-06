# Wolfram Language style guide

Conventions for Wolfram Language code: `.wl` package files, `.wls`
scripts, `.wlt` test files, and code in ` ```wl ` markdown cells. The
rules at the top are non-negotiable; the rest are conventions that keep
code readable and consistent with the IDE auto-formatter. For the
markdown documentation sources, see
[docs/doc-pages.md](docs/doc-pages.md).

## Formatting

This style is produced mechanically by `CodeFormatter`CodeFormat` with a
set of compact-multiline options. Format a source file with:

```wl
Needs["CodeFormatter`"]

CodeFormat[Import["Path/To/Source.wl", "Text"],
    "BreakLinesMethod" -> "LineBreakerV2",
    "LineWidth" -> 100,
    "KeepBindingsInline" -> True,
    "SpaceAfterControlOpener" -> True,
    "GlueAssignmentRHS" -> True,
    "TrailingCommas" -> True,
    "InlineShortControl" -> True,
    "SpaceAfterPrefixNot" -> True,
    "SpaceAroundPatternOperators" -> True
]
```

`LineBreakerV2` breaks a group all-or-nothing (one element per line, never
a mid-expression wrap). The options keep a scoping binding list / control
condition on the opener line when only the body is wide; add the `If[ `
space; keep an assignment RHS on the operator line (`f := Block[{`); keep
the comma at the end of a single-line element; leave a short control
structure inline (`If[a, b, c]`); space a prefix Not (`! cond`); and space
the pattern operators (`x_ ? NumericQ`). The rest of this guide describes
the resulting conventions so they can be followed (and reviewed) by hand.

These options are not in the released CodeFormatter; they come from
[WolframResearch/codeformatter#7](https://github.com/WolframResearch/codeformatter/pull/7).
A patched build is installed locally as **CodeFormatter 1.14** (with
CodeParser bumped to 1.14 so the version-match check passes), so a plain
`Needs["CodeFormatter`"]` picks it up. To reinstall it after a Wolfram
update, copy the bundled paclet, overlay `Kernel/CodeFormatter.wl` and
`Kernel/Indent.wl` from that branch, bump `Version` in `PacletInfo.wl`,
then `CreatePacletArchive` + `PacletInstall` (do the same version bump
for CodeParser).

## Rules the user has explicitly called out

These are non-negotiable. Strip on sight.

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
      Print["no examples to run"];
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

### Never `Sequence @@ listOfOptions` into an `OptionsPattern[]` slot

`OptionsPattern[]` matches a bare list of rules just as well as a
flat sequence, so passing `listOfOptions` directly is fine wherever
the function's arguments allow it. Don't splat it with
`Sequence @@` - that's noise.

```wolfram
opts = FilterRules[{userOpts}, Options[Graph]];

(* GOOD: the list is matched by OptionsPattern[] as-is *)
Graph[vs, es, opts]

(* BAD: ceremonial splat *)
Graph[vs, es, Sequence @@ opts]
```

Reach for `Sequence @@` only when the surrounding arguments genuinely
forbid a nested list (e.g. you must interleave the options with other
trailing arguments that a list would shadow).

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
    Print["no examples"];
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

A closing `]` (or `}`, `|>`, `)`) is in exactly one of two places:

1. **On the same line** as its content, when the whole call fits on one
   line, or
2. **On its own line**, indented to the column of the **first letter** of
   the opening head - under the `M` of `Module[`, not under the `[`.

Never end a multi-line form with `...]` dangling on the last expression's
line, and never put a closing `]` at some other random indent.

```wolfram
(* GOOD: fits, so the ]s close on the same line *)
res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"]] > 0

(* GOOD: multi-line, each ] under the head's first letter *)
Module[{x, y, z},
    body1;
    body2
]

(* BAD: dangling close on the last expression's line *)
Module[{x, y, z},
    body1;
    body2]
```

This makes block boundaries scan-readable and matches what the IDE
auto-formatter expects.

### No line-length limit

Do not break an expression across lines to satisfy a character budget -
there is no column limit. A line breaks only for a **structural** reason
(one statement per line in a `CompoundExpression`, one branch / case per
line in `If` / `Switch` / `Which`, one binding per line in a long option
list or `Association`), never merely because the line grew wide. The IDE
formatter is configured so whole expressions stay on one line and only
structure introduces newlines.

## Filesystem

### Temp files: use `CreateFile[]`, don't roll your own

For a short-lived scratch file, use `CreateFile[]` (no args). It
atomically creates a unique file under the system temp directory and
returns the absolute path - exactly the contract you usually want. Don't
hand-build a path under `$TemporaryDirectory` with `FileNameJoin` and a
random / hash / PID suffix; that's a reinvention of `CreateFile`'s
guarantee and risks racing or colliding.

```wolfram
(* GOOD *)
tmp = CreateFile[];
Export[tmp, body, "Text"];
res = Get[tmp];
DeleteFile[tmp]

(* BAD: hand-built path, no atomicity, ad-hoc collision avoidance *)
tmp = FileNameJoin[{$TemporaryDirectory,
    "mypkg-" <> IntegerString[$KernelID, 36] <> "-"
    <> IntegerString[RandomInteger[10^9], 36] <> ".txt"}];
Export[tmp, body, "Text"];
...
```

Reach for the manual form only when the file needs a recognisable
filename (e.g. it's surfaced in a user-facing message) or it must live
in a specific directory other than `$TemporaryDirectory`.

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

- Public symbols: `CamelCase` (e.g. `TLam`, `THeap`, `TWnf`, `LeanImport`).
- Internal helpers: `lowerCamelCase` (e.g. `loadFn`, `parsePath`,
  `decodeUTF8`).
- Don't prefix internal helpers with `i...`.
- For printing during evaluation, use the built-in `Print` directly. A
  lowercase `print` helper used to be a house convention; we no longer
  prefer it. Any leftover `print[...]` definition should be removed and
  its callers switched to `Print`.

## Tests

Use `VerificationTest` from the standard testing framework. Test specs
live in `.wlt` files, run by a `.wls` runner script that reports
outcomes via `TestReport`.

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
4. Small general helpers.
5. Domain-specific helpers.
6. Main entry-point definitions near the end.
7. `End[]; EndPackage[];`

## Comments

- Comment non-obvious behavior, quirks, or external format
  constraints (LibraryLink calling conventions, paclet layout
  expectations, etc.).
- Don't narrate obvious code.
- Prefer one short section comment over many tiny inline comments.
