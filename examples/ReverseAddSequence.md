---
Template: FunctionResource
ResourceType: Function
Name: ReverseAddSequence
ShortName: ReverseAddSequence
Description: The reverse-and-add iteration applied to an integer until it becomes a palindrome
ContributedBy: MarkdownToNotebook
Keywords: [palindrome, Lychrel, reverse-and-add, integer iteration, recreational mathematics]
Categories: [Number Theory, Recreational Computation]
RelatedSymbols: [IntegerReverse, PalindromeQ, NestWhileList]
RelatedResources: []
Links: ["[Lychrel number (Wikipedia)](https://en.wikipedia.org/wiki/Lychrel_number)", "[196 algorithm (Wikipedia)](https://en.wikipedia.org/wiki/196_(number)#196_algorithm)"]
---

## Definition

The function adds an integer to its digit-reversal and repeats until the value
becomes a palindrome (or a step cap is reached). The whole trajectory is
returned, so the caller sees every intermediate value.

```wl
ReverseAddSequence[n_Integer, max_Integer: 50] := NestWhileList[
    # + IntegerReverse[#] &,
    n,
    ! PalindromeQ[IntegerDigits[#]] &,
    1,
    max
]
```

## Usage

<code>[ReverseAddSequence]()[$n$]</code> gives the trajectory of the
reverse-and-add iteration starting from the integer $n$, stopping at the first
palindromic value.

<code>[ReverseAddSequence]()[$n$, $max$]</code> stops after at most $max$
iterations even if no palindrome was reached.

## Details & Options

- At each step the next value is the current one plus the integer formed by
  reversing its digits, so `89 + 98 -> 187 -> 187 + 781 -> 968 -> ...`.
- The iteration ends as soon as the value is a *digit palindrome*, the test
  used to declare success in the Lychrel literature.
- The default step cap is 50; raise it to chase candidates that take longer to
  resolve. Numbers that are conjectured never to reach a palindrome (Lychrel
  candidates, starting with 196) hit the cap instead.

## Basic Examples

The two-digit input `89` reaches a palindrome in 24 steps:

```wl
ReverseAddSequence[89]
```

<!-- => {89, 187, 968, 1837, 9218, 17347, ..., 8813200023188} -->

## Scope

`PalindromeQ` is used on the digit list, so any nonnegative integer is
accepted, including ones that are already palindromic:

```wl
ReverseAddSequence[121]
```

<!-- => {121} -->

## Applications

How many steps does each starting value need before it becomes palindromic?
The plot shows the strikingly uneven landscape that the Lychrel problem is
about:

```wl
#| screenshot: true
ListPlot[
    {#, Length[ReverseAddSequence[#]] - 1} & /@ Range[200],
    Filling -> Axis, PlotStyle -> ColorData[97, 2],
    AxesLabel -> {"n", "steps to palindrome"}, ImageSize -> 480
]
```

## Properties and Relations

The trajectory is exactly the `NestWhileList` of `# + IntegerReverse[#] &`
under the palindrome test, so the final value is always palindromic when the
sequence terminates:

```wl
With[{seq = ReverseAddSequence[89]}, PalindromeQ @ IntegerDigits @ Last[seq]]
```

<!-- => True -->

## Possible Issues

`196` is the smallest candidate Lychrel number: no palindrome has ever been
found for it. The function returns once the step cap is reached, with a
trajectory that just keeps growing:

```wl
Length @ ReverseAddSequence[196, 100]
```

<!-- => 101 -->

## Neat Examples

Map the steps-to-palindrome over the first thousand integers, then bucket by
that count: most resolve quickly, but a thin tail of starting values needs
dozens of iterations before the digits line up:

```wl
#| screenshot: true
Histogram[
    Length[ReverseAddSequence[#]] - 1 & /@ Range[1000],
    Automatic, "PDF",
    ChartStyle -> ColorData[97, 3], PlotRange -> All,
    AxesLabel -> {"steps", "fraction of n in 1..1000"}, ImageSize -> 480
]
```
