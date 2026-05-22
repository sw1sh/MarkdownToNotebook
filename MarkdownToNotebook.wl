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

paraSplit[{}, collected_] := {Reverse[collected], {}}
paraSplit[lines_List, collected_] := Block[{line = First[lines]},
    If[ StringTrim[line] === "" || fenceQ[line] || headingQ[line] || listItemQ[line],
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

listText[line_String] := StringTrim @ StringDrop[StringTrim[line], 2]

listSplit[{}, collected_] := {Reverse[collected], {}}
listSplit[lines_List, collected_] := If[ listItemQ[First[lines]],
    listSplit[Rest[lines], Prepend[collected, listText[First[lines]]]],
    {Reverse[collected], lines}
]

(* GitHub-flavored tables: a "| a | b |" row whose next line is a "|---|---|"
   separator. Cells are split on "|" with the outer pipes trimmed. *)
tableRowLineQ[line_String] := StringContainsQ[line, "|"] && StringTrim[line] =!= "" && ! fenceQ[line] && ! headingQ[line]

tableSepQ[line_String] := StringContainsQ[line, "-"] && StringContainsQ[line, "|"] &&
    StringMatchQ[StringTrim[line], ("|" | ":" | "-" | " ") ..]

splitTableRow[line_String] := StringTrim /@ StringSplit[StringTrim[StringTrim[line], "|"], "|"]

tableSplit[{}, collected_] := {Reverse[collected], {}}
tableSplit[lines_List, collected_] := If[ tableRowLineQ[First[lines]],
    tableSplit[Rest[lines], Prepend[collected, First[lines]]],
    {Reverse[collected], lines}
]

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
        headingQ[line],
            blockLoop[rest, Prepend[acc, headingBlock[line]]]
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
        True,
            split = paraSplit[lines, {}];
            blockLoop[Last[split], Prepend[acc, <|"Type" -> "Prose", "Text" -> StringRiffle[First[split], " "]|>]]
    ]
]

parseBlocks[body_String] := blockLoop[StringSplit[body, "\n"], {}]

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
   body, resolved (file or URL) relative to the document. *)
resolveBlock[b_Association, base_String] := If[
    b["Type"] === "Code" && KeyExistsQ[b["Options"], "file"],
    Append[b, "Code" -> Import[joinSource[base, b["Options"]["file"]], "Text"]],
    b
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

sectionText[sections_, key_] := StringRiffle[
    Cases[Lookup[sections, key, {}], b_ /; b["Type"] === "Prose" :> StringReplace[b["Text"], "`" -> ""]],
    " "
]

(* === notebook evaluation with a cumulative-hash cache ===
   All executable cells are evaluated in document order, threading state, so a
   cell's cache key depends on every cell before it (whole-notebook sequence). *)

cumulativeHashes[cells_List] := Map[Hash, Rest @ FoldList[#1 <> mdSep <> #2["Code"] &, "", cells]]

(* output boxes for an evaluated cell. A NotebookObject result - an example that
   opens the produced notebook, e.g. NotebookPut[MarkdownToNotebook[...]] - is shown
   the way the front end shows any NotebookObject output: a thumbnail of the
   notebook. We capture that thumbnail as a static image (a bare reference box would
   not render once the notebook is closed). This is the published-WFR convention for
   notebook-valued results; the converter does not rasterize Notebook *expressions*
   itself - the example chooses to display one by opening it. *)
outputBoxes[res_] := Which[
    res === Null, Null,
    Head[res] === NotebookObject,
        With[{img = Quiet @ Rasterize[res, ImageResolution -> 96]}, Quiet @ NotebookClose[res]; ToBoxes[img]],
    True, ToBoxes[res]
]

accumEval[state_, b_] := Block[{code = state["code"] <> mdSep <> b["Code"], res, tmp},
    (* Get a temp package so every top-level statement runs (ToExpression on a
       multi-statement string only takes the first); Get returns the last value. *)
    tmp = FileNameJoin[{$TemporaryDirectory, "mtnb-cell-" <> IntegerString[Hash[code], 36] <> ".wl"}];
    Export[tmp, b["Code"], "Text"];
    res = Quiet @ Get[tmp];
    <|"code" -> code, "out" -> Append[state["out"], Hash[code] -> outputBoxes[res]]|>
]

(* a front end is active for the whole pass so an example may open the notebook it
   produces (NotebookPut) and have its thumbnail captured (see outputBoxes). *)
evaluateAll[cells_List, ctx_String, ctxPath_List] := Block[{$Context = ctx, $ContextPath = ctxPath},
    UsingFrontEnd[Fold[accumEval, <|"code" -> "", "out" -> <||>|>, cells]]["out"]
]

(* attach each executable block's output (by cumulative hash) so builders read
   block["OutputBoxes"] directly instead of recomputing hashes. *)
annotateOutputs[blocks_List, hashes_List, outputs_] := Block[{i = 0},
    Map[
        b |-> If[ executableQ[b],
            (i += 1; Append[b, "OutputBoxes" -> Lookup[outputs, hashes[[i]], Missing[]]]),
            b
        ],
        blocks
    ]
]

(* === notebook cell builders === *)

$exampleOrder = {
    "basic examples", "scope", "options", "applications",
    "properties and relations", "possible issues", "neat examples"
}

$exampleTitle = <|
    "basic examples" -> "Basic Examples",
    "scope" -> "Scope",
    "options" -> "Options",
    "applications" -> "Applications",
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
inputBoxes[code_String] := Block[{boxes, parsed},
    boxes = Quiet @ UsingFrontEnd @ MathLink`CallFrontEnd[FrontEnd`ReparseBoxStructurePacket[StringTrim[code]]];
    If[ FreeQ[boxes, $Failed] && (StringQ[boxes] || ! AtomQ[boxes]),
        boxes,
        parsed = Quiet @ ToExpression[code, StandardForm, Defer];
        If[parsed === $Failed, code, ToBoxes[parsed]]
    ]
]

exampleIO[code_String, outBoxes_, n_Integer] := Block[{
    inCell = Cell[BoxData[inputBoxes[code]], "Input", CellLabel -> "In[" <> ToString[n] <> "]:= "]
},
    If[ MissingQ[outBoxes] || outBoxes === Null,
        {inCell},
        {Cell[CellGroupData[{
            inCell,
            Cell[BoxData[outBoxes], "Output", CellLabel -> "Out[" <> ToString[n] <> "]= "]
        }, Open]]}
    ]
]

functionSlot[opts_, defCode_String] := If[ defCode === "",
    slotDefault[opts],
    {Cell[BoxData[defCode], "Input", CellTags -> {"Function"}]}
]

(* a Usage section is a sequence of usage statements, one per prose paragraph
   that begins with a `code` span: the code is the signature (e.g.
   `MarkdownToNotebook[source]`) and the rest is its description. The signature
   is templated like the "Template Input" button (arguments italic, head linked)
   and the description keeps its inline formatting. *)
usageStatement[text_String] := StringCases[StringTrim[text],
    StartOfString ~~ "`" ~~ c : Shortest[__] ~~ "`" ~~ rest___ :> {c, StringTrim[rest]}, 1]

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

notesSlot[opts_, sections_] := Block[{prose = rawSectionText[sections, "details & options"]},
    If[prose === "", slotDefault[opts], {Cell[TextData @ inlineTextData[prose], "Notes"]}]
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

examplesSlot[opts_, sections_] := Block[{keys},
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
   tables -> a GridBox, executable cells -> evaluated Input/Output. A new prose
   lead-in after earlier content starts a new example, so an ExampleDelimiter is
   inserted before it and the In[]/Out[] counter restarts. *)
exampleContent[sectionBlocks_, textStyle_String] := Block[{counter = 0, started = False, out = {}},
    Do[
        Which[
            block["Type"] === "Prose",
                If[started, AppendTo[out, exampleDelimiterCell]; counter = 0];
                AppendTo[out, Cell[TextData @ inlineTextData[block["Text"]], textStyle]];
                started = True,
            block["Type"] === "Table",
                AppendTo[out, tableCell[block]]; started = True,
            executableQ[block],
                counter += 1; out = Join[out, exampleIO[block["Code"], block["OutputBoxes"], counter]]; started = True
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
        "Keywords", fillListCells[opts, asList @ Lookup[meta, "Keywords", {}]],
        "Links", fillLinkCells[opts, asList @ Lookup[meta, "Links", {}]],
        "SourceControlURL", fillTextCells[opts, Lookup[meta, "SourceControlURL", ""]],
        "Source/Reference Citation", fillListCells[opts, asList @ Lookup[meta, "Sources", {}]],
        "Related Symbols", fillListCells[opts, asList @ Lookup[meta, "RelatedSymbols", Lookup[meta, "SeeAlso", {}]]],
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

fillDocString[nb_, style_String, value_String] := If[ value === "",
    nb,
    nb /. Cell["XXXX", style, o___] :> Cell[value, style, o]
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

templateBox[code_String] := Block[{boxes},
    Needs["DocumentationTools`"];
    boxes = Quiet @ UsingFrontEnd @ DocumentationTools`Private`ParseTextTemplate[StringTrim[code], $docName];
    (* fall back to a plain parse if the front-end template parse is unavailable *)
    If[ FreeQ[boxes, $Failed] && (StringQ[boxes] || MatchQ[Head[boxes], RowBox | StyleBox | SubscriptBox | SuperscriptBox | FractionBox | SqrtBox]),
        boxes,
        inputBoxes[code]
    ]
]

symbolInContextQ[name_String, ctx_String] := ctx =!= "" &&
    StringMatchQ[name, (LetterCharacter | "$") ~~ (WordCharacter | "$") ...] &&
    Quiet[Names[ctx <> name] =!= {}]

(* drop every ButtonBox link wrapper, keeping its content. ParseTextTemplate
   eagerly links any System symbol it recognizes (Notebook, ResourceFunction,
   ...), which renders as ugly inline links - especially a whole expression like
   ResourceFunction["..."]. We strip those so a usage signature reads as code. *)
stripLinks[boxes_] := boxes //. ButtonBox[content_, ___] :> content

(* prose inline `code`: parse it literally (inputBoxes preserves strings and adds
   no template italics or links) - never auto-linked. Symbols are linked only when
   the author asks, via an explicit markdown link with a `code`-wrapped label,
   e.g. [`WCAGContrastRatio`](paclet:Wolfram/AccessibleColors/ref/WCAGContrastRatio)
   (handled in linkInline). ParseTextTemplate is reserved for Usage signatures
   (usagePair), where italic argument styling is wanted; on full code it would
   even italicize tokens inside string literals ("doc.md" -> "...StyleBox[doc]..."). *)
codeToInline[code_String] := Cell[BoxData[inputBoxes[code]], "InlineFormula"]

(* double-backtick ``code`` -> the palette's "Code (Inline)": a literal,
   non-linkified monospace span (InlineCode), unlike Template Input. *)
literalCodeInline[code_String] := Cell[BoxData[StyleBox[code, "InlineCode"]], "InlineCode"]

(* $math$ -> the palette's "Traditional Math" button: boxes shown in
   TraditionalForm inside an InlineFormula cell. *)
mathInline[math_String] := Cell[BoxData[FormBox[inputBoxes[math], TraditionalForm]], "InlineFormula"]

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

linkInline[text_String, url_String] := If[
    StringMatchQ[text, "`" ~~ ___ ~~ "`"],
    Cell[BoxData @ linkButton[StringTake[text, {2, -2}], url], "InlineFormula"],
    linkButton[text, url]
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

inlineTextData[text_String] := StringSplit[text, {
    "[" ~~ t : Shortest[Except["]"] ..] ~~ "](" ~~ u : Shortest[Except[")"] ..] ~~ ")" :> linkInline[t, u],
    "[`" ~~ t : Shortest[Except["`"] ..] ~~ "`]" :> linkInferred[t],
    "``" ~~ c : Shortest[__] ~~ "``" :> literalCodeInline[c],
    "`" ~~ c : Shortest[__] ~~ "`" :> codeToInline[c],
    "$" ~~ m : Shortest[Except["$"] ..] ~~ "$" :> mathInline[m],
    (* *word* -> an italic argument reference: a bare StyleBox in the TextData,
       the form usage descriptions use (StyleBox[arg, "TI"]), not a formula cell *)
    Verbatim["*"] ~~ i : (Except["*"] ..) ~~ Verbatim["*"] :> StyleBox[i, "TI"]
}]

(* a Symbol page's "## Usage" prose, rendered as one Usage cell with its inline
   formatting. Symbols are linked only where the author wrote an explicit
   [`Symbol`](paclet:...) link (see linkInline); inline `code` is not auto-linked. *)
usageCell[rawUsage_String] := Cell[
    TextData @ Prepend[inlineTextData[StringTrim[rawUsage]], Cell["   ", "ModInfo"]],
    "Usage"
]

(* a GitHub-flavored table -> a GridBox with gridlines (the palette's Insert
   Custom Table). Header row is bold; short rows are padded to the column count;
   each cell's text gets the usual inline formatting. *)
tableCellBox[text_String, opts___] := Cell[TextData @ inlineTextData[text], "TableText", opts]

tableGridRow[cells_List, ncol_Integer, opts___] :=
    tableCellBox[#, opts] & /@ PadRight[cells, ncol, ""]

tableCell[block_] := Block[{ncol = Length[block["Header"]], rows},
    rows = Join[
        {tableGridRow[block["Header"], ncol, FontWeight -> Bold]},
        tableGridRow[#, ncol] & /@ block["Rows"]
    ];
    Cell[BoxData[GridBox[rows,
        GridBoxAlignment -> {"Columns" -> {{Left}}, "Rows" -> {{Baseline}}},
        GridBoxDividers -> {"Columns" -> {{True}}, "Rows" -> {{True}}},
        GridBoxItemSize -> {"Columns" -> {{Automatic}}, "Rows" -> {{Automatic}}}
    ]], "Text"]
]

docExampleCells[sections_] := Block[{cells = sectionCells[sections, "basic examples"], counter = 0},
    Catenate @ Map[
        block |-> (counter += 1; exampleIO[block["Code"], block["OutputBoxes"], counter]),
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
    notes = rawSectionText[sections, "details & options"];
    nb = fillDocString[nb, "ObjectName", name];
    If[ usage =!= "",
        nb = nb /. Cell[_, "Usage", ___] :> usageCell[usage]
    ];
    If[ notes =!= "",
        nb = nb /. Cell[_, "Notes", o___] :> Cell[TextData @ inlineTextData[notes], "Notes", o]
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
            "Heading", If[block["Level"] <= 1, {}, {Cell[block["Text"], Lookup[$tutorialHeadingStyle, block["Level"], "Subsubsection"]]}],
            "Prose", {Cell[TextData @ inlineTextData[block["Text"]], "Text"]},
            "List", Map[Cell[TextData @ inlineTextData[#], "Item"] &, block["Items"]],
            "Table", {tableCell[block]},
            "Code", If[executableQ[block], (counter += 1; exampleIO[block["Code"], block["OutputBoxes"], counter]), {Cell[block["Code"], "Program"]}],
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

(* === default style-map builder ===
   No template/slots: markdown maps directly to standard documentation styles,
   so the author never writes cell styles. *)

$headingStyleMap = <|1 -> "Title", 2 -> "Section", 3 -> "Subsection", 4 -> "Subsubsection"|>

defaultNotebook[data_] := Block[{counter = 0, cells},
    cells = Catenate @ Map[
        block |-> Switch[block["Type"],
            "Heading", {Cell[block["Text"], Lookup[$headingStyleMap, block["Level"], "Subsubsection"]]},
            "Prose", {Cell[block["Text"], "Text"]},
            "List", Map[Cell[TextData @ inlineTextData[#], "Item"] &, block["Items"]],
            "Table", {tableCell[block]},
            "Code",
                If[ executableQ[block],
                    (counter += 1; exampleIO[block["Code"], block["OutputBoxes"], counter]),
                    {Cell[block["Code"], "Program"]}
                ],
            _, {}
        ],
        data["blocks"]
    ];
    Notebook[cells, StyleDefinitions -> "Default.nb"]
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

buildNotebook["FunctionResource", data_] := resourceNotebook["Function", data]
buildNotebook["Paclet", data_] := resourceNotebook["Paclet", data]
buildNotebook["Symbol", data_] := symbolNotebook[data]
buildNotebook["Guide", data_] := guideNotebook[data]
buildNotebook["TechNote", data_] := tutorialNotebook[data]
buildNotebook[_, data_] := defaultNotebook[data]

(* === entry point === *)

Options[MarkdownToNotebook] = {"Cache" -> True, "CacheDirectory" -> Automatic}

(* the result is chosen by the optional second argument:
     MarkdownToNotebook[source]                -> the Notebook expression
     MarkdownToNotebook[source, "Notebook"]    -> the Notebook expression
     MarkdownToNotebook[source, "Association"] -> the parsed structure
     MarkdownToNotebook[source, file]          -> write the notebook to file, return it
   ("Notebook"/"Association" are reserved; any other string is a file path.) The
   layout always comes from the document's own Template frontmatter key. *)
MarkdownToNotebook[file_String, opts : OptionsPattern[]] := MarkdownToNotebook[file, Automatic, opts]

MarkdownToNotebook[file_String, spec : (_String | Automatic), opts : OptionsPattern[]] := Block[{
    src, text, parsed, meta, blocks, sections, tmplName, defCode, ctx, ctxPath,
    orderedCode, hashes, cacheFile, cached, allHit, outputs, data, filled
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

    (* evaluate every executable cell in document order, threading state in a
       private context (so the document's own code can't clobber the live
       session), cached by a cumulative hash of all cells up to each one. *)
    orderedCode = Cases[blocks, b_ /; executableQ[b]];
    hashes = cumulativeHashes[orderedCode];
    ctx = "MTNB$" <> IntegerString[Hash[text], 36] <> "`";
    (* let example cells resolve the documented paclet's symbols unqualified *)
    ctxPath = DeleteDuplicates @ Flatten @ {Lookup[meta, "Context", Nothing], "System`"};
    cacheFile = With[{cacheDir = OptionValue["CacheDirectory"]},
        Which[
            StringQ[cacheDir], FileNameJoin[{cacheDir, src["Name"] <> ".cache.wxf"}],
            src["Local"], file <> ".cache.wxf",
            True, FileNameJoin[{$TemporaryDirectory, "mtnb-" <> IntegerString[Hash[src["Id"]], 36] <> ".cache.wxf"}]
        ]
    ];
    cached = If[ TrueQ[OptionValue["Cache"]] && FileExistsQ[cacheFile], Import[cacheFile, "WXF"], <||>];
    allHit = hashes =!= {} && AllTrue[hashes, KeyExistsQ[cached, #] &];
    outputs = If[ TrueQ[OptionValue["Cache"]] && allHit,
        KeyTake[cached, hashes],
        evaluateAll[orderedCode, ctx, ctxPath]
    ];
    If[ TrueQ[OptionValue["Cache"]] && hashes =!= {} && Not[allHit],
        Export[cacheFile, outputs, "WXF"]
    ];

    blocks = annotateOutputs[blocks, hashes, outputs];
    sections = sectionsFrom[blocks];
    defCode = StringRiffle[#["Code"] & /@ sectionCells[sections, "definition"], "\n\n"];
    data = <|"meta" -> meta, "blocks" -> blocks, "sections" -> sections, "defCode" -> defCode|>;
    filled = buildNotebook[tmplName, data];

    Which[
        spec === Automatic || spec === "Notebook", filled,
        spec === "Association",
            <|"Notebook" -> filled, "Metadata" -> meta, "Sections" -> Keys[sections], "Template" -> tmplName|>,
        True, Export[spec, filled, "NB"]
    ]
]
