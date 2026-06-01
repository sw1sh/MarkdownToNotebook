---
Template: Data
ResourceType: Data
Name: Thousands of Problems for Theorem Provers (TPTP)
Description: Index of the 26,264 TPTP v9.2.1 theorem-proving benchmark problems, parseable on demand from the online corpus
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [TPTP, theorem proving, automated reasoning, ATP, benchmark, CNF, FOF, TFF, THF, SZS status, first-order logic]
Categories: [Mathematics, Computer Systems]
ContentTypes: [Numerical Data, Text]
Author: Geoff Sutcliffe
Date: 2024
Publisher: Geoff Sutcliffe, University of Miami
GeographicCoverage: Global
TemporalCoverage: 1993-2024
Language: English
Rights: The TPTP problems are freely available for research and education from tptp.org; individual problems retain their original authors' terms
Citation: "Sutcliffe, G. (2017). The TPTP Problem Library and Associated Infrastructure: From CNF and DPLL to TFF0 and TPI. Journal of Automated Reasoning, 59(4), 483-502."
RelatedSymbols: [GroupBy, Counts, Histogram, Dataset]
Links: ["[TPTP (tptp.org)](https://tptp.org)", "[TPTP v9.2.1 distribution (922 MB)](https://tptp.org/TPTP/Distribution/TPTP-v9.2.1.tgz)", "[Sutcliffe (2017), The TPTP Problem Library and Associated Infrastructure](https://link.springer.com/article/10.1007/s10817-017-9407-7)", "[WolframParser paclet (TPTPImport)](https://github.com/sw1sh/WolframParser)", "[TPTPWorld SyntaxBNF](https://github.com/TPTPWorld/SyntaxBNF)", "[SeeTPTP problem viewer](https://tptp.org/cgi-bin/SeeTPTP)"]
---

TPTP (Thousands of Problems for Theorem Provers) is the standard cross-prover
benchmark corpus for automated reasoning. Version 9.2.1 ships 26,264 problems
across 57 mathematical domains, and every modern theorem prover, Vampire, E,
Twee, Waldmeister, Zipperposition, is measured against it. The full corpus is
9.9 GB extracted, so this resource ships only the lightweight catalogue index,
one record per problem carrying its domain, logical form, SZS status, and
difficulty rating, and leaves the problem files themselves on the online TPTP
server, where any entry can be fetched and parsed on demand.

## Details

- The corpus is organised into 57 three-letter domains (`GRP` group theory,
  `SET` set theory, `NUM` number theory, `SWV` software verification, `SYN`
  syntactic, and so on). Each problem has a stable name like `GRP001-4` whose
  prefix is its domain.
- `ClauseHead` records the SZS logical form taken from the problem's `% SPC`
  header line: `CNF` (clause normal form), `FOF` (first-order form), the typed
  first-order family (`TF0` monomorphic, `TF1` polymorphic, `TCF`), the
  higher-order family (`TH0`, `TH1`), the typed-extended `TXn`, and the
  nonclassical `NXn` / `NHn` / `DHn` forms. First-order forms still dominate the
  corpus, with a large and growing typed and higher-order tail.
- `Status` is the SZS ontology status: a `Theorem` or `Unsatisfiable` clause set
  is a positive proving target; `Satisfiable` / `CounterSatisfiable` problems
  have a model; `Open` and `Unknown` problems are unresolved.
- `Rating` is the TPTP difficulty rating for the current version: the fraction
  of state-of-the-art systems (in the latest evaluation cohort) that fail to
  solve the problem. A rating of $0$ means every system solves it; a rating of
  $1.0$ means none does. Problems at rating $\geq 0.98$ form the unsolved
  frontier. Problems with no rating carry `Missing["NoRating"]`.
- Each index entry points back at the live corpus. A problem `P` in domain `D`
  is served at `https://tptp.org/cgi-bin/SeeTPTP?Category=Problems&Domain=D&File=P.p`,
  so any problem can be fetched and parsed on demand into the canonical
  `<|"Axioms" -> {...}, "Conjecture" -> phi|>` shape with the WolframParser
  paclet's `TPTPImport`, without downloading the 9.9 GB distribution. Problems
  that `include('Axioms/...')` other files resolve those the same way (the
  `Category=Axioms` endpoint).

## Content

The catalogue index, keyed by TPTP problem name, is harvested once from the
`%`-prefixed header of every `.p` file in the distribution and shipped
compressed (about 5 MB uncompressed, 26,264 entries):

```wl
#| file: TPTPProblemLibrary-index.wl
(* tptpIndex = Uncompress["..."]  - the 26,264-entry catalogue index,
   loaded from the generated sidecar file. *)
```

The resource stores the index as primary content (so `$$Data` is the whole
association) and the by-domain / by-status / by-clause-head breakdowns plus the
domain-code lookup as named content elements, fetched with [ResourceData]():

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]]] = tptpIndex
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "ByDomain"] = ReverseSort @ Counts[Values[tptpIndex][[All, "Domain"]]]
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "ByStatus"] = ReverseSort @ Counts[Values[tptpIndex][[All, "Status"]]]
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "ByClauseHead"] = ReverseSort @ Counts[Values[tptpIndex][[All, "ClauseHead"]]]
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "DomainNames"] = KeySort @ GroupBy[Values[tptpIndex], #["Domain"] &, #[[1]]["DomainName"] &]
```

## Basic Examples

Look up a single problem by its TPTP name. `GRP001-4` is one of the abelian-group
warm-ups, a low-rated unsatisfiable clause set in group theory:

```wl
tptpIndex["GRP001-4"]
```

The catalogue indexes every problem in the v9.2.1 distribution:

```wl
Length[tptpIndex]
```

<!-- => 26264 -->

Every record shares the same flat schema; a `Dataset` view of the first few
entries shows the four metadata fields plus the human-readable domain name:

```wl
Dataset[tptpIndex[[1 ;; 6]]]
```

## Scope & Additional Elements

The problems span 57 domains; the largest are set-theory exports (`SEU`),
number theory (`NUM`), and interactive-theorem-proving exports (`ITP`). The top
ten by count (also stored as the `"ByDomain"` content element):

```wl
Take[ReverseSort @ Counts[Values[tptpIndex][[All, "Domain"]]], 10]
```

The SZS status partitions the corpus; the vast majority are provable `Theorem`s
or `Unsatisfiable` clause sets, the standard positive proving targets:

```wl
ReverseSort @ Counts[Values[tptpIndex][[All, "Status"]]]
```

By clause head, first-order forms (`FOF`, `CNF`) account for two thirds of the
corpus, with the typed (`TF0`) and higher-order (`TH0`) families making up most
of the rest:

```wl
ReverseSort @ Counts[Values[tptpIndex][[All, "ClauseHead"]]]
```

## Visualizations

A histogram of the difficulty ratings: most problems sit near $0$ (solved by
every modern system), with a heavy frontier spike at $1.0$ for the problems no
current system closes:

```wl
Histogram[
    Select[Values[tptpIndex][[All, "Rating"]], NumberQ],
    20,
    AxesLabel -> {"TPTP rating", "problems"},
    PlotLabel -> "Difficulty distribution",
    ImageSize -> 520
]
```

The twelve largest domains by problem count, showing how set theory, number
theory, and verification dominate the corpus:

```wl
top = Take[ReverseSort @ Counts[Values[tptpIndex][[All, "Domain"]]], 12];
BarChart[
    Values[top],
    ChartLabels -> Keys[top],
    ChartStyle -> StandardBlue,
    PlotLabel -> "Largest TPTP domains",
    ImageSize -> 520
]
```

## Analysis

Filtering to the unsolved frontier (rating $\geq 0.98$, the problems no system
in the current evaluation cohort closes) leaves several thousand open
challenges:

```wl
frontier = Select[Keys[tptpIndex],
    NumberQ[tptpIndex[#]["Rating"]] && tptpIndex[#]["Rating"] >= 0.98 &];
Length[frontier]
```

<!-- => 4565 -->

The rating spread within a single domain shows the difficulty gradient, from
trivial warm-ups to open problems. Group theory (`GRP`) ranges across the whole
scale:

```wl
grp = Select[Values[tptpIndex],
    #["Domain"] === "GRP" && NumberQ[#["Rating"]] &][[All, "Rating"]];
<|"Min" -> Min[grp], "Median" -> N @ Median[grp],
  "Max" -> Max[grp], "Count" -> Length[grp]|>
```

<!-- => <|Min -> 0., Median -> 0.18, Max -> 1., Count -> 1207|> -->

Each index entry links back to the live corpus, so any problem can be fetched
and parsed on demand. Build the [SeeTPTP](https://tptp.org/cgi-bin/SeeTPTP) URL
from the record's domain, strip the HTML wrapper, and hand the source to the
[WolframParser](https://github.com/sw1sh/WolframParser) paclet's `TPTPImport`,
which returns the axioms and conjecture as Wolfram Language expressions
(`ForAll` / `Exists` quantifiers, `head[args]` function application, `Equal` /
`Unequal` for `=` / `!=`). No local download of the 9.9 GB distribution is
needed:

```wl
#| eval: false
Needs["Wolfram`Parser`"];

tptpProblemText[name_String] := Block[{domain = tptpIndex[name, "Domain"], html, pre},
    html = Import[
        "https://tptp.org/cgi-bin/SeeTPTP?Category=Problems&Domain=" <>
            domain <> "&File=" <> name <> ".p",
        "Text"];
    pre = First @ StringCases[html, "<pre>" ~~ body___ ~~ "</pre>" :> body];
    StringReplace[
        StringReplace[pre, RegularExpression["<[^>]*>"] -> ""],
        {"&lt;" -> "<", "&gt;" -> ">", "&amp;" -> "&"}]
];

TPTPImport[tptpProblemText["GRP001-4"]]
```

<!-- => <|"Axioms" -> {...4 group axioms...}, "Conjecture" -> _Equal|> -->

## Author Notes

This resource was drafted with Claude (Anthropic, Opus 4) under the supervision
of Nikolay Murzin. The catalogue index was harvested mechanically from the TPTP
v9.2.1 distribution headers; the metadata schema, example code, and explanatory
prose were model-generated and reviewed and edited by the human supervisor. The
TPTP problem library itself is the work of Geoff Sutcliffe, Christian Suttner,
and the many problem contributors, maintained from 1993 onward.
