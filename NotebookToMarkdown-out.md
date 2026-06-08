---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a faithful literate-markdown twin of a Wolfram notebook
ContributedBy: "Nikolay Murzin, Claude (Anthropic)"
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html), or a `.nb` file path, it walks the cells and emits a literate-markdown twin - frontmatter (when the cells indicate a Symbol-template doc page), the verbatim typed Input code, Usage signatures, Notes / property tables, and the standard `Title` / `Section` / `Text` / `Item` / `Code` cell-style sequence mapped back to markdown blocks.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion time via the `#| file:` option; the deployed resource therefore carries it inline:

```wl
(* NotebookToMarkdown - the inverse of MarkdownToNotebook. Given a notebook
   (expression / NotebookObject / .nb file path), recover a literate-markdown
   twin: frontmatter (when the cells indicate a resource template), the verbatim
   typed Input code, Usage signatures, Notes / property tables, and the standard
   cell-style sequence walked back to markdown blocks.

   Walker-only by design: any TaggingRules stash a forward run might have left
   behind is ignored, so this code is exercised on every input and round-trip
   quality is the walker's responsibility, not a memoized shortcut.

   A faithful round trip uses the front end's InputText export to recover code
   cells verbatim (preserving subscripts, `@`, `//`, `[[…]]`, `%`). The public
   entry points wrap the work in UsingFrontEnd; if the call fails (no FE
   reachable, e.g. a minimal Notebook[] expression handed in directly), the
   walker falls back to a pure-kernel boxToCode tree walk so it still produces
   output, just less faithfully for exotic 2D code shapes.

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
   StringJoin. The broader match catches *any* PaneSelectorBox-in-a-Cell-in-
   TextData because such a thing is, by construction, a UI affordance the
   template injected (the source markdown has no way to express it). *)
decorationCellQ[Cell[BoxData[_PaneSelectorBox], ___]] := True
decorationCellQ[Cell[_, "MoreInfoText" | "MoreInfoTextOuter", ___]] := True
decorationCellQ[_] := False

(* === character normalization ===
   Wolfram FORMAL symbols (\[FormalA]..\[FormalZ] = 0xF800-0xF819, capitals
   0xF81A-0xF833) render fine in Mathematica but are INVISIBLE private-use
   glyphs in a web/markdown view, so a formal placeholder shows as nothing (the
   empty "**"). Map them to plain letters. Wolfram letter glyphs (script /
   gothic / double-struck) and named math constants (ExponentialE,
   ImaginaryI, ImaginaryJ, DifferentialD, CapitalDifferentialD) share the
   same PUA band as the FE structural box markers (the box-escape lead-ins,
   0xE000-0xF7FF) - the markers themselves are pure noise -> drop, but the
   letters / constants are content -> map to ASCII so they survive the drop. *)
normCharCode[n_Integer] := Which[
    63488 <= n <= 63513, FromCharacterCode[n - 63488 + 97],   (* formal a..z *)
    63514 <= n <= 63539, FromCharacterCode[n - 63514 + 65],   (* formal A..Z *)
    63154 <= n <= 63179, FromCharacterCode[n - 63154 + 97],   (* script a..z *)
    63344 <= n <= 63369, FromCharacterCode[n - 63344 + 65],   (* script A..Z *)
    63180 <= n <= 63205, FromCharacterCode[n - 63180 + 97],   (* gothic a..z *)
    63370 <= n <= 63395, FromCharacterCode[n - 63370 + 65],   (* gothic A..Z *)
    63206 <= n <= 63231, FromCharacterCode[n - 63206 + 97],   (* double-struck a..z *)
    63396 <= n <= 63421, FromCharacterCode[n - 63396 + 65],   (* double-struck A..Z *)
    63451 <= n <= 63460, FromCharacterCode[n - 63451 + 48],   (* double-struck 0..9 *)
    (* \[CapitalDifferentialD] \[DifferentialD] \[ExponentialE] \[ImaginaryI] \[ImaginaryJ] *)
    63307 <= n <= 63311, FromCharacterCode @ {68, 100, 101, 105, 106}[[n - 63306]],
    57344 <= n <= 63487, "",                                   (* FE structural box markers -> drop *)
    True, FromCharacterCode[n]
]
normStr[s_String] := StringJoin[normCharCode /@ ToCharacterCode[s]]
stripStructPUA[s_String] := StringJoin @ DeleteCases[Characters[s],
    c_ /; With[{n = First @ ToCharacterCode[c]}, 57344 <= n <= 63487]]

(* === math-mode Greek -> TeX commands ===
   In math mode a raw Unicode Greek glyph or math operator is non-canonical TeX
   (KaTeX renders an italic glyph at best, fails entirely for an operator). Map
   on the math leaf (walkerMath / sigSub / mathDq), never in normStr, so the
   same glyph in prose is left as the readable Unicode character. *)
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
    "\[Dagger]" -> "\\dagger ", "\[CircleTimes]" -> "\\otimes ", "\[Ellipsis]" -> "\\ldots ",
    "\[Sum]" -> "\\sum ", "\[ScriptCapitalL]" -> "\\mathcal{L}", "\[PartialD]" -> "\\partial ",
    "\[Times]" -> "\\times ", "\[CenterDot]" -> "\\cdot "
|>;

(* === math-mode serializer ===
   walkerMath produces the body of a "$...$" span (or, for FormBox /
   TraditionalForm, a free-standing math expression). No outer "$" wrapper;
   that lives in the inlineMd dispatchers. *)
walkerMath["mod"] := "\\bmod "
walkerMath["div"] := "\\div "
walkerMath["gcd"] := "\\gcd "
walkerMath["lcm"] := "\\operatorname{lcm} "
walkerMath[s_String /; s =!= "" && StringMatchQ[s, Whitespace]] := "\\, "
walkerMath[s_String] := StringReplace[normStr[s], Normal @ $mathTeX]
walkerMath[StyleBox[s_, ___]] := walkerMath[s]
walkerMath[FractionBox[a_, b_]] := walkerMath[a] <> "/" <> walkerMath[b]
walkerMath[SubscriptBox[a_, b_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[SuperscriptBox[a_, b_]] := walkerMath[a] <> "^{" <> walkerMath[b] <> "}"
walkerMath[SubsuperscriptBox[a_, b_, c_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[SqrtBox[a_]] := "\\sqrt{" <> walkerMath[a] <> "}"
walkerMath[RadicalBox[a_, b_]] := "\\sqrt[" <> walkerMath[b] <> "]{" <> walkerMath[a] <> "}"
walkerMath[UnderscriptBox[a_, b_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[OverscriptBox[a_, "^"]] := "\\hat{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, "_"]] := "\\overline{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, b_]] := "\\overset{" <> walkerMath[b] <> "}{" <> walkerMath[a] <> "}"
walkerMath[UnderoverscriptBox[a_, b_, c_]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[ButtonBox[n_, ___]] := walkerMath[n]
walkerMath[RowBox[xs_List]] := StringJoin[walkerMath /@ xs]
walkerMath[FormBox[box_, ___]] := walkerMath[box]
walkerMath[TagBox[x_, ___]] := walkerMath[x]
walkerMath[InterpretationBox[x_, ___]] := walkerMath[x]
walkerMath[Cell[BoxData[b_], ___]] := walkerMath[b]
walkerMath[Cell[c_, ___]] := walkerMath[c]
walkerMath[TemplateBox[{x_}, "Ket"]] := "|" <> walkerMath[x] <> "\\rangle"
walkerMath[TemplateBox[{x_}, "Bra"]] := "\\langle " <> walkerMath[x] <> "|"
walkerMath[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] := "\\langle " <> walkerMath[x] <> "|" <> walkerMath[y] <> "\\rangle"
walkerMath[TemplateBox[{x_}, "SuperDagger" | "Dagger"]] := walkerMath[x] <> "^\\dagger"
walkerMath[TemplateBox[{x_}, "Conjugate"]] := walkerMath[x] <> "^*"
walkerMath[other_] := ToString[other, InputForm]

(* === code-mode serializer ===
   Box-form WL code -> source string. A code cell's BoxData carries the user's
   surface form as a tree of RowBoxes whose leaves are tokens (operators,
   identifiers, literal whitespace); concatenating the leaves rebuilds the
   source verbatim, including the author's spacing and line breaks. That is
   simpler and more faithful than MakeExpression, which loses original spacing
   and (surprisingly) trips on multi-statement RowBoxes whose children include
   literal "\n" strings. The handful of 2D box types get one-dimensional
   surface equivalents - subscripts and superscripts have no surface form so we
   use the canonical functional one. *)
boxToCode[s_String] := normStr[s]
boxToCode[RowBox[xs_List]] := StringJoin[boxToCode /@ xs]
boxToCode[FractionBox[a_, b_]] := boxToCode[a] <> "/" <> boxToCode[b]
boxToCode[SqrtBox[a_]] := "Sqrt[" <> boxToCode[a] <> "]"
boxToCode[SubscriptBox[a_, b_]] := "Subscript[" <> boxToCode[a] <> ", " <> boxToCode[b] <> "]"
boxToCode[SuperscriptBox[a_, b_]] := boxToCode[a] <> "^" <> boxToCode[b]
boxToCode[SubsuperscriptBox[a_, b_, c_]] := boxToCode[a] <> "_" <> boxToCode[b] <> "^" <> boxToCode[c]
boxToCode[OverscriptBox[a_, _]] := boxToCode[a]
boxToCode[FormBox[b_, ___]] := walkerMath[b]
boxToCode[InterpretationBox[disp_, ___]] := boxToCode[disp]
boxToCode[TagBox[disp_, ___]] := boxToCode[disp]
boxToCode[StyleBox[disp_, ___]] := boxToCode[disp]
boxToCode[TemplateBox[{x_}, "Ket"]] := "|" <> boxToCode[x] <> "\[RightAngleBracket]"
boxToCode[TemplateBox[{x_}, "Bra"]] := "\[LeftAngleBracket]" <> boxToCode[x] <> "|"
boxToCode[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] :=
    "\[LeftAngleBracket]" <> boxToCode[x] <> "|" <> boxToCode[y] <> "\[RightAngleBracket]"
boxToCode[other_] := ToString[other, InputForm]

(* === inline emphasis wrapper ===
   wrap a markdown run in italic / bold asterisk markers, but NOT when it is
   punctuation / bracket only (italicising "]" gives a stray "*]*"), and NOT
   when it is already wrapped at the same level. *)
emWrap[s_String, mark_String] := Which[
    s === "" || StringMatchQ[s, (PunctuationCharacter | WhitespaceCharacter | "[" | "]" | "{" | "}" | "(" | ")") ..], s,
    StringMatchQ[s, mark ~~ Except["*"] .. ~~ mark], s,
    True, mark <> s <> mark
]

(* === string cleaner for inline captions ===
   A placeholder string in an authoring nb is stored as front-end linear syntax:
   "<PUA \!\(\*>StyleBox["x", "TI"]<PUA \)>". The \! \( \* \) markers are
   private-use characters; convert StyleBox["x","TI"] -> *x*, SubscriptBox ->
   $_{}$ etc., then drop the PUA markers and map formal/script/etc. glyphs.
   Do NOT put the raw linear-syntax form in this source: Get would parse it
   back into boxes. *)
dq[s_String] := StringTrim[StringTrim[StringTrim[s], "\""], "()" | "(" | ")"]
mathDq[x_String] := StringReplace[dq[x], Normal @ $mathTeX]
cleanStr[s_String] := normStr @ StringReplace[stripStructPUA[s], {
    "StyleBox[\"" ~~ Shortest[v__] ~~ "\", \"TI\"]" :> "*" <> v <> "*",
    "DisplayForm[StyleBox[" ~~ Shortest[v__] ~~ ", TI]]" :> "*" <> v <> "*",
    "StyleBox[" ~~ Shortest[v__] ~~ ", TI]" :> "*" <> v <> "*",
    "SubsuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ ", " ~~ Shortest[c__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}^{" <> mathDq[c] <> "}$",
    "SubscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}$",
    "SuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "^{" <> mathDq[b] <> "}$"
}]

(* === plain text extractor (titles, ObjectName, sectionTitle) === *)
cellPlain[s_String] := normStr[s]
cellPlain[TextData[xs_List]] := StringJoin[cellPlain /@ xs]
cellPlain[TextData[x_]] := cellPlain[x]
cellPlain[c_Cell] /; decorationCellQ[c] := ""
cellPlain[Cell[c_, ___]] := cellPlain[c]
cellPlain[BoxData[b_]] := boxToCode[b]
cellPlain[StyleBox[s_, ___]] := cellPlain[s]
cellPlain[ButtonBox[n_String, ___]] := n
cellPlain[_] := ""

(* === signature serialiser ===
   A Usage call box "Sym[...]" renders to <code>[Sym]()[*x*, *y*]</code>:
     - a Link ButtonBox -> [Name]()
     - the head bare identifier of a call -> [Name]() (linked)
     - an italic (TI) string arg -> *arg*
     - a subscript -> $base_{i}$ (canonical inline math, base INSIDE the math:
       MarkdownToNotebook's mathArgsToTemplate round-trips this to a clean
       subscript; the looser *base*$_i$ form round-trips broken)
     - operators / brackets / commas / arrows pass literally. *)
sig[s_String] := cleanStr[s]
sig[bb_ButtonBox] := "[" <> cellPlain[bb[[1]]] <> "]()"
sig[StyleBox[s_String, "TI", ___]] := emWrap[normStr[s], "*"]
sig[StyleBox[s_, ___]] := sig[s]
sig[SubscriptBox[a_, b_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}$"
sig[SuperscriptBox[a_, b_]] := "$" <> sigSub[a] <> "^{" <> sigSub[b] <> "}$"
sig[SubsuperscriptBox[a_, b_, c_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}^{" <> sigSub[c] <> "}$"
sig[FractionBox[a_, b_]] := sig[a] <> "/" <> sig[b]
sig[RowBox[xs_List]] := If[
    MatchQ[xs, {_String, "[", ___}] && StringMatchQ[First[xs], LetterCharacter ~~ (WordCharacter | "$") ...],
    "[" <> First[xs] <> "]()" <> StringJoin[sig /@ Rest[xs]],
    StringJoin[sig /@ xs]]
sig[FormBox[b_, ___]] := sig[b]
sig[f_Symbol] := SymbolName[f]
sig[other_] := normStr @ boxToCode[other]
sigSub[StyleBox[s_, ___]] := sigSub[s]
sigSub[s_String] := StringReplace[normStr[s], Normal @ $mathTeX]
sigSub[RowBox[xs_List]] := StringJoin[sigSub /@ xs]
sigSub[x_] := walkerMath[x]
sigBox[x_] := sig[x]

(* does a box tree carry 2D math structure (so it should render as $...$, not `code`)? *)
mathyQ[b_] := ! FreeQ[b, _SubscriptBox | _SuperscriptBox | _SubsuperscriptBox |
    _FractionBox | _SqrtBox | _RadicalBox | _OverscriptBox | _UnderscriptBox | _FormBox |
    TemplateBox[_, "Ket" | "Bra" | "Braket" | "BraKet" | "SuperDagger" | "Dagger" | "Conjugate"]]

(* a non-Link call box (Sym[...], "name"[...], *circ*[...]) is a SIGNATURE, not
   a formula, so it should render as <code> even without a Link BaseStyle.
   Guard out heavy-math boxes so a functional-form formula (e.g. Tr[Sqrt[...]])
   stays $...$. A code signature is sometimes authored inside a TraditionalForm
   FormBox; unwrap so it still routes to <code> rather than $...$ math (where
   literal {} / [] would become invisible TeX grouping). *)
sigCallBoxQ[RowBox[{h_, "[", ___}] ? (FreeQ[#, SqrtBox | FractionBox | RadicalBox | UnderoverscriptBox] &)] :=
    MatchQ[h, _Symbol | _String | StyleBox[_, "TI", ___]]
sigCallBoxQ[FormBox[b_, ___]] := sigCallBoxQ[b]
sigCallBoxQ[_] := False

(* === inline TextData -> markdown text ===
   Patterns mirror the forward parser's inlineTextData output so a round trip
   preserves formatting choices. *)
inlineMd[s_String] := cleanStr[s]
inlineMd[c_Cell] /; decorationCellQ[c] := ""

(* StyleBox: TI-wrapped subscript/superscript becomes canonical inline math
   (the most-specific cases win pattern dispatch); a TI / TB wrap becomes
   italic / bold; a "Code" wrap is a code span. *)
inlineMd[StyleBox[SubscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "_{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[SuperscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "^{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[s_, "TI", ___]] := emWrap[inlineMd[s], "*"]
inlineMd[StyleBox[s_, "Code", ___]] := "`" <> boxToCode[s] <> "`"
inlineMd[StyleBox[s_, opts___]] := With[{styles = {opts}, inner = inlineMd[s]},
    Which[
        MemberQ[styles, FontSlant -> "Italic"], emWrap[inner, "*"],
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
(* a generic ButtonBox - the FE often wraps the label in a StyleBox/RowBox and
   may give BaseStyle a Dynamic mouse-over. Treat it as an inferred symbol link. *)
inlineMd[bb_ButtonBox] := "[" <> cellPlain[bb[[1]]] <> "]()"

(* An InlineFormula cell wraps either a FormBox (typeset math from a "$...$"
   span), a Link/call box (a "`Symbol`" or call-form signature), a 2D math
   tree, or a plain WL box tree. Dispatch on the shape so a signature renders
   as <code>[Sym]()[...]</code>, real math as $math$, and a plain backticked
   code-span as `code`. *)
inlineMd[Cell[BoxData[FormBox[b_, ___]], "InlineFormula", ___]] := "$" <> walkerMath[b] <> "$"
inlineMd[Cell[BoxData[StyleBox[s_, "TI", ___]], "InlineFormula", ___]] :=
    If[mathyQ[s], "$" <> walkerMath[s] <> "$", "*" <> boxToCode[s] <> "*"]
inlineMd[Cell[BoxData[ButtonBox[a___]], "InlineFormula", ___]] := inlineMd[ButtonBox[a]]
inlineMd[Cell[BoxData[TagBox[bb_ButtonBox, ___]], "InlineFormula", ___]] := inlineMd[bb]
inlineMd[c0 : Cell[BoxData[b_], "InlineFormula", ___]] /; ! decorationCellQ[c0] := Which[
    ! FreeQ[b, BaseStyle -> "Link" | "Hyperlink"], "<code>" <> sigBox[b] <> "</code>",
    sigCallBoxQ[b], "<code>" <> sigBox[b] <> "</code>",
    mathyQ[b], "$" <> walkerMath[b] <> "$",
    True, With[{c = cleanStr[boxToCode[b]]},
        (* a styled-string placeholder ("name" with TI) cleans to contain *...*;
           emit as bare italic prose, not a backtick code span (asterisks don't
           render in code). *)
        If[StringContainsQ[c, "*"], c, "`" <> c <> "`"]]
]

(* a generic BoxData wrapper in a Cell: unwrap a nested Cell, route call-form
   to <code>, 2D math to $...$, otherwise emit as inline code. *)
inlineMd[c0 : Cell[BoxData[b_], ___]] /; ! decorationCellQ[c0] :=
    Which[
        MatchQ[b, _Cell], inlineMd[b],
        sigCallBoxQ[b], "<code>" <> sigBox[b] <> "</code>",
        mathyQ[b], "$" <> walkerMath[b] <> "$",
        True, "`" <> boxToCode[b] <> "`"
    ]
inlineMd[BoxData[b_]] := If[mathyQ[b], "$" <> walkerMath[b] <> "$", "`" <> boxToCode[b] <> "`"]

(* TraditionalForm / StandardForm math at the inline level. *)
inlineMd[FormBox[box_, TraditionalForm | StandardForm, ___]] :=
    "$" <> walkerMath[box] <> "$"
inlineMd[FractionBox[a_, b_]] := "$" <> walkerMath[a] <> "/" <> walkerMath[b] <> "$"
inlineMd[SubscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "_" <> walkerMath[b] <> "$"
inlineMd[SuperscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "^" <> walkerMath[b] <> "$"
inlineMd[SqrtBox[a_]] := "$\\sqrt{" <> walkerMath[a] <> "}$"
inlineMd[OverscriptBox[a_, "^"]] := "$\\hat{" <> walkerMath[a] <> "}$"

(* nested cells (a doc table cell can wrap its prose several Cells deep:
   Cell[TextData[Cell[BoxData[Cell[TextData[...],"TableText"]]]]]). Recurse into
   the content instead of letting boxToCode ToString-dump the inner Cell:
   a TEXT cell (TextData / String content) -> unwrap to its content. *)
inlineMd[c0 : Cell[content : (_TextData | _String), _String, ___]] /; ! decorationCellQ[c0] := inlineMd[content]

inlineMd[RowBox[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[x_]] := inlineMd[x]
inlineMd[TagBox[x_, ___]] := inlineMd[x]
inlineMd[InterpretationBox[x_, ___]] := inlineMd[x]
inlineMd[other_] := ToString[other, InputForm]

(* === faithful Input code via FE InputText, with a kernel-only fallback ===
   The front end's "InputText" export packet gives the verbatim typed source of
   a Cell, preserving subscripts (a_1), `@`, `//`, `[[…]]`, `%`, the author's
   spacing, and 2D box content as their linear-syntax equivalents - faithful to
   what the user typed. CallFrontEnd needs a live FE link, so the public entry
   wraps the whole walk in UsingFrontEnd. When that fails (no FE reachable,
   e.g. a minimal Notebook[] handed in directly with no kernel-FE link), fall
   back to a pure-kernel boxToCode tree walk so the walker still produces
   output, just less faithful for exotic 2D code shapes. *)
feInputText[bd_] := Module[{r},
    r = MathLink`CallFrontEnd[FrontEnd`ExportPacket[Cell[bd, "Input"], "InputText"]];
    StringTrim @ If[MatchQ[r, {_String, ___}], First[r], ToString[r]]
]
codeText[bd : BoxData[b_]] := Module[{r},
    r = Quiet @ Check[feInputText[bd], $Failed];
    If[StringQ[r] && r =!= "", r, boxToCode[b]]
]
codeText[c : Cell[BoxData[b_], ___]] := codeText[BoxData[b]]
codeText[s_String] := s
codeText[other_] := boxToCode[other]

(* === per-cell builders === *)

(* clean caption whitespace (newlines -> space, collapse) *)
tidy[s_String] := StringTrim @ StringReplace[s, {"\n" -> " ", "\r" -> " ", Whitespace -> " "}]

(* the Usage cell: split the TextData on ModInfo separators - the doc template's
   actual statement boundaries - into one paragraph per usage statement. Splitting
   on ModInfo (not on every signature-like element) keeps an inline symbol
   reference inside a description from being mistaken for a new statement. *)
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

(* ExampleSection wraps its title in an InterpretationBox counter cell;
   ExampleSubsection / Subsubsection store the title string directly. *)
sectionTitle[content_] := Module[{inner},
    inner = FirstCase[content, Cell[t_, _String, ___] :> t, $noInner, Infinity];
    cellPlain @ If[inner === $noInner, content, inner]
]

(* GridBox rows -> pipe table; drop ModInfo spacer columns. The left "spec"
   column of a doc table is the literal thing you type, so a bare-string spec
   ("Bell") and a subscript-free call-form spec ("Graph"[g]) both render as
   inline code so the spec column is uniform. A spec carrying a 2D subscript
   ("Multiplexer"[op_1,...]) can't live in a code span (backticking would
   linearise op_1 to the literal text Subscript[op, 1]), so it renders as a
   signature with canonical $op_{1}$ math instead. *)
spacerQ[Cell[s_String, "ModInfo", ___]] := StringMatchQ[s, Whitespace | ""]
spacerQ[_] := False
gridCellMd[s_String] := "`" <> StringTrim[s] <> "`"
gridCellMd[Cell[t_, "TableText", ___]] := tidy @ inlineMd[t]
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

(* Styles a walker should skip entirely:
     - evaluation artifacts (Output / Message / MSG / Print): regenerate on re-run
     - template metadata cells (Categorization, Keywords, SeeAlso, MoreAbout,
       ...): the frontmatter recovery (below) reads these directly; emitting
       them as prose would duplicate the YAML
     - template decoration (MoreInfoText / DockedCell / *CellLabel / *Flag):
       inserted by the front end for the resource authoring UI, never in source *)
$dropStyles = {
    "Output", "Message", "MSG", "Print", "ExampleInitialization",
    "ModInfo", "MoreInfoText", "MoreInfoTextOuter",
    "DockedCell",
    "ExcludedCellLabel", "HiddenMaterialCellLabel",
    "FutureFlag", "ExcisedFlag", "ObsoleteFlag", "TemporaryFlag", "PreviewFlag", "InternalFlag",
    "Categorization", "CategorizationSection",
    "Keywords", "KeywordsSection",
    "Template", "TemplatesSection",
    "History", "HistoryData",
    "TechNotesSection", "Tutorials",
    "RelatedDemonstrations", "RelatedDemonstrationsSection",
    "RelatedLinks", "RelatedLinksSection",
    "SeeAlso", "SeeAlsoSection",
    "MoreAbout", "MoreAboutSection",
    "ExtendedExamplesSection", "ExamplesInitializationSection"
}

ClearAll[blockFor]
(* Image cells (raster or vector graphics in BoxData) are evaluation output, not
   source - the markdown twin embeds them as ![]() but the source markdown that
   produced them is the WL Input cell that evaluated to them. Drop. The TagBox
   wrapping covers the FE's "Image Placeholder" cell, which the resource
   templates inject under "Hero Image" / similar slots and is not authored. *)
blockFor[_, BoxData[(GraphicsBox | Graphics3DBox | RasterBox)[___]]] := ""
blockFor[_, BoxData[TagBox[(GraphicsBox | Graphics3DBox | RasterBox)[___], ___]]] := ""

(* Top-level headings. A doc template puts the function name in an ObjectName
   cell; frontmatter recovery emits it as `Name:`, so the cell itself drops. *)
blockFor["Title", c_] := "# " <> cellPlain[c]
blockFor["Section", c_] := "## " <> cellPlain[c]
blockFor["Subsection", c_] := "### " <> cellPlain[c]
blockFor["Subsubsection", c_] := "#### " <> cellPlain[c]
blockFor["ObjectName", _] := ""

(* Usage / Notes / property tables - the doc template's headings are implicit,
   so we emit the corresponding `##` / `- ` markers ourselves. The "## Details
   & Options" header fires once before the first Notes block so the section
   round-trips through MarkdownToNotebook (which maps that heading back to the
   Notes slot). *)
blockFor["Usage", c_] := "## Usage\n\n" <> usageMd[c]
blockFor["UsageDescription", c_] := tidy @ inlineMd[c]
blockFor["Notes", c_] := With[{b = "- " <> tidy @ inlineMd[c]},
    If[TrueQ[$detailsHeadingDone], b,
        $detailsHeadingDone = True; "## Details & Options\n\n" <> b]]
blockFor["2ColumnTableMod" | "3ColumnTableMod" | "TableNotes", BoxData[GridBox[rows_List, ___]]] := gridTable[rows]
blockFor["2ColumnTableMod" | "3ColumnTableMod", c_] := tidy @ inlineMd[c]

(* Prose styles. *)
blockFor["Text" | "Quote", c_] := tidy @ inlineMd[c]
blockFor["Caption", c_] := tidy @ inlineMd[c]
blockFor["ExampleText" | "CodeText", c_] := tidy @ inlineMd[c]

(* Lists. *)
blockFor["Item" | "Item1" | "Item2" | "Bullet", c_] := "- " <> tidy @ inlineMd[c]
blockFor["ItemNumbered" | "ItemNumbered1", c_] := "1. " <> tidy @ inlineMd[c]

(* Code cells: verbatim Input source via FE InputText (with kernel fallback).
   The fence length is one greater than the longest run of backticks in the
   cell body so an example showing ` ``` ` fences inside its source doesn't
   break the surrounding fence. Program cells emit with NO language tag - the
   .nb has no record of the original fence language (a `text` / `ebnf` / etc.
   fence becomes Program-styled the same as a `#| eval: false` wl cell), so we
   stay neutral: a no-lang fence round-trips back through MTN as Program. *)
codeFence[text_String] := Module[{maxRun = 2},
    Scan[(If[StringLength[#] > maxRun, maxRun = StringLength[#]]) &,
        StringCases[text, "`" ..]];
    StringRepeat["`", Max[3, maxRun + 1]]
]
fencedCode[txt_String, lang_String] := With[{f = codeFence[txt]},
    f <> lang <> "\n" <> txt <> "\n" <> f]
blockFor["Input" | "Code" | "ExampleInput", c_] := fencedCode[codeText[c], "wl"]
blockFor["Program", c_] := fencedCode[codeText[c], ""]

(* Example-section scaffold (the resource template's nested example structure). *)
blockFor["PrimaryExamplesSection", _] := "## Basic Examples"
blockFor["ExampleSection", c_] := "## " <> sectionTitle[c]
blockFor["ExampleSubsection", c_] := "### " <> sectionTitle[c]
blockFor["ExampleSubsubsection", c_] := "#### " <> sectionTitle[c]
blockFor["ExampleDelimiter", _] := "---"

(* InlineFormula at block level (rare; normally inlined). *)
blockFor["InlineFormula", c_] := "`" <> tidy @ inlineMd[c] <> "`"

(* Drop known-decoration / evaluation / metadata styles. *)
blockFor[s_String, _] /; MemberQ[$dropStyles, s] := ""

(* Generic fallback: any unknown style is treated as prose. *)
blockFor[_String, c_] := tidy @ inlineMd[c]

(* === tree walk === *)
walkCell[Cell[CellGroupData[inner_List, ___]]] := walkCells[inner]
walkCell[Cell[content_, style_String, opts___]] := blockFor[style, content]
walkCell[_] := ""
walkCells[cells_List] := DeleteCases[Flatten[{walkCell /@ cells}], "" | Null]

(* === frontmatter recovery ===
   For doc-page notebooks (Symbol / Guide / TechNote authoring templates), the
   metadata that would have been YAML frontmatter lives in dedicated cells the
   walker drops as content (Categorization / Keywords / SeeAlso / MoreAbout).
   Recover it as a leading `---` block so the markdown twin is rebuildable.
   When the notebook has no Categorization cells (it isn't a doc template), the
   block is omitted and the walker emits a bare body, matching the historical
   behaviour for arbitrary notebooks. *)
catList[nb_] := Flatten @ Cases[nb, Cell[c_, "Categorization", ___] :> Cases[{c}, _String, Infinity], Infinity]
linkNames[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[n_String, ___] :> n, Infinity]
guideIds[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[_, ___, ButtonData -> d_String, ___] :> Last[StringSplit[d, "/"]], Infinity]
keywordList[nb_] := Flatten @ Cases[nb, Cell[c_, "Keywords", ___] :> Cases[{c}, _String, Infinity], Infinity]

(* Symbol-page templates carry an ObjectName cell (the function name) and a
   Categorization cell (entity type / paclet / context / URI). When both are
   present we emit a Symbol-template frontmatter the forward path can rebuild
   the doc-tools authoring notebook from. Other templates (FunctionResource,
   Data, TechNote, Demonstration, ...) have their own metadata in cells we
   don't currently round-trip; emit no frontmatter so the recovered .md
   round-trips as a generic body and the forward path is the one that has to
   be told the template via a hand-added frontmatter block. *)
hasObjectNameQ[nb_] := ! FreeQ[nb, Cell[_, "ObjectName", ___]]

frontmatter[nb_, name_] := Module[{cat, paclet, ctx, uri, kw, sa, rg},
    If[! hasObjectNameQ[nb], Return[""]];
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
        "---\n\n"
    ]
]

(* === post-process: drop empty heading-only sections ===
   A heading-only block is "## Title" on a single line. A block that bakes
   content after its heading (e.g. "## Usage\n\n<sig>...") contains a newline
   and is NOT heading-only, so dropEmptySections never mistakes it for an empty
   section. A heading is empty only if the next block is a heading of the same
   or higher level (a sibling / parent section), or end of document; a deeper
   following subsection is content. *)
headingQ[s_String] := StringMatchQ[s, ("#" ..) ~~ " " ~~ Except["\n"] ...]
headingLevel[s_String] := StringLength @ First @ StringCases[s, StartOfString ~~ h : ("#" ..) :> h]
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

(* === core: a Notebook -> faithful literate markdown ===
   Doc-page templates (recognised by the presence of Categorization cells)
   carry a fixed sequence of placeholder sections; their unused sections show
   up as bare `## Title` blocks with no following content, which we drop.
   For an arbitrary notebook a trailing heading IS authored content, so the
   drop pass only runs when a doc-page frontmatter is being emitted. *)
markdownOfNb[nb : Notebook[_List, ___]] := Block[{name, blocks, fm, $detailsHeadingDone = False},
    name = cellPlain @ FirstCase[nb, Cell[t_, "ObjectName", ___] :> t, "", Infinity];
    blocks = walkCells[First[nb]];
    fm = frontmatter[nb, name];
    If[fm =!= "", blocks = dropEmptySections[blocks]];
    fm <> StringRiffle[blocks, "\n\n"] <> "\n"
]

(* === public entry === *)
NotebookToMarkdown[nb : Notebook[_List, ___]] := UsingFrontEnd @ markdownOfNb[nb]
NotebookToMarkdown[nbo_NotebookObject] := UsingFrontEnd @ markdownOfNb[NotebookGet[nbo]]
NotebookToMarkdown[file_String /; FileExistsQ[file] && StringEndsQ[ToLowerCase[file], ".nb"]] :=
    UsingFrontEnd @ markdownOfNb[Get[file]]
NotebookToMarkdown[source_, "String"] := NotebookToMarkdown[source]
NotebookToMarkdown[source_, target_String /; StringEndsQ[ToLowerCase[target], ".md"]] := Block[
    {md = NotebookToMarkdown[source]},
    Export[target, md, "Text"];
    target
]
```

## Usage

<code>[NotebookToMarkdown]()[*nb*]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html), or a `.nb` file path).

<code>[NotebookToMarkdown]()[*nb*, "*file*.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook](https://reference.wolfram.com/language/ref/Notebook.html) expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html) open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Caption` / `Quote` / `ExampleText` / `CodeText` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` / `ExampleInput` to ```` ```wl ... ``` ```` fenced blocks; `Program` cells (`#| eval: false`, or non-`wl` fenced source) to a no-language fenced block; `Output` / `Message` / `Print` are skipped (they regenerate on re-conversion).
- The doc-template scaffolding cells - the `Usage` slot, `Notes`, `2ColumnTableMod` / `3ColumnTableMod` property tables, `ExampleSection` / `Subsection` titles, the `PrimaryExamplesSection` opener - all round-trip with their template-implied markdown shape: `## Usage`, `## Details & Options`, a pipe-table per `*TableMod`, `## Basic Examples`, etc.
- **Frontmatter is recovered** when the notebook carries an `ObjectName` cell (the Symbol-template marker): the `Categorization` / `Keywords` / `SeeAlso` / `MoreAbout` cells feed a YAML block at the top of the output, so a shipped reference page round-trips to a rebuildable literate-markdown twin. Notebooks without an `ObjectName` cell (an arbitrary `.nb`) get no frontmatter, just the body.
- **Code cells are verbatim** when a front end is available: the implementation calls the FE's `InputText` export packet so subscripts, `@`, `//`, `[[…]]`, `%`, and 2D-box content survive as their linear-syntax forms. Without a FE the walker falls back to a kernel-only `boxToCode` tree walk - still faithful for plain WL but less so for exotic 2D shapes. Either way the cell text wraps in a fence whose backtick run is one longer than the longest backtick run inside the cell body, so a cell that shows a ` ``` ` fence inside its own source still produces valid markdown.
- **Signature recovery.** An `InlineFormula` cell whose box tree is a call form (`Sym[...]`, an inferred-link `ButtonBox`) renders as <code>[Sym]()[*x*, *y*]</code> - a clickable head with code styling, italic args, subscripts as canonical inline math (`$obj_{i}$`, the form [MarkdownToNotebook]()'s forward parser round-trips to a clean subscript). 2D math without a call shape renders as `$math$` with Greek letters and operators mapped to their TeX commands (`\theta`, `\pi`, `\dagger`, `\cdot`).
- **Empty placeholder sections** (a doc-template `## Properties & Relations` heading with no following content) are dropped from the output when frontmatter is being emitted, matching MarkdownToNotebook's forward-path behaviour. For an arbitrary notebook every heading is kept.
- **Round-trip contract for signatures**: subscripted arguments emit as `$obj_{i}$` (base inside the math). The looser `*obj*$_i$` form (italic base plus a separate `$_i$`) renders fine raw but round-trips broken through MTN, so the walker never emits it.

## Basic Examples

Walk a small notebook and recover the markdown body:

```wl
NotebookToMarkdown @ Notebook[{
    Cell["Demo", "Title"],
    Cell["A paragraph.", "Text"],
    Cell[BoxData["Range[5]^2"], "Input"]
}]
```

![output](images/NotebookToMarkdown-out-1.png)

---

Recover a shipped reference page (a `Symbol` / `Guide` / `TechNote` authoring notebook) as a rebuildable literate-markdown twin:

```wl
NotebookToMarkdown[
    "/path/to/Documentation/English/ReferencePages/Symbols/MyFn.nb",
    "/path/to/MyFn.md"
]
```

## Scope

A `.nb` file path is read via `Get` and converted the same way as the in-memory `Notebook[…]` form. Round-trip an authored notebook through disk to demonstrate:

```wl
With[{tmp = FileNameJoin[{$TemporaryDirectory, "ntm-scope-demo.nb"}]},
    Put[Notebook[{Cell["Demo", "Title"], Cell["A paragraph.", "Text"], Cell[BoxData["Range[5]^2"], "Input"]}], tmp];
    NotebookToMarkdown[tmp]
]
```

![output](images/NotebookToMarkdown-out-2.png)

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - cell `#|` options are not recovered, fenced-block language tags for non-`wl` fences are lost (the .nb cell only remembers it's `"Program"` styled, not the original language), and the FE may have introduced decorative cells the walker filters out - but feeding the walker's output back through the forward path produces an equivalent notebook.

## Possible Issues

- Frontmatter is recovered only when the notebook has an `ObjectName` cell (the Symbol-template marker). A FunctionResource / Data / TechNote / Demonstration notebook walks to a bare body; add the `Template:` / `Name:` / etc. block back by hand if you need a rebuildable twin.
- The fenced-block language tag is lost for non-`wl` fences (a `text` / `ebnf` / `python` block becomes a Program-styled cell in the .nb, which walks back to a no-language fence). The block round-trips structurally but the syntax-highlighting hint doesn't.
- The faithful Input recovery uses the front end's `InputText` packet. In a session with no FE link available, the walker falls back to a kernel-only `boxToCode` tree walk; the cell still recovers, but subscripts, the `@` / `//` shorthand, and other 2D-input niceties are returned in their box-source rather than the typed form.

## Neat Examples

A round-trip smoke test: forward, walk, forward again, and check the second forward run produces a notebook whose Input cells (by reconstructed source text, normalised) match the first:

```wl
With[{md = "# Demo\n\n## Section\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n"},
    Module[{nb1, md2, nb2, normWS, sourceTexts},
        nb1 = MarkdownToNotebook[md, "Evaluate" -> False];
        md2 = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[md2, "Evaluate" -> False];
        normWS[s_String] := StringDelete[StringReplace[s, "\\\n" -> ""], Whitespace];
        sourceTexts[nb_] := normWS @ boxToCode[#] & /@
            Cases[nb, Cell[BoxData[b_], "Input" | "Code" | "ExampleInput" | "Program", ___] :> b, Infinity];
        sourceTexts[nb1] === sourceTexts[nb2]
    ]
]
```

![output](images/NotebookToMarkdown-out-3.png)

## Tests

Each `wl` cell in this section is an explicit `VerificationTest[code, expected, TestID -> …]` expression that becomes one Input cell in the resource's `VerificationTests` slot (the docked *Run Tests* button evaluates them). The repo's `tests.wls` scrapes this section and runs the same assertions out-of-band, so the in-notebook button and the CI script share a single source of truth.

An `InlineFormula` cell wrapping a `FormBox` is emitted as `$math$`, not as a backticked code span, and in math mode a Wolfram Greek glyph becomes its canonical TeX command (`\[Theta]` -> `\theta`, not a raw Unicode `θ`) so the output is valid TeX rather than a literal codepoint (regression: the previous handler both wrapped every `InlineFormula` content in backticks, giving ``` `$θ$` ``` with extra delimiters, and left the Greek letter as Unicode):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[TextData[{"angle ", Cell[BoxData[FormBox["\[Theta]", TraditionalForm]], "InlineFormula"]}], "Text"]
        }],
        "$\\theta"
    ],
    True,
    TestID -> "InlineFormula+FormBox -> $math$ (no backticks)"
]
```

The named math constants `\[ExponentialE]`, `\[ImaginaryI]`, `\[ImaginaryJ]`, `\[DifferentialD]`, `\[CapitalDifferentialD]` occupy the same private-use band as the FE structural markers the converter drops, but they are content. They map to plain ASCII (`e`, `i`, `j`, `d`, `D`) before that drop, so a `SuperscriptBox["\[ExponentialE]", …]` keeps its base instead of collapsing to an orphan `$^{…}$` (regression: `e^{i 2 π λ}` rendered as a bare superscript `^{2 π λ}` with the base `e` and exponent `i` silently deleted):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"in the form ", Cell[BoxData[
            SuperscriptBox["\[ExponentialE]", RowBox[{"\[ImaginaryI]", " ", "2", "\[Pi]", " ", "\[Lambda]"}]]],
            "InlineFormula"]}], "Text"]
    }]},
        StringContainsQ[md, "$e^{i"] && StringContainsQ[md, "\\pi"] &&
            StringContainsQ[md, "\\lambda"] && ! StringContainsQ[md, "$^{"]
    ],
    True,
    TestID -> "math constants \[ExponentialE]/\[ImaginaryI] survive in a SuperscriptBox"
]
```

The left "spec" column of a doc table is the literal thing you type, so a subscript-free call-form (`"Graph"[g]`) renders as inline code just like a bare-string entry (`"Bell"`) - no mix of code-styled pill and plain text. A code span cannot hold a 2D subscript, though: a subscript-bearing spec (`"Multiplexer"[op_1,op_2,…]`) is rendered as a signature with canonical `$op_{1}$` math instead, which shows a real subscript and round-trips back to the `SubscriptBox` (backticking it would linearize `op_1` to the literal text `Subscript[op, 1]`):

```wl
VerificationTest[
    {
        gridCellMd["\"Bell\""],
        gridCellMd[RowBox[{"\"Graph\"", "[", StyleBox["g", "TI"], "]"}]],
        gridCellMd[RowBox[{"\"Mux\"", "[", SubscriptBox[StyleBox["op", "TI"], "1"], "]"}]]
    },
    {"`\"Bell\"`", "`\"Graph\"[g]`", "\"Mux\"[$op_{1}$]"},
    TestID -> "table spec column: simple specs inline-code, subscript specs canonical $math$"
]
```

A code cell's original surface layout is preserved by walking the `BoxData` tree directly - so a multi-statement Input cell with literal `"\n"` separators round-trips with its line breaks intact (regression: an earlier `MakeExpression`-based deparse choked on multi-statement boxes and fell back to literal `RawBoxes[RowBox[…]]` output):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[BoxData[RowBox[{RowBox[{"a", " ", "=", " ", "1"}], ";", "\n", RowBox[{"b", " ", "=", " ", "2"}], ";"}]], "Input"]
        }],
        "a = 1;\nb = 2;"
    ],
    True,
    TestID -> "multi-statement Input cell preserves the \"\\n\" between statements"
]
```

Decoration cells the resource template injects are silently dropped - the help-bubble opener that sits inside a heading's `TextData` is a `Cell[BoxData[PaneSelectorBox[…]]]`, never authored content, so the recovered heading is just the title (regression: the opener leaked through as raw box source jammed onto the heading line):

```wl
VerificationTest[
    StringTrim @ NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"Caption", Cell[BoxData[PaneSelectorBox[{True -> "x"}, Dynamic[True]]], "Section"]}], "Section"]
    }],
    "## Caption",
    TestID -> "drops MoreInfoOpener-shaped decoration cells from heading TextData"
]
```

A code signature authored inside a TraditionalForm `FormBox` renders as a `<code>` span, not `$math$` - in math mode its literal `{}`/`[]` would be invisible TeX grouping (braces vanish) and the code would show italic (regression: a `QuantumEvolve[H,{L1,...},...]` signature wrapped in a FormBox lost its list braces and rendered as big italic math):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"have ", Cell[BoxData[FormBox[RowBox[{"Foo", "[", RowBox[{"a", ",", "b"}], "]"}], TraditionalForm]]], " only"}], "Text"]
    }]},
        StringContainsQ[md, "<code>"] && ! StringContainsQ[md, "$Foo"]
    ],
    True,
    TestID -> "code signature in FormBox renders as <code>, not $math$"
]
```
