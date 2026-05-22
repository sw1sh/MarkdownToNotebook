#!/usr/bin/env wolframscript
(* Regenerate the screenshots embedded in docs/*.md so they track the current
   converter output and the live Documentation Tools palette. Each image is
   rebuilt from source: the AccessibleColors markdown is converted and (for doc
   pages) run through DocumentationBuild, the resource notebook is opened, and
   the system palette is loaded; every notebook is rasterized to docs/images/.

   Run from anywhere:  wolframscript docs/update-screenshots.wls            *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

docsDir = DirectoryName[$InputFileName]
repoDir = ParentDirectory[docsDir]
imagesDir = FileNameJoin[{docsDir, "images"}]
acDir = FileNameJoin[{repoDir, "examples", "AccessibleColors"}]

Get[FileNameJoin[{repoDir, "MarkdownToNotebook.wl"}]]
Needs["DocumentationBuild`"]
PacletDirectoryLoad[acDir]
Needs["Wolfram`AccessibleColors`"]

(* resolution for the rasters; lower the page DPI so the long doc pages stay a
   reasonable file size, keep the palette crisp. A window width is forced so the
   page rasters at its real layout rather than collapsing to the minimum. *)
$pageDPI = 96
$paletteDPI = 144
$pageWidth = 1010

saveImage[img_, name_] := (
    Export[FileNameJoin[{imagesDir, name}], img];
    print["  wrote images/", name, "  ", ImageDimensions[img]]
)

(* convert a markdown doc to its authoring notebook expression *)
authoringNotebook[mdFile_String] :=
    MarkdownToNotebook[mdFile, "Notebook"]

(* a built reference/guide page: convert, then run DocumentationBuild (the
   Preview button) and rasterize the resulting page at a fixed width *)
captureBuiltPage[mdFile_String, name_String] := UsingFrontEnd @ Module[{built, img},
    built = DocumentationBuild`DocumentationBuildNotebook[None, authoringNotebook[mdFile]];
    SetOptions[built, WindowSize -> {$pageWidth, Automatic}, Magnification -> 1];
    img = Rasterize[built, ImageResolution -> $pageDPI];
    Quiet @ NotebookClose[built];
    saveImage[img, name]
]

(* a notebook shown as authored (no build): open and rasterize. dpi is kept low
   for the heavy definition notebook (its docked toolbar + dynamic panels are
   large enough to exhaust the rasterizer at full resolution). *)
captureNotebook[nbExpr_, name_String, dpi_:$pageDPI, width_:$pageWidth] := UsingFrontEnd @ Module[{obj, img},
    obj = NotebookPut[nbExpr];
    SetOptions[obj, WindowSize -> {width, Automatic}, Magnification -> 1];
    img = Rasterize[obj, ImageResolution -> dpi];
    NotebookClose[obj];
    saveImage[img, name]
]

print["updating documentation screenshots"]

(* 1. the Documentation Tools palette *)
palettePath = FileNameJoin[{$InstallationDirectory, "AddOns", "Applications",
    "DocumentationTools", "FrontEnd", "Palettes", "DocumentationTools.nb"}]
If[ FileExistsQ[palettePath],
    captureNotebook[Get[palettePath], "palette.png", $paletteDPI],
    print["  palette not found: ", palettePath]
]

(* 2. a built Symbol reference page *)
captureBuiltPage[FileNameJoin[{acDir, "docs", "Symbols", "WCAGContrastRatio.md"}], "symbol-page.png"]

(* 3. a built Guide page *)
captureBuiltPage[FileNameJoin[{acDir, "docs", "Guides", "AccessibleColors.md"}], "guide-page.png"]

(* 4. a built Tutorial (tech note) page *)
captureBuiltPage[FileNameJoin[{acDir, "docs", "Tutorials", "DesigningAccessibleColorSchemes.md"}], "tutorial-page.png"]

(* 5. the paclet-repository definition notebook, shown as authored (low DPI to
   keep the tall, toolbar-heavy notebook within the rasterizer's limits) *)
captureNotebook[
    authoringNotebook[FileNameJoin[{acDir, "ResourceDefinition.md"}]],
    "resource-definition.png", 54
]

print["done"]
