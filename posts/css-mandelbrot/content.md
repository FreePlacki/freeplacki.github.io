## What?

If you somehow don't know what the [Mandelbrot set](https://en.wikipedia.org/wiki/Mandelbrot_set)
is, here is a quick introduction.
It's defined as the set of all numbers $c \in \mathbb{C}$ for which the function $f(z) = z^2 + c$
doesn't diverge to infinity when iterated starting at $z=0$.

By mapping the values of $c$ to cartesian coordinates
(meaning for example $c=3+4i$ gets mapped to the point $(3, 4)$) we can produce
some [cool images](https://en.wikipedia.org/wiki/Mandelbrot_set#/media/File:Mandel_zoom_00_mandelbrot_set.jpg).
You choose a color for the points that belong to the set and for others you pick
the colors based on how fast they diverge (how many iterations were needed before
the value crossed a certain threshold).

You can check out the final product [here](https://freeplacki.github.io/cssbrot)
along with the source code [here](https://github.com/FreePlacki/cssbrot)
(NOTE: if it doesn't work try disabling darkreader or any similar extension).

::: {.sidenote}
Try moving your cursor over it.
:::

## Why?

You can generate such images with a few lines of pretty much any *reasonable*
programming language. Doing it in pure HTML+CSS presents some challanges.
As we all know CSS is clearly [not Turing complete](https://stackoverflow.com/a/26445990)
as there is no way to have infinite loops so if it was then we have a contradiction with
[the Halting Problem](https://en.wikipedia.org/wiki/Halting_problem).

> Actually... it is. [Look](http://eli.fox-epste.in/rule110-full.html) I implemented [Rule 110](https://en.wikipedia.org/wiki/Rule_110).
> 
>> [Nope](https://accodeing.com/blog/2015/duty-calls-css3-is-not-proven-to-be-turing-complete). Using your approach the number of CSS rules would scale with the input AND it requires constant human interaction to function.
>>
>>> Ok, [maybe not](https://accodeing.com/blog/2015/css3-proven-to-be-turing-complete) but still it requires the user to constantly press keys so you might as well just [write the instructions for the human in natural language](https://stackoverflow.com/a/51408598).

...

It's not that simple and you're welcome to do your own research. What is certain though, is that
modern CSS has features (that we will explore in a second) that allow you to do [cool shit](https://mooninaut.github.io/css-is-turing-complete/) and [perform arithmetic](https://lab.avl.la/css-calculations/).

## Laying the foundation, variables

As far as I'm aware there is no way to draw on the html canvas with just CSS and
we are gonna need something to represent our drawing, so we're gonna use individal `div`s to
represent the pixels. Let's go for a $20\times20$ image for a total of $400$ `div`s...
<!-- abcd <span class="rainbow">variables</span> abc -->

::: {.sidenote}
I get a weird feeling in my stomach when the size of my code scales with the size
of the output, but hey, HTML is not a programming language, so it's fine, <small>right?</small>
:::
