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

::: {.sidenote}
I get a weird feeling in my stomach when the size of my code scales with the size
of the output, but hey, HTML is not a programming language, so it's fine, <small>right?</small>
:::

Ok `400i<div></div><CR><Esc>` done.

::: {.sidenote}
vim btw.
:::

We're gonna need some way to identify them to be able to calculate their colors later.
That's where <span class="rainbow">variables</span> come in. Let's assign them their
$x, y$ coordinates (starting with $(1, 1)$ for the top left). Basically:

```html
<div style="--x:1; --y:1;"></div>
<div style="--x:2; --y:1;"></div>
<div style="--x:3; --y:1;"></div>
...
```

I'm sure you could come up with a clever vim macro to do this but we're gonna use
python for code generation later any way so might as well...

```python
rows, cols = 20, 20

for y in range(1, rows + 1):
    for x in range(1, cols + 1):
        print(f"<div style=\"--x:{x}; --y:{y};\"></div>")
    print()
```

We also want to display them in a $20x20$ grid. So let's wrap everything in a
`<div id="mandelbrot>...</div>`.

```css
:root {
    --s: 20;
}

#mandelbrot {
    display: grid;
    grid-template-columns: repeat(var(--s), 30px);
    grid-auto-rows: 30px;
}
```

Notice we use a variable for the grid size as we're going to use this value in
calculations later.

To see variables in action let's use our grid to display a simple pattern.
For that we'll need another key CSS feature -- the <span class="rainbow">calc</span> function.

```css
#mandelbrot div {
    background-color: rgba(255, 255, 255,
        calc(var(--x) * var(--y) / pow(var(--s), 2)));
}
```

It's [most often used](https://developer.mozilla.org/en-US/docs/Web/CSS/calc#examples)
for its ability to combine different units. For example if you
wanted an element to take up 100% of the width but with some room for margins:
`width: calc(100% - 80px);`. We'll keep it simple though and just use it in one place --
to compute the alpha values of our divs (as above).

## The first iteration

Now for the core question -- how do we actually compute the alpha values to make
the Mandelbrot set appear?

As I explained at the [beginning](#what), the usual approach is to count the number
of iterations it takes the value to cross a certain threshold, but the thing is, it's
not easy to get CSS to do loops. So we're gonna use a fixed number of iterations
(you'll see how in a minute) and then map the magnitude (distance from the origin)
of a number to the alpha value of the corresponding `div`. Intuition: if after our
fixed number of iterations $|z|$ will be large it means that it probably diverges quickly,
so we'll map it to a low alpha value and if $|z|$ is small it's probably in the set `->` high alpha.

Let's start simple -- just one iteration. Meaning we apply $f(z) = z^2 + c$ once
starting with $z = 0$ and c being the point represented by a specific `div`.
Then we just need to get the magnitude: $|z|^2 = \mathfrak{R}(z)^2 + \mathfrak{I}(z)^2$.

We'll use python to generate the `calc` call to use as the alpha value in CSS.

```python
def sq(num):
    return f"pow({num},2)"

def var(name):
    return f"var(--{name})"

x = var('x')
y = var('y')

def gen_iters():
    return f"{sq(x)} + {sq(y)}"

print(gen_iters())
```

This gets us `pow(var(--x),2) + pow(var(--y),2)` and pasting it for the alpha value
of our `divs`'s `background-color`... All turned white.

## Fixing the problems

That's unsuprising. The alpha in `rgba` is in range `0..1` and all our values are $\ge 1$.
It seems we have to apply some <span class="rainbow">mappings</span>.

::: {.sidenote}
Ok, no more rainbows...
:::

__First__: the Mandelbrot set tastes best when served in roughly $[-2.0, 1.0] \times [-1.5, 1.5]$ range.
Right now we have $[1.0, 20.0] \times [1.0, 20.0]$ so pretty far from ideal.
As a general problem statement: we have a value $x \in [a, b]$ and want to map it to be in $[c, d]$.

::: {.sidenote}
This is a very common problem and I go through this process all the time.
:::

$$
\begin{aligned}
1.\ & x - a &\in &[0, b-a] \\
2.\ & \frac{x-a}{b-a} &\in &[0, 1] \\
3.\ & \frac{x-a}{b-a}(d-c) &\in &[0, d-c] \\
4.\ & \frac{x-a}{b-a}(d-c) + c &\in &[c, d]
\end{aligned}
$$

Voilà. Some python follows.

```python
def scale(x, a_to, b_to, a_from=1, b_from=20):
    """
    Maps x that is in [a_from, b_from] to be in [a_to, b_to]
    """
    return f"{a_to} + ({x} - {a_from})*({b_to} - {a_to})/({b_from} - {a_from})"
```

If you look closely you might notice that I put whitespace around `+` and `-`
but not around `*` and `/`. The code we'll generate later is going to get a
little large so I wanted to at least save up on some whitespace. The spaces around
`+` and `-` [are necessary](https://developer.mozilla.org/en-US/docs/Web/CSS/calc-sum#description)
though as CSS uses them to distinguish from unary `+` and `-` (for example
`calc(1-2)` is interpreted as `1` followed by `-2`).

::: {.sidenote}
Thanks to CSS's [lovely error handling](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_syntax/Error_handling)
this is a fact that I will remember for a long time.
:::

__Second__: Right now our outputted alpha values are in $[0, \infty)$ and we need
them to be in $[0, 1.0]$. Our previous method doesn't digest infinities well so
we need something different. There are many different approaches but I personally
like the [sigmoid](https://en.wikipedia.org/wiki/Sigmoid_function).

$$
\sigma(x) = \frac{1}{1+e^{-x}}
$$

It maps the nonnegative values to $[0.5, 1]$ so we'll take $2\sigma(-x)$ which also
makes it so that magnitudes close to 0 (in the set) get an alpha close to 1
(that's just so it plays nicely with the site's darkmode).

Integrating it back to our little script. First the coordinates:

```python
x = scale(var('x'), var('xa'), var('xb'))
y = scale(var('y'), var('ya'), var('yb'))

# ...

print(mapping(gen_iters(n)))
```

I thought it might be a good idea to keep the values as CSS variables for easy access.

```css
#mandelbrot {
    /* ... */
    --xa: var(-2.0);
    --xb: var(1.0);
    --ya: var(-1.5);
    --yb: var(1.5);
}
```

Nice! It seems that now all we need is...

## More iterations

TODO
