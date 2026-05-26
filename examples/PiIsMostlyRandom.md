---
Template: ComputationalEssay
ResourceType: ComputationalEssay
Name: How Random Is Pi?
Author: MarkdownToNotebook
Date: 2026
Description: A short computational essay that probes the digits of pi for the kinds of patterns a "normal" number ought not have
Abstract: Pi is conjectured to be a *normal* number, meaning every finite digit sequence appears with the expected frequency in its decimal expansion. The conjecture has never been proven, but the first few million digits behave well enough that they are routinely used as a source of pseudorandomness. This essay computes the first 10000 digits, looks at the digit frequencies, walks a 2D random walk driven by them, and runs a quick chi-square test - building the intuition for why "normality" is a remarkably strong claim about a single, perfectly determined number.
Keywords: [pi, normal number, randomness, statistics, chi-square, random walk]
Sources: ["[Normal number (Wikipedia)](https://en.wikipedia.org/wiki/Normal_number)", "[The y-cruncher digits-of-pi project](http://www.numberworld.org/y-cruncher/)"]
Links: ["[Stephen Wolfram - What Is a Computational Essay?](https://writings.stephenwolfram.com/2017/11/what-is-a-computational-essay/)"]
---

## Pulling the digits

The first ingredient is the digits themselves. [`RealDigits`]() returns the
decimal expansion of any real number; we take the first 10000:

A glance at the first twenty:

```wl
digits = First @ RealDigits[Pi, 10, 10000];
Take[digits, 20]
```

## Are they uniformly distributed?

If pi is normal in base 10, each digit 0-9 should appear about one tenth of
the time. Counting and dividing by the total puts the empirical frequencies
right next to the theoretical 0.1:

```wl
freqs = N @ KeySort @ Counts[digits] / Length[digits];
BarChart[Values[freqs], ChartLabels -> Keys[freqs],
    PlotLabel -> "Frequency of each digit in the first 10000 of pi",
    Epilog -> {Red, Dashed, Line[{{0, 0.1}, {11, 0.1}}]}, ImageSize -> 480]
```

The deviation from 0.1 is small but not zero - that is just what we should
expect from a finite sample of a uniform distribution. A formal chi-square
test against the uniform hypothesis quantifies the noise:

```wl
PearsonChiSquareTest[digits]
```

A p-value comfortably above 0.05 means the digits are *consistent* with a
uniform distribution at the chosen sample size; we cannot reject the
normality hypothesis, but we also have not proved it.

## A walk on the digits

A visual way to look for hidden structure: turn each digit into a step in
one of ten compass directions and let it walk:

```wl
walk = AnglePath[Rest[digits] 2 Pi / 10];
ListLinePlot[walk, AspectRatio -> 1, Axes -> False, PlotStyle -> Thin,
    PlotLabel -> "2D walk driven by 10000 digits of pi", ImageSize -> 480]
```

A truly random walk drifts away from the origin like $\sqrt{n}$. The walk
on pi looks the same to the eye - no spirals, no clustering, no preferred
direction. The exact end-to-end distance against the expected value is the
quantitative version:

```wl
{Norm[Last[walk]], Sqrt[Length[digits]] // N}
```

## What we have not shown

None of this is proof. Pi could turn out to be non-normal in some base, or
could have arbitrarily long stretches of low-entropy digits past the
ten-thousandth decimal place that ruin every test we have run. The
conjecture is genuinely open. What the essay *does* show is that a very
short computation - five plotting commands and a statistical test - already
puts a sharp upper bound on how non-random pi can be over the regime
ordinary computations encounter it.

## References

[1] S. Wolfram, [*What Is a Computational Essay?*](https://writings.stephenwolfram.com/2017/11/what-is-a-computational-essay/), Wolfram Writings, 2017.

[2] D. H. Bailey and R. E. Crandall, [On the random character of fundamental constant expansions](https://www.davidhbailey.com/dhbpapers/baicran.pdf), *Experimental Mathematics*, 10(2):175-190, 2001.

[3] Y. Kanada, [The world record computation of pi](https://www.super-computing.org/pi_decimal_current.html.en), University of Tokyo, 2025.
