#!/usr/bin/env wolframscript
(* Generate the headline image for the MarkdownToNotebook function repository
   resource: a markdown source card, an arrow, and the notebook it converts into. *)
SetDirectory[DirectoryName[$InputFileName]];

md = Style[
    Column[{
        "# A sine wave", "",
        "The plot of $\\sin x$", "",
        "```wl", "Plot[Sin[x],", "  {x, 0, 2 Pi}]", "```"},
      Spacings -> 0.55],
    FontFamily -> "Source Code Pro", FontSize -> 13, FontColor -> GrayLevel[0.25]];

nb = Column[{
     Style["A sine wave", FontSize -> 18, FontWeight -> Bold, FontColor -> GrayLevel[0.1], FontFamily -> "Source Sans Pro"],
     Style["The plot of sin x", FontSize -> 11, FontColor -> GrayLevel[0.35], FontFamily -> "Source Sans Pro"],
     Plot[Sin[x], {x, 0, 2 Pi}, ImageSize -> 160, PlotStyle -> StandardBlue, AspectRatio -> 0.5, Ticks -> None, AxesStyle -> GrayLevel[0.6]]},
   Alignment -> Left, Spacings -> 1.0];

card[content_] := Framed[content,
    Background -> White, FrameStyle -> Directive[AbsoluteThickness[1], GrayLevel[0.85]],
    FrameMargins -> 18, RoundingRadius -> 10];

headline = Framed[
    Row[{
        card[md],
        Style["\[LongRightArrow]", FontSize -> 34, FontColor -> StandardBlue],
        card[nb]},
      Spacer[26], Alignment -> Center],
    Background -> GrayLevel[0.97], FrameStyle -> None, FrameMargins -> 30, RoundingRadius -> 16];

img = Rasterize[headline, ImageResolution -> 144, Background -> GrayLevel[0.97]];
Export["images/headline.png", img];
WriteString["stdout", "wrote docs/images/headline.png ", ToString[ImageDimensions[img]], "\n"];
