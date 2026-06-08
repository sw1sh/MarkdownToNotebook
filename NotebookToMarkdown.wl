(* NotebookToMarkdown - the inverse of MarkdownToNotebook. Given a notebook
   (expression / NotebookObject / .nb file path), recover a markdown
   approximation of its source by walking the cells.

   Walker-only by design: any TaggingRules stash a forward run might have left
   behind is ignored, so this code is exercised on every input and round-trip
   quality is the walker's responsibility, not a memoized shortcut. The walker
   recognises the standard cell styles MarkdownToNotebook itself emits (Title /
   Section / ... / Text / Notes / Item / Input / Code / etc.) plus their inline
   TextData formatting.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as the forward converter, so a resource notebook can inline this file with a
   "#| file: NotebookToMarkdown.wl" cell and have it work on Get. *)

(* === decoration filters ===
   The resource templates (Demonstration, Symbol, ...) insert decorative cells
   inline with the heading TextData - the help-bubble opener that pops the
   "MoreInfo" guidance for each slot. The opener is a Cell wrapping a
   PaneSelectorBox of the "MoreInfoOpenerButtonTemplate"; the body it pops is
   a sibling Cell of style "MoreInfoText". Neither belongs in the recovered
   markdown - the source never mentioned them, the front end injected them.
   Return "" from inlineMd for any such cell so it falls out of the
   StringJoin. *)
(* The MoreInfoOpener cell sits inside a heading's TextData as
     Cell[BoxData[PaneSelectorBox[{True -> TemplateBox[{slot, ...}, "MoreInfoOpenerButtonTemplate"]}, Dynamic[...], ImageSize -> Automatic]]]
   - the "MoreInfoOpenerButtonTemplate" tag is nested inside the TemplateBox
   in the True branch, not a direct PaneSelectorBox argument. The broader
   match below catches *any* PaneSelectorBox-in-a-Cell-in-TextData because
   such a thing is, by construction, a UI affordance the template injected
   (the source markdown has no way to express it). *)
decorationCellQ[Cell[BoxData[_PaneSelectorBox], ___]] := True
decorationCellQ[Cell[_, "MoreInfoText" | "MoreInfoTextOuter", ___]] := True
decorationCellQ[_] := False

(* === inline TextData -> markdown text ===
   Patterns mirror the forward parser's inlineTextData output so a round trip
   preserves formatting choices. *)
inlineMd[s_String] := s
inlineMd[c_Cell] /; decorationCellQ[c] := ""
(* wrap a markdown run in italic (*) / bold (**) markers, but NOT when it is
   punctuation / bracket only (italicizing "]" gives a stray "*]*"), and NOT when it is
   already wrapped at the same level (StyleBox[StyleBox[x,"TI"],FontSlant->Italic] must
   give *x*, not **x**). This keeps overlapping/malformed markers out of the output. *)
emWrap[s_String, mark_String] := Which[
    s === "" || StringMatchQ[s, (PunctuationCharacter | WhitespaceCharacter | "[" | "]" | "{" | "}" | "(" | ")") ..], s,
    StringMatchQ[s, mark ~~ Except["*"] .. ~~ mark], s,
    True, mark <> s <> mark
]
inlineMd[StyleBox[s_, opts___]] := With[{styles = {opts}, inner = inlineMd[s]},
    Which[
        MemberQ[styles, "TI"] || MemberQ[styles, FontSlant -> "Italic"], emWrap[inner, "*"],
        MemberQ[styles, "TB"] || MemberQ[styles, FontWeight -> "Bold"], emWrap[inner, "**"],
        True, inner
    ]
]
(* paclet-link button -> [Name]() (the inferred form the forward parser knows). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Link", ButtonData -> uri_String, ___]] :=
    "[" <> name <> "](" <> If[StringStartsQ[uri, "paclet:"], "", uri] <> ")"
(* hyperlink button -> [text](url). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Hyperlink", ButtonData -> {URL[u_String], ___}, ___]] :=
    "[" <> name <> "](" <> u <> ")"
(* An InlineFormula cell wraps either a FormBox (typeset math from a "$...$"
   span) or a plain WL box tree (a "`Symbol`" code span). The forward parser
   sends "$...$" to FormBox, "`code`" to bare boxes, so dispatching on the
   inner shape lets us emit "$math$" for math and "`code`" or "<code>...</code>"
   for code - the same convention markdown uses. *)
inlineMd[Cell[BoxData[FormBox[box_, _, ___]], "InlineFormula", ___]] :=
    "$" <> walkerMath[box] <> "$"
inlineMd[Cell[BoxData[b_], "InlineFormula", ___]] := With[{md = inlineMd[b]},
    Which[
        StringMatchQ[md, "[" ~~ ___ ~~ "](" ~~ ___ ~~ ")"], "<code>" <> md <> "</code>",
        True, "`" <> md <> "`"
    ]
]
(* TraditionalForm math -> $...$. The body is boxes too; the same inlineMd
   walker serializes them recursively - subscripts, superscripts, fractions,
   and italics already produce LaTeX-style fragments, so a FormBox is just
   a "$" delimiter around the result. *)
inlineMd[FormBox[box_, TraditionalForm | StandardForm, ___]] :=
    "$" <> walkerMath[box] <> "$"
inlineMd[FractionBox[a_, b_]] := "$" <> walkerMath[a] <> "/" <> walkerMath[b] <> "$"
inlineMd[SubscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "_" <> walkerMath[b] <> "$"
inlineMd[SuperscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "^" <> walkerMath[b] <> "$"
inlineMd[SqrtBox[a_]] := "$\\sqrt{" <> walkerMath[a] <> "}$"
inlineMd[OverscriptBox[a_, "^"]] := "$\\hat{" <> walkerMath[a] <> "}$"
inlineMd[RowBox[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[x_]] := inlineMd[x]
inlineMd[other_] := ToString[other, InputForm]

(* math-mode siblings of inlineMd: same recursion, but without the "$" wrapper
   each math-aware rule above prepends - so a FormBox containing SubscriptBox
   does not emit "$$ ... $$" twice. Strings and italics pass through clean. *)
walkerMath[s_String] := s
walkerMath[StyleBox[s_, "TI" | (FontSlant -> "Italic"), ___]] := walkerMath[s]
walkerMath[StyleBox[s_, ___]] := walkerMath[s]
walkerMath[FractionBox[a_, b_]] := walkerMath[a] <> "/" <> walkerMath[b]
walkerMath[SubscriptBox[a_, b_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[SuperscriptBox[a_, b_]] := walkerMath[a] <> "^{" <> walkerMath[b] <> "}"
walkerMath[SqrtBox[a_]] := "\\sqrt{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, "^"]] := "\\hat{" <> walkerMath[a] <> "}"
walkerMath[RowBox[xs_List]] := StringJoin[walkerMath /@ xs]
walkerMath[FormBox[box_, ___]] := walkerMath[box]
walkerMath[other_] := ToString[other, InputForm]

(* TextData / String / Cell content -> a plain text string (recovers prose). *)
cellText[Cell[content_, ___]] := cellText[content]
cellText[s_String] := s
cellText[TextData[xs_]] := If[ListQ[xs], StringJoin[inlineMd /@ xs], inlineMd[xs]]
cellText[BoxData[b_]] := boxToCode[b]
cellText[other_] := ToString[other, InputForm]

(* Box-form WL code -> source string. A code cell's BoxData carries the user's
   surface form as a tree of RowBoxes whose leaves are tokens (operators,
   identifiers, literal whitespace); concatenating the leaves rebuilds the
   source verbatim, including the author's spacing and line breaks. That is
   simpler and more faithful than MakeExpression, which loses original spacing
   and (surprisingly) trips on multi-statement RowBoxes whose children include
   literal "\n" strings, and than ToString[..., InputForm] of the parsed
   expression, which would re-emit canonical formatting. The handful of 2D box
   types (FractionBox / SqrtBox / SubscriptBox / SuperscriptBox) get
   one-dimensional surface equivalents - subscripts and superscripts have no
   surface form so we use the canonical functional one. *)
boxToCode[s_String] := s
boxToCode[RowBox[xs_List]] := StringJoin[boxToCode /@ xs]
boxToCode[FractionBox[a_, b_]] := boxToCode[a] <> "/" <> boxToCode[b]
boxToCode[SqrtBox[a_]] := "Sqrt[" <> boxToCode[a] <> "]"
boxToCode[SubscriptBox[a_, b_]] := "Subscript[" <> boxToCode[a] <> ", " <> boxToCode[b] <> "]"
boxToCode[SuperscriptBox[a_, b_]] := boxToCode[a] <> "^" <> boxToCode[b]
boxToCode[InterpretationBox[disp_, ___]] := boxToCode[disp]
boxToCode[TagBox[disp_, ___]] := boxToCode[disp]
boxToCode[StyleBox[disp_, ___]] := boxToCode[disp]
boxToCode[other_] := ToString[other, InputForm]

(* Styles a walker should skip entirely:
     - evaluation artifacts (Output / Message / MSG): regenerate on re-run
     - template decoration (MoreInfoText / DockedCell / *CellLabel / *Flag):
       inserted by the front end for the resource authoring UI, never in source
   The list is open: any unknown style still falls through to the generic
   "_, txt" branch (so authored content in a custom style is recovered as
   prose) - only the known-decoration list is silenced. *)
$skipStyles = {
    "Output", "Message", "MSG", "Print", "ExampleInitialization",
    "MoreInfoText", "MoreInfoTextOuter",
    "DockedCell",
    "ExcludedCellLabel", "HiddenMaterialCellLabel",
    "FutureFlag", "ExcisedFlag", "ObsoleteFlag", "TemporaryFlag", "PreviewFlag", "InternalFlag"
}
cellMd[Cell[_, s_String, ___]] /; MemberQ[$skipStyles, s] := ""

(* Image cells (raster or vector graphics in BoxData) are output, not source -
   the markdown twin embeds them as ![]() but the source markdown that produced
   them is the WL Input cell that evaluated to them. The walker drops them. *)
cellMd[Cell[BoxData[(GraphicsBox | Graphics3DBox | RasterBox)[___]], _String, ___]] := ""

(* a single Cell -> one markdown block (or "" if it should be skipped). *)
cellMd[Cell[content_, style_String, opts___]] := Block[{txt = cellText[Cell[content, style, opts]]},
    Switch[style,
        "Title" | "ObjectName",     "# " <> txt,
        "Section",                  "## " <> txt,
        "Subsection",               "### " <> txt,
        "Subsubsection",            "#### " <> txt,
        "Text" | "Caption" | "Quote" | "ExampleText" | "Usage" | "UsageDescription",
                                    txt,
        "Notes",                    txt,
        "ItemNumbered" | "ItemNumbered1",  "1. " <> txt,
        "Item" | "Item1" | "Item2" | "Bullet",  "- " <> txt,
        "Code" | "Input" | "ExampleInput" | "Program",  "```wl\n" <> txt <> "\n```",
        "InlineFormula",            "`" <> txt <> "`",
        _, txt
    ]
]
cellMd[Cell[CellGroupData[cells_List, ___]]] := StringRiffle[DeleteCases[cellMd /@ cells, ""], "\n\n"]
cellMd[other_] := ""

(* === public entry === *)

NotebookToMarkdown[Notebook[cells_List, ___]] :=
    StringRiffle[DeleteCases[cellMd /@ cells, ""], "\n\n"] <> "\n"
NotebookToMarkdown[nbo_NotebookObject] := NotebookToMarkdown[NotebookGet[nbo]]
NotebookToMarkdown[file_String /; FileExistsQ[file] && StringEndsQ[ToLowerCase[file], ".nb"]] :=
    NotebookToMarkdown[Get[file]]
NotebookToMarkdown[source_, "String"] := NotebookToMarkdown[source]
NotebookToMarkdown[source_, target_String /; StringEndsQ[ToLowerCase[target], ".md"]] := Block[
    {md = NotebookToMarkdown[source]},
    Export[target, md, "Text"];
    target
]

(* ============================================================================
   FAITHFUL DOC-PAGE MODE  (opt-in: NotebookToMarkdown[file, "DocPage" -> True])
   ----------------------------------------------------------------------------
   The general walker above recovers an APPROXIMATE markdown body from any
   notebook. The doc-page mode below recovers a FAITHFUL literate-markdown twin
   of a shipped DocumentationTools reference page (Symbol / Guide / TechNote):
     - the exact typed Input code, via the front end's InputText export (feInput);
     - YAML frontmatter, from the Categorization / Keywords / SeeAlso / MoreAbout cells;
     - Usage signatures as <code>[Sym]()[...]</code> spans (round-trip-safe, see below);
     - Notes / property / named-circuit GridBoxes as pipe tables.
   It REQUIRES a front end (feInput) and is opt-in via the "DocPage" -> True form.
   See NotebookToMarkdown.md (## Faithful doc-page twin) for the pipeline and the
   round-trip contract with MarkdownToNotebook.

   The rules below EXTEND the general inlineMd / walkerMath / boxToCode with the
   richer doc-page behavior. The two generic inlineMd[Cell[BoxData...]] rules are
   guarded with !decorationCellQ so the general walker's decoration-drop (and its
   test) is preserved.
   ============================================================================ *)
(* --- extend the inline converter for code-styled spans --- *)
inlineMd[StyleBox[s_, "Code", ___]] := "`" <> boxToCode[s] <> "`"
(* an inline subscript/superscript placeholder in PROSE -> canonical inline math
   $base_{sub}$ (base inside the $...$), the round-trip-safe form. The TI-wrapped
   case is more specific than the generic "TI" rule below, so it wins; without it
   the subscript falls through to boxToCode and leaks "Subscript[obj, i]". *)
inlineMd[StyleBox[SubscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "_{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[SuperscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "^{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[s_, "TI", ___]] := emWrap[inlineMd[s], "*"]

(* The front end's inline-box escape for a styled placeholder string parses, on Get, to
   DisplayForm[StyleBox[x, TI]] inside the string; convert that to the *x* italic form.
   (Do NOT put the raw linear-syntax form in this source: Get would parse it into boxes.) *)
(* A styled placeholder string in the nb is stored as front-end linear-syntax:
   "<PUA \!\(\*>StyleBox["x", "TI"]<PUA \)>".  The \! \( \* \) markers are private-use
   characters (codes ~63300-63500), not ASCII. Convert StyleBox["x","TI"] -> *x* and
   strip the PUA box-marker characters. Also handle the DisplayForm[StyleBox[x, TI]]
   rendering form as a fallback. *)
dq[s_String] := StringTrim[StringTrim[StringTrim[s], "\""], "()" | "(" | ")"]

(* === character normalization ===
   Wolfram FORMAL symbols (\[FormalA]..\[FormalZ] = 0xF800-0xF819, capitals 0xF81A-0xF833)
   render fine in Mathematica but are INVISIBLE private-use glyphs in a web/markdown view,
   so a formal placeholder shows as nothing (the empty "**"). Map them to plain letters.
   FE structural box markers (\! \( \* \), 0xE000-0xF7FF) are pure noise -> drop. *)
normCharCode[n_Integer] := Which[
    63488 <= n <= 63513, FromCharacterCode[n - 63488 + 97],   (* formal a..z *)
    63514 <= n <= 63539, FromCharacterCode[n - 63514 + 65],   (* formal A..Z *)
    (* Wolfram letter glyphs (script / gothic / double-struck) live in the same PUA
       band as the FE structural markers but are CONTENT, not noise; map them to plain
       ASCII (not \mathscr{} - normStr runs on prose too, where a TeX command would not
       render). Dropping them instead leaves e.g. a subscript base empty, which renders
       as "_{+}_{+}" -> a KaTeX "double subscript" error. *)
    63154 <= n <= 63179, FromCharacterCode[n - 63154 + 97],   (* script a..z *)
    63344 <= n <= 63369, FromCharacterCode[n - 63344 + 65],   (* script A..Z *)
    63180 <= n <= 63205, FromCharacterCode[n - 63180 + 97],   (* gothic a..z *)
    63370 <= n <= 63395, FromCharacterCode[n - 63370 + 65],   (* gothic A..Z *)
    63206 <= n <= 63231, FromCharacterCode[n - 63206 + 97],   (* double-struck a..z *)
    63396 <= n <= 63421, FromCharacterCode[n - 63396 + 65],   (* double-struck A..Z *)
    63451 <= n <= 63460, FromCharacterCode[n - 63451 + 48],   (* double-struck 0..9 *)
    (* Named math constants \[CapitalDifferentialD] \[DifferentialD] \[ExponentialE]
       \[ImaginaryI] \[ImaginaryJ] live in the same PUA band as the FE markers but are
       CONTENT (the e in e^{i...}, the i in an exponent). Map to plain ASCII so they are
       not swallowed by the drop below, which would orphan a SuperscriptBox into ^{...}. *)
    63307 <= n <= 63311, FromCharacterCode @ {68, 100, 101, 105, 106}[[n - 63306]],
    57344 <= n <= 63487, "",                                   (* FE structural box markers -> drop *)
    True, FromCharacterCode[n]
]
normStr[s_String] := StringJoin[normCharCode /@ ToCharacterCode[s]]
stripStructPUA[s_String] := StringJoin @ DeleteCases[Characters[s],
    c_ /; With[{n = First @ ToCharacterCode[c]}, 57344 <= n <= 63487]]

(* cleanStr: for an inline STRING, rewrite any serialized box-syntax a placeholder may
   carry (StyleBox["x","TI"] -> *x*, SubscriptBox -> $_{}$) then normalize characters.
   Strip the FE \!\(\* wrapper first so the box heads are matchable. *)
(* mathDq: dq, then canonicalize Greek to TeX commands - for the $..$ math segments only,
   so a serialized SubscriptBox[\[Gamma], 1] string yields $\gamma_{1}$, not a raw $γ_{1}$. *)
mathDq[x_String] := StringReplace[dq[x], Normal @ $mathTeX]
cleanStr[s_String] := normStr @ StringReplace[stripStructPUA[s], {
    "StyleBox[\"" ~~ Shortest[v__] ~~ "\", \"TI\"]" :> "*" <> v <> "*",
    "DisplayForm[StyleBox[" ~~ Shortest[v__] ~~ ", TI]]" :> "*" <> v <> "*",
    "StyleBox[" ~~ Shortest[v__] ~~ ", TI]" :> "*" <> v <> "*",
    "SubsuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ ", " ~~ Shortest[c__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}^{" <> mathDq[c] <> "}$",
    "SubscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}$",
    "SuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "^{" <> mathDq[b] <> "}$"
}]

(* route all inline caption strings through the cleaner; plain prose passes unchanged *)
inlineMd[s_String] := cleanStr[s]

(* Dirac kets/bras that appear in table-description boxes *)
boxToCode[TemplateBox[{x_}, "Ket"]] := "|" <> boxToCode[x] <> "\[RightAngleBracket]"
boxToCode[TemplateBox[{x_}, "Bra"]] := "\[LeftAngleBracket]" <> boxToCode[x] <> "|"
boxToCode[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] :=
    "\[LeftAngleBracket]" <> boxToCode[x] <> "|" <> boxToCode[y] <> "\[RightAngleBracket]"
boxToCode[s_String] := normStr[s]

(* === signature serializer (sig) ===
   Renders a Usage call box to markdown using the hand-authored conventions:
   - a link button -> [Name]()
   - an italic (TI) string arg -> *arg*   (TI around a structure: recurse, don't wrap)
   - a subscript -> $base_{i}$  (canonical inline math: the base lives INSIDE the $...$,
     so the forward MarkdownToNotebook's mathArgsToTemplate round-trips it to a clean
     subscript. The older *base*$_i$ form - italic base + a separate $_i$ - renders fine
     as raw markdown but round-trips BROKEN through MarkdownToNotebook, so it is not used.)
   - operators / brackets / commas / arrows -> literal (formal chars mapped, PUA dropped) *)
sig[s_String] := cleanStr[s]
sig[bb_ButtonBox] := "[" <> cellPlain[bb[[1]]] <> "]()"
sig[StyleBox[s_String, "TI", ___]] := emWrap[normStr[s], "*"]
sig[StyleBox[s_, ___]] := sig[s]
sig[SubscriptBox[a_, b_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}$"
sig[SuperscriptBox[a_, b_]] := "$" <> sigSub[a] <> "^{" <> sigSub[b] <> "}$"
sig[SubsuperscriptBox[a_, b_, c_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}^{" <> sigSub[c] <> "}$"
sig[FractionBox[a_, b_]] := sig[a] <> "/" <> sig[b]
(* a call box "Sym[...]" links its HEAD ([Sym]()) then maps the rest. The head is stored
   as a bare-identifier String; a quoted named-circuit literal ("\"Fourier\"") is not linked.
   One rule with an If, so there is no pattern-ordering race with the generic RowBox map. *)
sig[RowBox[xs_List]] := If[
    MatchQ[xs, {_String, "[", ___}] && StringMatchQ[First[xs], LetterCharacter ~~ (WordCharacter | "$") ...],
    "[" <> First[xs] <> "]()" <> StringJoin[sig /@ Rest[xs]],
    StringJoin[sig /@ xs]]
sig[f_Symbol] := SymbolName[f]
sig[other_] := normStr @ boxToCode[other]
(* subscript/superscript content: strip styling, keep the plain text for the $...$ *)
sigSub[StyleBox[s_, ___]] := sigSub[s]
(* sig subscripts/superscripts are emitted inside $..$, so canonicalize Greek to TeX
   commands here too (matches the walkerMath math leaf); ASCII bases are unaffected. *)
sigSub[s_String] := StringReplace[normStr[s], Normal @ $mathTeX]
sigSub[RowBox[xs_List]] := StringJoin[sigSub /@ xs]
sigSub[x_] := walkerMath[x]
sigBox[x_] := sig[x]

(* does a box tree carry 2D math structure (so it should render as $...$, not `code`)? *)
mathyQ[b_] := ! FreeQ[b, _SubscriptBox | _SuperscriptBox | _SubsuperscriptBox |
    _FractionBox | _SqrtBox | _RadicalBox | _OverscriptBox | _UnderscriptBox | _FormBox |
    TemplateBox[_, "Ket" | "Bra" | "Braket" | "BraKet" | "SuperDagger" | "Dagger" | "Conjugate"]]

(* a non-Link call box (Sym[...], "name"[...], *circ*[...]) is a SIGNATURE, not a
   formula, so it should render as <code> even without a Link BaseStyle. Guard out
   heavy-math boxes so a functional-form formula (e.g. Tr[Sqrt[...]]) stays $...$. *)
sigCallBoxQ[RowBox[{h_, "[", ___}] ? (FreeQ[#, SqrtBox | FractionBox | RadicalBox | UnderoverscriptBox] &)] :=
    MatchQ[h, _Symbol | _String | StyleBox[_, "TI", ___]]
(* a code signature is sometimes authored inside a TraditionalForm FormBox (math); unwrap
   it so it routes to <code>. In math mode its literal {} / [] would otherwise become
   invisible TeX grouping (braces vanish) and the code renders in italic. *)
sigCallBoxQ[FormBox[b_, ___]] := sigCallBoxQ[b]
sigCallBoxQ[_] := False
sig[FormBox[b_, ___]] := sig[b]

(* a FormBox is math by definition: never serialize it as code *)
boxToCode[FormBox[b_, ___]] := walkerMath[b]

(* extend math-mode serializer (walkerMath) for the box types seen in captions/tables *)
walkerMath[SubsuperscriptBox[a_, b_, c_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[RadicalBox[a_, b_]] := "\\sqrt[" <> walkerMath[b] <> "]{" <> walkerMath[a] <> "}"
walkerMath[UnderscriptBox[a_, b_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[OverscriptBox[a_, "_"]] := "\\overline{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, b_]] := "\\overset{" <> walkerMath[b] <> "}{" <> walkerMath[a] <> "}"
walkerMath[UnderoverscriptBox[a_, b_, c_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[ButtonBox[n_, ___]] := walkerMath[n]
boxToCode[OverscriptBox[a_, _]] := boxToCode[a]
boxToCode[SubsuperscriptBox[a_, b_, c_]] := boxToCode[a] <> "_" <> boxToCode[b] <> "^" <> boxToCode[c]
walkerMath[TemplateBox[{x_}, "Ket"]] := "|" <> walkerMath[x] <> "\\rangle"
walkerMath[TemplateBox[{x_}, "Bra"]] := "\\langle " <> walkerMath[x] <> "|"
walkerMath[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] := "\\langle " <> walkerMath[x] <> "|" <> walkerMath[y] <> "\\rangle"
walkerMath[TemplateBox[{x_}, "SuperDagger" | "Dagger"]] := walkerMath[x] <> "^\\dagger"
walkerMath[TemplateBox[{x_}, "Conjugate"]] := walkerMath[x] <> "^*"
walkerMath[StyleBox[s_, ___]] := walkerMath[s]
walkerMath[Cell[BoxData[b_], ___]] := walkerMath[b]
walkerMath[Cell[c_, ___]] := walkerMath[c]

(* math leaf strings: map formal symbols, strip FE PUA.
   In TeX/KaTeX math, literal spaces are IGNORED and a multi-letter token like "mod"
   renders as a product of italics, so "(a+b) mod n" collapses to "(a+b)modn". Map the
   common text operators to their TeX operators and a run of spaces to a thin space so
   the spacing survives. *)
walkerMath["mod"] := "\\bmod "
walkerMath["div"] := "\\div "
walkerMath["gcd"] := "\\gcd "
walkerMath["lcm"] := "\\operatorname{lcm} "
walkerMath[s_String /; s =!= "" && StringMatchQ[s, Whitespace]] := "\\, "
(* In math mode a raw Unicode Greek glyph or math operator is non-canonical TeX; map to
   the command. Applied ONLY on the math leaf (walkerMath / sigSub / mathDq), never in
   normStr, so the same glyph in prose is left as the readable Unicode character. *)
$mathTeX = <|
    "\[Alpha]" -> "\\alpha ", "\[Beta]" -> "\\beta ", "\[Gamma]" -> "\\gamma ",
    "\[Delta]" -> "\\delta ", "\[Epsilon]" -> "\\epsilon ", "\[CurlyEpsilon]" -> "\\varepsilon ",
    "\[Zeta]" -> "\\zeta ", "\[Eta]" -> "\\eta ", "\[Theta]" -> "\\theta ",
    "\[CurlyTheta]" -> "\\vartheta ", "\[Iota]" -> "\\iota ", "\[Kappa]" -> "\\kappa ",
    "\[Lambda]" -> "\\lambda ", "\[Mu]" -> "\\mu ", "\[Nu]" -> "\\nu ", "\[Xi]" -> "\\xi ",
    "\[Pi]" -> "\\pi ", "\[Rho]" -> "\\rho ", "\[Sigma]" -> "\\sigma ", "\[FinalSigma]" -> "\\varsigma ",
    "\[Tau]" -> "\\tau ", "\[Upsilon]" -> "\\upsilon ", "\[Phi]" -> "\\phi ",
    "\[CurlyPhi]" -> "\\varphi ", "\[Chi]" -> "\\chi ", "\[Psi]" -> "\\psi ", "\[Omega]" -> "\\omega ",
    "\[CapitalGamma]" -> "\\Gamma ", "\[CapitalDelta]" -> "\\Delta ", "\[CapitalTheta]" -> "\\Theta ",
    "\[CapitalLambda]" -> "\\Lambda ", "\[CapitalXi]" -> "\\Xi ", "\[CapitalPi]" -> "\\Pi ",
    "\[CapitalSigma]" -> "\\Sigma ", "\[CapitalUpsilon]" -> "\\Upsilon ", "\[CapitalPhi]" -> "\\Phi ",
    "\[CapitalPsi]" -> "\\Psi ", "\[CapitalOmega]" -> "\\Omega ",
    (* math operators / letterlike symbols *)
    "\[Dagger]" -> "\\dagger ", "\[CircleTimes]" -> "\\otimes ", "\[Ellipsis]" -> "\\ldots ",
    "\[Sum]" -> "\\sum ", "\[ScriptCapitalL]" -> "\\mathcal{L}", "\[PartialD]" -> "\\partial ",
    "\[Times]" -> "\\times ", "\[CenterDot]" -> "\\cdot "
|>;
walkerMath[s_String] := StringReplace[normStr[s], Normal @ $mathTeX]

(* robust link: a ButtonBox's first argument is its label (String / StyleBox / RowBox);
   emit the inferred-link form [label](). Always produces a link, never a raw dump. *)
buttonLabel[ButtonBox[label_, ___]] := cellPlain[label]
inlineMd[bb_ButtonBox] := "[" <> buttonLabel[bb] <> "]()"

(* InlineFormula: link signature -> <code>...</code>; bare italic arg -> *arg*;
   2D math -> $...$; otherwise inline `code`. Also catch styleless math cells. *)
inlineMd[Cell[BoxData[FormBox[b_, ___]], "InlineFormula", ___]] := "$" <> walkerMath[b] <> "$"
inlineMd[Cell[BoxData[StyleBox[s_, "TI", ___]], "InlineFormula", ___]] :=
    If[mathyQ[s], "$" <> walkerMath[s] <> "$", "*" <> boxToCode[s] <> "*"]
(* a lone Link ButtonBox is a symbol mention, not a call -> [name]() not <code>.
   The front end often wraps it in a TagBox and gives BaseStyle a Dynamic mouse-over. *)
inlineMd[Cell[BoxData[ButtonBox[a___]], "InlineFormula", ___]] := inlineMd[ButtonBox[a]]
inlineMd[Cell[BoxData[TagBox[bb_ButtonBox, ___]], "InlineFormula", ___]] := inlineMd[bb]
inlineMd[c0 : Cell[BoxData[b_], "InlineFormula", ___]] /; ! decorationCellQ[c0] := Which[
    ! FreeQ[b, BaseStyle -> "Link" | "Hyperlink"], "<code>" <> sigBox[b] <> "</code>",
    sigCallBoxQ[b], "<code>" <> sigBox[b] <> "</code>",
    mathyQ[b], "$" <> walkerMath[b] <> "$",
    True, With[{c = cleanStr[boxToCode[b]]},
        (* a styled-string placeholder ("name" with TI) cleans to contain *...*; emit it
           as bare italic prose, not a backtick code span (asterisks don't render in code) *)
        If[StringContainsQ[c, "*"], c, "`" <> c <> "`"]]
]
inlineMd[c0 : Cell[BoxData[b_], ___]] /; ! decorationCellQ[c0] :=
    Which[MatchQ[b, _Cell], inlineMd[b], sigCallBoxQ[b], "<code>" <> sigBox[b] <> "</code>", mathyQ[b], "$" <> walkerMath[b] <> "$", True, "`" <> boxToCode[b] <> "`"]
inlineMd[BoxData[b_]] := If[mathyQ[b], "$" <> walkerMath[b] <> "$", "`" <> boxToCode[b] <> "`"]
inlineMd[TagBox[x_, ___]] := inlineMd[x]
inlineMd[InterpretationBox[x_, ___]] := inlineMd[x]
(* nested cells (a doc table cell can wrap its prose several Cells deep:
   Cell[TextData[Cell[BoxData[Cell[TextData[...],"TableText"]]]]]). Recurse into the
   content instead of letting boxToCode ToString-dump the inner Cell:
   - a BoxData wrapper around a Cell -> unwrapped in the BoxData rule's Which below;
   - a TEXT cell (TextData / String content) -> unwrap to its content. *)
inlineMd[c0 : Cell[content : (_TextData | _String), _String, ___]] /; ! decorationCellQ[c0] := inlineMd[content]
walkerMath[TagBox[x_, ___]] := walkerMath[x]
walkerMath[InterpretationBox[x_, ___]] := walkerMath[x]
boxToCode[InterpretationBox[x_, ___]] := boxToCode[x]

(* --- plain text of a TextData / string (for titles, ObjectName) --- *)
cellPlain[s_String] := normStr[s]
cellPlain[TextData[xs_List]] := StringJoin[cellPlain /@ xs]
cellPlain[TextData[x_]] := cellPlain[x]
cellPlain[Cell[c_, ___]] := cellPlain[c]
cellPlain[BoxData[b_]] := boxToCode[b]
cellPlain[StyleBox[s_, ___]] := cellPlain[s]
cellPlain[ButtonBox[n_String, ___]] := n
cellPlain[_] := ""

(* --- faithful Input code via FE InputText (call inside UsingFrontEnd) --- *)
feInput[bd_] := Module[{r},
    r = MathLink`CallFrontEnd[FrontEnd`ExportPacket[Cell[bd, "Input"], "InputText"]];
    StringTrim @ If[MatchQ[r, {_String, ___}], First[r], ToString[r]]
]

(* --- clean caption whitespace (newlines -> space, collapse) --- *)
tidy[s_String] := StringTrim @ StringReplace[s, {"\n" -> " ", "\r" -> " ", Whitespace -> " "}]

(* --- Usage cell: split the TextData on its ModInfo separators - the doc template's
   actual statement boundaries - into one paragraph per usage statement. Splitting on
   ModInfo (not on every signature-like element) keeps an inline symbol reference inside
   a description, e.g. "...changes the basis of the QuantumOperator qo...", from being
   mistaken for a new statement and breaking the paragraph. --- *)
usageMd[TextData[xs_List]] := Module[{lines = {}, cur = {}},
    Do[
        If[ MatchQ[e, Cell[_, "ModInfo", ___]],
            If[cur =!= {}, AppendTo[lines, cur]]; cur = {},
            AppendTo[cur, e]
        ],
        {e, xs}
    ];
    If[cur =!= {}, AppendTo[lines, cur]];
    StringRiffle[tidy[StringJoin[inlineMd /@ #]] & /@ DeleteCases[lines, {}], "\n\n"]
]
usageMd[other_] := tidy @ inlineMd[other]

(* a signature element: an InlineFormula cell that is a call box (Sym[...]) or carries
   a Link ButtonBox. usageLines starts a new Usage line at each, so multiple signatures
   each get their own line even without a Link BaseStyle. *)
sigQ[Cell[BoxData[b_], "InlineFormula", ___]] := sigCallBoxQ[b] || ! FreeQ[b, BaseStyle -> "Link"]
sigQ[_] := False

usageLines[elts_List] := Module[{lines = {}, cur = {}},
    Do[
        If[ sigQ[e] && cur =!= {},
            AppendTo[lines, cur]; cur = {e},
            AppendTo[cur, e]
        ],
        {e, elts}
    ];
    If[cur =!= {}, AppendTo[lines, cur]];
    StringRiffle[tidy[StringJoin[inlineMd /@ #]] & /@ lines, "\n\n"]
]

(* --- section title: ExampleSection wraps the title in an InterpretationBox counter
   cell; ExampleSubsection/Subsubsection store the title string directly. --- *)
sectionTitle[content_] := Module[{inner},
    inner = FirstCase[content, Cell[t_, _String, ___] :> t, $noInner, Infinity];
    cellPlain @ If[inner === $noInner, content, inner]
]

(* --- per-cell block --- *)
ClearAll[blockFor]
$dropStyles = {
    "Output", "Message", "Print", "ModInfo", "MoreInfoText", "MoreInfoTextOuter",
    "Categorization", "CategorizationSection", "Keywords", "KeywordsSection",
    "Template", "TemplatesSection", "History", "HistoryData",
    "TechNotesSection", "Tutorials", "RelatedDemonstrations", "RelatedDemonstrationsSection",
    "RelatedLinks", "RelatedLinksSection", "SeeAlso", "SeeAlsoSection",
    "MoreAbout", "MoreAboutSection", "ExtendedExamplesSection",
    "ExamplesInitializationSection", "ExampleInitialization"
};

blockFor["ObjectName", _] := ""
blockFor["Usage", c_] := "## Usage\n\n" <> usageMd[c]
(* The Notes cells are the "Details & Options" section of a doc page; the nb carries
   no heading cell for it (the template implies it), so emit "## Details & Options"
   once, before the first Notes block, so the section round-trips through the forward
   MarkdownToNotebook (which maps that heading back to the Notes slot). *)
blockFor["Notes", c_] := With[{b = "- " <> tidy @ inlineMd[c]},
    If[TrueQ[$detailsHeadingDone], b, $detailsHeadingDone = True; "## Details & Options\n\n" <> b]]
blockFor["2ColumnTableMod" | "3ColumnTableMod" | "TableNotes", BoxData[GridBox[rows_List, ___]]] := gridTable[rows]
blockFor["2ColumnTableMod" | "3ColumnTableMod", c_] := tidy @ inlineMd[c]

(* GridBox rows -> pipe table; drop ModInfo spacer columns, convert each remaining cell *)
spacerQ[Cell[s_String, "ModInfo", ___]] := StringMatchQ[s, Whitespace | ""]
spacerQ[_] := False
gridCellMd[s_String] := "`" <> StringTrim[s] <> "`"
gridCellMd[Cell[t_, "TableText", ___]] := tidy @ inlineMd[t]
(* A left-column "spec" call-form (`"Graph"[g]`, `qco["Diagram"]`) is the literal thing
   you type, exactly like a bare-string spec - render it as inline code so the spec column
   is uniform (bare strings already backtick via the s_String rule). BUT a code span cannot
   hold a 2D subscript: backticking `"Multiplexer"[op_1,..]` would linearize op_1 to the
   literal text `Subscript[op, 1]` (ugly, and round-trips to literal text, not the box).
   So backtick only when the spec is sub/superscript-free; otherwise render it as a
   signature with canonical $op_{1}$ math (proper subscript, round-trips to the SubscriptBox,
   matching how Usage signatures present subscript args). *)
gridCellMd[b_ /; sigCallBoxQ[b] && FreeQ[b, SubscriptBox | SuperscriptBox | SubsuperscriptBox]] :=
    "`" <> boxToCode[b] <> "`"
gridCellMd[b_ /; sigCallBoxQ[b]] := tidy @ sig[b]
gridCellMd[c_] := tidy @ inlineMd[c]
gridTable[rows_List] := Module[{drows, ncol},
    drows = Function[r, gridCellMd /@ DeleteCases[r, _?spacerQ]] /@ rows;
    drows = DeleteCases[drows, {}];
    If[drows === {}, Return[""]];
    ncol = Max[Length /@ drows];
    drows = PadRight[#, ncol, ""] & /@ drows;
    StringRiffle[
        Join[
            {"| " <> StringRiffle[ConstantArray[" ", ncol], " | "] <> " |"},
            {"|" <> StringRiffle[ConstantArray["---", ncol], "|"] <> "|"},
            ("| " <> StringRiffle[#, " | "] <> " |") & /@ drows
        ],
        "\n"
    ]
]
blockFor["ExampleText" | "CodeText" | "Caption", c_] := tidy @ inlineMd[c]
blockFor["Input" | "Code" | "ExampleInput" | "Program", BoxData[b_]] :=
    "```wl\n" <> feInput[BoxData[b]] <> "\n```"
blockFor["Input" | "Code", c_] := "```wl\n" <> feInput[c] <> "\n```"
blockFor["PrimaryExamplesSection", _] := "## Basic Examples"
blockFor["ExampleSection", c_] := "## " <> sectionTitle[c]
blockFor["ExampleSubsection", c_] := "### " <> sectionTitle[c]
blockFor["ExampleSubsubsection", c_] := "#### " <> sectionTitle[c]
blockFor["ExampleDelimiter", _] := "---"
blockFor[s_String, _] /; MemberQ[$dropStyles, s] := ""
blockFor[_, _] := ""

(* --- tree walk --- *)
walkCell[Cell[CellGroupData[inner_List, ___]]] := walkCells[inner]
walkCell[Cell[content_, style_String, ___]] := blockFor[style, content]
walkCell[_] := ""
walkCells[cells_List] := DeleteCases[Flatten[{walkCell /@ cells}], "" | Null]

(* --- frontmatter --- *)
catList[nb_] := Flatten @ Cases[nb, Cell[c_, "Categorization", ___] :> Cases[{c}, _String, Infinity], Infinity]
seeAlsoList[nb_] := Cases[nb,
    Cell[_, "SeeAlso", ___] -> _,
    Infinity] /. {} -> {};
linkNames[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[n_String, ___] :> n, Infinity]
guideIds[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[_, ___, ButtonData -> d_String, ___] :> Last[StringSplit[d, "/"]], Infinity]
keywordList[nb_] := Cases[nb, Cell[c_, "Keywords", ___] :> Cases[{c}, _String, Infinity], Infinity] // Flatten

frontmatter[nb_, name_] := Module[{cat, paclet, ctx, uri, kw, sa, rg},
    cat = catList[nb];
    paclet = If[Length[cat] >= 2, cat[[2]], ""];
    ctx = If[Length[cat] >= 3, cat[[3]], ""];
    uri = If[Length[cat] >= 4, cat[[4]], ""];
    kw = keywordList[nb];
    sa = linkNames[nb, "SeeAlso"];
    rg = guideIds[nb, "MoreAbout"];
    StringJoin[
        "---\n",
        "Template: Symbol\n",
        "Name: ", name, "\n",
        "Context: ", ctx, "\n",
        "Paclet: ", paclet, "\n",
        "URI: ", uri, "\n",
        "Keywords: [", StringRiffle[kw, ", "], "]\n",
        "SeeAlso: [", StringRiffle[sa, ", "], "]\n",
        "RelatedGuides: [", StringRiffle[rg, ", "], "]\n",
        "---\n"
    ]
]

(* --- post-process: drop a heading immediately followed by another heading or EOF --- *)
(* a HEADING-ONLY block: "## Title" on a single line. A block that bakes content
   after its heading (e.g. the Usage block "## Usage\n\n<sig>...") contains a newline
   and is NOT heading-only, so dropEmptySections never mistakes it for an empty section. *)
headingQ[s_String] := StringMatchQ[s, ("#" ..) ~~ " " ~~ Except["\n"] ...]
headingLevel[s_String] := StringLength @ First @ StringCases[s, StartOfString ~~ h : ("#" ..) :> h]
(* a heading is empty only if the next block is a heading of the SAME or HIGHER level
   (a sibling/parent section), or end of document; a following deeper subsection is content *)
dropEmptySections[blocks_List] := Module[{i, out = {}},
    Do[
        If[ headingQ[blocks[[i]]] &&
            (i == Length[blocks] ||
                (headingQ[blocks[[i + 1]]] && headingLevel[blocks[[i + 1]]] <= headingLevel[blocks[[i]]])),
            Null,
            AppendTo[out, blocks[[i]]]
        ],
        {i, Length[blocks]}
    ];
    out
]

(* strip the front end's structural box-marker / spanning private-use chars (range
   0xE000-0xF7FF) that survive serialization into prose. Applied ONLY to non-code blocks:
   code cells come verbatim from the front end and may legitimately carry PUA glyphs
   (e.g. \[FormalX] at 0xF800+, which is above this band anyway). *)
stripPUA[s_String] := StringJoin @ DeleteCases[Characters[s],
    c_ /; With[{n = First @ ToCharacterCode[c]}, 57344 <= n <= 63487]]
codeBlockQ[s_String] := StringStartsQ[s, "```"]

(* core: a doc-page Notebook -> faithful literate markdown (frontmatter + body).
   Assumes a front end is available (feInput); the public entry points wrap it
   in UsingFrontEnd. *)
docPageMarkdown[nb : Notebook[_List, ___]] := Block[{name, blocks, $detailsHeadingDone = False},
    name = cellPlain @ FirstCase[nb, Cell[t_, "ObjectName", ___] :> t, "", Infinity];
    blocks = walkCells[First[nb]];
    blocks = dropEmptySections[blocks];
    (* non-code blocks: map formal symbols to plain letters + strip FE structural PUA;
       code blocks stay verbatim (they may carry \[FormalX] etc. that must round-trip) *)
    blocks = If[codeBlockQ[#], #, normStr[#]] & /@ blocks;
    normStr[frontmatter[nb, name]] <> "\n" <> StringRiffle[blocks, "\n\n"] <> "\n"
]
convertNb[nbFile_String] := docPageMarkdown[Get[nbFile]]

(* --- batch entry: convert a list of nb paths to md (sibling .md), one FE session --- *)
convertAll[nbFiles_List] := UsingFrontEnd @ Map[
    Function[f, Module[{md, out},
        out = StringReplace[f, ".nb" -> ".md"];
        md = convertNb[f];
        Export[out, md, "Text"];
        Print["wrote ", FileNameTake[out], "  (", StringLength[md], " chars)"];
        out
    ]],
    nbFiles
]

(* === public doc-page entry (opt-in; requires a front end for feInput) ===
   NotebookToMarkdown[src, "DocPage" -> True] recovers the FAITHFUL doc-page twin
   (frontmatter + verbatim code + signatures + tables) instead of the general
   walker's approximate body. src is a Notebook expression, a NotebookObject, or
   a .nb file path; a trailing .md target writes the result. *)
NotebookToMarkdown[nb : Notebook[_List, ___], "DocPage" -> True] := UsingFrontEnd @ docPageMarkdown[nb]
NotebookToMarkdown[nbo_NotebookObject, "DocPage" -> True] := UsingFrontEnd @ docPageMarkdown[NotebookGet[nbo]]
NotebookToMarkdown[file_String /; FileExistsQ[file] && StringEndsQ[ToLowerCase[file], ".nb"], "DocPage" -> True] :=
    UsingFrontEnd @ docPageMarkdown[Get[file]]
NotebookToMarkdown[src_, "DocPage" -> True, target_String /; StringEndsQ[ToLowerCase[target], ".md"]] := Block[
    {md = NotebookToMarkdown[src, "DocPage" -> True]}, Export[target, md, "Text"]; target]
