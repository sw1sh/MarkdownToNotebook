(* MarkdownToNotebook - convert a literate-markdown document into a Wolfram
   notebook, choosing the layout from a template.

   The source can be a local file path, an http(s) URL, or a raw markdown
   string. The Template frontmatter key selects a registry entry:
     FunctionResource - fill the slots of the official Function Repository
        definition template (its stylesheet and docked Deploy/Submit toolbar
        are preserved), so the .nb is publishable as-is.
     Symbol, Guide - fill the DocumentationTools authoring templates.
     Default - map headings and code directly to standard notebook styles.
   Frontmatter drives metadata; the Definition section is the code; example
   sections become evaluated + cached Input/Output cells.

   Deliberately plain top-level definitions (no BeginPackage): the converter
   Gets this file into a freshly generated private context so converting a
   document cannot clobber the live definition doing the converting. *)

Needs["GeneralUtilities`"]

mdSep = "\n(*--cell--*)\n"

(* === frontmatter === *)

stripQuotes[s_String] := StringReplace[StringTrim[s], {
    StartOfString ~~ "\"" ~~ v___ ~~ "\"" ~~ EndOfString :> v,
    StartOfString ~~ "'" ~~ v___ ~~ "'" ~~ EndOfString :> v
}]

(* split a bracketed list body on commas that are not inside double quotes, so a
   quoted item (e.g. a citation) keeps its internal commas *)
splitListItems[s_String] := Block[{acc = {}, cur = "", inQ = False},
    Do[
        Which[
            c === "\"", inQ = ! inQ; cur = cur <> c,
            c === "," && ! inQ, AppendTo[acc, cur]; cur = "",
            True, cur = cur <> c
        ],
        {c, Characters[s]}
    ];
    Append[acc, cur]
]

parseFmValue[s_String] := Block[{t = StringTrim[s]},
    Which[
        StringMatchQ[t, "[" ~~ ___ ~~ "]"],
            stripQuotes /@ Select[StringTrim /@ splitListItems[StringTake[t, {2, -2}]], # =!= "" &]
        ,
        MemberQ[{"true", "false"}, ToLowerCase[t]],
            ToLowerCase[t] === "true"
        ,
        True,
            stripQuotes[t]
    ]
]

yamlLine[line_String] := Block[{parts = StringSplit[line, ":", 2]},
    StringTrim[First[parts]] -> parseFmValue[Last[parts]]
]

parseYamlish[lines_List] := Association @ Map[yamlLine, Select[lines, StringContainsQ[#, ":"] &]]

extractFrontmatter[text_String] := Block[{lines, close},
    lines = StringSplit[text, "\n"];
    If[ lines === {} || StringTrim[First[lines]] =!= "---",
        Return[{<||>, text}]
    ];
    close = SelectFirst[Range[2, Length[lines]], StringTrim[lines[[#]]] === "---" &, 0];
    If[ close === 0,
        Return[{<||>, text}]
    ];
    {parseYamlish[lines[[2 ;; close - 1]]], StringRiffle[lines[[close + 1 ;;]], "\n"]}
]

(* === block parsing === *)

fenceQ[line_String] := StringMatchQ[StringTrim[line], "```" ~~ ___]

headingQ[line_String] := StringMatchQ[line, ("#" ..) ~~ " " ~~ ___]

headingBlock[line_String] := Block[{hashes},
    hashes = First @ StringCases[StringTrim[line], StartOfString ~~ h : ("#" ..) :> h];
    <|
        "Type" -> "Heading",
        "Level" -> StringLength[hashes],
        "Text" -> StringTrim @ StringReplace[StringTrim[line], StartOfString ~~ ("#" ..) ~~ " " -> ""]
    |>
]

parseOptionValue[s_String] := Which[
    MemberQ[{"true", "yes"}, ToLowerCase[StringTrim[s]]], True,
    MemberQ[{"false", "no"}, ToLowerCase[StringTrim[s]]], False,
    True, stripQuotes[s]
]

cellOptionLine[line_String] := Block[{parts = StringSplit[StringReplace[StringTrim[line], StartOfString ~~ "#|" -> ""], ":", 2]},
    StringTrim[First[parts]] -> parseOptionValue[Last[parts]]
]

parseCellOptions[lines_List] := Association @ Map[cellOptionLine, Select[lines, StringContainsQ[#, ":"] &]]

codeBlock[info_String, bodyLines_List] := Block[{optLines, codeLines},
    optLines = TakeWhile[bodyLines, StringMatchQ[StringTrim[#], "#|" ~~ ___] &];
    codeLines = Drop[bodyLines, Length[optLines]];
    <|
        "Type" -> "Code",
        "Lang" -> First[StringSplit[ToLowerCase @ StringDelete[info, {"{", "}"}]], ""],
        "Options" -> parseCellOptions[optLines],
        "Code" -> StringRiffle[codeLines, "\n"]
    |>
]

fenceSplit[{}, collected_] := {Reverse[collected], {}}
fenceSplit[lines_List, collected_] := If[ fenceQ[First[lines]],
    {Reverse[collected], Rest[lines]},
    fenceSplit[Rest[lines], Prepend[collected, First[lines]]]
]

(* Pandoc-style fenced divs ":::". An opening line "::: kind" (kind is any
   non-empty token, e.g. "solved-example", "theorem", "proof", "exercise",
   "solution") starts a div; the matching "::: " closes it. Divs nest.
   Used by the Chapter template to scaffold the multi-cell book constructs
   (SolvedExample, Theorem/Proof, Exercise/Solution) that have no direct
   markdown analogue. *)
divOpenQ[line_String] := Block[{t = StringTrim[line]},
    StringStartsQ[t, ":::"] && StringTrim[StringDrop[t, 3]] =!= ""
]
divCloseQ[line_String] := StringTrim[line] === ":::"
divKind[line_String] := StringTrim[StringDrop[StringTrim[line], 3]]

(* gather lines until the matching ::: closer; respects nested divs *)
divSplit[lines_List] := Block[{depth = 1, acc = {}, rest = lines},
    While[depth > 0 && rest =!= {},
        Which[
            divOpenQ[First[rest]],
                depth++; AppendTo[acc, First[rest]]; rest = Rest[rest],
            divCloseQ[First[rest]],
                depth--;
                If[depth > 0, AppendTo[acc, First[rest]]];
                rest = Rest[rest],
            True,
                AppendTo[acc, First[rest]]; rest = Rest[rest]
        ]
    ];
    {acc, rest}
]

paraSplit[{}, collected_] := {Reverse[collected], {}}
paraSplit[lines_List, collected_] := Block[{line = First[lines]},
    If[ StringTrim[line] === "" || fenceQ[line] || headingQ[line] || listItemQ[line] ||
            orderedItemQ[line] || blockquoteQ[line] || mathBlockOpenQ[line] ||
            divOpenQ[line] || divCloseQ[line],
        {Reverse[collected], lines},
        paraSplit[Rest[lines], Prepend[collected, line]]
    ]
]

(* markdown list items: "- ", "* " or "+ " (the marker is stripped). Tested by
   explicit character checks, not a string pattern: a bare "*" in a
   StringExpression is the wildcard metacharacter, not a literal asterisk. *)
listItemQ[line_String] := Block[{t = StringTrim[line]},
    StringLength[t] >= 2 && MemberQ[{"-", "*", "+"}, StringTake[t, 1]] && StringTake[t, {2}] === " "
]

listText[line_String] := taskCheckbox @ StringTrim @ StringDrop[StringTrim[line], 2]

(* a GitHub task-list item "[ ] ..." / "[x] ..." -> a ballot-box glyph before the
   text (unchecked U+2610, checked U+2611), so the checkbox renders instead of a
   literal "[ ]". *)
taskCheckbox[t_String] := Which[
    StringStartsQ[t, "[ ] "], "\:2610 " <> StringDrop[t, 4],
    StringStartsQ[t, "[x] " | "[X] "], "\:2611 " <> StringDrop[t, 4],
    True, t
]

(* ordered list items: "1. ", "2) ", ... (a run of digits, then "." or ")", then a
   space). The marker is dropped; the List block is tagged "Ordered" so it renders
   numbered. *)
orderedItemQ[line_String] := StringMatchQ[StringTrim[line], DigitCharacter .. ~~ ("." | ")") ~~ " " ~~ ___]
orderedText[line_String] := StringTrim @ StringReplace[StringTrim[line], StartOfString ~~ DigitCharacter .. ~~ ("." | ")") ~~ " " -> ""]
orderedSplit[{}, collected_] := {Reverse[collected], {}}
orderedSplit[lines_List, collected_] := With[{line = First[lines]},
    Which[
        orderedItemQ[line],
            orderedSplit[Rest[lines], Prepend[collected, orderedText[line]]],
        collected =!= {} && listContinuationQ[line],
            orderedSplit[Rest[lines],
                Prepend[Rest[collected], First[collected] <> " " <> StringTrim[line]]],
        True,
            {Reverse[collected], lines}
    ]
]

(* a "$$ ... $$" line (or a "$$"-fenced block across multiple lines) is display math.
   Detected separately from inline "$math$" so it can become a centered DisplayFormula
   block rather than be mis-parsed as broken inline math on either side. *)
mathBlockOpenQ[line_String] := StringStartsQ[StringTrim[line], "$$"]
mathBlockClosedQ[line_String] := Block[{t = StringTrim[line]}, StringLength[t] >= 4 && StringStartsQ[t, "$$"] && StringEndsQ[t, "$$"]]

mathBlockGather[lines_List] := Block[{first = StringTrim @ First[lines], rest = Rest[lines], idx},
    If[ mathBlockClosedQ[First[lines]],
        {StringTrim @ StringTake[first, {3, -3}], rest},
        idx = FirstPosition[rest, l_String /; StringEndsQ[StringTrim[l], "$$"], {0}, {1}, Heads -> False];
        If[ idx === {0},
            (* unterminated: take everything after the opening "$$" as content *)
            {StringTrim @ StringDrop[first, 2], rest},
            With[{n = First[idx]},
                {StringTrim @ StringRiffle[Join[
                    {StringDrop[first, 2]},
                    rest[[1 ;; n - 1]],
                    {StringDrop[StringTrim[rest[[n]]], -2]}
                ], "\n"], rest[[n + 1 ;;]]}
            ]
        ]
    ]
]

(* blockquote lines start with ">". Consecutive lines are gathered and the marker
   ("> " or ">") stripped; the joined text becomes a "Quote" block. *)
blockquoteQ[line_String] := StringStartsQ[StringTrim[line], ">"]
quoteText[line_String] := StringReplace[StringTrim[line], StartOfString ~~ ">" ~~ (" " | "") -> ""]
quoteSplit[{}, collected_] := {Reverse[collected], {}}
quoteSplit[lines_List, collected_] := If[ blockquoteQ[First[lines]],
    quoteSplit[Rest[lines], Prepend[collected, quoteText[First[lines]]]],
    {Reverse[collected], lines}
]

(* a thematic break - a line of only "-", "_" or "*" (3+) between blank lines -
   is an explicit example separator (an ExampleDelimiter). Frontmatter "---" is
   already stripped, and "|---|" table rules contain "|", so neither matches.
   Tested by explicit character checks: in a string pattern a bare "*" is the
   wildcard metacharacter, so StringMatchQ[t, "*"..] would match anything. *)
separatorQ[line_String] := Block[{chars = Characters[StringTrim[line]]},
    Length[chars] >= 3 && MemberQ[{"-", "_", "*"}, First[chars, ""]] && Length[DeleteDuplicates[chars]] === 1
]

(* a continuation line under a list item: any non-empty, non-marker-starting
   line that does not itself open a new block. Standard markdown indents the
   continuation under the bullet's text column (2-4 spaces); we accept any
   leading whitespace and fall back to a plain non-list line, so wrapped
   prose under a bullet folds into the same item instead of breaking the list
   into "one item + a paragraph + another item + a paragraph + ..." (which is
   what the user sees as "6 bullets instead of 3"). *)
listContinuationQ[line_String] := StringLength[line] > 0 &&
    StringStartsQ[line, " " | "\t"] && StringTrim[line] =!= "" &&
    ! listItemQ[line] && ! orderedItemQ[line] && ! headingQ[line] &&
    ! fenceQ[line] && ! blockquoteQ[line] && ! mathBlockOpenQ[line]

(* collect a markdown list, folding indented continuation lines into the
   current item (joined with a single space, the way a CommonMark renderer
   would). `collected` is built in reverse - the first element is the current
   item being extended, so prepending a new item makes that the new "current". *)
listSplit[{}, collected_] := {Reverse[collected], {}}
listSplit[lines_List, collected_] := With[{line = First[lines]},
    Which[
        listItemQ[line],
            listSplit[Rest[lines], Prepend[collected, listText[line]]],
        collected =!= {} && listContinuationQ[line],
            listSplit[Rest[lines],
                Prepend[Rest[collected], First[collected] <> " " <> StringTrim[line]]],
        True,
            {Reverse[collected], lines}
    ]
]

(* GitHub-flavored tables: a "| a | b |" row whose next line is a "|---|---|"
   separator. Cells are split on "|" with the outer pipes trimmed. *)
tableRowLineQ[line_String] := StringContainsQ[line, "|"] && StringTrim[line] =!= "" && ! fenceQ[line] && ! headingQ[line]

tableSepQ[line_String] := StringContainsQ[line, "-"] && StringContainsQ[line, "|"] &&
    StringMatchQ[StringTrim[line], ("|" | ":" | "-" | " ") ..]

(* GitHub-flavored Markdown lets a cell contain a literal `|` by
   escaping it as `\|` - the backslash protects the pipe from being
   read as a cell delimiter. We split on UNescaped `|`s by temporarily
   swapping `\|` for a U+0001 sentinel character (never appears in
   normal Markdown), splitting on `|`, then swapping the sentinel back
   to a literal `|` in each cell. *)
splitTableRow[line_String] := Block[{sentinel = FromCharacterCode[1]},
    Map[
        StringReplace[#, sentinel -> "|"] &,
        StringTrim /@ StringSplit[
            StringReplace[StringTrim[StringTrim[line], "|"], "\\|" -> sentinel],
            "|"
        ]
    ]
]

tableSplit[{}, collected_] := {Reverse[collected], {}}
tableSplit[lines_List, collected_] := If[ tableRowLineQ[First[lines]],
    tableSplit[Rest[lines], Prepend[collected, First[lines]]],
    {Reverse[collected], lines}
]

(* markdown image on its own line: ![alt](path) or ![alt](path "effect"). The
   optional title is read as an effect keyword - "papertear" applies the front
   end's Paper Tear background to the inlined image's cell. *)
imageLineQ[line_String] := StringMatchQ[StringTrim[line], "![" ~~ ___ ~~ "](" ~~ ___ ~~ ")"]

parseImageTarget[rest_String] := Block[{
    m = StringCases[StringTrim[rest],
        StartOfString ~~ p : Shortest[Except["\""] ..] ~~ "\"" ~~ t : Shortest[___] ~~ "\"" ~~ EndOfString :> {StringTrim[p], t}, 1]
},
    If[m === {}, {StringTrim[rest], ""}, First[m]]
]

imageBlock[line_String] := First @ StringCases[StringTrim[line],
    "![" ~~ alt : Shortest[Except["]"] ...] ~~ "](" ~~ rest : Shortest[Except[")"] ..] ~~ ")" :>
        With[{pt = parseImageTarget[rest]}, <|"Type" -> "Image", "Alt" -> alt, "Path" -> First[pt], "Effect" -> Last[pt]|>]]

blockLoop[{}, acc_] := Reverse[acc]
blockLoop[lines_List, acc_] := Block[{line = First[lines], rest = Rest[lines], split},
    Which[
        StringTrim[line] === "",
            blockLoop[rest, acc]
        ,
        fenceQ[line],
            split = fenceSplit[rest, {}];
            blockLoop[Last[split], Prepend[acc, codeBlock[StringReplace[StringTrim[line], StartOfString ~~ "```" -> ""], First[split]]]]
        ,
        divOpenQ[line],
            split = divSplit[rest];
            blockLoop[Last[split], Prepend[acc,
                <|"Type" -> "Div",
                  "Kind" -> divKind[line],
                  "Blocks" -> parseBlocks[StringRiffle[First[split], "\n"]]|>
            ]]
        ,
        headingQ[line],
            blockLoop[rest, Prepend[acc, headingBlock[line]]]
        ,
        imageLineQ[line],
            blockLoop[rest, Prepend[acc, imageBlock[line]]]
        ,
        separatorQ[line],
            blockLoop[rest, Prepend[acc, <|"Type" -> "Separator"|>]]
        ,
        blockquoteQ[line],
            split = quoteSplit[lines, {}];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "Quote", "Text" -> StringRiffle[First[split], " "]|>]]
        ,
        mathBlockOpenQ[line],
            split = mathBlockGather[lines];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "MathBlock", "Text" -> First[split]|>]]
        ,
        tableRowLineQ[line] && rest =!= {} && tableSepQ[First[rest]],
            split = tableSplit[lines, {}];
            With[{rows = splitTableRow /@ First[split]},
                blockLoop[Last[split], Prepend[acc, <|"Type" -> "Table", "Header" -> First[rows], "Rows" -> Drop[rows, 2]|>]]
            ]
        ,
        listItemQ[line],
            split = listSplit[lines, {}];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "List", "Items" -> First[split]|>]]
        ,
        orderedItemQ[line],
            split = orderedSplit[lines, {}];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "List", "Ordered" -> True, "Items" -> First[split]|>]]
        ,
        True,
            split = paraSplit[lines, {}];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "Prose", "Text" -> StringRiffle[First[split], " "]|>]]
    ]
]

(* blockLoop and its sibling splitters (fenceSplit, paraSplit, listSplit, ...)
   recurse once per source line, and Wolfram does not tail-call optimize -
   the default $RecursionLimit of 1024 trips on any document longer than
   roughly a thousand lines. Lift the limit to scale with the document
   (8x the line count, capped, with a 10000 floor so short docs are
   unaffected) so a real-world tutorial of tens of thousands of lines
   parses without aborting. Rewriting the parser as an iterative
   While-loop would be cleaner long-term; this is the minimal patch
   that keeps the parser useful on big inputs. *)
parseBlocks[body_String] := Block[
    {lines = StringSplit[body, "\n"], $RecursionLimit},
    $RecursionLimit = Max[10000, 8 * Length[lines], Replace[$RecursionLimit, Except[_Integer] -> 0]];
    blockLoop[lines, {}]
]

(* drop HTML/markdown comments (e.g. "<!-- => 21. -->" output annotations) *)
stripComments[s_String] := StringReplace[s, "<!--" ~~ Shortest[___] ~~ "-->" -> ""]

litParse[text_String] := Block[{fm = extractFrontmatter[text]},
    <|"Metadata" -> First[fm], "Blocks" -> parseBlocks[stripComments[Last[fm]]]|>
]

(* === source resolution ===
   The entry accepts a local file path, an http(s) URL, or a raw markdown
   string. Resolution yields the text, a base for "#| file:" includes, a name
   for the default output, and whether the source is a local file. *)

urlQ[s_String] := StringMatchQ[s, ("http://" | "https://") ~~ ___]

joinSource[base_String, path_String] := If[ urlQ[base],
    StringTrim[base, "/"] <> "/" <> path,
    FileNameJoin[{base, path}]
]

resolveSource[input_String] := Which[
    urlQ[input],
        <|"Text" -> Import[input, "Text"], "Base" -> StringReplace[input, RegularExpression["/[^/]*$"] -> ""], "Name" -> FileBaseName @ Last @ StringSplit[input, "/"], "Local" -> False, "Id" -> input|>
    ,
    FileExistsQ[input],
        <|"Text" -> Import[input, "Text"], "Base" -> DirectoryName[input], "Name" -> FileBaseName[input], "Local" -> True, "Id" -> input|>
    ,
    True,
        <|"Text" -> input, "Base" -> Directory[], "Name" -> "Notebook", "Local" -> False, "Id" -> input|>
]

(* a code cell carrying a "file" option inlines that file's contents as its
   body, resolved (file or URL) relative to the document; a markdown image block
   imports its image (file or URL) relative to the document. Both resolutions
   happen here because the document base is known. *)
resolveBlock[b_Association, base_String] := Which[
    b["Type"] === "Code" && KeyExistsQ[b["Options"], "file"],
        Append[b, "Code" -> Import[joinSource[base, b["Options"]["file"]], "Text"]],
    b["Type"] === "Image",
        Append[b, "Image" -> Quiet @ Import[joinSource[base, b["Path"]]]],
    True, b
]

resolveIncludes[blocks_List, base_String] := Map[resolveBlock[#, base] &, blocks]

(* === sections === *)

sectionsFrom[blocks_List] := Block[{step, init},
    init = <|"key" -> "", "acc" -> <||>|>;
    step[state_, b_] := Which[
        b["Type"] === "Heading" && b["Level"] <= 2,
            <|"key" -> ToLowerCase[b["Text"]], "acc" -> Append[state["acc"], ToLowerCase[b["Text"]] -> {}]|>
        ,
        state["key"] === "",
            state
        ,
        True,
            <|"key" -> state["key"], "acc" -> MapAt[Append[#, b] &, state["acc"], Key[state["key"]]]|>
    ];
    Fold[step, init, blocks]["acc"]
]

executableQ[b_] := b["Type"] === "Code" && MemberQ[{"wl", "wolfram", "mathematica"}, b["Lang"]] && TrueQ[Lookup[b["Options"], "eval", True]]

sectionCells[sections_, key_] := Cases[Lookup[sections, key, {}], b_ /; executableQ[b]]

sectionCode[sections_, key_] := StringRiffle[#["Code"] & /@ sectionCells[sections, key], "\n\n"]

(* Concatenate the prose paragraphs of a section, preserving any inline
   markdown (backticks / bold / italic / links / math) - downstream renderers
   route the result through inlineTextData so they handle the markup; the
   legacy backtick-stripping done here used to defend a plain-string cell
   path that no longer exists. *)
sectionText[sections_, key_] := StringRiffle[
    Cases[Lookup[sections, key, {}], b_ /; b["Type"] === "Prose" :> b["Text"]],
    " "
]

(* === notebook evaluation with a cumulative-hash cache ===
   All executable cells are evaluated in document order, threading state, so a
   cell's cache key depends on every cell before it (whole-notebook sequence). *)

cumulativeHashes[cells_List] := Map[Hash, Rest @ FoldList[#1 <> mdSep <> #2["Code"] &, "", cells]]

(* the light/dark mode example renderings are pinned to. Default light (the
   deployed notebook is light); the markdown-out twin sets it to "Dark". Guard the
   initialization with ValueQ so re-loading this file (the Definition cell inlines
   and evaluates the whole .wl during conversion) does not clobber an override. *)
If[! ValueQ[$lightDark], $lightDark = "Light"]

(* conversion nesting depth. A self-referential example (a doc whose example calls
   MarkdownToNotebook on a document, e.g. the function on its own GitHub source)
   would otherwise re-evaluate that document's examples, and so on without end. So
   only the top-level conversion evaluates examples; a nested one builds the
   notebook with its example cells left unevaluated (input only). *)
If[! ValueQ[$convertDepth], $convertDepth = 0]

(* the notebook a result stands for (a Notebook expression, or the open notebook of
   a NotebookObject), pinned to the current mode. The Resource templates
   (FunctionResource / Example / Data) come from DefinitionNotebookClient with
   LightDark -> "Light" already baked in; appending a second LightDark would
   leave both in the option sequence and the front end would honour the first
   (Light) one, so strip any existing LightDark before setting ours. *)
resultNotebook[res_] := Block[{nb = If[MatchQ[res, _NotebookObject], NotebookGet[res], res]},
    nb /. Notebook[c_, o___] :> Notebook[c, Sequence @@ DeleteCases[{o}, LightDark -> _], LightDark -> $lightDark]
]

(* output for an evaluated cell. A whole notebook has no faithful inline form -
   inlining its cells breaks the surrounding layout (a Title/Section renders
   document-wide; a CellFrame is just a per-cell option, it does not bound a group).
   So a produced notebook is shown as a *rendered thumbnail*: a NotebookObject (the
   notebook itself, opened with NotebookPut, as published WFR functions return) is
   rasterized and closed, the WFR-canonical display; a bare Notebook *expression*
   opts into the same rasterization with "#| screenshot: true" (otherwise it is
   shown as its literal expression boxes). *)
(* keep a rasterized cell image under the resource Check's "large cell area"
   threshold (~500k pixels). Cap both the long dimension and the area to keep
   the cell from tripping LargeCellBounds while still showing the content
   readably. *)
$rasterMaxLongDim = 1200
$rasterMaxArea = 480000
capRaster[img_] := If[ ! ImageQ[img], img,
    Block[{w, h, longDim, area, scale},
        {w, h} = ImageDimensions[img];
        longDim = Max[w, h];
        area = w h;
        scale = Min[1, $rasterMaxLongDim / longDim, Sqrt[$rasterMaxArea / area]];
        If[scale < 1, ImageResize[img, Round[scale {w, h}]], img]
    ]
]

outputBoxes[res_, opts_] := Which[
    res === Null, Null,
    MatchQ[res, _NotebookObject],
        (* a whole-notebook thumbnail can be enormous; rasterize at a lower
           resolution and cap the height so the cell does not trip the analysis
           "huge raster" / "large screen area" checks, while still showing the
           entire notebook. *)
        With[{img = Quiet @ Rasterize[resultNotebook[res], ImageResolution -> 96]},
            Quiet @ NotebookClose[res];
            ToBoxes @ capRaster[img]],
    TrueQ[Lookup[opts, "screenshot", False]] && MatchQ[res, _Notebook],
        ToBoxes @ capRaster @ Quiet @ Rasterize[resultNotebook[res], ImageResolution -> 144],
    True, ToBoxes[res]
]

(* a captured message string -> a notebook "Message" cell. captureMessages
   redirects $Messages to a write stream and we read the printed text back
   verbatim, so the cell text is exactly the line the kernel itself printed -
   no template lookup, no arg substitution to redo. *)
messageCell[s_String] := Cell[s, "Message", "MSG"]
messageCell[hf_] := Cell[ToString[hf, InputForm], "Message", "MSG"]

(* Plain-text rendering of a captured message for the markdown twin: just a
   blockquote with each line prefixed. The message text is whatever the kernel
   itself would print to $Messages, so what shows up is exactly what an
   interactive user would see fire for that cell. *)
messageMd[s_String] := "> " <> StringReplace[StringTrim[s], "\n" -> "\n> "]
messageMd[_] := ""

(* Capture the messages the kernel would *print* during evaluation, by
   redirecting $Messages to a private write stream. This is the proper fix
   for the "ton of garbage in the twin" problem - Internal`HandlerBlock
   captures every fired message, including the 50k OptionValue::optnf and
   General::newsym Wolfram's own framework fires per Plot and which the
   kernel's normal message printer silently swallows (most of them have
   $Off-style suppression, are inside an Internal`InheritedBlock[{$Off}, ...]
   in Charting, or hit General::stop). Redirecting the print stream is the
   *one* mechanism that respects all of those: whatever the kernel decides
   to actually print, we capture verbatim. *)

(* The local file path here must NOT be named `tmp` - the caller (accumEval)
   has its own `tmp` holding the cell source file path, and captureMessages
   is HoldFirst, so the `Get[tmp]` inside `captureMessages @ Get[tmp]` is
   evaluated only after Block re-binds `tmp` to OUR message file. The
   captured Get then reads the empty message file and returns Null - the
   bug that made every example cell's output Null. Use `msgFile` so the
   shadow can't happen. *)
captureMessages[expr_] := Block[{msgFile, stream, res, txt, msgs},
    msgFile = FileNameJoin[{$TemporaryDirectory,
        "mtnb-msg-" <> IntegerString[$KernelID, 36] <> "-" <>
        IntegerString[RandomInteger[10^9], 36] <> ".txt"}];
    stream = OpenWrite[msgFile];
    res = Block[{$Messages = {stream}}, expr];
    Close[stream];
    txt = If[FileExistsQ[msgFile], Quiet @ Import[msgFile, "Text"], ""];
    Quiet @ DeleteFile[msgFile];
    msgs = If[StringQ[txt] && StringTrim[txt] =!= "",
        DeleteCases[Map[StringTrim, StringSplit[txt, "\n\n"]], ""],
        {}];
    {res, msgs}
]
SetAttributes[captureMessages, HoldFirst]

accumEval[state_, b_] := Block[{code = state["code"] <> mdSep <> b["Code"], res, msgs, tmp},
    (* Get a temp package so every top-level statement runs (ToExpression on a
       multi-statement string only takes the first); Get returns the last value. *)
    tmp = FileNameJoin[{$TemporaryDirectory, "mtnb-cell-" <> IntegerString[Hash[code], 36] <> ".wl"}];
    Export[tmp, b["Code"], "Text"];
    {res, msgs} = captureMessages @ Get[tmp];
    <|"code" -> code,
      "out" -> Append[state["out"], Hash[code] -> <|"out" -> outputBoxes[res, b["Options"]], "msgs" -> msgs|>]|>
]

(* Pre-load every package whose first use during evaluation would otherwise
   fire setup-time chatter (General::newsym for each interned symbol, ::shdw
   for cross-context shadowing, Pattern::patv from package-private code) -
   that chatter then fires HERE, outside the per-cell capture scope, where
   Quiet swallows it. Without preloading, the first cell that touches such a
   package "owns" hundreds of bookkeeping messages that have nothing to do
   with what the cell's author wrote, and the FE doesn't show them either
   (by the time the user clicks Run the package is already loaded).

   The list spans:
     - $framePackages: the resource framework Wolfram lazy-loads on first
       use of ResourceObject[EvaluationNotebook[]] /
       DefinitionNotebookClient`Check... / DocumentationBuild. The pair
       ResourceSystemClient`DefinitionNotebook` and DefinitionNotebookClient`
       defines dozens of overlapping symbol names and triggers a flood of
       ::shdw warnings unless both are loaded together up front.
     - the document's own context path (so a resource that depends on a
       paclet has the paclet ready when an example calls it).

   A genuine load failure for any of these is benign here - we just don't
   pre-load it, and the first cell that actually uses it surfaces the real
   error in context. *)
$framePackages = {
    "ResourceSystemClient`",
    "DefinitionNotebookClient`",
    "DocumentationTools`"
}
preloadContextPath[ctxPath_List] := Quiet @ Scan[
    Quiet @ Check[Needs[#], Null] &,
    DeleteDuplicates @ Select[Join[$framePackages, ctxPath], # =!= "System`" &]
]

(* a front end is active for the whole pass so an example may open the notebook it
   produces (NotebookPut) and have its thumbnail captured (see outputBoxes). *)
evaluateAll[cells_List, ctx_String, ctxPath_List] := Block[{$Context = ctx, $ContextPath = ctxPath},
    preloadContextPath[ctxPath];
    UsingFrontEnd[Fold[accumEval, <|"code" -> "", "out" -> <||>|>, cells]]["out"]
]

(* attach each executable block's output (by cumulative hash) so builders read
   block["OutputBoxes"] / block["Messages"] directly instead of recomputing hashes.
   The cache entry is normally an Association <|"out" -> boxes, "msgs" -> {...}|>;
   accept the legacy raw-boxes form too (older cache entries with no message data). *)
annotateOutputs[blocks_List, hashes_List, outputs_] := Block[{i = 0, walk},
    walk[b_] := Which[
        executableQ[b],
            Block[{entry, out, msgs},
                i += 1;
                entry = Lookup[outputs, hashes[[i]], Missing[]];
                {out, msgs} = If[AssociationQ[entry] && KeyExistsQ[entry, "out"],
                    {entry["out"], Lookup[entry, "msgs", {}]},
                    {entry, {}}
                ];
                Append[Append[b, "OutputBoxes" -> out], "Messages" -> msgs]
            ],
        b["Type"] === "Div",
            (* recurse: walk the Div's inner blocks, the counter `i`
               continues from the outer walk so each cell's hash and
               output map line up. *)
            Append[b, "Blocks" -> walk /@ b["Blocks"]],
        True, b
    ];
    walk /@ blocks
]

(* === notebook cell builders === *)

(* known example-section keys, in canonical render order. The list is the union of
   conventions across templates (FunctionResource uses Basic / Scope / Options / ... ;
   Data uses Basic / Scope & Additional Elements / Visualizations / Analysis); each
   doc supplies whatever subset is meaningful, and exampleNotebookSlot renders only
   the present sections in this order. *)
$exampleOrder = {
    "basic examples", "scope", "scope & additional elements", "options", "applications",
    "visualizations", "analysis",
    "properties and relations", "possible issues", "neat examples"
}

$exampleTitle = <|
    "basic examples" -> "Basic Examples",
    "scope" -> "Scope",
    "scope & additional elements" -> "Scope & Additional Elements",
    "options" -> "Options",
    "applications" -> "Applications",
    "visualizations" -> "Visualizations",
    "analysis" -> "Analysis",
    "properties and relations" -> "Properties and Relations",
    "possible issues" -> "Possible Issues",
    "neat examples" -> "Neat Examples"
|>

$osCanonical = <|
    "windows" -> "Windows", "mac" -> "MacOSX", "macosx" -> "MacOSX",
    "linux" -> "Unix", "unix" -> "Unix"
|>

asList[x_List] := x
asList[x_] := {x}

(* a TemplateSlot's default content, used as both the cell shape to clone and
   the fallback when the markdown supplies nothing for that slot. *)
slotDefault[opts_List] := FirstCase[opts, (DefaultValue -> v_) :> v, {}]

(* drop the markers that flag a cell as an unfilled template placeholder *)
cleanCell[cell_] := DeleteCases[
    cell /. (CellTags -> t_) :> (CellTags -> DeleteCases[Flatten[{t}], "DefaultContent"]),
    CellID -> _,
    {1}
]

fillTextCells[opts_, text_String] := Block[{def = slotDefault[opts]},
    If[ def === {} || text === "",
        def,
        {cleanCell @ ReplacePart[First[def], 1 -> text]}
    ]
]

(* like fillTextCells, but the text keeps its inline formatting (`code` spans
   become templated InlineFormula, links become hyperlinks) by replacing the
   cell content with TextData rather than a bare string. *)
fillTextDataCells[opts_, text_String] := Block[{def = slotDefault[opts]},
    If[ def === {} || StringTrim[text] === "",
        def,
        {cleanCell @ ReplacePart[First[def], 1 -> TextData @ inlineTextData[text]]}
    ]
]

fillListCells[opts_, items_List] := Block[{def = slotDefault[opts], vals = DeleteCases[items, ""]},
    If[ def === {} || vals === {},
        def,
        Map[cleanCell @ ReplacePart[First[def], 1 -> #] &, vals]
    ]
]

(* like fillListCells, but an item may be a markdown link [label](url), rendered
   as a labeled hyperlink (the resource Check asks for labeled links, not raw
   URLs); a plain string stays as text. The ButtonBox sits directly in TextData
   (not inside BoxData) so the label stays a String literal - inside BoxData the
   front end would reparse a multi-word label into a RowBox, which the resource
   scraper's ButtonBox[_String, ...] link pattern would then miss. *)
linkItemContent[item_String] := Block[{
    m = StringCases[item, "[" ~~ t : Shortest[Except["]"] ..] ~~ "](" ~~ u : Shortest[Except[")"] ..] ~~ ")" :> {t, u}, 1]
},
    If[ m === {},
        item,
        TextData[{ButtonBox[First @ First @ m, BaseStyle -> "Hyperlink", ButtonData -> {URL[Last @ First @ m], None}]}]
    ]
]

fillLinkCells[opts_, items_List] := Block[{def = slotDefault[opts], vals = DeleteCases[items, ""]},
    If[ def === {} || vals === {},
        def,
        Map[cleanCell @ ReplacePart[First[def], 1 -> linkItemContent[#]] &, vals]
    ]
]

fillCheckbox[property_String, checked_List, type_String : "Function"] := {
    DefinitionNotebookClient`CheckboxesCell[<|
        "ResourceType" -> type, "Property" -> property, "Checked" -> checked
    |>]
}

(* literal input boxes for a code string: parse it through the front end the way
   typing it would (ReparseBoxStructurePacket), so the boxes are the *code*.
   ToBoxes[Defer[...]] instead *renders* display heads (Framed, Style, Grid, Row,
   RGBColor, ...) into frames/swatches, corrupting the Input cell. Fall back to
   the Defer parse, then the raw string, if the front end is unavailable. *)
inputBoxes[code_String] := Block[{boxes, parsed, trimmed = StringTrim[code]},
    (* LaTeX-style "\command" sequences (\left, \right, \sqrt, \to, \notin, ...)
       collide with Wolfram's string-escape syntax: the front end's reparser
       interprets "\r" / "\n" / "\t" / "\b" / "\f" as their control-character
       escapes, so "\right" gets tokenised as "\r" + "ight". For inputs containing
       backslash + two-or-more-letter commands - never valid bare WL, but the
       normal shape of inline LaTeX - skip the reparse and emit the raw string
       so it renders verbatim. "\[Name]" Wolfram named characters are unaffected
       because they have "[" (not a letter) after the backslash. *)
    If[StringContainsQ[trimmed, "\\" ~~ LetterCharacter ~~ LetterCharacter],
        Return[trimmed]
    ];
    boxes = Quiet @ UsingFrontEnd @ MathLink`CallFrontEnd[FrontEnd`ReparseBoxStructurePacket[trimmed]];
    If[ FreeQ[boxes, $Failed] && (StringQ[boxes] || ! AtomQ[boxes]),
        boxes,
        parsed = Quiet @ ToExpression[code, StandardForm, Defer];
        If[parsed === $Failed, code, ToBoxes[parsed]]
    ]
]

(* extra options for an example's Output cell, from the code cell's "#|" options.
   "#| background: papertear" sets BackgroundAppearance -> "PaperTear", the cell
   option the front end's Convert To > Paper Tear menu item toggles - a torn-paper
   edge, used to make a generated-notebook screenshot look like a screenshot. *)
(* "#| tear: ..." gives an output cell the front end's torn-paper appearance. The
   tear only shows once the cell is height-constrained, so it also sets a CellSize:
   "#| tear: h" keeps the top h points visible (smaller tears more off), while
   "#| tear: true" (or yes / auto) uses a default height. "#| tear: false" (or no
   tear option) leaves the output untorn. *)
$defaultTearHeight = 200

paperTearQ[block_] := Lookup[block["Options"], "tear", False] =!= False

tearHeight[block_] := With[{v = Lookup[block["Options"], "tear", True]},
    Which[
        NumberQ[v], v,
        StringQ[v] && NumberQ[Quiet @ ToExpression[v]], ToExpression[v],
        True, $defaultTearHeight
    ]
]

extraOutputOpts[block_] := If[
    paperTearQ[block],
    {BackgroundAppearance -> "PaperTear", CellSize -> {Automatic, tearHeight[block]}},
    {}
]

(* hideInput drops the Input cell entirely and emits only the captured Output
   (plus any messages). The use case is a Demonstration Snapshot: the cell's
   code recreates the Manipulate at a specific control state via a parameterised
   helper from the Initialization section ("demo[p1, p2]"), but only the
   resulting panel image is wanted in the published notebook - showing the
   call would clutter the snapshot section. Toggled per-cell with
   "#| input: false". *)
exampleIO[code_String, outBoxes_, n_Integer, outOpts_List : {}, msgs_List : {}, hideInput : (True | False) : False] := Block[{
    inCell = Cell[BoxData[inputBoxes[code]], "Input", CellLabel -> "In[" <> ToString[n] <> "]:= "],
    msgCells = messageCell /@ msgs,
    outCell
},
    Which[
        MissingQ[outBoxes] || outBoxes === Null,
            If[hideInput, msgCells, Join[{inCell}, msgCells]],
        hideInput,
            (* output-only: no Input cell, no In/Out label, no group bracket *)
            outCell = Cell[BoxData[outBoxes], "Output", Sequence @@ outOpts];
            Flatten[{msgCells, outCell}],
        True,
            outCell = Cell[BoxData[outBoxes], "Output", CellLabel -> "Out[" <> ToString[n] <> "]= ", Sequence @@ outOpts];
            {Cell[CellGroupData[Flatten[{inCell, msgCells, outCell}], Open]]}
    ]
]

(* a documentation *flag* - the front end's Futurize / Excise / ... toolbar
   buttons, which mark a page or cell for the doc build (DocumentationBuild reads
   these flag-styled banner cells to include, hide, or defer content). A
   document-level flag is the "Flag" frontmatter key; a per-cell flag is a code
   cell's "#| flag: ..." option. The value is a friendly name mapped to the build's
   flag cell style and its spaced-out banner text. *)
$flagStyles = <|
    "future" -> "FutureFlag", "futurize" -> "FutureFlag",
    "excised" -> "ExcisedFlag", "excise" -> "ExcisedFlag",
    "obsolete" -> "ObsoleteFlag",
    "temporary" -> "TemporaryFlag",
    "preview" -> "PreviewFlag",
    "internal" -> "InternalFlag"
|>
$flagBanners = <|
    "FutureFlag" -> "F  U  T  U  R  E",
    "ExcisedFlag" -> "E  X  C  I  S  E  D",
    "ObsoleteFlag" -> "O  B  S  O  L  E  T  E",
    "TemporaryFlag" -> "T  E  M  P  O  R  A  R  Y",
    "PreviewFlag" -> "P  R  E  V  I  E  W",
    "InternalFlag" -> "I  N  T  E  R  N  A  L"
|>
flagCell[v_String] := With[{s = Lookup[$flagStyles, ToLowerCase[StringTrim[v]], None]},
    If[s === None, Nothing, Cell[$flagBanners[s], s]]]
flagCell[_] := Nothing

(* prefix a list of cells with the block's per-cell flag banner ("#| flag: ...") *)
withCellFlag[block_, cells_List] := With[{f = flagCell[Lookup[block["Options"], "flag", ""]]},
    If[f === Nothing, cells, Prepend[cells, f]]]

(* "#| excluded: true" appends the "Excluded" cell style. The resource scraper
   strips any Cell[..., "Excluded", ...] from the published resource (vExclusions
   in ResourceSystemClient`DefinitionNotebook`Scraping`), but the cell stays in
   the source .nb so the author can keep work-in-progress or reviewer notes that
   travel with the document but never ship.

   Split a Cell's args into "leading style strings" and "trailing options"
   manually - the `Cell[content_, styles___String, opts___]` pattern doesn't
   bind styles greedily (___String prefers a zero match when followed by ___),
   so we'd end up emitting Cell[content, "Excluded", "Input", ...] with the
   modifier style ahead of the base. *)
splitCellArgs[args_List] := Block[{styles, rest},
    styles = TakeWhile[args, StringQ];
    rest = Drop[args, Length[styles]];
    {styles, rest}
]

withExtraCellStyle[Cell[CellGroupData[cells_List, st_], go___], style_String] :=
    Cell[CellGroupData[Map[withExtraCellStyle[#, style] &, cells], st], go]
withExtraCellStyle[Cell[content_, args___], style_String] := Block[
    {parts = splitCellArgs[{args}]},
    Cell[content, Sequence @@ parts[[1]], style, Sequence @@ parts[[2]]]
]
withExtraCellStyle[other_, _] := other

applyExcluded[block_, cells_List] := If[
    TrueQ[Lookup[block["Options"], "excluded", False]],
    Map[withExtraCellStyle[#, "Excluded"] &, cells],
    cells
]

(* "#| hidden: true" closes the cell on the *published* web page but keeps it
   open in the downloadable example notebook - that is, CellOpen -> False plus
   the "HiddenMaterial" modifier style (which the FunctionResource stylesheet
   wraps in a green-edged frame with a "hidden" label so the author sees it
   is marked). The cell still scrapes into the deployed resource, unlike
   "excluded" which strips it entirely. *)
withHiddenOptions[Cell[CellGroupData[cells_List, _], go___]] :=
    Cell[CellGroupData[Map[withHiddenOptions, cells], Closed], go]
withHiddenOptions[Cell[content_, args___]] := Block[
    {parts = splitCellArgs[{args}]},
    Cell[content, Sequence @@ parts[[1]], "HiddenMaterial",
         Sequence @@ parts[[2]], CellOpen -> False]
]
withHiddenOptions[other_] := other

applyHidden[block_, cells_List] := If[
    TrueQ[Lookup[block["Options"], "hidden", False]],
    Map[withHiddenOptions, cells],
    cells
]

(* an example's cells (Input / Output), prefixed with its per-cell flag banner
   and decorated with any "excluded" / "hidden" per-cell tag. "#| input: false"
   drops the Input cell - the example renders as just its captured Output (the
   Demonstration-snapshot use case). *)
exampleIOFor[block_, n_Integer] :=
    applyExcluded[block, applyHidden[block, withCellFlag[block, exampleIO[
        block["Code"], block["OutputBoxes"], n,
        extraOutputOpts[block], Lookup[block, "Messages", {}],
        Lookup[block["Options"], "input", True] === False
    ]]]]

(* a document-level flag banner ("Flag" frontmatter) prepended to the notebook *)
applyDocFlag[nb_, ""] := nb
applyDocFlag[Notebook[cells_, o___], v_String] := With[{f = flagCell[v]},
    If[f === Nothing, Notebook[cells, o], Notebook[Prepend[cells, f], o]]]
applyDocFlag[nb_, _] := nb

(* the filled function-definition cell. It must carry the "DefaultContent" cell
   tag the official template puts on every content cell, or the resource scraper
   (and the submission Check) does not recognize it as the function's definition. *)
functionSlot[opts_, defCode_String] := If[ defCode === "",
    slotDefault[opts],
    {Cell[BoxData[defCode], "Code", CellTags -> {"DefaultContent"}, InitializationCell -> True]}
]

(* the content-defining cells of an Example Repository resource (the "ContentElements"
   slot). An Example resource exposes named content via ResourceData, so each
   executable cell in a "## Content" section is the literal defining assignment
   (typically ResourceData[ResourceObject[EvaluationNotebook[]], "name"] = value) and
   becomes an Input cell carrying the "DefaultContent" tag the scraper needs. *)
codeBlockQ[b_] := b["Type"] === "Code" && MemberQ[{"wl", "wolfram", "mathematica"}, b["Lang"]]

contentSlot[opts_, sections_] := Block[{cells = Cases[Lookup[sections, "content", {}], b_ /; codeBlockQ[b]]},
    If[ cells === {},
        slotDefault[opts],
        Map[Cell[BoxData[inputBoxes[#["Code"]]], "Input", CellTags -> {"DefaultContent"}] &, cells]
    ]
]

(* === single-cell-from-section helpers, used by Prompt and Demonstration ===
   Each fills a TemplateSlot with one cell built from the FIRST code block (or
   prose block) of a given markdown section. They mirror contentSlot's pattern
   but for slots that take a single value rather than a list, and tag the cell
   with "DefaultContent" so the resource scraper picks it up. *)

(* Pull the first executable WL block from a section, or Missing[] if none. *)
firstCodeOf[sections_, key_] := FirstCase[Lookup[sections, key, {}], b_ /; codeBlockQ[b], Missing[]]

(* All executable WL blocks in a section, in order. *)
allCodeOf[sections_, key_] := Cases[Lookup[sections, key, {}], b_ /; codeBlockQ[b]]

(* All prose / list / quote / table blocks of a section, in order, as ordinary
   Text cells - the format the Demonstration template's Caption / Details /
   References slots expect. *)
proseBlockCells[blocks_, style_String : "Text"] := Catenate @ Map[
    b |-> Switch[b["Type"],
        "Prose", {Cell[TextData @ inlineTextData[b["Text"]], style]},
        "List",  listItemCells[b, style],
        "Table", {tableCell[b]},
        "Quote", {quoteCell[b["Text"]]},
        "MathBlock", {mathBlockCell[b["Text"]]},
        _, {}
    ],
    blocks
]

(* Fill a slot with a single Input cell built from the first code block of the
   named section; falls back to the template default if the section is empty.
   The cell carries "DefaultContent" so the official scraper finds it. *)
codeSlot[opts_, sections_, key_String] := Block[{b = firstCodeOf[sections, key]},
    If[ MissingQ[b],
        slotDefault[opts],
        {Cell[BoxData[inputBoxes[b["Code"]]], "Input", CellTags -> {"DefaultContent"}]}
    ]
]

(* Fill a slot with one Input cell per code block of the named section. Used for
   Snapshot groups (>= 3 panel-producing inputs) and similar list-of-cells
   slots. A cell flagged "#| input: false" emits only its captured Output (no
   Input cell, no In[]/Out[] label) - the Demonstration snapshot convention:
   the snapshot is the *rendered Manipulate panel* at a parameter state,
   produced by calling a helper from the Initialization section, with only
   the panel visible. *)
multiCodeSlot[opts_, sections_, key_String] := Block[{cells = allCodeOf[sections, key]},
    If[ cells === {}, Return[slotDefault[opts]] ];
    Catenate @ MapIndexed[
        Function[{b, ix},
            If[ Lookup[b["Options"], "input", True] === False,
                Block[{out = Lookup[b, "OutputBoxes", Missing[]]},
                    If[MissingQ[out] || out === Null, {}, {Cell[BoxData[out], "Output", CellTags -> {"DefaultContent"}]}]
                ],
                {Cell[BoxData[inputBoxes[b["Code"]]], "Input", CellTags -> {"DefaultContent"}]}
            ]
        ],
        cells
    ]
]

(* Fill a slot with one Text (or other styled) cell per prose / list / quote
   block of the named section. Used for CaptionCells / DetailCells /
   ReferenceCells in the Demonstration template, and PromptTemplate in the
   Prompt template (whose body is plain prose). *)
proseSectionSlot[opts_, sections_, key_String, style_String : "Text"] := Block[{cells},
    cells = proseBlockCells[Lookup[sections, key, {}], style];
    If[cells === {}, slotDefault[opts], cells]
]

(* A Manipulate slot needs the Input cell AND its evaluated Manipulate output
   (the live panel), grouped so the published demo shows the panel. The cached
   OutputBoxes from the example-evaluation pass provide the output; without it
   we leave the Input alone and let the front end produce the output on open. *)
manipulateSlot[opts_, sections_] := Block[{b = firstCodeOf[sections, "manipulate"]},
    If[ MissingQ[b], Return[slotDefault[opts]] ];
    Block[{out = Lookup[b, "OutputBoxes", Missing[]]},
        If[ MissingQ[out] || out === Null,
            {Cell[BoxData[inputBoxes[b["Code"]]], "Input", CellTags -> {"DefaultContent"}]},
            {Cell[CellGroupData[{
                Cell[BoxData[inputBoxes[b["Code"]]], "Input", CellTags -> {"DefaultContent"}],
                Cell[BoxData[out], "Output"]
            }, Open]]}
        ]
    ]
]

(* a Usage section is a sequence of usage statements, one per prose paragraph
   that begins with a `code` span: the code is the signature (e.g.
   `MarkdownToNotebook[source]`) and the rest is its description. The signature
   is templated like the "Template Input" button (arguments italic, head linked)
   and the description keeps its inline formatting. *)
(* a usage statement is either a backticked code-span signature (legacy form,
   `Name[c$1, c$2]`) or a prose signature with inline-math arguments (the
   pandoc-friendly form, "Name[$c_1$, $c_2$]"). The math form renders correctly
   in pandoc / GitHub since markdown forbids nested formatting inside code spans;
   for our notebook output, "$c_1$" is rewritten to the ParseTextTemplate
   subscript form "c$1" and fed through templateBox. *)
mathArgsToTemplate[s_String] := StringReplace[s, {
    "$" ~~ base:(LetterCharacter ~~ (WordCharacter ...)) ~~ "_" ~~ "{" ~~ sub:Shortest[Except["}"]..] ~~ "}" ~~ "$" :> base <> "$" <> sub,
    "$" ~~ base:(LetterCharacter ~~ (WordCharacter ...)) ~~ "_" ~~ sub:(DigitCharacter | LetterCharacter) ~~ "$" :> base <> "$" <> ToString[sub],
    "$" ~~ ident:(LetterCharacter ~~ (WordCharacter ...)) ~~ "$" :> ident
}]

(* Sanitize the markdown styling out of a usage signature, leaving the plain WL
   signature string that templateBox / ParseTextTemplate can render. Strips
   inferred-link wrappers in both forms - the canonical bare "[Name](url)" and
   the legacy backtick-wrapped "[`Name`](url)" - and "*italic*" markers. The
   "$x_i$" math and "<sub>i</sub>" / "~i~" subscript forms pass through to
   mathArgsToTemplate / mdToTemplateSubs which already know how to template
   them. The backticked rule runs first so a "[`X`](url)" does not part-match
   the bare rule and leak its surrounding backticks. *)
unwrapMarkdownSig[s_String] := StringReplace[s, {
    "[`" ~~ n : Shortest[Except["`"] ..] ~~ "`](" ~~ Shortest[Except[")"] ...] ~~ ")" :> n,
    "[" ~~ n : Shortest[Except["]" | "`" | "\n"] ..] ~~ "](" ~~ Shortest[Except[")"] ...] ~~ ")" :> n,
    "*" ~~ w : Shortest[Except["*" | " "] ..] ~~ "*" :> w
}]

usageStatement[text_String] := Block[{trimmed = StringTrim[text], m},
    (* the canonical wrapper: <code>...</code>. GitHub / Pandoc process markdown
       *inside* an inline HTML tag, so the inferred-link head, italic args, math
       subscripts, etc. all render naturally while the whole span is code-styled.
       Strip the code wrapper and the inner markdown to recover the plain WL
       signature; the templateBox / ParseTextTemplate pipeline does the rest. *)
    m = StringCases[trimmed,
        StartOfString ~~ "<code>" ~~ sig : Shortest[__] ~~ "</code>" ~~ rest___ :>
            {mathArgsToTemplate[unwrapMarkdownSig[sig]], StringTrim[rest]}, 1];
    If[m =!= {}, Return[m]];
    (* hybrid form (pandoc-friendly): a backticked head followed *immediately* by a
       "[...]" bracket group whose args use inline math. *)
    m = StringCases[trimmed,
        StartOfString ~~ "`" ~~ name : Shortest[Except["`"] ..] ~~ "`" ~~ args : ("[" ~~ Shortest[Except["\n"] ..] ~~ "]") ~~ rest___ :>
            {name <> mathArgsToTemplate[args], StringTrim[rest]}, 1];
    If[m =!= {}, Return[m]];
    (* legacy form: the whole signature inside one code span ("`f[x~1~, x~2~]`"). *)
    m = StringCases[trimmed,
        StartOfString ~~ "`" ~~ c : Shortest[__] ~~ "`" ~~ rest___ :> {c, StringTrim[rest]}, 1];
    If[m =!= {}, Return[m]];
    (* prose form: an identifier head, then [ ... ] balanced once, then prose. *)
    StringCases[trimmed,
        StartOfString ~~ name : (LetterCharacter ~~ (WordCharacter | "`") ...) ~~ args : ("[" ~~ Shortest[Except["\n"] ..] ~~ "]") ~~ rest___ :>
            {name <> mathArgsToTemplate[args], StringTrim[rest]},
        1]
]

usagePair[{code_String, desc_String}] := {
    Cell[BoxData[stripLinks @ templateBox[code]], "UsageInputs", FontFamily -> "Source Sans Pro"],
    Cell[TextData @ inlineTextData[desc], "UsageDescription"]
}

usageSlot[opts_, sections_] := Block[{pairs},
    pairs = Flatten[
        usageStatement /@ Cases[Lookup[sections, "usage", {}], b_ /; b["Type"] === "Prose" :> b["Text"]],
        1
    ];
    If[ pairs === {}, Return[slotDefault[opts]] ];
    {Cell[CellGroupData[Catenate[usagePair /@ pairs], Open]]}
]

(* the Details & Options notes: one "Notes" cell per item, so each renders as its
   own bullet (the reference-page convention) - a paragraph is one note, a markdown
   list is one note per item, a table becomes a grid. *)
(* a blockquote -> a Text cell set off by a left rule and indent, the way GitHub
   renders "> ...". Self-styled (CellFrame / CellMargins), so it does not depend on
   a Quote cell style being present in the template's stylesheet. *)
quoteCell[text_String] := Cell[TextData @ inlineTextData[text], "Text",
    FontSlant -> "Italic", FontColor -> LightDarkSwitched[GrayLevel[0.45], GrayLevel[0.65]],
    CellFrame -> {{3, 0}, {0, 0}}, CellFrameColor -> GrayLevel[0.55], CellFrameMargins -> 10,
    CellMargins -> {{40, 10}, {7, 7}},
    Background -> LightDarkSwitched[GrayLevel[0.96], GrayLevel[0.2]]]

(* list items as cells of the given bullet style, numbered ("ItemNumbered") when the
   block is an ordered list. *)
listItemCells[block_, base_String] := With[{style = If[TrueQ[block["Ordered"]], "ItemNumbered", base]},
    Map[Cell[TextData @ inlineTextData[#], style] &, block["Items"]]
]

detailsCells[sections_] := Catenate @ Map[
    block |-> Switch[block["Type"],
        "Prose", {Cell[TextData @ inlineTextData[block["Text"]], "Notes"]},
        "List", listItemCells[block, "Notes"],
        "Table", {tableCell[block]},
        "Quote", {quoteCell[block["Text"]]},
        "MathBlock", {mathBlockCell[block["Text"]]},
        _, {}
    ],
    Lookup[sections, "details & options", {}]
]

notesSlot[opts_, sections_] := With[{cells = detailsCells[sections]},
    If[cells === {}, slotDefault[opts], cells]
]

(* the landing-page hero image: a "## Hero Image" section's first executable cell
   is evaluated; the rendered output is the visible image and the generating code
   is kept beneath it in a Closed cell group (a closed group shows only its first
   cell, so the image shows and the code stays available but hidden). Replaces
   the template's "Image Placeholder".
   Standard Input/Output group with the open state {2}, which shows only cell 2
   (the Output image) and collapses the code Input - the idiom working paclet
   definition notebooks use for a hero, so the scrape sees the image and the code
   stays available but hidden. *)
heroSlot[opts_, sections_] := Block[{cells = sectionCells[sections, "hero image"], out, code},
    If[ cells === {}, Return[slotDefault[opts]] ];
    out = First[cells]["OutputBoxes"];
    code = First[cells]["Code"];
    If[ MissingQ[out] || out === Null, Return[slotDefault[opts]] ];
    {Cell[CellGroupData[{
        Cell[BoxData[inputBoxes[code]], "Input"],
        Cell[BoxData[out], "Output"]
    }, {2}]]}
]

(* The FunctionResource template's VerificationTests slot accepts both Input /
   Output cell pairs and symbolic VerificationTest expressions. We always emit
   the explicit VerificationTest form: each wl code block in a "## Tests"
   section is expected to be a `VerificationTest[code, expected, TestID -> "..."]`
   expression (the docked Run Tests button evaluates these directly), so the
   slot just wraps each code block as a single Input cell tagged
   DefaultContent. Authors write the assertion explicitly - what is tested
   and what is expected - rather than relying on an Input/Output pair the
   scraper would otherwise infer the assertion from. *)
testsSlot[opts_, sections_] := Block[
    {cells = Cases[Lookup[sections, "tests", {}], b_ /; codeBlockQ[b]]},
    If[ cells === {}, Return[slotDefault[opts]] ];
    Map[
        Cell[BoxData[inputBoxes[#["Code"]]], "Input", CellTags -> {"DefaultContent"}] &,
        cells
    ]
]

examplesSlot[opts_, sections_] := Block[{keys, body},
    (* a document may put everything under a single "## Examples" section (the
       natural shape for an Example Repository resource, whose template has one
       Examples slot rather than the Function template's named example sections);
       fill the slot with that section's content directly, no subsection wrapper. *)
    If[ KeyExistsQ[sections, "examples"],
        body = exampleContent[Lookup[sections, "examples", {}], "Text"];
        If[body =!= {}, Return[body]]
    ];
    keys = Select[$exampleOrder, KeyExistsQ[sections, #] &];
    If[ keys === {}, Return[slotDefault[opts]] ];
    Map[
        key |-> Cell[CellGroupData[
            Prepend[
                exampleContent[Lookup[sections, key, {}], "Text"],
                Cell[Lookup[$exampleTitle, key, Capitalize[key]], "Subsection"]
            ],
            Open
        ]],
        keys
    ]
]

(* the cell that separates two examples within a section. The In[]/Out[] counter
   restarts at 1 for each example via the reset in exampleContent (the authored
   InterpretationBox[..., $Line=0] reset matters only when a reader re-evaluates;
   we do not embed it because $Line=0 would evaluate at construction). *)
exampleDelimiterCell := Cell["\t", "ExampleDelimiter"]

(* shared example-content builder: prose -> a text cell of the given style,
   tables -> a GridBox, executable cells -> evaluated Input/Output. Examples are
   separated explicitly by a thematic-break line (--- or ___), which becomes an
   ExampleDelimiter and restarts the In[]/Out[] counter - never inserted
   automatically. A "### Heading" becomes a subsubsection (an ExampleSubsection on
   doc pages) and likewise restarts the counter. *)
exampleSubStyle["ExampleText"] = "ExampleSubsection"
exampleSubStyle[_] = "Subsubsection"

exampleContent[sectionBlocks_, textStyle_String] := Block[{counter = 0, out = {}},
    Do[
        Which[
            block["Type"] === "Heading",
                AppendTo[out, Cell[TextData @ inlineTextData[block["Text"]], exampleSubStyle[textStyle]]];
                counter = 0,
            block["Type"] === "Separator",
                AppendTo[out, exampleDelimiterCell]; counter = 0,
            block["Type"] === "Prose",
                AppendTo[out, Cell[TextData @ inlineTextData[block["Text"]], textStyle]],
            block["Type"] === "Table",
                AppendTo[out, tableCell[block]],
            block["Type"] === "List",
                out = Join[out, listItemCells[block, "Item"]],
            block["Type"] === "Quote",
                AppendTo[out, quoteCell[block["Text"]]],
            block["Type"] === "MathBlock",
                AppendTo[out, mathBlockCell[block["Text"]]],
            block["Type"] === "Image",
                AppendTo[out, imageCell[block]],
            executableQ[block],
                counter += 1; out = Join[out, exampleIOFor[block, counter]]
        ],
        {block, sectionBlocks}
    ];
    out
]

(* Paclet "ExampleNotebook" slot: unlike the Function template's "Examples" slot,
   the example sub-sections are literal Subsection/Text/Input/Output cells (not a
   slot). Keep the template's ExampleInitialization group (the PacletDirectoryLoad
   + Needs cells, filled from PacletDirectory/Context), then build one Subsection
   group per example section with the markdown's prose and evaluated I/O. *)
exampleNotebookSlot[opts_, sections_] := Block[{def = slotDefault[opts], initGroup, keys},
    keys = Select[$exampleOrder, KeyExistsQ[sections, #] && exampleContent[Lookup[sections, #, {}], "Text"] =!= {} &];
    If[ keys === {}, Return[def] ];
    initGroup = FirstCase[def,
        g : Cell[CellGroupData[{Cell[_, "Subsection", "Excluded", ___], _TemplateSlot, ___}, _], ___] :> g,
        Nothing, Infinity];
    MapIndexed[
        Function[{key, pos},
            Cell[CellGroupData[
                Join[
                    If[First[pos] === 1, Flatten[{initGroup}], {}],
                    {Cell[Lookup[$exampleTitle, key, Capitalize[key]], "Subsection"]},
                    exampleContent[Lookup[sections, key, {}], "Text"]
                ],
                Open
            ]]
        ],
        keys
    ]
]

(* === slot dispatch === *)

fillSlot[name_, opts_, data_] := Block[{meta = data["meta"]},
    Switch[name,
        "Name", fillTextCells[opts, Lookup[meta, "Name", ""]],
        "Description", fillTextCells[opts, Lookup[meta, "Description", ""]],
        "Contributed By", fillTextCells[opts, Lookup[meta, "ContributedBy", ""]],
        "ContributorInformation", fillTextCells[opts, Lookup[meta, "ContributedBy", ""]],
        "ContentElements", contentSlot[opts, data["sections"]],
        "Keywords", fillListCells[opts, asList @ Lookup[meta, "Keywords", {}]],
        "Links", fillLinkCells[opts, asList @ Lookup[meta, "Links", {}]],
        "SourceControlURL", fillTextCells[opts, Lookup[meta, "SourceControlURL", ""]],
        "Source/Reference Citation", fillListCells[opts, asList @ Lookup[meta, "Sources", {}]],
        "Related Symbols", fillListCells[opts, asList @ Lookup[meta, "RelatedSymbols", Lookup[meta, "SeeAlso", {}]]],
        "RelatedSymbols", fillListCells[opts, asList @ Lookup[meta, "RelatedSymbols", Lookup[meta, "SeeAlso", {}]]],
        "Related Resource Objects", fillListCells[opts, asList @ Lookup[meta, "RelatedResources", {}]],
        "Categories",
            If[ KeyExistsQ[meta, "Categories"],
                fillCheckbox["Categories", asList @ meta["Categories"], Lookup[data, "resourceType", "Function"]],
                slotDefault[opts]
            ],
        "CompatibilityOperatingSystem",
            If[ KeyExistsQ[meta, "OperatingSystems"],
                fillCheckbox["CompatibilityOperatingSystem",
                    Lookup[$osCanonical, ToLowerCase /@ asList[meta["OperatingSystems"]], Nothing]],
                slotDefault[opts]
            ],
        "CompatibilityEvaluationEnvironment",
            If[ KeyExistsQ[meta, "Environments"],
                fillCheckbox["CompatibilityEvaluationEnvironment", asList @ meta["Environments"]],
                slotDefault[opts]
            ],
        "CompatibilityCloudSupport",
            If[ KeyExistsQ[meta, "CloudSupport"],
                fillCheckbox["CompatibilityCloudSupport", If[TrueQ @ meta["CloudSupport"], {True}, {}]],
                slotDefault[opts]
            ],
        "Function", functionSlot[opts, data["defCode"]],
        "HeroImage", heroSlot[opts, data["sections"]],
        "Usage", usageSlot[opts, data["sections"]],
        "Notes", notesSlot[opts, data["sections"]],
        "Details", notesSlot[opts, data["sections"]],
        "LongDescription", fillTextDataCells[opts, rawSectionText[data["sections"], "usage"]],
        "PrimaryContext", fillTextCells[opts, Lookup[meta, "Context", ""]],
        "Examples", examplesSlot[opts, data["sections"]],
        "ExampleNotebook", exampleNotebookSlot[opts, data["sections"]],
        "VerificationTests", testsSlot[opts, data["sections"]],
        "Author Notes",
            With[{an = sectionText[data["sections"], "author notes"]},
                If[an === "", slotDefault[opts], {cleanCell @ ReplacePart[First[slotDefault[opts]], 1 -> an]}]
            ],
        "CompatibilityFeatures",
            If[ KeyExistsQ[meta, "Features"],
                fillCheckbox["CompatibilityFeatures", asList @ meta["Features"]],
                slotDefault[opts]
            ],
        "CompatibilityWolframLanguageVersionRequired",
            fillTextCells[opts, Lookup[meta, "WolframVersion", "14.0+"]],
        (* Data Repository: statistical-metadata fields. Each is a Text cell; accept
           either the SMD-prefixed key or the cleaner alias (Author / Title / ...). *)
        "SMDAuthor", fillTextCells[opts, Lookup[meta, "Author", Lookup[meta, "SMDAuthor", Lookup[meta, "ContributedBy", ""]]]],
        "SMDTitle", fillTextCells[opts, Lookup[meta, "Title", Lookup[meta, "SMDTitle", Lookup[meta, "Name", ""]]]],
        "SMDDate", fillTextCells[opts, Lookup[meta, "Date", Lookup[meta, "SMDDate", ""]]],
        "SMDPublisher", fillTextCells[opts, Lookup[meta, "Publisher", Lookup[meta, "SMDPublisher", ""]]],
        "SMDGeographicCoverage", fillTextCells[opts, Lookup[meta, "GeographicCoverage", Lookup[meta, "SMDGeographicCoverage", ""]]],
        "SMDTemporalCoverage", fillTextCells[opts, Lookup[meta, "TemporalCoverage", Lookup[meta, "SMDTemporalCoverage", ""]]],
        "SMDLanguage", fillTextCells[opts, Lookup[meta, "Language", Lookup[meta, "SMDLanguage", ""]]],
        "SMDRights", fillTextCells[opts, Lookup[meta, "Rights", Lookup[meta, "SMDRights", ""]]],
        "Citation",
            fillTextCells[opts, Lookup[meta, "Citation", sectionText[data["sections"], "citation"]]],
        "ContentTypes",
            If[ KeyExistsQ[meta, "ContentTypes"],
                fillCheckbox["ContentTypes", asList @ meta["ContentTypes"], Lookup[data, "resourceType", "Data"]],
                slotDefault[opts]
            ],
        "SubmissionNotes",
            With[{sn = Lookup[meta, "SubmissionNotes", ""]},
                If[sn === "", slotDefault[opts], fillTextCells[opts, sn]]
            ],
        (* === Prompt Repository slots ===
           PromptTemplate is the prompt body (a "## Prompt" section of plain prose).
           The optional WL slots (PersonaIcon, CellProcessingFunction, ...) pull
           the first code block of the matching section into the template's input
           cell. SampleChat / Examples / Notes / Usage reuse the existing helpers. *)
        "PromptTemplate", proseSectionSlot[opts, data["sections"], "prompt", "Text"],
        "PersonaIcon", codeSlot[opts, data["sections"], "persona icon"],
        "CellProcessingFunction", codeSlot[opts, data["sections"], "cell processing function"],
        "CellPostEvaluationFunction", codeSlot[opts, data["sections"], "cell post evaluation function"],
        "PromptInterpreter", codeSlot[opts, data["sections"], "output interpreter"],
        "Tools", codeSlot[opts, data["sections"], "llm tools"],
        "LLMConfigurationExtra", codeSlot[opts, data["sections"], "llm configuration"],
        "SampleChat", multiCodeSlot[opts, data["sections"], "chat examples"],
        "Topics", fillListCells[opts, asList @ Lookup[meta, "Topics", {}]],
        (* === LLMTool slots ===
           A Tool resource exposes a callable LLMTool with a name +
           one-sentence ToolDescription (used by the model to decide whether to
           call it), a parameter spec, and the actual function body. Three of
           the slots take one code block each from the matching named section. *)
        "ToolDescription", fillTextDataCells[opts, sectionText[data["sections"], "tool description"]],
        "ToolParameters", codeSlot[opts, data["sections"], "tool parameters"],
        "ToolFunction", codeSlot[opts, data["sections"], "tool function"],
        "ToolAppearanceRules", codeSlot[opts, data["sections"], "tool appearance"],
        (* === Demonstration slots ===
           A Demonstration's content is split across named sections rather than the
           Function template's TemplateSlots: Caption / Initialization / Manipulate /
           Snapshots / Details / References each map to one slot. AuthorNames takes
           a frontmatter list (one cell per author item, falling back to ContributedBy
           for the common single-author case). RelatedDemonstrations is the
           "see also" of other Demos. *)
        "CaptionCells", proseSectionSlot[opts, data["sections"], "caption", "Text"],
        "InitializationCode", codeSlot[opts, data["sections"], "initialization"],
        "ManipulateGroup", manipulateSlot[opts, data["sections"]],
        "SnapshotGroup", multiCodeSlot[opts, data["sections"], "snapshots"],
        "AuthorNames",
            With[{vs = asList @ Lookup[meta, "AuthorNames", Lookup[meta, "ContributedBy", ""]]},
                fillListCells[opts, DeleteCases[vs, ""]]
            ],
        "DetailCells", proseSectionSlot[opts, data["sections"], "details", "Text"],
        "ReferenceCells", proseSectionSlot[opts, data["sections"], "references", "Text"],
        "RelatedDemonstrations", fillListCells[opts, asList @ Lookup[meta, "RelatedDemonstrations", {}]],
        "ExternalLinks", fillLinkCells[opts, asList @ Lookup[meta, "Links", {}]],
        "CompatibilityARSupport",
            If[ KeyExistsQ[meta, "ARSupport"],
                fillCheckbox["CompatibilityARSupport", If[TrueQ @ meta["ARSupport"], {True}, {}]],
                slotDefault[opts]
            ],
        _, slotDefault[opts]
    ]
]

(* === documentation-page builders (Symbol / Guide) ===
   These templates are styled placeholders (no TemplateSlot): we start from the
   authoring template (which carries the page stylesheet + docked Build toolbar)
   and replace placeholder cells, then seed the build metadata. DocsBuild later
   adds the AnchorBar / FooterCell. *)

$docResourceDir := FileNameJoin[{$InstallationDirectory, "AddOns", "Applications", "DocumentationTools", "FrontEnd", "TextResources"}]

docTemplate[file_String] := Get[FileNameJoin[{$docResourceDir, file}]]

(* Doc-page placeholder cells (ObjectName / GuideTitle / GuideAbstract / Title)
   hold prose that can carry the same inline markup other prose does -
   backticks, bold / italic / strike, math, links. headingText runs the value
   through inlineTextData and wraps the result as TextData (or keeps the bare
   string when nothing matched), so a "## Abstract" paragraph with
   "[Accessibility](paclet:guide/Accessibility)" or "`ColorConvert`" renders
   the link / code span instead of dumping the literal markdown into the cell. *)
fillDocString[nb_, style_String, value_String] := If[ value === "",
    nb,
    nb /. Cell["XXXX", style, o___] :> Cell[headingText[value], style, o]
]

(* replace the placeholder cells of a style with one cell per item (first match
   expands to all items; any further placeholders of that style are dropped) *)
fillDocList[nb_, style_String, items_List] := Block[{vals = DeleteCases[items, ""], first = True},
    If[ vals === {},
        nb,
        nb /. Cell["XXXX", style, o___] :> If[ first,
            first = False; Sequence @@ Map[Cell[#, style, o] &, vals],
            Sequence @@ {}
        ]
    ]
]

(* a resolved documentation link, e.g. paclet:Wolfram/AccessibleColors/ref/WCAGLevel *)
docLinkCell[name_String, uri_String] :=
    Cell[BoxData[ButtonBox[name, BaseStyle -> "Link", ButtonData -> "paclet:" <> uri]], "InlineFormula"]

(* the link target for a See Also / More About entry. A System symbol (e.g.
   StandardRed, LightDarkSwitched) points at its system ref page; a related guide
   that is not the paclet's own (e.g. Color, Accessibility) points at the system
   guide; otherwise the link is into the paclet (the paclet's own guide is taken
   to be the last segment of Pub/Name). *)
linkURI[name_String, paclet_String, kind_String] := Which[
    kind === "ref" && symbolInContextQ[name, "System`"] && ! symbolInContextQ[name, $docContext],
        "ref/" <> name,
    kind === "guide" && paclet =!= "" && name =!= Last[StringSplit[paclet, "/"]],
        "guide/" <> name,
    True,
        paclet <> "/" <> kind <> "/" <> name
]

(* a related-guide / related-tutorial link cell: a Link ButtonBox in TextData *)
guideLinkContent[name_String, paclet_String, kind_String] :=
    TextData[ButtonBox[name, BaseStyle -> "Link", ButtonData -> "paclet:" <> linkURI[name, paclet, kind]]]

(* fill a style's XXXX placeholders with one cell per given content expression *)
fillDocCells[nb_, style_String, contents_List] := Block[{vals = contents, first = True},
    If[ vals === {},
        nb,
        nb /. Cell["XXXX", style, o___] :> If[ first,
            first = False; Sequence @@ Map[Cell[#, style, o] &, vals],
            Sequence @@ {}
        ]
    ]
]

linkRowCell[names_List, style_String, paclet_String, kind_String] := Cell[
    TextData @ Riffle[
        Map[docLinkCell[#, linkURI[#, paclet, kind]] &, names],
        " \[FilledVerySmallSquare] "
    ],
    style
]

(* === usage line rendering (matches reference-page formatting) === *)

(* prose of a section without stripping inline-code backticks *)
rawSectionText[sections_, key_] := StringRiffle[
    Cases[Lookup[sections, key, {}], b_ /; b["Type"] === "Prose" :> b["Text"]],
    " "
]

(* The DocumentationTools "Template Input" button parses the selected text into
   InlineFormula boxes (arguments italic, c$1 subscripts, ...) and lets
   DocumentationBuild linkify the known symbols at build time. The button itself
   (DocumentationTools`FunctionTemplate) is coupled to the front-end selection;
   the transformation under it is DocumentationTools`Private`ParseTextTemplate,
   which takes a plain string and the documented object's name. We call that
   directly for every `code` span, so the boxes match the button exactly. *)

(* the documented symbol's name, its paclet, and its context, set per build. The
   name is passed to ParseTextTemplate (to resolve sym::tag); the paclet+context
   pair turns symbol-name tokens into reference links. *)
$docName = ""
$docPaclet = ""
$docContext = ""
$docTemplate = ""

(* Subscripts in a usage signature use the portable HTML form "x<sub>i</sub>" (works
   in every markdown renderer and on GitHub), with "x~i~" accepted as the Pandoc
   shorthand. Both forms are rewritten to ParseTextTemplate's "x$i" template form
   so its existing subscript handling does the rest. *)
mdToTemplateSubs[s_String] := StringReplace[s, {
    "<sub>" ~~ i:Shortest[Except["<"]..] ~~ "</sub>" :> "$" <> i,
    "~" ~~ i:Shortest[Except["~"]..] ~~ "~" :> "$" <> i
}]

templateBox[code_String] := Block[{boxes, prepped = mdToTemplateSubs[StringTrim[code]]},
    Needs["DocumentationTools`"];
    boxes = Quiet @ UsingFrontEnd @ DocumentationTools`Private`ParseTextTemplate[prepped, $docName];
    (* fall back to a plain parse if the front-end template parse is unavailable *)
    If[ FreeQ[boxes, $Failed] && (StringQ[boxes] || MatchQ[Head[boxes], RowBox | StyleBox | SubscriptBox | SuperscriptBox | FractionBox | SqrtBox]),
        boxes,
        inputBoxes[prepped]
    ]
]

(* A "<code>...</code>" span: strip the markdown link / italic wrappers in the
   inner signature, run it through the same templateBox pipeline a Usage
   signature uses (italic args via ParseTextTemplate), and wrap the result in
   a single InlineFormula cell so the code styling covers the whole span -
   brackets included - and not just the linked head. The leading head is
   wrapped in a paclet-link ButtonBox via inferURL when the name resolves
   (in $docContext or System`); ParseTextTemplate by itself does not link a
   page's own symbol, but a "<code>[Self]()</code>" reference should still
   render as a tappable link to the symbol's own ref page. *)
(* unescape markdown's backslash-punctuation in a prose-bearing context (link
   labels, <code>...</code> bodies). Wolfram named-character escapes
   ("\[Theta]", "\[CircleTimes]", ...) share the leading "\[" with markdown's
   "\[" escape for a literal "[", so the Wolfram-name rule runs FIRST: at a
   "\[CircleTimes]" position it matches and rebuilds the escape verbatim,
   blocking the punctuation rule from eating the "\" and turning the kernel
   char into a stray "[CircleTimes]". *)
unescapeMarkdownPunctuation[s_String] := StringReplace[s, {
    "\\[" ~~ name : (LetterCharacter ..) ~~ "]" :> "\\[" <> name <> "]",
    "\\" ~~ c : PunctuationCharacter :> c
}]

codeInlineCell[inner_String] := Block[{sig, head, url, boxes, unescaped},
    (* "<code>...</code>" content lets markdown formatting through (links,
       italics, math), so backslash-punctuation escapes inside it are markdown
       source escapes and unescape before any further processing - same rule
       inlineTextData applies to prose. Without this, an authored "\*" inside
       <code> would land in the .nb as literal "\*" instead of "*", which a
       markdown viewer renders as just "*" but the notebook would show the
       backslash. Backticked spans skip this because backticks freeze content
       by design - "\*" in `` `code` `` is meant to be literal. *)
    unescaped = unescapeMarkdownPunctuation[inner];
    sig = mathArgsToTemplate @ unwrapMarkdownSig @ unescaped;
    head = First[StringCases[sig,
        StartOfString ~~ h : ((LetterCharacter | "$") ~~ (WordCharacter | "$" | "`") ...) :> h, 1], ""];
    url = If[head =!= "", inferURL[head], None];
    boxes = templateBox[sig];
    If[ url =!= None,
        boxes = Replace[boxes, {
            s_String /; s === head :> ButtonBox[s, BaseStyle -> "Link", ButtonData -> url],
            RowBox[{s_String /; s === head, rest___}] :>
                RowBox[{ButtonBox[s, BaseStyle -> "Link", ButtonData -> url], rest}]
        }]
    ];
    Cell[BoxData @ boxes, "InlineFormula"]
]

symbolInContextQ[name_String, ctx_String] := ctx =!= "" &&
    StringMatchQ[name, (LetterCharacter | "$") ~~ (WordCharacter | "$") ...] &&
    Quiet[Names[ctx <> name] =!= {}]

(* drop every ButtonBox link wrapper, keeping its content. ParseTextTemplate
   eagerly links any System symbol it recognizes (Notebook, ResourceFunction,
   ...), which renders as ugly inline links - especially a whole expression like
   ResourceFunction["..."]. We strip those so a usage signature reads as code. *)
stripLinks[boxes_] := boxes //. ButtonBox[content_, ___] :> content

(* prose inline `code`: if the body is a single known symbol (in $docContext
   or System`), auto-link it to its ref page - so authors can write `Range` or
   `WCAGContrastRatio` and get the same clickable code-styled link the
   explicit "[`Name`](paclet:Pub/Pkg/ref/Name)" form produces, no need to
   spell the URI by hand. Multi-token bodies ("Range[5]"), names the kernel
   does not know (a paragraph-locale variable like `x`), and anything that
   does not look like an identifier pass through as plain InlineFormula -
   the bare-string fallback inputBoxes builds. *)
codeToInline[code_String] := Block[{trimmed = StringTrim[code], url},
    url = If[symbolLikeQ[trimmed] && ! StringContainsQ[trimmed, "`" | "[" | " "],
        inferURL[trimmed], None];
    If[ url =!= None,
        Cell[BoxData[ButtonBox[trimmed, BaseStyle -> "Link", ButtonData -> url]], "InlineFormula"],
        Cell[BoxData[inputBoxes[code]], "InlineFormula"]
    ]
]

(* double-backtick ``code`` -> the palette's "Code (Inline)": a literal,
   non-linkified monospace span (InlineCode), unlike Template Input. *)
(* a double-backtick verbatim span. CommonMark keeps the spaces just inside the
   backticks (`` `x` `` -> " `x` "), but those padding spaces trip the notebook
   analysis "extra whitespace" check, so trim them. *)
literalCodeInline[code_String] := Cell[BoxData[StyleBox[StringTrim[code], "InlineCode"]], "InlineCode"]

(* inline emphasis -> styled text runs. Bold is FontWeight, strikethrough a
   FontVariation; italic keeps the "TI" (text-italic) style usage descriptions
   already mark arguments with. The styled content is a plain string (not re-parsed),
   so a single emphasis level is supported, which covers ordinary prose. *)
(* Wrap a single inlineTextData element (a string, StyleBox, InlineFormula
   Cell, ButtonBox, ...) with one more layer of styling, merging into any
   existing StyleBox / Cell options so a nested "**$x$**" produces an
   InlineFormula whose own option list carries the bold attribute rather
   than a hopeless StyleBox-of-Cell. Hyperlinks pass through unchanged -
   inheriting a parent bold would clobber the link's own styling. *)
wrapStyle[s_String, opts_List] := StyleBox[s, Sequence @@ opts]
wrapStyle[StyleBox[c_, existing___], opts_List] := StyleBox[c, existing, Sequence @@ opts]
wrapStyle[Cell[content_, style_String, cellOpts___], opts_List] :=
    Cell[content, style, cellOpts, Sequence @@ opts]
wrapStyle[ButtonBox[args___], _] := ButtonBox[args]
wrapStyle[other_, _] := other

(* Bold / italic / strike runs that may carry other inline markup ("**$x$**",
   "***`code`***", "~~bold $y$~~", ...) recursively re-enter inlineTextData
   on the inner text so any math / code / link spans are processed first;
   the formatting is then distributed across each resulting element via
   wrapStyle. Returning a Sequence keeps the surrounding StringSplit's
   result list flat. *)
emWith[s_String, opts_List] := Sequence @@ Map[wrapStyle[#, opts] &, inlineTextData[s]]

emBoldBox[s_String] := emWith[s, {FontWeight -> "Bold"}]
emItalicBox[s_String] := emWith[s, {"TI"}]
emBoldItalicBox[s_String] := emWith[s, {"TI", FontWeight -> "Bold"}]
emStrikeBox[s_String] := emWith[s, {FontVariations -> {"StrikeThrough" -> True}}]

(* A heading's text can carry the same inline markup prose does - backticks,
   bold, italic, math, links. Run it through inlineTextData and wrap the
   result as TextData so a "## A `foo` heading" or "## Bold **$x$**" renders
   the code span / bold math correctly. If the result is a single plain
   string, keep it bare - the simple "## Plain heading" stays Cell["Plain
   heading", "Section"] and Symbol-page tooling expecting a string content
   keeps working. *)
headingText[text_String] := Block[{td = inlineTextData[text]},
    If[Length[td] == 1 && StringQ[td[[1]]], td[[1]], TextData[td]]
]

(* Pandoc / GFM markdown subscript "x~n~" and superscript "x^n^". The script is
   rendered as a one-character formula cell (SubscriptBox / SuperscriptBox with an
   empty base), which sits inline at the right baseline in TextData. *)
proseSubBox[s_String] := Cell[BoxData[SubscriptBox["", s]], "InlineFormula"]
proseSupBox[s_String] := Cell[BoxData[SuperscriptBox["", s]], "InlineFormula"]

(* underscore emphasis (_em_, __strong__), applied to a plain prose run *after* the
   main split has pulled out code / links / math. CommonMark only treats underscores
   as emphasis at word boundaries, so a snake_case identifier in prose is left alone;
   enforce that with lookarounds, then split on private-use sentinels (the regex
   replacement string cannot itself build boxes). *)
underscoreEm[s_String] := If[! StringContainsQ[s, "_"], {s},
    StringSplit[
        StringReplace[s, {
            RegularExpression["(?<![A-Za-z0-9_])__(\\S|\\S.*?\\S)__(?![A-Za-z0-9_])"] -> "\:f8f1$1\:f8f2",
            RegularExpression["(?<![A-Za-z0-9_])_(\\S|\\S.*?\\S)_(?![A-Za-z0-9_])"] -> "\:f8f3$1\:f8f4"
        }],
        {
            "\:f8f1" ~~ c : Shortest[__] ~~ "\:f8f2" :> emBoldBox[c],
            "\:f8f3" ~~ c : Shortest[__] ~~ "\:f8f4" :> emItalicBox[c]
        }
    ]
]

(* an inline image ![alt](src): embed the imported graphic, or, when it cannot be
   loaded (e.g. a path relative to a base this context does not have), fall back to a
   plain link so the text is never left with a stray "!" the way an unhandled image
   span would be. *)
inlineImage[alt_String, src_String] := Block[{img = Quiet @ Import[src]},
    If[ MatchQ[img, _Image | _Graphics | _Legended | _Graphics3D],
        Cell[BoxData @ ToBoxes[img], "InlineFormula"],
        linkButton[If[StringTrim[alt] === "", src, alt], src]
    ]
]

(* $math$ -> inline math; $$math$$ -> centered display math. The content is TeX
   (LaTeX math notation). The Wolfram`Parser`LaTeX` paclet (when installed)
   is preferred - its LaTeXMathParse handles \mathbb / \frac / big operators
   / Greek / named symbols properly. Fall back to ImportString[..., "TeX"]
   (the built-in importer that drops styling) when the paclet isn't
   available, and to a Wolfram-expression parse if that also fails. *)

texBoxes[math_String] :=
    Block[{r = wolframParserTeX[math]},
        If[ r =!= $Failed, r, texBoxesViaImport[math] ]
    ]

wolframParserTeX[math_String] :=
    If[ Length[Names["Wolfram`Parser`LaTeX`LaTeXMathParse"]] === 0,
        $Failed,
        Block[{r = Quiet @ Check[
            Symbol["Wolfram`Parser`LaTeX`LaTeXMathParse"][math],
            $Failed
        ]},
            If[MatchQ[r, _ParseError | $Failed | _Failure], $Failed, r]
        ]
    ]

texBoxesViaImport[math_String] :=
    Block[{nb = Quiet @ ImportString["$" <> math <> "$", "TeX"]},
        If[ MatchQ[nb, _Notebook],
            FirstCase[nb, Cell[BoxData[b_], ___] :> b, $Failed, Infinity],
            $Failed
        ]
    ]

mathInline[math_String] := Block[{boxes = texBoxes[math]},
    If[ boxes === $Failed,
        Cell[BoxData[FormBox[inputBoxes[math], TraditionalForm]], "InlineFormula"],
        Cell[BoxData[boxes], "InlineFormula"]
    ]
]

(* $$ ... $$ on its own line (or fenced across lines) -> a centered "DisplayFormula"
   cell. Stylesheets vary in whether DisplayFormula centers within the cell or
   left-indents it, so wrap the formula in a PaneBox that takes the full cell width
   and centers its content; that way the equation sits horizontally centered the way
   a markdown viewer renders display math, in any stylesheet. *)
mathBlockCell[math_String] := With[{
    boxes = Replace[texBoxes[math], $Failed -> FormBox[inputBoxes[math], TraditionalForm]]
},
    Cell[BoxData[PaneBox[boxes, ImageSize -> Full, Alignment -> Center]], "DisplayFormula"]
]

(* markdown links: [text](paclet:Pub/Name/ref/Sym) -> a reference Link (palette
   "Custom URI"); [text](http...) -> a Hyperlink (palette "Link to URL"). The
   ButtonBox sits directly in the surrounding TextData (a text hyperlink), not
   wrapped in Cell[BoxData[...], "InlineFormula"] - the latter renders the link
   text in code/formula style instead of as an inline prose link.

   A `code`-wrapped label is the explicit "link this symbol" annotation: it renders
   the label in code/formula style as the link, i.e. a reference link the way
   See Also entries look. So [`WCAGContrastRatio`](paclet:.../ref/WCAGContrastRatio)
   is a code-styled symbol link, while [the docs](https://...) is a prose link. *)
linkButton[text_String, url_String] := If[
    StringStartsQ[url, "paclet:"],
    ButtonBox[text, BaseStyle -> "Link", ButtonData -> url],
    ButtonBox[text, BaseStyle -> "Hyperlink", ButtonData -> {URL[url], None}]
]

backtickedQ[text_String] := StringMatchQ[text, "`" ~~ ___ ~~ "`"]

(* a bare label is treated as a symbol name when it looks like one - a leading
   letter or "$" followed by letters / digits / context marks. Only used for the
   empty-target inferred form [Name](), so non-symbol prose hyperlinks like
   "[click here]()" still go through unchanged. *)
symbolLikeQ[text_String] := StringMatchQ[text, (LetterCharacter | "$") ~~ (WordCharacter | "$" | "`") ...]

linkInline[text_String, url_String] := Which[
    (* an empty target - [Symbol]() (canonical) or the legacy [`Symbol`]() form -
       infers the reference. The backtick wrapping is purely decorative here, so
       both render identically; bare prose labels with an empty target are left
       as literal text. *)
    url === "" && backtickedQ[text], linkInferred[StringTake[text, {2, -2}]],
    url === "" && symbolLikeQ[text], linkInferred[text],
    url === "", unescapeMarkdownPunctuation[text],
    (* a `code`-wrapped label is a code-styled reference link; backslash escapes
       inside the backticks are literal, so the stripped content is used as-is. *)
    backtickedQ[text], Cell[BoxData @ linkButton[StringTake[text, {2, -2}], url], "InlineFormula"],
    (* a plain label is an ordinary prose hyperlink; markdown's \<punct> escapes
       in the label (e.g. "[Wolfram\`Parser\`](paclet:...)") unescape before the
       ButtonBox so the displayed text doesn't keep the literal backslashes. *)
    True, linkButton[unescapeMarkdownPunctuation[text], url]
]

(* the ref-page URI a bare symbol name resolves to: a name in the documented
   paclet's context links to its paclet ref page, a System symbol to its system
   ref page; anything else does not resolve. *)
inferURL[name_String] := Which[
    symbolInContextQ[name, $docContext] && $docPaclet =!= "", "paclet:" <> $docPaclet <> "/ref/" <> name,
    symbolInContextQ[name, $docContext], "paclet:ref/" <> name,
    symbolInContextQ[name, "System`"], "paclet:ref/" <> name,
    True, None
]

(* the public web URL a bare symbol name resolves to. Mirrors inferURL but for the
   GitHub-renderable twin: paclet symbols point at their PacletRepository page, System
   symbols at the Wolfram Language reference site. *)
inferWebURL[name_String] := Which[
    symbolInContextQ[name, $docContext] && $docPaclet =!= "",
        "https://resources.wolframcloud.com/PacletRepository/resources/" <> $docPaclet <> "/ref/" <> name,
    symbolInContextQ[name, "System`"],
        "https://reference.wolfram.com/language/ref/" <> name <> ".html",
    True, None
]

(* translate a "paclet:..." URI (the notebook's internal link target) to the public
   web URL of the same ref/guide/tutorial. Used when serialising the markdown twin
   so the rendered page has working links on GitHub. *)
pacletToWebURL[uri_String] := Block[{rest = StringTrim[uri], paclet, kind, name, parts},
    rest = StringDelete[rest, StartOfString ~~ "paclet:"];
    parts = StringSplit[rest, "/"];
    Which[
        Length[parts] === 2 && MemberQ[{"ref", "guide", "tutorial"}, parts[[1]]],
            "https://reference.wolfram.com/language/" <> parts[[1]] <> "/" <> parts[[2]] <> If[parts[[1]] === "ref", ".html", ""],
        Length[parts] >= 3 && MemberQ[{"ref", "guide", "tutorial"}, parts[[-2]]],
            paclet = StringRiffle[parts[[;; -3]], "/"];
            kind = parts[[-2]]; name = parts[[-1]];
            "https://resources.wolframcloud.com/PacletRepository/resources/" <> paclet <> "/" <> kind <> "/" <> name,
        True, "paclet:" <> rest
    ]
]

(* rewrite inferred and paclet-scheme links in a prose run to their public web URLs
   for the GitHub-renderable twin. The notebook keeps the paclet: targets unchanged
   (linkInferred / linkInline). Three forms get expanded:
     [`Symbol`]            (bare inferred)         -> [`Symbol`](https://...)
     [`Symbol`]()          (explicit empty)        -> [`Symbol`](https://...)
     [label](paclet:...)   (explicit paclet URI)   -> [label](https://...)
   Unresolvable symbols (not in $docContext or System`) and non-paclet URLs are left
   alone, so a stray "[`SomeRandomThing`]" passes through unchanged. *)
resolveWebRefs[text_String] := Block[{s = text, resolveLink},
    (* step 1: normalise the legacy [`X`] without parens to [`X`]() so the inferred
       URL resolves uniformly with the canonical [`X`]() / [X]() forms. *)
    s = StringReplace[s, RegularExpression["\\[`([^`\\n]+)`\\](?!\\()"] -> "[`$1`]()"];
    (* step 2: rewrite every inferred link [label](url) where label is either bare
       (the canonical form) or backtick-wrapped (the legacy form). For an empty url
       look up the web URL from the bare symbol name; for "paclet:..." translate to
       the public web URL. *)
    resolveLink[sym_, url_] := Which[
        StringStartsQ[url, "paclet:"], pacletToWebURL[url],
        url === "", With[{w = inferWebURL[sym]}, If[w === None, "", w]],
        True, url
    ];
    s = StringReplace[s, {
        "[`" ~~ sym : Shortest[Except["`" | "\n"] ..] ~~ "`](" ~~ url : Shortest[Except[")"] ...] ~~ ")" :>
            "[`" <> sym <> "`](" <> resolveLink[sym, url] <> ")",
        "[" ~~ sym : Shortest[Except["]" | "`" | "\n"] ..] ~~ "](" ~~ url : Shortest[Except[")"] ...] ~~ ")" :>
            "[" <> sym <> "](" <> resolveLink[sym, url] <> ")"
    }];
    s
]

(* an "empty" backtick link [`Name`] (brackets, no URL) is the convenient symbol
   annotation: infer the ref URL from the name and render a code-styled reference
   link, the way auto-linking used to. Linking only ever happens on backticked
   content - a bare [Name] is left as literal text. If the name does not resolve,
   fall back to plain inline code. *)
linkInferred[name_String] := Block[{url = inferURL[name]},
    If[ url === None,
        codeToInline[name],
        Cell[BoxData @ ButtonBox[name, BaseStyle -> "Link", ButtonData -> url], "InlineFormula"]
    ]
]

inlineTextData[text_String] := Replace[
    (* underscore emphasis runs last, on the plain-text runs the main split leaves
       behind, so its word-boundary check never sees code / link / math content. *)
    Replace[
        StringSplit[text, {
            (* a backslashed ASCII punctuation is that literal char (so \* is not
               emphasis); listed first so the escape wins before the marker rules. *)
            "\\" ~~ c : PunctuationCharacter :> c,
            (* "<code>...</code>" - the canonical inline-HTML wrapper for a code-styled
               span that may contain a markdown link and italic args inside. Pandoc /
               GitHub use it because markdown forbids nested formatting inside a
               backticked code span. The whole inner span is rendered as a single
               InlineFormula cell so the code styling wraps everything - the linked
               head AND the surrounding brackets AND the italic args - not just the
               linked head; the previous strip-and-recurse left the brackets and
               args as plain text in the surrounding TextData. The signature is fed
               through templateBox (the same pipeline usageStatement uses), so a
               head in $docContext or System` gets its paclet link automatically. *)
            "<code>" ~~ inner : Shortest[__] ~~ "</code>" :> codeInlineCell[inner],
            (* an inline image is a link with a leading "!"; match it before the link *)
            "![" ~~ a : Shortest[Except["]"] ...] ~~ "](" ~~ u : Shortest[Except[")"] ..] ~~ ")" :> inlineImage[a, u],
            (* allow an empty URL "[`Symbol`]()" - that is the pandoc / GitHub-renderable
               inferred form (an empty link is at least a recognisable link element in
               markdown viewers); linkInline routes it to linkInferred. The bare
               "[`Symbol`]" without parens is *not* auto-linked: that follows strict
               markdown semantics ("[X]" alone is literal bracketed text) and avoids
               surprising linkifying of expressions like "[`Import`]["doc.md"]" where
               the author wanted only inline code. *)
            "[" ~~ t : Shortest[Except["]"] ..] ~~ "](" ~~ u : Shortest[Except[")"] ...] ~~ ")" :> linkInline[t, u],
            "``" ~~ c : Shortest[__] ~~ "``" :> literalCodeInline[c],
            "`" ~~ c : Shortest[__] ~~ "`" :> codeToInline[c],
            "$$" ~~ m : Shortest[Except["$"] ..] ~~ "$$" :> mathInline[m],
            "$" ~~ m : Shortest[Except["$"] ..] ~~ "$" :> mathInline[m],
            "~~" ~~ s : Shortest[__] ~~ "~~" :> emStrikeBox[s],
            (* portable subscript "H<sub>2</sub>O" and superscript "2<sup>10</sup>" -
               HTML tags renderers agree on. The single-tilde / single-caret Pandoc
               shorthands ("H~2~O", "2^10^") are accepted too; listed after "~~" so
               strikethrough wins at a doubled-tilde position. *)
            "<sub>" ~~ s : Shortest[Except["<"] ..] ~~ "</sub>" :> proseSubBox[s],
            "<sup>" ~~ s : Shortest[Except["<"] ..] ~~ "</sup>" :> proseSupBox[s],
            "~" ~~ s : Shortest[Except["~"|" "] ..] ~~ "~" :> proseSubBox[s],
            "^" ~~ s : Shortest[Except["^"|" "] ..] ~~ "^" :> proseSupBox[s],
            "***" ~~ s : Shortest[__] ~~ "***" :> emBoldItalicBox[s],
            "**" ~~ s : Shortest[__] ~~ "**" :> emBoldBox[s],
            (* *word* -> italic: the StyleBox["TI"] form usage descriptions mark
               arguments with (not a formula cell) *)
            Verbatim["*"] ~~ i : (Except["*"] ..) ~~ Verbatim["*"] :> emItalicBox[i]
        }],
        s_String :> Sequence @@ underscoreEm[s],
        {1}
    ],
    (* a literal "..." in prose should be the single ellipsis character (the
       notebook analysis flags three dots); only the plain-text runs are touched. *)
    s_String :> StringReplace[s, "..." -> "\[Ellipsis]"],
    {1}
]

(* a Symbol page's "## Usage" prose, rendered as one Usage cell with its inline
   formatting. Backticked spans inside a usage line are signatures and argument
   references, so route them through templateBox (which italicises args and turns
   "~i~" into a subscript) instead of the literal codeToInline used elsewhere. *)
usageCell[rawUsage_String] := Block[{
    codeToInline = Function[c, Cell[BoxData[stripLinks @ templateBox[c]], "InlineFormula"]]
},
    Cell[
        TextData @ Prepend[inlineTextData[StringTrim[rawUsage]], Cell["   ", "ModInfo"]],
        "Usage"
    ]
]

(* a GitHub-flavored pipe table -> the same GridBox the palette inserts via
   "Insert Custom Table" / "2 Column" / "3 Column": outer style
   NColumnTableMod, with each row prefixed by a fixed Cell["      ", "ModInfo"]
   placeholder (the narrow modification-indicator column, always whitespace -
   NOT a slot for col-1 content) and the N content cells styled TableText.
   The cell style supplies dividers / alignment / spacing, so no inline
   GridBox options are needed. *)
tableModStyleFor[2] := "2ColumnTableMod"
tableModStyleFor[3] := "3ColumnTableMod"
tableModStyleFor[_] := None

modInfoPlaceholder = Cell["      ", "ModInfo"];

tableModRow[cells_List, ncol_Integer, opts___] := Prepend[
    Cell[TextData @ inlineTextData[#], "TableText", opts] & /@ PadRight[cells, ncol, ""],
    modInfoPlaceholder
]

(* Fallback for column counts the palette has no *TableMod style for (1 or
   >= 4). "TableNotes" is the table style the Function Repository / Paclet /
   Example definition-notebook docked cells insert, and exists in those
   stylesheets. The documentation stylesheets (Symbol / Guide / TechNote)
   and Default.nb do not define it, so a "TableNotes" cell renders unstyled
   / cramped there - switch to "Text" for those, which exists everywhere. *)
tableCellBox[text_String, opts___] := Cell[TextData @ inlineTextData[text], "TableText", opts]

tableGridRow[cells_List, ncol_Integer, opts___] :=
    tableCellBox[#, opts] & /@ PadRight[cells, ncol, ""]

$tableCellStyleFor := If[MemberQ[{"FunctionResource", "Paclet", "Example", "Data", "Prompt", "Demonstration"}, $docTemplate], "TableNotes", "Text"]

(* a pipe table renders as a *TableMod cell when the column count matches a
   palette-supported width (2 or 3); the header row is bolded for readability.
   Other widths fall through to a generic GridBox with inline dividers. *)
tableCell[block_] := Block[{ncol = Length[block["Header"]], modStyle = tableModStyleFor[Length[block["Header"]]], rows},
    If[modStyle =!= None,
        rows = Join[
            {tableModRow[block["Header"], ncol, FontWeight -> Bold]},
            tableModRow[#, ncol] & /@ block["Rows"]
        ];
        Cell[BoxData[GridBox[rows]], modStyle]
        ,
        rows = Join[
            {tableGridRow[block["Header"], ncol, FontWeight -> Bold]},
            tableGridRow[#, ncol] & /@ block["Rows"]
        ];
        Cell[BoxData[GridBox[rows,
            GridBoxAlignment -> {"Columns" -> {{Left}}, "Rows" -> {{Baseline}}},
            GridBoxDividers -> {"Columns" -> {{None}}, "Rows" -> {{True}}},
            GridBoxSpacings -> {"Columns" -> {{1.5}}, "Rows" -> {{0.7}}}
        ]], $tableCellStyleFor]
    ]
]

(* an inlined markdown image (![alt](path "title")) -> an image cell. The title is
   a *raw cell style* override (a "Text" style cell will not render its graphic on
   the deployed cloud page, so the default is "Output", the style the evaluated
   example images use); a documentation image wants "ExampleImage". The special
   title "papertear" keeps the "Output" style and adds the front end's Paper Tear
   background. *)
imageCell[block_] := With[{title = StringTrim @ Lookup[block, "Effect", ""]},
    Which[
        ToLowerCase[title] === "papertear",
            Cell[BoxData[ToBoxes @ block["Image"]], "Output", BackgroundAppearance -> "PaperTear"],
        title =!= "",
            Cell[BoxData[ToBoxes @ block["Image"]], title],
        True,
            Cell[BoxData[ToBoxes @ block["Image"]], "Output"]
    ]
]

docExampleCells[sections_] := Block[{cells = sectionCells[sections, "basic examples"], counter = 0},
    Catenate @ Map[
        block |-> (counter += 1; exampleIOFor[block, counter]),
        cells
    ]
]

(* fill the visible Categorization section cells (Entity Type / Paclet Name /
   Context / URI) from the frontmatter, keyed by their CellLabel. *)
fillCategorization[nb_, type_String, meta_] := Block[{
    vals = <|
        "Entity Type" -> type,
        "Paclet Name" -> Lookup[meta, "Paclet", ""],
        "Context" -> Lookup[meta, "Context", ""],
        "URI" -> Lookup[meta, "URI", ""]
    |>,
    filled, hasURI
},
    filled = nb /. Cell[c_, "Categorization", o___] :> With[{lbl = CellLabel /. Flatten[{o}]},
        If[ KeyExistsQ[vals, lbl] && vals[lbl] =!= "",
            Cell[vals[lbl], "Categorization", o],
            Cell[c, "Categorization", o]
        ]
    ];
    (* the base templates have no URI row; append one to the section *)
    hasURI = ! FreeQ[filled, Cell[_, "Categorization", a___] /; (CellLabel /. Flatten[{a}]) === "URI"];
    If[ vals["URI"] =!= "" && ! hasURI,
        filled = filled /. Cell[CellGroupData[{sec : Cell[_, "CategorizationSection", ___], body___}, st_], go___] :>
            Cell[CellGroupData[{sec, body, Cell[vals["URI"], "Categorization", CellLabel -> "URI"]}, st], go]
    ];
    filled
]

setDocMetadata[Notebook[cells_, o : OptionsPattern[]], meta_, type_String] := Block[{opts = Flatten[{o}], md, tr},
    md = {
        "title" -> Lookup[meta, "Name", Lookup[meta, "Title", ""]],
        "context" -> Lookup[meta, "Context", ""],
        "keywords" -> asList @ Lookup[meta, "Keywords", {}],
        "summary" -> Lookup[meta, "Description", ""],
        "paclet" -> Lookup[meta, "Paclet", ""],
        "uri" -> Lookup[meta, "URI", ""],
        "type" -> type,
        "index" -> True,
        "language" -> "en"
    };
    tr = Lookup[opts, TaggingRules, {}];
    tr = If[ ListQ[tr], Append[DeleteCases[tr, "Metadata" -> _], "Metadata" -> md], {"Metadata" -> md} ];
    Notebook[cells, TaggingRules -> tr, Sequence @@ DeleteCases[opts, _[TaggingRules, _]]]
]

(* markdown example-taxonomy sections -> the symbol page's ExampleSection titles *)
$extendedTitles = <|
    "scope" -> "Scope",
    "options" -> "Options",
    "applications" -> "Applications",
    "properties and relations" -> "Properties & Relations",
    "possible issues" -> "Possible Issues",
    "neat examples" -> "Neat Examples"
|>

extendedExampleCells[sectionBlocks_] := exampleContent[sectionBlocks, "ExampleText"]

(* populate the "More Examples" scaffold: each ExampleSection title is an
   InterpretationBox counter cell (it resets In[]/Out[] numbering). For sections
   we have content for, wrap the counter cell + content in a CellGroupData; drop
   the empty ones (incl. the Options group's XXXX ExampleSubsection placeholders),
   and drop the whole scaffold if nothing is populated. *)
fillExtendedExamples[nb_, sections_] := Block[{content},
    content = Association @ Map[
        $extendedTitles[#] -> extendedExampleCells[Lookup[sections, #, {}]] &,
        Select[Keys[$extendedTitles], KeyExistsQ[sections, #] &]
    ];
    content = Select[content, # =!= {} &];
    If[ content === <||>,
        Return[ nb /. Cell[CellGroupData[{Cell[_, "ExtendedExamplesSection", ___], ___}, ___], ___] :> Nothing ]
    ];
    nb /. {
        Cell[CellGroupData[{cnt : Cell[BoxData[InterpretationBox[Cell[title_String, "ExampleSection", ___], _]], "ExampleSection", ___], ___}, _], ___] :>
            With[{c = Lookup[content, title, {}]}, If[c === {}, Nothing, Cell[CellGroupData[Prepend[c, cnt], Open]]]],
        cnt : Cell[BoxData[InterpretationBox[Cell[title_String, "ExampleSection", ___], _]], "ExampleSection", ___] :>
            With[{c = Lookup[content, title, {}]}, If[c === {}, Nothing, Cell[CellGroupData[Prepend[c, cnt], Open]]]]
    }
]

symbolNotebook[data_] := Block[{meta = data["meta"], sections = data["sections"], nb, name, usage, notes, basicText, basicCells},
    nb = docTemplate["FunctionBaseTemplateExt.nb"];
    name = Lookup[meta, "Name", ""];
    usage = rawSectionText[sections, "usage"];
    notes = detailsCells[sections];
    nb = fillDocString[nb, "ObjectName", name];
    If[ usage =!= "",
        nb = nb /. Cell[_, "Usage", ___] :> usageCell[usage]
    ];
    If[ notes =!= {},
        nb = nb /. Cell[_, "Notes", ___] :> Sequence @@ notes
    ];
    (* load the documented paclet so a reader can run the examples *)
    If[ KeyExistsQ[meta, "Context"],
        nb = nb /. Cell[_, "ExampleInitialization", o___] :> Cell[BoxData[inputBoxes["Needs[\"" <> meta["Context"] <> "\"]"]], "ExampleInitialization", o]
    ];
    basicText = rawSectionText[sections, "basic examples"];
    basicCells = Join[
        If[basicText === "", {}, {Cell[TextData @ inlineTextData[basicText], "ExampleText"]}],
        docExampleCells[sections]
    ];
    (* the base template leaves PrimaryExamplesSection empty for the author;
       insert the basic example right after its header *)
    If[ basicCells =!= {},
        nb = nb /. Cell[ph_, "PrimaryExamplesSection", o___] :> Sequence[Cell[ph, "PrimaryExamplesSection", o], Sequence @@ basicCells]
    ];
    With[{paclet = Lookup[meta, "Paclet", ""], sa = asList @ Lookup[meta, "SeeAlso", {}], ma = asList @ Lookup[meta, "RelatedGuides", {}]},
        If[ sa =!= {} && paclet =!= "", nb = nb /. Cell[_, "SeeAlso", ___] :> linkRowCell[sa, "SeeAlso", paclet, "ref"] ];
        If[ ma =!= {} && paclet =!= "", nb = nb /. Cell[_, "MoreAbout", ___] :> linkRowCell[ma, "MoreAbout", paclet, "guide"] ]
    ];
    (* drop unfilled placeholders, including dangling FunctionPlaceholder links *)
    nb = nb /. {
        Cell["XXXX", _, ___] :> Nothing,
        Cell[BoxData["XXXX"], _, ___] :> Nothing,
        Cell[c_, _, ___] /; ! FreeQ[c, FrameBox["XXXX"]] :> Nothing
    };
    (* extended example sections (Scope/Options/...): each "More Examples" entry
       is an InterpretationBox counter cell that resets the In[]/Out[] numbering;
       wrap the ones we have content for in a CellGroupData with that content, and
       drop the empty ones (built pages omit empty sections - leaving the XXXX
       ExampleSubsection placeholders or bare counters makes the build fail). *)
    nb = fillExtendedExamples[nb, sections];
    setDocMetadata[fillCategorization[nb, "Symbol", meta], meta, "Symbol"]
]

(* the palette's "Inline Listing": a function-name chip linking to its ref page,
   the same box the Documentation Tools button produces. *)
guideFnChip[name_String, paclet_String] := Cell[
    BoxData[ButtonBox[name, BaseStyle -> "Link", ButtonData -> "paclet:" <> paclet <> "/ref/" <> name]],
    "InlineGuideFunction", TaggingRules -> {"PageType" -> "Function"}
]

(* a "## Functions" list item "`Sym` description" -> the docked "1-Line Function"
   template: a GuideText cell of TextData[{<chip>, " \[LongDash] ", <description>}],
   the chip linked to the symbol's ref page and the description rendered inline. *)
guideFunctionItem[item_String, paclet_String] := Block[{m = StringCases[item,
        StartOfString ~~ WhitespaceCharacter ... ~~ "`" ~~ s : Shortest[__] ~~ "`" ~~ r___ :> {s, r}, 1]},
    If[ m === {},
        Cell[TextData @ inlineTextData[item], "GuideText"],
        Cell[TextData @ Join[
            {guideFnChip[First @ First @ m, paclet], " \[LongDash] "},
            inlineTextData[StringTrim[Last @ First @ m]]
        ], "GuideText"]
    ]
]

guideFunctionCells[sections_, paclet_String] := Block[{items},
    items = Catenate @ Cases[Lookup[sections, "functions", {}], b_ /; b["Type"] === "List" :> b["Items"]];
    If[ items === {} || paclet === "", {}, Map[guideFunctionItem[#, paclet] &, items] ]
]

guideNotebook[data_] := Block[{meta = data["meta"], sections = data["sections"], nb, title, abstract, fnCells},
    nb = docTemplate["GuideBaseTemplateExt.nb"];
    title = Lookup[meta, "Name", Lookup[meta, "Title", ""]];
    abstract = sectionText[sections, "abstract"];
    If[ abstract === "", abstract = Lookup[meta, "Description", ""] ];
    nb = fillDocString[nb, "GuideTitle", title];
    nb = fillDocString[nb, "GuideAbstract", abstract];
    (* the Functions section: replace the GuideText / InlineGuideFunctionListing
       placeholders with one GuideText chip-led cell per "## Functions" item *)
    fnCells = guideFunctionCells[sections, Lookup[meta, "Paclet", ""]];
    If[ fnCells =!= {},
        nb = nb /. Cell[CellGroupData[{sec : Cell[_, "GuideFunctionsSection", ___], ___}, st_], go___] :>
            Cell[CellGroupData[Prepend[fnCells, sec], st], go]
    ];
    (* Related Guides are guide links *)
    With[{paclet = Lookup[meta, "Paclet", ""]},
        nb = fillDocCells[nb, "GuideMoreAbout", guideLinkContent[#, paclet, "guide"] & /@ asList @ Lookup[meta, "RelatedGuides", {}]]
    ];
    (* Related Links are labeled hyperlinks; the template has only the section
       header (no placeholder), so insert one GuideRelatedLinks cell per link. *)
    With[{links = asList @ Lookup[meta, "Links", {}]},
        If[ links =!= {},
            nb = nb /. Cell[c_, "GuideRelatedLinksSection", o___] :>
                Sequence[Cell[c, "GuideRelatedLinksSection", o], Sequence @@ Map[Cell[linkItemContent[#], "GuideRelatedLinks"] &, links]]
        ]
    ];
    nb = fillDocList[nb, "Keywords", asList @ Lookup[meta, "Keywords", {}]];
    nb = nb /. {
        Cell["XXXX", _, ___] :> Nothing,
        Cell[BoxData["XXXX"], _, ___] :> Nothing,        Cell[c_, _, ___] /; ! FreeQ[c, FrameBox["XXXX"]] :> Nothing
    };
    setDocMetadata[fillCategorization[nb, "Guide", meta], meta, "Guide"]
]

(* === TechNote (tutorial) builder ===
   A tech note is free-flowing prose + code, not fixed sections. Fill the Title,
   replace the template's body placeholders with the converted markdown (headings
   -> Section/Subsection, prose -> Text, wl -> Input/Output, tables, lists), and
   keep + fill the Related Guides / Related Tech Notes / Categorization / Keywords. *)
$tutorialHeadingStyle = <|2 -> "Section", 3 -> "Subsection", 4 -> "Subsubsection"|>

tutorialBody[blocks_] := Block[{counter = 0},
    Catenate @ Map[
        block |-> Switch[block["Type"],
            "Heading", If[block["Level"] <= 1, {}, {Cell[headingText[block["Text"]], Lookup[$tutorialHeadingStyle, block["Level"], "Subsubsection"]]}],
            "Prose", {Cell[TextData @ inlineTextData[block["Text"]], "Text"]},
            "List", listItemCells[block, "Item"],
            "Table", {tableCell[block]},
            "Quote", {quoteCell[block["Text"]]},
            "MathBlock", {mathBlockCell[block["Text"]]},
            "Image", {imageCell[block]},
            "Code", If[executableQ[block], (counter += 1; exampleIOFor[block, counter]), withCellFlag[block, {Cell[block["Code"], "Program"]}]],
            _, {}
        ],
        blocks
    ]
]

tutorialNotebook[data_] := Block[{meta = data["meta"], nb, title, body, paclet, ma, rt},
    nb = docTemplate["TechNoteBaseTemplateExt.nb"];
    title = Lookup[meta, "Title", Lookup[meta, "Name", ""]];
    nb = fillDocString[nb, "Title", title];
    body = tutorialBody[data["blocks"]];
    (* rebuild the Title group: title cell + our body + the two link-section groups *)
    nb = nb /. Cell[CellGroupData[{tc : Cell[_, "Title", ___], ___,
            tma : Cell[CellGroupData[{Cell[_, "TutorialMoreAboutSection", ___], ___}, _], ___],
            rtg : Cell[CellGroupData[{Cell[_, "RelatedTutorialsSection", ___], ___}, _], ___]}, st_], go___] :>
        Cell[CellGroupData[Join[{tc}, body, {tma, rtg}], st], go];
    paclet = Lookup[meta, "Paclet", ""];
    ma = asList @ Lookup[meta, "RelatedGuides", {}];
    rt = asList @ Lookup[meta, "RelatedTutorials", {}];
    If[ ma =!= {} && paclet =!= "", nb = nb /. Cell[_, "TutorialMoreAbout", ___] :> linkRowCell[ma, "TutorialMoreAbout", paclet, "guide"] ];
    If[ rt =!= {} && paclet =!= "", nb = nb /. Cell[_, "RelatedTutorials", ___] :> linkRowCell[rt, "RelatedTutorials", paclet, "tutorial"] ];
    nb = fillDocList[nb, "Keywords", asList @ Lookup[meta, "Keywords", {}]];
    nb = nb /. {
        Cell["XXXX", _, ___] :> Nothing,
        Cell[BoxData["XXXX"], _, ___] :> Nothing,
        Cell[c_, _, ___] /; ! FreeQ[c, FrameBox["XXXX"]] :> Nothing
    };
    setDocMetadata[fillCategorization[nb, "Tech Note", meta], meta, "Tech Note"]
]

(* === Overview (paclet table-of-contents) builder ===
   An Overview page is the high-level table of contents the paclet's
   Documentation index links to; in the FE the Documentation Tools palette
   builds one with GenerateOverview by walking each tech-note's headings and
   wrapping them in TOC* cells (Title -> TOCChapter, Section -> TOCSection, ...).
   For markdown we map heading depth directly:

       # Title          -> TOCDocumentTitle (once, at the top)
       ## Chapter       -> TOCChapter
       ### Section      -> TOCSection
       #### Subsection  -> TOCSubsection
       ##### …          -> TOCSubsubsection

   Each heading text may carry a markdown link (`[label](paclet:…)` or the
   inferred `[Name]()` form) - when present, the TOC cell renders the heading
   as a clickable ButtonBox to that target, the same shape GenerateOverview
   emits. List items inherit a "one level deeper than the previous heading"
   so a chapter+bulleted-list entries pattern groups cleanly:

       ## Symbols       -> TOCChapter "Symbols"
       - [A]()          -> TOCSection link to A
       - [B]()          -> TOCSection link to B

   Categorization (Entity Type = "Overview") and the Paclet/Context/URI rows
   come from the frontmatter (Paclet/Context/URI keys), same convention the
   Symbol / Guide / TechNote builders use. *)
$tocStyleMap = <|
    1 -> "TOCDocumentTitle",
    2 -> "TOCChapter",
    3 -> "TOCSection",
    4 -> "TOCSubsection",
    5 -> "TOCSubsubsection",
    6 -> "TOCSubsubsubsection"
|>
tocStyleFor[level_Integer] := Lookup[$tocStyleMap, level, "TOCSubsubsubsection"]

(* parse a heading / list-item text into either an inline-formatted heading
   or a ButtonBox linked target - so "[Name](paclet:Pub/Pkg/tutorial/Name)"
   and the inferred "[Name]()" form both render as clickable TOC entries,
   and plain headings (or `code`-styled ones) carry their inline markup
   (backticks, bold, italic, math) the same way every other heading does. *)
tocCellContent[text_String, paclet_String] := Block[{trimmed = StringTrim[text], m},
    m = StringCases[trimmed, StartOfString ~~ "[" ~~ label : Shortest[Except["]"] ..] ~~ "](" ~~ url : Shortest[Except[")"] ...] ~~ ")" ~~ EndOfString :> {label, url}, 1];
    If[ m === {},
        headingText[trimmed],
        With[{label = m[[1, 1]], url = m[[1, 2]]},
            ButtonBox[label, BaseStyle -> "Link",
                ButtonData -> If[ url === "",
                    (* inferred link: assume a tutorial in the documented paclet,
                       since this is the conventional shape for an overview entry. *)
                    "paclet:" <> If[paclet === "", label, paclet <> "/tutorial/" <> label],
                    If[StringStartsQ[url, "paclet:" | "http"], url, "paclet:" <> url]
                ]
            ]
        ]
    ]
]

tocCell[content_, style_String] := Cell[
    Switch[Head[content],
        String, content,
        TextData, content,
        _, TextData[content]
    ],
    style
]

(* Walk the block stream once and build a nested CellGroupData tree of TOC*
   cells. A heading at depth N opens / continues a group at that depth, a list
   item under a heading at depth N becomes a leaf TOC cell at depth N+1.
   Everything else (prose, code, tables) is dropped - an overview is a TOC,
   not a body. A level-1 heading is silently dropped: the page title comes
   from the frontmatter "Name:" key and is filled into the template's
   single TOCDocumentTitle cell separately, so emitting another body cell
   of the same style would duplicate the title. *)
(* Fold threads the parent-heading depth through the block walk: each step
   sees the running depth and the cells emitted so far, and returns the
   updated pair. The result is a single allocation - no AppendTo growing a
   list one element at a time. *)
overviewBodyCells[blocks_, paclet_String] := Last @ Fold[
    Function[{state, block},
        Block[{depth = First[state], cells = Last[state], lvl},
            Switch[block["Type"],
                "Heading",
                    lvl = block["Level"];
                    If[ lvl >= 2,
                        {lvl, Append[cells, tocCell[tocCellContent[block["Text"], paclet], tocStyleFor[lvl]]]},
                        {depth, cells}
                    ],
                "List",
                    {depth, Join[cells, Map[
                        tocCell[tocCellContent[#, paclet], tocStyleFor[depth + 1]] &,
                        block["Items"]
                    ]]},
                _, state
            ]
        ]
    ],
    {1, {}},
    blocks
]

(* Group a flat sequence of TOC cells into the nested CellGroupData tree the
   front end uses for collapsible TOC sections. Each cell of style s opens a
   group, every following cell of a deeper style is a child of it, the first
   cell of equal-or-shallower depth closes the group. *)
$tocDepthOf = <|
    "TOCDocumentTitle" -> 0, "TOCChapter" -> 1, "TOCSection" -> 2,
    "TOCSubsection" -> 3, "TOCSubsubsection" -> 4, "TOCSubsubsubsection" -> 5
|>
groupTocCells[cells_List] := Block[{stack = {{}}, depths = {-1}, finalize, push},
    finalize[] := Block[{kids = First[stack], parentKids, headWithKids},
        stack = Rest[stack]; depths = Rest[depths];
        If[kids =!= {} && Length[stack] > 0,
            (* kids[[1]] is the head cell of this group; rest are its children *)
            headWithKids = If[Length[kids] >= 2,
                Cell[CellGroupData[kids, Open]],
                First[kids]
            ];
            parentKids = First[stack];
            stack = Prepend[Rest[stack], Append[parentKids, headWithKids]]
        ]
    ];
    Scan[
        cell |-> Block[{d = Lookup[$tocDepthOf, cell[[2]], 99]},
            While[Length[depths] > 1 && First[depths] >= d, finalize[]];
            stack = Prepend[stack, {cell}];
            depths = Prepend[depths, d];
        ],
        cells
    ];
    While[Length[stack] > 1, finalize[]];
    First[stack]
]

overviewNotebook[data_] := Block[{
    meta = data["meta"], blocks = data["blocks"],
    nb, title, paclet, tocCells, tocBlocks
},
    nb = docTemplate["OverviewBaseTemplateExt.nb"];
    title = Lookup[meta, "Name", Lookup[meta, "Title", ""]];
    paclet = Lookup[meta, "Paclet", ""];
    nb = nb /. Cell["XXXX", "TOCDocumentTitle", o___] :>
        Cell[If[title === "", "XXXX", title], "TOCDocumentTitle", o];
    tocCells = overviewBodyCells[blocks, paclet];
    tocBlocks = groupTocCells[tocCells];
    (* Force the title group's state to Open. The empty
       OverviewBaseTemplateExt.nb wraps its whole TOC in
       CellGroupData[..., Closed] (the author opens the title once and starts
       authoring), but a generated overview's body IS the content the reader
       is meant to see - leaving it Closed hides the entire TOC behind a
       click on the title. *)
    nb = nb /. Cell[CellGroupData[{titleCell : Cell[_, "TOCDocumentTitle", ___], _Cell | _ ..}, _], go___] :>
        Cell[CellGroupData[Prepend[tocBlocks, titleCell], Open], go];
    nb = fillDocList[nb, "Keywords", asList @ Lookup[meta, "Keywords", {}]];
    nb = nb /. {
        Cell["XXXX", _, ___] :> Nothing,
        Cell[BoxData["XXXX"], _, ___] :> Nothing
    };
    setDocMetadata[fillCategorization[nb, "Overview", meta], meta, "Overview"]
]

(* === default style-map builder ===
   No template/slots: markdown maps directly to standard documentation styles,
   so the author never writes cell styles. *)

$headingStyleMap = <|1 -> "Title", 2 -> "Section", 3 -> "Subsection", 4 -> "Subsubsection"|>

defaultNotebook[data_] := Block[{counter = 0, cells},
    cells = Catenate @ Map[
        block |-> Switch[block["Type"],
            "Heading", {Cell[headingText[block["Text"]], Lookup[$headingStyleMap, block["Level"], "Subsubsection"]]},
            "Prose", {Cell[TextData @ inlineTextData[block["Text"]], "Text"]},
            "List", listItemCells[block, "Item"],
            "Table", {tableCell[block]},
            "Quote", {quoteCell[block["Text"]]},
            "MathBlock", {mathBlockCell[block["Text"]]},
            "Image", {imageCell[block]},
            "Code",
                If[ executableQ[block],
                    (counter += 1; exampleIOFor[block, counter]),
                    withCellFlag[block, {Cell[block["Code"], "Program"]}]
                ],
            _, {}
        ],
        data["blocks"]
    ];
    Notebook[cells, StyleDefinitions -> "Default.nb"]
]

(* === Computational Essay ===
   Stephen Wolfram's notebook genre: title, byline (author + date), an
   abstract paragraph, then narrative-driven body where every code cell sits
   between a short prose intro and its own one-line caption (the "CodeText"
   style cell). The published venue is the Notebook Archive / Wolfram
   Cloud, not a Function Repository submission, so the produced notebook
   is just a plain .nb with the Default stylesheet plus the essay's metadata
   header. Frontmatter beyond Name / Description carries Author, Date, and
   Abstract; the body falls through the same Heading / Prose / List / Code
   handlers the Default template uses, with code-block captions promoted to
   "CodeText" cells when they end in a colon. *)
essayHeaderCells[meta_] := Block[{title, author, date, abstract, cells = {}},
    title = Lookup[meta, "Name", Lookup[meta, "Title", ""]];
    author = Lookup[meta, "Author", Lookup[meta, "ContributedBy", ""]];
    date = Lookup[meta, "Date", ""];
    abstract = Lookup[meta, "Abstract", Lookup[meta, "Description", ""]];
    If[title =!= "", AppendTo[cells, Cell[title, "Title"]]];
    (* the official template's "Author" style takes one author cell; if a Date
       is given, append it after a bullet in the same cell. *)
    If[author =!= "" || date =!= "",
        AppendTo[cells, Cell[
            Which[
                author =!= "" && date =!= "", author <> " \[Bullet] " <> date,
                author =!= "", author,
                True, date
            ],
            "Author"
        ]]
    ];
    If[abstract =!= "",
        AppendTo[cells, Cell[TextData @ inlineTextData[abstract], "Abstract"]]
    ];
    cells
]

(* The official Computational Essay template - the same notebook
   File > New > Computational Essay opens, or that
   ResourceFunction["ComputationalEssayTemplate"][] returns - carries the
   essay's custom stylesheet (CodeText, Abstract, Author, ExampleDelimiter,
   the docked Notebook Analysis pod, etc.) and its TaggingRules. We use the
   template as the *shell* for the essay: cache the empty template once per
   session, then build our notebook with the template's StyleDefinitions
   so the body cells render in the right styles when opened in the FE.

   Pull any pending repository update first - the kernel routinely fires
   ResourceObject::updavb ("an update is available") when the locally
   cached resource is older than what's on the server, and that notice
   bypasses Quiet (it is printed via the resource-system print path, not
   the normal message system). ResourceUpdate refreshes the local cache so
   the subsequent call finds a current resource and the message is silent.
   Wrapped in Quiet/Check so a network failure here is benign - the older
   cached template still works. *)
$essayTemplate := $essayTemplate = Replace[
    Quiet @ UsingFrontEnd @ With[{nbo = (
        Quiet @ Check[ResourceUpdate["ComputationalEssayTemplate"], Null];
        ResourceFunction["ComputationalEssayTemplate"][]
    )},
        With[{nb = NotebookGet[nbo]}, NotebookClose[nbo]; nb]
    ],
    Except[_Notebook] -> Notebook[{}, StyleDefinitions -> "Default.nb"]
]

essayNotebook[data_] := Block[{meta = data["meta"], counter = 0, header, body,
    templateOpts = If[MatchQ[$essayTemplate, _Notebook], Rest[List @@ $essayTemplate],
        {StyleDefinitions -> "Default.nb"}]},
    header = essayHeaderCells[meta];
    body = Catenate @ MapIndexed[
        Function[{block, ix},
            Block[{type = block["Type"], text, captionStyle},
                Switch[type,
                    "Heading", {Cell[headingText[block["Text"]], Lookup[$headingStyleMap, block["Level"], "Subsubsection"]]},
                    "Prose", text = block["Text"];
                        (* a one-line prose paragraph that ends in ":" right before a
                           code cell is the essay's code-caption style ("CodeText");
                           ordinary multi-line / non-colon paragraphs stay "Text". *)
                        captionStyle = StringEndsQ[StringTrim[text], ":"] &&
                            ! StringContainsQ[text, "\n"] &&
                            ix[[1]] < Length[data["blocks"]] &&
                            Lookup[data["blocks"][[ix[[1]] + 1]], "Type", ""] === "Code";
                        {Cell[TextData @ inlineTextData[text], If[captionStyle, "CodeText", "Text"]]},
                    "List", listItemCells[block, "Item"],
                    "Table", {tableCell[block]},
                    "Quote", {quoteCell[block["Text"]]},
                    "MathBlock", {mathBlockCell[block["Text"]]},
                    "Image", {imageCell[block]},
                    "Code",
                        If[ executableQ[block],
                            counter += 1; exampleIOFor[block, counter],
                            withCellFlag[block, {Cell[block["Code"], "Program"]}]
                        ],
                    _, {}
                ]
            ]
        ],
        data["blocks"]
    ];
    Notebook[Join[header, body], Sequence @@ templateOpts]
]

(* === template registry === *)

(* the Paclet template also wraps its directory / main-guide / context metadata
   in TemplateExpression / TemplateIf (not plain TemplateSlot). Those resolve to
   raw values (strings, Missing, or boxes), not cells, so they are evaluated in a
   first pass; CheckDefinitionNotebook flags any left unresolved. *)
rawSlotValue[name_String, opts_List, meta_] := Block[{def = FirstCase[opts, (DefaultValue -> v_) :> v, Missing[]]},
    Switch[name,
        "PacletDirectoryType", If[MissingQ[def], "Notebook", def],
        "Context", Lookup[meta, "Context", If[MissingQ[def], "MyPublisherID`MyPaclet`", def]],
        "MainGuidePageString", Lookup[meta, "MainGuide", def],
        (* the license radio is selected by the cell's "RadioButtonValue" tagging
           rule, which is the license ID *string* (e.g. "MIT"); the serialized
           CheckboxData blob is left untouched (Checked stays {}). *)
        "SelectedLicenseID", If[KeyExistsQ[meta, "License"], meta["License"], def],
        "SpecifiedLicenseID", def,
        _, Lookup[meta, name, def]
    ]
]

(* Resolve in stages: slots must be substituted before the enclosing TemplateIf
   collapses, otherwise its condition (e.g. StringQ[TemplateSlot[...]]) is tested
   on the inert slot and always fails; TemplateExpression is unwrapped last so its
   body (DeleteMissing/ToBoxes/...) then evaluates normally. *)
resolveTemplateExpressions[template_, meta_] := template /. te : (_TemplateExpression | _TemplateIf) :> Block[{t = te},
    t = t //. TemplateSlot[n_String, o___] :> rawSlotValue[n, {o}, meta];
    t = t //. {TemplateIf[cond_, a_] :> If[TrueQ[cond], a, Missing[]], TemplateIf[cond_, a_, b_] :> If[TrueQ[cond], a, b]};
    t //. TemplateExpression[e_, ___] :> e
]

(* resource definition notebooks (Function Repository, Paclet Repository): fill
   the official template's slots and keep everything else (stylesheet + docked
   Deploy/Submit toolbar) intact, so the .nb is publishable as-is. *)
resourceNotebook[resourceType_String, data0_] := Block[{template, data = Append[data0, "resourceType" -> resourceType]},
    Needs["DefinitionNotebookClient`"];
    template = DefinitionNotebookClient`DefinitionTemplate[resourceType];
    template = resolveTemplateExpressions[template, data["meta"]];
    (* scalar slots that live in held TaggingRules (a license radio value, a guide
       path) must be replaced by their raw value directly - the cell-fill pass
       below wraps results in Sequence@@, which would leave a stray Sequence[...]
       in the held option and break the control. *)
    template = template /. TemplateSlot[n : ("SelectedLicenseID" | "SpecifiedLicenseID" | "MainGuidePageString"), o___] :>
        rawSlotValue[n, {o}, data["meta"]];
    (* ReplaceRepeated: some slots (e.g. the Compatibility group) nest sub-slots
       inside their DefaultValue, which a single pass would not reach. *)
    template = template //. TemplateSlot[n_, o___] :> Sequence @@ fillSlot[n, {o}, data];
    (* the template seeds a blank standalone usage-input placeholder beside the
       Usage slot (for a second usage line); we fill all usage from the markdown,
       so drop any UsageInputs cell with no real content (matched by emptiness,
       not a literal BoxData[] - the template's BoxData is a context-shadowed
       symbol the bare pattern misses) rather than leave a blank usage line. *)
    template = template /. c : Cell[_, "UsageInputs", ___] /;
        StringTrim[StringJoin[Cases[First[c], _String, Infinity]]] === "" :> Nothing;
    (* collapse the Definition section by default - the inlined source can be long.
       The section header is a "Section" cell tagged "Definition". *)
    template = template /. Cell[CellGroupData[{hdr : Cell[_, "Section", ___, CellTags -> {___, "Definition", ___}, ___], body___}, Open], go___] :>
        Cell[CellGroupData[{hdr, body}, Closed], go];
    (* pin the deployed notebook to light mode so the cloud page never renders
       dark (LightDark -> "Light" forces light regardless of the viewer theme). *)
    Replace[template, Notebook[cells_, o___] :>
        Notebook[cells, LightDark -> "Light", Sequence @@ FilterRules[{o}, Except[LightDark]]]]
]

(* === Template: Chapter (Wolfram Book Tools) ===
   A chapter notebook in the WolframBookTools sense: one Section heading
   (with CounterAssignments -> {{"Section", n-1}, ...}), then body blocks
   in the BookToolsStyles vocabulary. The H1 of the markdown is the chapter
   title; the frontmatter "ChapterNumber:" sets the counter. H2 headings
   are Subsection by default, but a fixed set of reserved titles
   (Summary / Vocabulary / Exercises / Q&A / Tech Notes / More to Explore
   / References / Takeaways / Resources / Key Concepts) drop the block
   that follows them into the matching book-style back-matter section
   instead. Multi-cell scaffolds that have no direct markdown analogue
   (SolvedExample, Theorem/Proof, Exercise/Solution) are authored as
   Pandoc-style ":::" fenced divs - see docs/book-palette.md for the full
   markdown <-> cell-style mapping. *)

$bookStyleSheet := FrontEnd`FileName[{"Wolfram"}, "BookToolsStyles.nb",
    CharacterEncoding -> "UTF-8"]

(* heading levels inside a chapter notebook: H2..H5 -> Subsection..Sub^4section.
   H1 is reserved for the chapter title (rendered as the Section cell). *)
$chapterHeadingStyle = <|
    2 -> "Subsection",
    3 -> "Subsubsection",
    4 -> "Subsubsubsection",
    5 -> "Subsubsubsubsection"
|>

(* H2 titles that select a named back-matter section style (case-insensitive,
   trimmed). The value is the SectionStyle plus the body-cell context the
   section renders in. *)
$reservedH2 = <|
    "summary"               -> "Summary",
    "vocabulary"            -> "Vocabulary",
    "vocab"                 -> "Vocabulary",
    "key concepts"          -> "KeyConcepts",
    "key terms"             -> "KeyConcepts",
    "exercises"             -> "Exercises",
    "exercise"              -> "Exercises",
    "q&a"                   -> "QA",
    "q & a"                 -> "QA",
    "q and a"               -> "QA",
    "questions"             -> "QA",
    "questions and answers" -> "QA",
    "tech notes"            -> "TechNotes",
    "technical notes"       -> "TechNotes",
    "more to explore"       -> "MoreExplore",
    "more"                  -> "MoreExplore",
    "further reading"       -> "MoreExplore",
    "references"            -> "References",
    "bibliography"          -> "References",
    "resources"             -> "Resources",
    "takeaways"             -> "Takeaways",
    "key points"            -> "Takeaways"
|>

reservedSectionKindOf[heading_String] := Lookup[$reservedH2,
    ToLowerCase[StringTrim[heading]], None]

(* the chapter's Section heading: the canonical "<counter> | <title>" shape the
   palette's New Chapter dialog writes (CounterBox + SectionBar separator +
   title), with CounterAssignments resetting Section / Subsection /
   Subsubsection / Exercise counters at the start of the chapter. *)
chapterSectionCell[title_String, num_Integer] := Cell[
    TextData[Join[
        {CounterBox["Section"], StyleBox[" | ", "SectionBar"]},
        inlineTextData[title]
    ]],
    "Section",
    CounterAssignments -> {
        {"Section", num - 1}, {"Subsection", 0},
        {"Subsubsection", 0}, {"Exercise", 0}
    }
]
chapterSectionCell[title_String, _] := Cell[
    TextData[Join[{StyleBox[" | ", "SectionBar"]}, inlineTextData[title]]],
    "Section"
]

(* a normal Input/Output pair re-styled to a given pair of styles (e.g.
   ExerciseInput/ExerciseOutput, SolvedExampleInput/SolvedExampleOutput,
   TechNoteInput/TechNoteOutput). Mirrors exampleIO but with custom styles
   and without numbered In[]/Out[] labels - the book style sheets don't
   carry those for the alt code styles. *)
styledIOCells[block_, inStyle_String, outStyle_String] := Block[{
    outBoxes = Lookup[block, "OutputBoxes", Missing[]],
    code = block["Code"], inCell, outCell, msgs = Lookup[block, "Messages", {}]
},
    inCell = Cell[BoxData[inputBoxes[code]], inStyle];
    Which[
        MissingQ[outBoxes] || outBoxes === Null,
            Prepend[messageCell /@ msgs, inCell] // (Flatten[{#}] &),
        True,
            outCell = Cell[BoxData[outBoxes], outStyle];
            {Cell[CellGroupData[
                Flatten[{inCell, messageCell /@ msgs, outCell}],
                Open
            ]]}
    ]
]

(* "free-form" body cells - the cells produced inside an ordinary subsection
   (i.e. one whose H2 isn't a reserved back-matter title), or inside the
   chapter's introduction (the prose between the chapter heading and the
   first H2). Mirrors defaultNotebook's per-block dispatch with book styles
   substituted (Item/Subitem nested by list depth, CodeText for a colon-
   ending prose line preceding an Input). The "counter" reference is shared
   with the rest of the chapter (each evaluated Input gets the next In[n] /
   Out[n] number, increasing through the whole notebook). *)
$bookListLevel = 1
$bookListStyle[1] = "Item"
$bookListStyle[2] = "Subitem"
$bookListStyle[_] = "Subsubitem"

bookProseCell[block_, nextBlockType_String] := Block[{text = block["Text"]},
    If[StringEndsQ[StringTrim[text], ":"] &&
        ! StringContainsQ[text, "\n"] && nextBlockType === "Code",
        Cell[TextData @ inlineTextData[text], "CodeText"],
        Cell[TextData @ inlineTextData[text], "Text"]
    ]
]

(* free-form (subsection-level) cell from a block. `next` is the type of the
   following block (used to decide CodeText vs Text for caption-like prose). *)
bookFreeCells[block_, next_String, counterSym_] := Switch[block["Type"],
    "Heading",
        {Cell[headingText[block["Text"]],
            Lookup[$chapterHeadingStyle, block["Level"], "Subsubsubsection"]]},
    "Prose",
        {bookProseCell[block, next]},
    "List",
        listItemCells[block, "Item"],
    "Table",
        {tableCell[block]},
    "Quote",
        {quoteCell[block["Text"]]},
    "MathBlock",
        {mathBlockCell[block["Text"]]},
    "Image",
        {imageCell[block]},
    "Code",
        If[ executableQ[block],
            $chapterCounter += 1;
            exampleIOFor[block, $chapterCounter],
            withCellFlag[block, {Cell[block["Code"], "Program"]}]
        ],
    "Div",
        bookDivCells[block, counterSym],
    "Separator",
        {Cell["", "ExampleDelimiter"]},
    _, {}
]

(* the fenced-div dispatch: each ::: kind opens one of the Book Tools
   multi-cell scaffolds. Kinds we handle: solved-example, theorem,
   theorem-numbered, proof, exercise, solution. Anything else falls back to
   rendering the inner blocks as plain free-form cells. *)
bookDivCells[block_, counterSym_] := Block[{
    kind = ToLowerCase[StringTrim[StringReplace[block["Kind"], "_" -> "-"]]],
    inner = block["Blocks"]
},
    Switch[kind,
        "solved-example",       solvedExampleCells[inner, counterSym, False],
        "solved-example-numbered", solvedExampleCells[inner, counterSym, True],
        "theorem",              theoremCells[inner, counterSym, False],
        "theorem-numbered",     theoremCells[inner, counterSym, True],
        "proof",                proofCells[inner, counterSym, False],
        "proof-numbered",       proofCells[inner, counterSym, True],
        "exercise",             exerciseDivCells[inner, counterSym],
        "solution",             solutionDivCells[inner, counterSym],
        _,
            Flatten[Map[
                bookFreeCells[#, "", counterSym] &,
                inner
            ]]
    ]
]

(* SolvedExample scaffold. The first non-code inner block is the lead-in
   that becomes the SolvedExampleNote, the inner ``wl`` blocks become
   SolvedExampleInput / SolvedExampleOutput, and any inner display math
   becomes SolvedExampleDisplayFormula(Numbered). A SolvedExampleEndCap
   terminates the group. If `numbered`, the heading carries CounterBox
   counters; otherwise it's just titled "Solved Example" plus the lead-in. *)
solvedExampleCells[inner_List, counterSym_, numbered_] := Block[{
    headBlock, restBlocks, headTextData, headCell
},
    {headBlock, restBlocks} = If[
        inner =!= {} && First[inner]["Type"] === "Prose",
        {First[inner], Rest[inner]},
        {<|"Type" -> "Prose", "Text" -> "Solved Example"|>, inner}
    ];
    headTextData = If[numbered,
        Join[inlineTextData[headBlock["Text"] <> " "],
            {CounterBox["Section"], ".", CounterBox["SolvedExample"]}],
        inlineTextData[headBlock["Text"]]
    ];
    headCell = Cell[TextData[headTextData], "SolvedExample"];
    Join[
        {headCell},
        Flatten @ Map[bookSolvedInnerCells[#, counterSym] &, restBlocks],
        {Cell["", "SolvedExampleEndCap"]}
    ]
]

bookSolvedInnerCells[block_, counterSym_] := Switch[block["Type"],
    "Prose",
        {Cell[TextData @ inlineTextData[block["Text"]], "SolvedExampleNote"]},
    "Code",
        If[ executableQ[block],
            styledIOCells[block, "SolvedExampleInput", "SolvedExampleOutput"],
            {Cell[block["Code"], "SolvedExampleInput"]}
        ],
    "MathBlock",
        With[{nm = Lookup[block, "Numbered", False]},
            {Cell[BoxData[PaneBox[
                Replace[texBoxes[block["Text"]], $Failed ->
                    FormBox[inputBoxes[block["Text"]], TraditionalForm]],
                ImageSize -> Full, Alignment -> Center]],
                If[TrueQ[nm], "SolvedExampleDisplayFormulaNumbered",
                    "SolvedExampleDisplayFormula"]]}
        ],
    "List",
        listItemCells[block, "Item"],
    _, bookFreeCells[block, "", counterSym]
]

(* Theorem scaffold: a Theorem heading (with CounterBox counters when
   numbered), then a TheoremStatement (the first prose paragraph if any),
   then any further inner blocks rendered as free-form cells. The
   ProofTheoremEndCap terminates the group only when nested under a Proof. *)
theoremCells[inner_List, counterSym_, numbered_] := Block[{
    headBlock, restBlocks, headTextData, headCell, statementCell, rest
},
    {headBlock, restBlocks} = If[
        inner =!= {} && First[inner]["Type"] === "Prose",
        {First[inner], Rest[inner]},
        {<|"Type" -> "Prose", "Text" -> "Theorem"|>, inner}
    ];
    headTextData = If[numbered,
        Join[inlineTextData[headBlock["Text"] <> " "],
            {CounterBox["Section"], ".", CounterBox["Subsection"]}],
        inlineTextData[headBlock["Text"]]
    ];
    headCell = Cell[TextData[headTextData], "Theorem"];
    (* split the statement cell out of restBlocks without using a multi-
       assignment - {Nothing, x} would auto-collapse to {x} and break Set. *)
    If[restBlocks =!= {} && First[restBlocks]["Type"] === "Prose",
        statementCell = Cell[TextData @ inlineTextData[First[restBlocks]["Text"]],
            "TheoremStatement"];
        rest = Rest[restBlocks]
    ,
        statementCell = Nothing;
        rest = restBlocks
    ];
    Join[{headCell, statementCell},
        Flatten @ Map[bookFreeCells[#, "", counterSym] &, rest]]
]

proofCells[inner_List, counterSym_, numbered_] := Block[{
    rest, contentCells
},
    contentCells = Flatten @ Map[bookProofInnerCells[#, counterSym] &, inner];
    Join[{Cell["Proof", "Proof"]}, contentCells,
        {Cell["", "ProofTheoremEndCap"]}]
]

bookProofInnerCells[block_, counterSym_] := Switch[block["Type"],
    "Prose",
        {Cell[TextData @ inlineTextData[block["Text"]], "ProofContent"]},
    "MathBlock",
        {Cell[BoxData[PaneBox[
            Replace[texBoxes[block["Text"]], $Failed ->
                FormBox[inputBoxes[block["Text"]], TraditionalForm]],
            ImageSize -> Full, Alignment -> Center]],
            "ProofTheoremDisplayFormula"]},
    _, bookFreeCells[block, "", counterSym]
]

(* one Exercise. The first prose line becomes the Exercise prompt cell;
   subsequent prose/code/list/math blocks render in the Exercise context
   (paragraphs -> ExerciseNote, ``wl`` -> ExerciseInput/ExerciseOutput).
   A nested ::: solution div opens the ExerciseSolution group. *)
exerciseDivCells[inner_List, counterSym_] := Block[{
    promptBlock, rest, promptCell
},
    {promptBlock, rest} = If[
        inner =!= {} && First[inner]["Type"] === "Prose",
        {First[inner], Rest[inner]},
        {<|"Type" -> "Prose", "Text" -> "Exercise"|>, inner}
    ];
    promptCell = Cell[TextData @ inlineTextData[promptBlock["Text"]],
        "Exercise"];
    Prepend[
        Flatten @ Map[bookExerciseInnerCells[#, counterSym] &, rest],
        promptCell
    ]
]

bookExerciseInnerCells[block_, counterSym_] := Switch[block["Type"],
    "Prose",
        {Cell[TextData @ inlineTextData[block["Text"]], "ExerciseNote"]},
    "Code",
        If[ executableQ[block],
            styledIOCells[block, "ExerciseInput", "ExerciseOutput"],
            {Cell[block["Code"], "ExerciseInput"]}
        ],
    "List",
        listItemCells[block, "Item"],
    "MathBlock",
        {mathBlockCell[block["Text"]]},
    "Div",
        If[ToLowerCase[StringTrim[block["Kind"]]] === "solution",
            solutionDivCells[block["Blocks"], counterSym],
            bookDivCells[block, counterSym]
        ],
    _, bookFreeCells[block, "", counterSym]
]

solutionDivCells[inner_List, counterSym_] := Join[
    {Cell["Solution", "ExerciseSolution"]},
    Flatten @ Map[bookSolutionInnerCells[#, counterSym] &, inner]
]

bookSolutionInnerCells[block_, counterSym_] := Switch[block["Type"],
    "Prose",
        {Cell[TextData @ inlineTextData[block["Text"]], "SolutionAnswer"]},
    "Code",
        If[ executableQ[block],
            styledIOCells[block, "ExerciseInput", "ExerciseOutput"],
            {Cell[block["Code"], "ExerciseInput"]}
        ],
    "List",
        Map[Cell[TextData @ inlineTextData[#], "SolutionItem"] &,
            block["Items"]],
    _, bookFreeCells[block, "", counterSym]
]

(* === reserved back-matter sections === *)

(* group consecutive blocks under H2 boundaries. Returns a list of
   {<heading or None>, {blocks}} pairs. The first group has heading None
   if there is intro content before the first H2; subsequent groups carry
   their H2 heading block as the first element. *)
groupByH2[blocks_List] := Block[{groups = {}, current = None, currentBlocks = {}, finalize},
    finalize[h_, bs_] := AppendTo[groups, {h, bs}];
    Do[
        If[b["Type"] === "Heading" && b["Level"] === 2,
            finalize[current, currentBlocks];
            current = b; currentBlocks = {},
            AppendTo[currentBlocks, b]
        ],
        {b, blocks}
    ];
    finalize[current, currentBlocks];
    DeleteCases[groups, {None, {}}]
]

(* Summary section: heading -> SummarySection; paragraphs -> SummaryNote;
   bullets -> SummaryList. *)
summarySectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {Cell[TextData @ inlineTextData[b["Text"]], "SummaryNote"]},
            "List",  listItemCells[b, "SummaryList"],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "SummarySection"]
]

(* Vocabulary: a 2-column pipe table becomes a VocabularyTable GridBox;
   anything else renders free-form (so subsection headings nested inside
   vocab still work). *)
vocabularyTableCellFromTable[block_] := Cell[
    BoxData[GridBox[
        Map[
            row |-> {RowBox[{
                row[[1]], " ",
                Cell[row[[2]], "VocabularyText"]
            }]},
            block["Rows"]
        ]
    ]],
    "VocabularyTable"
]

vocabularySectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Table",
                {vocabularyTableCellFromTable[b]},
            "Prose",
                {Cell[TextData @ inlineTextData[b["Text"]], "Text"]},
            "Heading",
                {Cell[headingText[b["Text"]],
                    Switch[b["Level"],
                        3, "VocabularySubsection",
                        4, "VocabularySubsubsection",
                        _, "VocabularySubsection"]]},
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "VocabularySection"]
]

(* KeyConcepts: a "Key Concepts" / "Key Terms" H2 - renders the heading as
   a regular Subsection and the bulleted list as plain Items (the EIWL-style
   "things you'll learn" bullet list at the top of a chapter). *)
keyConceptsSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[bookFreeCells[#, "", counterSym] &, blocks],
    Cell[headingText[heading["Text"]], "Subsection"]
]

(* Exercises: heading -> ExerciseSection; H3 -> ExerciseSubsection; each
   "::: exercise" div is one Exercise group; bare ordered-list items
   collapse to single-line Exercise cells. *)
exercisesSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Heading",
                {Cell[headingText[b["Text"]],
                    If[b["Level"] === 3, "ExerciseSubsection",
                        Lookup[$chapterHeadingStyle, b["Level"],
                            "Subsubsection"]]]},
            "Prose",
                {Cell[TextData @ inlineTextData[b["Text"]],
                    "ExerciseSectionNote"]},
            "List",
                Map[Cell[TextData @ inlineTextData[#], "Exercise"] &,
                    b["Items"]],
            "Div",
                bookDivCells[b, counterSym],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "ExerciseSection"]
]

(* Q&A: heading -> QASection; paragraph that starts with Q. / Q: / Q -
   trims that lead-in and becomes a Question; same for A. -> Answer.
   Anything else falls through to a plain Text cell. *)
qaProseCell[text_String] := Block[{trimmed = StringTrim[text]},
    Which[
        StringMatchQ[trimmed, ("Q." | "Q:" | "Q -" | "**Q.**" | "**Q:**") ~~ Whitespace ~~ ___],
            Cell[TextData @ inlineTextData @ StringTrim @
                StringReplace[trimmed,
                    StartOfString ~~ ("**Q.**" | "**Q:**" | "Q." | "Q:" | "Q -") ~~ Whitespace -> ""],
                "Question"],
        StringMatchQ[trimmed, ("A." | "A:" | "A -" | "**A.**" | "**A:**") ~~ Whitespace ~~ ___],
            Cell[TextData @ inlineTextData @ StringTrim @
                StringReplace[trimmed,
                    StartOfString ~~ ("**A.**" | "**A:**" | "A." | "A:" | "A -") ~~ Whitespace -> ""],
                "Answer"],
        True,
            Cell[TextData @ inlineTextData[text], "Text"]
    ]
]

qaSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {qaProseCell[b["Text"]]},
            "List",  listItemCells[b, "Item"],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "QASection"]
]

(* Tech Notes: heading -> TechNoteSection; paragraphs -> TechNote; code ->
   TechNoteInput/Output; list items -> TechNoteItem. *)
techNotesSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {Cell[TextData @ inlineTextData[b["Text"]], "TechNote"]},
            "Code",
                If[ executableQ[b],
                    styledIOCells[b, "TechNoteInput", "TechNoteOutput"],
                    {Cell[b["Code"], "TechNoteInput"]}
                ],
            "List",
                Map[Cell[TextData @ inlineTextData[#], "TechNoteItem"] &,
                    b["Items"]],
            "MathBlock", {mathBlockCell[b["Text"]]},
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "TechNoteSection"]
]

(* More to Explore: heading -> MoreExploreSection; bullets -> MoreExplore;
   bare-URL prose -> MoreExploreShortURL. *)
moreExploreCell[text_String] := Cell[TextData @ inlineTextData[text],
    If[StringMatchQ[StringTrim[text], "http" ~~ ___ | "wolfr.am/" ~~ ___],
        "MoreExploreShortURL", "MoreExplore"]
]

moreExploreSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {moreExploreCell[b["Text"]]},
            "List",
                Map[Cell[TextData @ inlineTextData[#], "MoreExplore"] &,
                    b["Items"]],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "MoreExploreSection"]
]

(* References: heading -> ReferenceSection; bullets / paragraphs ->
   Reference cells. *)
referencesSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {Cell[TextData @ inlineTextData[b["Text"]], "Reference"]},
            "List",
                Map[Cell[TextData @ inlineTextData[#], "Reference"] &,
                    b["Items"]],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "ReferenceSection"]
]

resourcesSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {Cell[TextData @ inlineTextData[b["Text"]], "ResourcesText"]},
            "List",
                Map[Cell[TextData @ inlineTextData[#], "ResourcesText"] &,
                    b["Items"]],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "ResourcesSubsection"]
]

takeawaysSectionCells[heading_, blocks_, counterSym_] := Prepend[
    Catenate @ Map[
        b |-> Switch[b["Type"],
            "Prose", {Cell[TextData @ inlineTextData[b["Text"]], "TakeawaysText"]},
            "List",
                Map[Cell[TextData @ inlineTextData[#], "TakeawaysText"] &,
                    b["Items"]],
            _, bookFreeCells[b, "", counterSym]
        ],
        blocks
    ],
    Cell[headingText[heading["Text"]], "TakeawaysSection"]
]

(* dispatch: given an H2 heading block (or None) plus its body blocks,
   build the cells for that group. None means "intro content before the
   first H2" - emit it as free-form cells. *)
chapterGroupCells[None, blocks_, counterSym_] :=
    Block[{i, next, out = {}},
        Do[
            next = If[i < Length[blocks], blocks[[i + 1]]["Type"], ""];
            out = Join[out, bookFreeCells[blocks[[i]], next, counterSym]],
            {i, Length[blocks]}
        ];
        out
    ]
chapterGroupCells[heading_Association, blocks_, counterSym_] := Block[{
    kind = reservedSectionKindOf[heading["Text"]], i, next, out
},
    Switch[kind,
        "Summary",      summarySectionCells[heading, blocks, counterSym],
        "Vocabulary",   vocabularySectionCells[heading, blocks, counterSym],
        "KeyConcepts",  keyConceptsSectionCells[heading, blocks, counterSym],
        "Exercises",    exercisesSectionCells[heading, blocks, counterSym],
        "QA",           qaSectionCells[heading, blocks, counterSym],
        "TechNotes",    techNotesSectionCells[heading, blocks, counterSym],
        "MoreExplore",  moreExploreSectionCells[heading, blocks, counterSym],
        "References",   referencesSectionCells[heading, blocks, counterSym],
        "Resources",    resourcesSectionCells[heading, blocks, counterSym],
        "Takeaways",    takeawaysSectionCells[heading, blocks, counterSym],
        _,
            out = {Cell[headingText[heading["Text"]], "Subsection"]};
            Do[
                next = If[i < Length[blocks], blocks[[i + 1]]["Type"], ""];
                out = Join[out, bookFreeCells[blocks[[i]], next, counterSym]],
                {i, Length[blocks]}
            ];
            out
    ]
]

(* `counterSym` is a Block-local symbol so the nested helpers can SetDelayed
   on it (the value mutates as wl example cells get In[n]/Out[n] labels).
   We carry it as an explicit argument through the section dispatchers so
   each is closure-free. *)
chapterNotebook[data_] := Block[{
    meta = data["meta"], blocks = data["blocks"],
    title, chapterNum, groups, bodyCells, $chapterCounter = 0, frontmatterOpts,
    firstH1, contentBlocks
},
    (* Drop the H1 heading from the body: the chapter title is the Section
       heading we emit ourselves, not a Subsection/.. inside the chapter.
       Fall back to the H1 text for the title when Name: is absent. *)
    firstH1 = SelectFirst[blocks,
        # =!= Null && #["Type"] === "Heading" && #["Level"] === 1 &, Null];
    contentBlocks = DeleteCases[blocks,
        b_ /; AssociationQ[b] && b["Type"] === "Heading" && b["Level"] === 1];
    title = Lookup[meta, "Name", Lookup[meta, "Title",
        If[firstH1 =!= Null, firstH1["Text"], ""]]];
    chapterNum = With[{n = Lookup[meta, "ChapterNumber", Missing[]]},
        Which[
            IntegerQ[n], n,
            StringQ[n] && StringMatchQ[StringTrim[n], DigitCharacter ..],
                ToExpression[StringTrim[n]],
            True, Missing[]
        ]
    ];
    (* a Title-style banner above the chapter heading - used only when a
       Subtitle frontmatter key is set, to mimic the palette's optional
       Subchapter cell. The chapter title itself always renders as the
       Section heading. *)
    groups = groupByH2[contentBlocks];
    bodyCells = Catenate @ Map[
        chapterGroupCells[#[[1]], #[[2]], $chapterCounter] &,
        groups
    ];
    frontmatterOpts = DeleteCases[{
        With[{pw = Lookup[meta, "PageWidth", Inherited]},
            If[NumericQ[pw], PageWidth -> pw, Nothing]],
        With[{spb = Lookup[meta, "ShowPageBreaks", Inherited]},
            If[BooleanQ[spb], ShowPageBreaks -> spb, Nothing]]
    }, Nothing];
    Notebook[
        Join[
            {chapterSectionCell[title,
                Replace[chapterNum, Except[_Integer] -> 0]]},
            If[Lookup[meta, "Subtitle", ""] =!= "",
                {Cell[Lookup[meta, "Subtitle", ""], "Subchapter"]}, {}],
            bodyCells
        ],
        StyleDefinitions -> $bookStyleSheet,
        Sequence @@ frontmatterOpts
    ]
]

buildNotebook["FunctionResource", data_] := resourceNotebook["Function", data]
buildNotebook["Paclet", data_] := resourceNotebook["Paclet", data]
buildNotebook["Example", data_] := resourceNotebook["Example", data]
buildNotebook["Data", data_] := resourceNotebook["Data", data]
buildNotebook["Prompt", data_] := resourceNotebook["Prompt", data]
buildNotebook["Demonstration", data_] := resourceNotebook["Demonstration", data]
buildNotebook["Symbol", data_] := symbolNotebook[data]
buildNotebook["Guide", data_] := guideNotebook[data]
buildNotebook["TechNote", data_] := tutorialNotebook[data]
buildNotebook["Overview", data_] := overviewNotebook[data]
buildNotebook["ComputationalEssay", data_] := essayNotebook[data]
buildNotebook["Essay", data_] := essayNotebook[data]
buildNotebook["Chapter", data_] := chapterNotebook[data]
buildNotebook["BookChapter", data_] := chapterNotebook[data]
buildNotebook["LLMTool", data_] := resourceNotebook["LLMTool", data]
buildNotebook[_, data_] := defaultNotebook[data]

(* Every cell needs a CellID for the resource scraper to locate the definition and
   example cells. The interactive front end assigns them when a notebook is opened,
   but a notebook deployed headlessly (build.wls, never opened by hand) keeps
   whatever the expression carries - and without CellIDs the scraper reports the
   function definition as missing and deploys an empty resource. Setting the
   notebook's CreateCellID option makes the front end assign the missing CellIDs as
   soon as it opens the notebook, the idiomatic equivalent of clicking into it. *)
withCreateCellID[Notebook[cells_, o : OptionsPattern[]]] :=
    Notebook[cells, CreateCellID -> True, Sequence @@ FilterRules[{o}, Except[CreateCellID]]]
withCreateCellID[other_] := other

(* === markdown-out: a rendered markdown twin ===
   MarkdownToNotebook[source, "out.md"] re-serializes the document to markdown but
   follows each evaluated wl cell with an image of its output, saved under images/
   beside the target. The twin is the rendered, viewer-ready version: prose,
   headings, lists, tables, frontmatter, and every evaluated output - and nothing
   else. Notebook-side cell options ("#| file: ...", "#| screenshot: true",
   "#| tear: 200", "#| eval: false", "#| flag: ...") are stripped, since they
   carry processing directives the rendered view has no use for (the file include
   is already expanded, the screenshot is already there, etc.). Inferred [Symbol]()
   links are resolved to public web URLs (paclet:Wolfram/AccessibleColors/ref/X ->
   https://resources.wolframcloud.com/PacletRepository/... ; bare System symbols ->
   their reference.wolfram.com page) so every link clicks through on GitHub. *)
(* quote a YAML value when it would otherwise break parsing: brackets / braces /
   commas open a flow collection, ": " or " #" end a scalar, and a leading
   indicator char reads as a node tag. A markdown link "[label](url)" in a [list]
   hits the bracket case, so the source's quotes (which the YAML parser strips on
   the way in) must be restored on the way out, or GitHub rejects the frontmatter. *)
yamlNeedsQuote[s_String] := StringContainsQ[s, "[" | "]" | "{" | "}" | "," | ": " | " #" | "\""] ||
    StringStartsQ[s, "[" | "{" | "&" | "*" | "!" | "|" | ">" | "@" | "`" | "%" | "'" | "\"" | "#"] ||
    s =!= StringTrim[s]
yamlValue[s_String] := If[yamlNeedsQuote[s], "\"" <> StringReplace[s, {"\\" -> "\\\\", "\"" -> "\\\""}] <> "\"", s]
yamlValue[x_] := ToString[x]

fmLine[k_, v_String] := k <> ": " <> yamlValue[v]
fmLine[k_, v_List] := k <> ": [" <> StringRiffle[yamlValue /@ v, ", "] <> "]"
fmLine[k_, v_] := k <> ": " <> ToString[v]

serializeFrontmatter[meta_] := If[meta === <||> || meta === Null, "",
    "---\n" <> StringRiffle[KeyValueMap[fmLine, meta], "\n"] <> "\n---\n"]

serializeTableMd[block_] := StringRiffle[Join[
    {"| " <> StringRiffle[block["Header"], " | "] <> " |",
     "|" <> StringRiffle[ConstantArray["---", Length[block["Header"]]], "|"] <> "|"},
    ("| " <> StringRiffle[#, " | "] <> " |") & /@ block["Rows"]
], "\n"]

(* write the rasterized image only if it differs pixel-wise from what's on disk:
   PNG re-encoding is non-deterministic at the byte level (compression / timestamps),
   so two visually identical re-renders would otherwise show as "modified" and churn
   git history. Compare raw byte ImageData (dimensions first, as a cheap reject). *)
writeImageIfChanged[path_String, img_] := Block[{existing},
    existing = If[FileExistsQ[path], Quiet @ Import[path], None];
    If[ ImageQ[existing] && ImageQ[img] &&
        ImageDimensions[existing] === ImageDimensions[img] &&
        ImageData[existing, "Byte"] === ImageData[img, "Byte"],
        path,
        Quiet @ Export[path, img, "PNG"]; path
    ]
]

markdownWithImages[blocks_, meta_, target_String] := Block[{dir, base, imgDir, n = 0, mdOf, codeMd},
    dir = DirectoryName[target]; base = FileBaseName[target];
    imgDir = FileNameJoin[{dir, "images"}];
    Quiet @ CreateDirectory[imgDir, CreateIntermediateDirectories -> True];
    codeMd[b_] := Block[{fence, imgFile, img, msgs, msgBlock, hasOutput},
        (* twin keeps no "#| key: value" cell options - those are notebook-side
           evaluation directives (file, screenshot, tear, eval, flag) that have
           no rendered meaning. The file include is already expanded into
           b["Code"] by resolveIncludes, so the twin shows the actual code. *)
        fence = "```" <> b["Lang"] <> "\n" <> b["Code"] <> "\n```";
        (* captured kernel messages render as plain markdown blockquote admonitions
           (one per message) so a stray Power::infy or Part::partw shows up in the
           viewer right next to the cell that fired it - the twin had been silent
           about them, hiding real errors behind a tidy-looking output image. *)
        msgs = If[KeyExistsQ[b, "Messages"], b["Messages"], {}];
        msgBlock = If[msgs === {} || MissingQ[msgs], "",
            "\n\n" <> StringRiffle[DeleteCases[messageMd /@ msgs, ""], "\n\n"]];
        hasOutput = executableQ[b] && ! MissingQ[b["OutputBoxes"]] && b["OutputBoxes"] =!= Null;
        If[ hasOutput,
            n += 1; imgFile = base <> "-" <> ToString[n] <> ".png";
            img = UsingFrontEnd @ Rasterize[
                Notebook[{Cell[BoxData[b["OutputBoxes"]], "Output", Sequence @@ extraOutputOpts[b]]}, LightDark -> $lightDark, StyleDefinitions -> "Default.nb"],
                ImageResolution -> 96];
            writeImageIfChanged[FileNameJoin[{imgDir, imgFile}], img];
            fence <> msgBlock <> "\n\n![output](images/" <> imgFile <> ")",
            fence <> msgBlock
        ]
    ];
    mdOf[b_] := Switch[b["Type"],
        "Heading", StringRepeat["#", b["Level"]] <> " " <> resolveWebRefs[b["Text"]],
        "Prose", resolveWebRefs[b["Text"]],
        "List", If[ TrueQ[b["Ordered"]],
            StringRiffle[MapIndexed[ToString[First[#2]] <> ". " <> resolveWebRefs[#1] &, b["Items"]], "\n"],
            StringRiffle["- " <> resolveWebRefs[#] & /@ b["Items"], "\n"]
        ],
        "Table", serializeTableMd[b],
        "Separator", "---",
        "Quote", "> " <> resolveWebRefs[b["Text"]],
        "MathBlock", "$$ " <> b["Text"] <> " $$",
        "Image", "![" <> Lookup[b, "Alt", ""] <> "](" <> Lookup[b, "Path", ""] <> ")",
        "Code", codeMd[b],
        "Div", "::: " <> b["Kind"] <> "\n\n" <>
            StringRiffle[DeleteCases[mdOf /@ b["Blocks"], ""], "\n\n"] <>
            "\n\n:::",
        _, ""
    ];
    Export[target, serializeFrontmatter[meta] <> "\n" <> StringRiffle[DeleteCases[mdOf /@ blocks, ""], "\n\n"] <> "\n", "Text"];
    target
]

(* === example-output cache ===
   Evaluated example outputs are cached with the built-in persistence framework -
   a PersistentSymbol per cell, keyed by the cumulative hash, at the "Local"
   location so it survives sessions. No cache option: manage it the standard way -
   PersistentObjects["MarkdownToNotebook/**"] to list, DeleteObject to clear, and
   $PersistencePath / PersistenceLocation to relocate. *)
$cacheLocation = "Local"
exampleCacheName[h_Integer] := "MarkdownToNotebook/ExampleOutput/" <> IntegerString[h, 36]
exampleCacheGet[h_Integer] := PersistentSymbol[exampleCacheName[h], $cacheLocation]
exampleCacheSet[h_Integer, v_] := (PersistentSymbol[exampleCacheName[h], $cacheLocation] = v;)

(* === entry point === *)

(* the result is chosen by the optional second argument:
     MarkdownToNotebook[source]                -> the Notebook expression
     MarkdownToNotebook[source, "Notebook"]    -> the Notebook expression
     MarkdownToNotebook[source, "Association"] -> the parsed structure
     MarkdownToNotebook[source, "out.md"]      -> a rendered markdown twin: the
        document re-serialized with each wl output added as an image under images/
     MarkdownToNotebook[source, file]          -> write the notebook to file, return it
   ("Notebook"/"Association" are reserved; a ".md" target writes markdown; any other
   string is a notebook file path.) The layout comes from the Template frontmatter. *)
(* "PreserveSource" -> True stamps the produced notebook with the original
   markdown source under TaggingRules -> {..., "MarkdownToNotebook" -> <|
   "Source" -> ..., "Template" -> ...|>}. The default is False so that a
   notebook is a strictly-rendered artifact - any post-conversion edit to
   the cells shows up faithfully when the inverse (NotebookToMarkdown) walks
   it back to markdown, which is the right semantics for diffing the edited
   .nb against the .md it was built from. With True, the .nb becomes
   self-contained (rendered view + the markdown source it came from in one
   file), useful for tooling that wants the source side-loaded without
   re-parsing the cells. NotebookToMarkdown does NOT read this stash - by
   design, the walker runs on every input. *)
withMarkdownSource[Notebook[cells_, o : OptionsPattern[]], src_String, tmpl_String] := Block[
    {oldRules = Lookup[{o}, TaggingRules, {}], newEntry},
    newEntry = "MarkdownToNotebook" -> <|"Source" -> src, "Template" -> tmpl|>;
    Notebook[cells,
        TaggingRules -> If[ListQ[oldRules],
            Append[DeleteCases[oldRules, "MarkdownToNotebook" -> _], newEntry],
            {newEntry}
        ],
        Sequence @@ FilterRules[{o}, Except[TaggingRules]]
    ]
]
withMarkdownSource[other_, _, _] := other

Options[MarkdownToNotebook] = {"Evaluate" -> True, "PreserveSource" -> False}

(* spec is an *optional* second argument (default Automatic). Do not split this
   into a separate 1-argument form that forwards to the 3-argument one: an empty
   OptionsPattern[] also matches Automatic, so MarkdownToNotebook[file, Automatic]
   matches both forms and, once the resource scraper reorders the down-values,
   forwards to itself without end (RecursionLimit). One definition with an optional
   spec avoids the ambiguity. *)
MarkdownToNotebook[file_String, spec : (_String | Automatic) : Automatic, opts : OptionsPattern[]] := Block[{
    (* Start the nesting counter self-contained: read $convertDepth only when it is
       already an integer, else treat it as 0. The load-time `$convertDepth = 0`
       (above) sets it in a Get-ed session, but a deployed ResourceFunction runs in a
       fresh kernel where that init may not have executed - and `$convertDepth + 1`
       on an *unbound* symbol binds the local to the symbolic `$convertDepth + 1`,
       which re-expands without end (RecursionLimit on every call). *)
    $convertDepth = If[IntegerQ[$convertDepth], $convertDepth, 0] + 1,
    (* resolve the "Evaluate" option directly - OptionValue[func, {opts}, name] in a
       Block initializer mis-binds (it reads "func" as the option name and errors
       OptionValue::optnf, leaving evalExamples False so nothing is ever evaluated). *)
    evalExamples = TrueQ[Lookup[Flatten[{opts}], "Evaluate", True]],
    preserveSource = TrueQ[Lookup[Flatten[{opts}], "PreserveSource", False]],
    src, text, parsed, meta, blocks, sections, tmplName, defCode, ctx, ctxPath,
    orderedCode, hashes, cached, allHit, outputs, data, filled
},
    src = resolveSource[file];
    text = src["Text"];
    parsed = litParse[text];
    meta = parsed["Metadata"];
    $docName = Lookup[meta, "Name", ""];
    $docPaclet = Lookup[meta, "Paclet", ""];
    $docContext = Lookup[meta, "Context", ""];
    blocks = resolveIncludes[parsed["Blocks"], src["Base"]];
    tmplName = Lookup[meta, "Template", "Default"];
    $docTemplate = tmplName;

    (* evaluate every executable cell in document order, threading state in a
       private context (so the document's own code can't clobber the live
       session), cached by a cumulative hash of all cells up to each one. *)
    (* recurse into Div blocks so executable cells nested inside ::: fenced
       divs (exercises, solutions, solved-examples, ...) get evaluated and
       cached alongside the top-level cells. *)
    orderedCode = Cases[blocks, b_ /; executableQ[b], Infinity];
    hashes = cumulativeHashes[orderedCode];
    ctx = "MTNB$" <> IntegerString[Hash[text], 36] <> "`";
    (* let example cells resolve the documented paclet's symbols unqualified, plus
       MarkdownToNotebook's own context so self-referential examples (a doc whose
       examples call MarkdownToNotebook itself) actually evaluate. *)
    ctxPath = DeleteDuplicates @ Flatten @ {Lookup[meta, "Context", Nothing], Context[MarkdownToNotebook], "System`"};
    cached = AssociationMap[exampleCacheGet, hashes];
    allHit = hashes =!= {} && AllTrue[cached, ! MissingQ[#] &];
    (* "Evaluate" -> False leaves the example cells unevaluated (input only). An
       example may itself convert another document (so its screenshot shows that
       document's own evaluated cells), which is one level of nesting; beyond that a
       hard depth cap stops a self-referential document - one whose example converts
       its own source - from recursing without end (the self-referential example
       passes "Evaluate" -> False to stop at the first level). *)
    outputs = Which[
        ! evalExamples || $convertDepth > 2, <||>,
        allHit, cached,
        True, evaluateAll[orderedCode, ctx, ctxPath]
    ];
    If[ evalExamples && $convertDepth <= 2 && Not[allHit], KeyValueMap[exampleCacheSet, outputs] ];

    blocks = annotateOutputs[blocks, hashes, outputs];
    sections = sectionsFrom[blocks];
    defCode = StringRiffle[#["Code"] & /@ sectionCells[sections, "definition"], "\n\n"];
    data = <|"meta" -> meta, "blocks" -> blocks, "sections" -> sections, "defCode" -> defCode|>;
    filled = withCreateCellID @ applyDocFlag[buildNotebook[tmplName, data], Lookup[meta, "Flag", ""]];
    If[preserveSource, filled = withMarkdownSource[filled, text, tmplName]];

    Which[
        spec === Automatic || spec === "Notebook", filled,
        spec === "Association",
            <|"Notebook" -> filled, "Metadata" -> meta, "Sections" -> Keys[sections], "Template" -> tmplName|>,
        StringQ[spec] && StringEndsQ[ToLowerCase[spec], ".md"], markdownWithImages[blocks, meta, spec],
        True, Export[spec, filled, "NB"]
    ]
]
