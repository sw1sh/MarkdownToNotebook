#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Build the IntroToQuantumComputing book end-to-end:

     1. Convert every chapter markdown under chapters/*.md into a chapter
        notebook under book/<n>-<slug>.nb using `Template: Chapter`
        (Wolfram Book Tools styles).
     2. Stamp ExpressionUUIDs on each Section/Subsection/Subsubsection cell
        (NotebookOpen + NotebookSave round-trip via the FE) so the TOC
        buttons have stable jump targets.
     3. Generate book/Contents.nb using the **Wolfram Book Tools paclet's
        own helpers** - `WolframBookTools`Private`makeContentsCellsToWrite`
        plus the same inline TOC stylesheet `WBTMakeContentsFromDialog`
        writes - so the TOC looks identical to what the palette's "Make
        Contents" button produces.
     4. Build book/Master.nb: concatenate every chapter's cells (after
        stripping Tentative/WebOnly/Suggestion editorial markers, mirroring
        `WBTCreateCorrespondingPrintDirectory`) into a single book-form
        notebook using BookToolsStyles.nb.
     5. On --publish, CloudDeploy each chapter, Contents.nb, and Master.nb
        to https://www.wolframcloud.com/obj/.../IntroToQuantumComputing/
        with public read.

   Point the Wolfram Book Tools palette ("Set Chapters Directory") at the
   `book/` output to edit chapters interactively. *)

$here     = If[ValueQ[$ScriptCommandLine] && $ScriptCommandLine =!= {},
                 DirectoryName @ AbsoluteFileName @ First @ $ScriptCommandLine,
                 NotebookDirectory[]];
$skillDir = ParentDirectory @ ParentDirectory @ $here;
(* macOS / APFS is case-insensitive; "Chapters" alongside source "chapters"
   collides. Use a distinct name. *)
$outDir   = FileNameJoin[{$here, "book"}];

$publish = MemberQ[Rest @ $ScriptCommandLine, "--publish"];

Print["Building book in: ", $here];
Print["Output directory: ", $outDir];

If[! DirectoryQ[$outDir], CreateDirectory[$outDir]];

PacletInstall["Wolfram/QuantumFramework"];
PacletInstall["WolframBookTools"];
Needs["WolframBookTools`"];

Get[FileNameJoin[{$skillDir, "MarkdownToNotebook.wl"}]];

chapters = Sort @ FileNames["*.md", FileNameJoin[{$here, "chapters"}]];
If[ chapters === {}, Print["No chapters found."]; Exit[0]];

(* === 1. md -> chapter .nb === *)
builtFiles = {};
Do[
    With[{out = FileNameJoin[{$outDir, FileBaseName[md] <> ".nb"}]},
        Print["[", FileBaseName[md], "] -> ", out];
        MarkdownToNotebook[md, out];
        AppendTo[builtFiles, out];
        Print["    ok"]
    ],
    {md, chapters}
];

(* === 2. stamp ExpressionUUIDs on every Section/Subsection/Subsubsection ===
   `MarkdownToNotebook` does not emit ExpressionUUIDs; the FE assigns one
   when the file is opened. Round-trip each chapter through the FE so the
   UUIDs become persistent on disk, where `makeContentsCellsToWrite` can
   read them via `Get`. *)
Print["Stamping UUIDs on heading cells (FE round-trip)"];
UsingFrontEnd @ Do[
    With[{nbo = NotebookOpen[file, Visible -> False]},
        (* touching the UUID forces the FE to assign one if absent *)
        Do[CurrentValue[c, ExpressionUUID],
            {c, Cells[nbo, CellStyle ->
                {"Section", "Subsection", "Subsubsection"}]}];
        NotebookSave[nbo];
        NotebookClose[nbo];
    ],
    {file, builtFiles}
];

(* === 3. Contents.nb via WBT's own helpers === *)
$headingList = {"Section", "Subsection", "Subsubsection"};

(* The same inline stylesheet WBTMakeContentsFromDialog (line 626-633 of
   WolframBookTools.m) constructs for the Contents notebook. Note this is
   *not* BookToolsStyles.nb - WBT defines its own TOC styles inline so the
   Contents notebook is self-contained. *)
$tocStylesheet = Notebook[{
    Cell[StyleData["TOCTitle"],
        CellFrame -> {{0, 0}, {0, 0}},
        CellMargins -> {{47, Inherited}, {12, 64}},
        CellGroupingRules -> {"SectionGrouping", 60},
        FontFamily -> "Source Sans Pro Semibold", FontSize -> 28,
        FontSlant -> "Plain", FontColor -> GrayLevel[0]],
    Cell[StyleData["TOCSection"],
        CellMargins -> {{66, 3}, {-13, 9}},
        FontFamily -> "Source Sans Pro Semibold", FontSize -> 20,
        FontSlant -> "Plain", FontColor -> GrayLevel[0]],
    Cell[StyleData["TOCSubsection"],
        CellMargins -> {{82, 3}, {2, 7}},
        FontFamily -> "Source Sans Pro Semibold", FontSize -> 16,
        FontSlant -> "Italic", FontColor -> GrayLevel[0.2]],
    Cell[StyleData["TOCSubsubsection"],
        CellMargins -> {{95, 3}, {2, 7}},
        FontFamily -> "Source Sans Pro Semibold", FontSize -> 13,
        FontSlant -> "Italic", FontColor -> GrayLevel[0.25]]
}, Visible -> False, StyleDefinitions -> "PrivateStylesheetFormatting.nb"];

(* `WolframBookTools`Private`makeContentsCellsToWrite` uses `Get` on each
   chapter file, which trips on the FE-serialized SummaryBox output that
   `MarkdownToNotebook` writes for QuantumState/etc. results (the kernel
   parser fails partway through). Replicate the same TOC cell shape it
   would produce, but read each chapter via `NotebookGet` so SummaryBox
   round-tripping is the FE's problem, not the parser's. *)
$tocStyleRules = {
    "Section" -> "TOCSection",
    "Subsection" -> "TOCSubsection",
    "Subsubsection" -> "TOCSubsubsection"
};

(* Extract the plain title text from a heading cell's content. The chapter
   `Section` cell is `TextData[{CounterBox["Section"], StyleBox[" | ",
   "SectionBar"], "Chapter title"}]`; we want just "Chapter title".
   Strategy: walk the TextData tree, drop CounterBox and the SectionBar
   separator, unwrap StyleBox/ButtonBox to their inner content, and
   concatenate the remaining plain strings. *)
extractTitleStrings[expr_] := Which[
    StringQ[expr], {expr},
    MatchQ[expr, _CounterBox], {},
    MatchQ[expr, StyleBox[" | ", "SectionBar", ___]], {},
    MatchQ[expr, StyleBox[_, ___]], extractTitleStrings[First[expr]],
    MatchQ[expr, ButtonBox[_, ___]], extractTitleStrings[First[expr]],
    MatchQ[expr, TextData[_List]], Flatten[extractTitleStrings /@ First[expr]],
    MatchQ[expr, _TextData], extractTitleStrings[First[expr]],
    MatchQ[expr, RowBox[_List]], Flatten[extractTitleStrings /@ First[expr]],
    MatchQ[expr, _Cell], extractTitleStrings[First[expr]],
    True, {}
];

tocTitleFor[content_] := StringTrim @ StringJoin @ extractTitleStrings[content];

makeTOCCell[fn_String, content_, style_String, uuid_String] := Cell[
    TextData @ ButtonBox[
        tocTitleFor[content],
        ButtonFunction :> Module[{nb},
            nb = NotebookOpen[FileNameJoin[{NotebookDirectory[], fn}]];
            NotebookFind[nb, uuid, All, ExpressionUUID]
        ],
        Evaluator -> Automatic,
        BaseStyle -> (style /. $tocStyleRules),
        Appearance -> None
    ],
    style /. $tocStyleRules
];

(* `NotebookGet` strips ExpressionUUID from the returned cell options, so
   read live CellObjects and pull each one's UUID via CurrentValue. *)
contentsCellsFromChapter[file_String] := Module[{out = {}, basename},
    basename = FileNameTake[file, -1];
    UsingFrontEnd[
        With[{nbo = NotebookOpen[file, Visible -> False]},
            Do[
                Module[{content, style, uuid},
                    content = NotebookRead[c];
                    uuid = CurrentValue[c, ExpressionUUID];
                    style = First[Cases[{content},
                        Cell[_, s_String, ___] :> s, {0, 2}, 1], None];
                    If[StringQ[uuid] && uuid =!= "" && StringQ[style],
                        AppendTo[out, makeTOCCell[basename,
                            content[[1]], style, uuid]]
                    ]
                ],
                {c, Cells[nbo, CellStyle ->
                    {"Section", "Subsection", "Subsubsection"}]}
            ];
            NotebookClose[nbo];
        ]
    ];
    out
];

Print["Building Contents.nb"];
contentsFile = FileNameJoin[{$outDir, "Contents.nb"}];
UsingFrontEnd @ Module[{contentsCells, nb},
    contentsCells = Catenate[contentsCellsFromChapter /@ builtFiles];
    nb = NotebookPut @ Notebook[
        Prepend[contentsCells, Cell["Contents", "TOCTitle"]],
        StyleDefinitions -> $tocStylesheet,
        WindowToolbars -> {},
        WindowSize -> {750, 800}
    ];
    NotebookSave[nb, contentsFile];
    NotebookClose[nb];
];
Print["    -> ", contentsFile, " (", Length[Cases[Import[contentsFile, "NB"],
    Cell[_, ("TOCSection" | "TOCSubsection" | "TOCSubsubsection"), ___],
    Infinity]], " entries)"];

(* === 4. Master.nb: concat all chapters with editorial cells stripped ===
   This mirrors WBTCreateCorrespondingPrintDirectory's Master.nb step
   (line 3854-3866 of WolframBookTools.m): import each chapter's cells,
   strip Tentative/WebOnly/Suggestion editorial markers, and concatenate
   under a single BookToolsStyles.nb. *)
Print["Building Master.nb (concat + strip editorial cells)"];
masterFile = FileNameJoin[{$outDir, "Master.nb"}];
UsingFrontEnd @ Module[{cellLists, masterCells, nb},
    cellLists = Map[
        Function[file,
            Module[{nbo = NotebookOpen[file, Visible -> False], cells},
                cells = First @ NotebookGet[nbo];
                NotebookClose[nbo];
                (* strip the front-end-only editorial cells that
                   WBTCreateCorrespondingPrintDirectory removes for print *)
                DeleteCases[cells,
                    Cell[_, _, "Tentative" | "WebOnly" | "Suggestion", ___],
                    Infinity]
            ]
        ],
        builtFiles
    ];
    masterCells = Catenate[cellLists];
    nb = NotebookPut @ Notebook[masterCells,
        StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
            "BookToolsStyles.nb", CharacterEncoding -> "UTF-8"]];
    NotebookSave[nb, masterFile];
    NotebookClose[nb];
];
Print["    -> ", masterFile];

(* === 5. optional cloud publish === *)
If[$publish,
    Print["Publishing to Wolfram Cloud (public)"];
    UsingFrontEnd @ Do[
        Module[{nbo, nb, co, name = FileNameTake[file, -1]},
            nbo = NotebookOpen[file, Visible -> False];
            nb = NotebookGet[nbo];
            NotebookClose[nbo];
            co = CloudDeploy[nb,
                "IntroToQuantumComputing/" <> name,
                Permissions -> "Public"];
            Print["    ", name, " -> ", First[co]];
        ],
        {file, Join[builtFiles, {contentsFile, masterFile}]}
    ];
];

Print["Done. ", Length[chapters], " chapter(s) + Contents.nb + Master.nb under ", $outDir]
