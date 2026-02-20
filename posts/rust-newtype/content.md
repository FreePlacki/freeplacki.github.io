---
title: On Rust's newtype pattern
---

## Quick introduction

If you're already familiar with the pattern please skip to the [next section](#the-problem).

The [newtype](https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html)
pattern refers to wrapping a type in a (usually) single field [tuple struct](https://doc.rust-lang.org/book/ch05-01-defining-structs.html#using-tuple-structs-without-named-fields-to-create-different-types). For example:

```rust
struct UserId(pub u64);
```

Note that this is different than defining a type alias:

```rust
type UserId = u64;
```

Take the following example.

```rust
struct UserId(pub u64);
struct OrderId(pub u64);

fn delete_user(id: UserId) {
    // ...
}
```

Passing a value of type `OrderId` into this function results in a compile error.
If `UserId` and `OrderId` were just type aliases for `u64` passing both would
compile but with probably unintended behavior.

## The problem

The example will be from a [drawing app](https://github.com/FreePlacki/kajet) that
I was developing recently. More specifically we'll be concerned about conversion
between the *screen* and *canvas* coordinate systems. The canvas is the space where
your drawings (lines, images, etc.) live; while the camera defines which part of
the canvas is visible and can pan and zoom.

Say, for example, that a circle has been drawn at $(100, 50)$ with a radius of 5.
The camera has been moved to $(20, 30)$ and the user applied a 2x zoom.
The circle we should display on the screen should be located at $(100 - 20, 50 - 30) = (80, 20)$
with a radius of 10.

Let's get some basic definitions in place.

```rust
struct Camera {
    pub pos: Vector2,
    pub zoom: f32,
}

struct Circle {
    pub pos: Vector2,
    pub r: f32,
}
```

Since we want to implement the conversion for `Vector2` and `f32` types
(position and radius) and rust doesn't allow function overloading let's use a trait.

```rust
trait ScreenCanvasCoords {
    fn to_screen(self, camera: &Camera) -> Self;
    fn to_canvas(self, camera: &Camera) -> Self;
}

impl ScreenCanvasCoords for Vector2 {
    fn to_screen(self, camera: &Camera) -> Self {
        (self - camera.pos) * camera.zoom
    }

    fn to_canvas(self, camera: &Camera) -> Self {
        self / camera.zoom + camera.pos
    }
}

impl ScreenCanvasCoords for f32 {
    fn to_screen(self, camera: &Camera) -> Self {
        self * camera.zoom
    }

    fn to_canvas(self, camera: &Camera) -> Self {
        self / camera.zoom
    }
}
```

Now the api will look like this:

```rust
draw(circle.pos.to_screen(&camera), circle.r.to_screen(&camera));
```

Done. This works well and the api seems ergonomic so what's the problem?

Here are some of them:

1. Forgetting to convert to screen coordinates before calling draw.
2. Converting something that was already in the correct coordinate space.
3. Increasing mental overhead (in which coordinate space is this `Vector2`
that got passed to this function?).

And the problems get worse as the codebase grows.

The newtype pattern addresses all of them (and more).

::: sidenote
For the low (?) price of a little boilerplate.
:::

## The new types

Let's start with the position. We could create two separate structs like so:
```rust
struct ScreenPoint(Vector2);
struct CanvasPoint(Vector2);
```

But I like the generic parameter version better (`Point<ScreenSpace>`, `Point<CanvasSpace>`).
For one we can now do a generic `impl` block (`impl<Space> Point<Space> { ... }`)
to avoid repeating the same methods. We can also easily make other structs generic over the space
if needed (for example `Circle<Space>` if we need some circles to live in the screen space and other on the canvas).

::: sidenote
The name `Space` here refers to the *coordinate space* if that wasn't clear. I'll
be using it a lot.
:::

```rust
struct ScreenSpace;
struct CanvasSpace;

struct Point<Space>(Vector2);
```

Aaaand...

```rust
error[E0392]: type parameter `Space` is never used
help: consider removing `Space`, referring to it in a field,
or using a marker such as `PhantomData`
```

It seems that unused generic parameters aren't allowed. The error helpfully suggests
using `PhantomData` so let's do just that.

```rust
struct Point<Space> {
    v: Vector2,
    _marker: PhantomData<Space>,
}
```

This unfortunately means that you have to initialize the marker when creating the struct.
We need a `new` method (we would need one anyway since I want to keep the underlying `Vector2` private). 

::: sidenote
You've been warned about the boilerplate but stick around and you'll be convinced
that it's worth it.
:::

```rust
impl<Space> Point<Space> {
    pub fn new(v: Vector2) -> Self {
        Self {
            v,
            _marker: PhantomData,
        }
    }
}
```

Let's also slap some type aliases while we're at it.

```rust
type ScreenPoint = Point<ScreenSpace>;
type CanvasPoint = Point<CanvasSpace>;
```

## Rethinking the conversion trait

Recall the trait we defined earlier:

```rust
trait ScreenCanvasCoords {
    fn to_screen(self, camera: &Camera) -> Self;
    fn to_canvas(self, camera: &Camera) -> Self;
}
```

Notice that we no longer want to return `Self` after the conversion. In fact we
want to return the opposite coordinate space from the one we were in. To achieve
this we have to split the trait into two and use an associated type like so:

```rust
trait ToScreen {
    type Output;
    fn to_screen(self, camera: &Camera) -> Self::Output;
}

trait ToCanvas {
    type Output;
    fn to_canvas(self, camera: &Camera) -> Self::Output;
}
```

Now we simply tell what type we're returning when implementing the trait.

```rust
impl ToScreen for CanvasPoint {
    type Output = ScreenPoint;
    fn to_screen(self, camera: &Camera) -> Self::Output {
        ScreenPoint::new((self.v - camera.pos) * camera.zoom)
    }
}

impl ToCanvas for ScreenPoint {
    type Output = CanvasPoint;
    fn to_canvas(self, camera: &Camera) -> Self::Output {
        CanvasPoint::new(self.v / camera.zoom + camera.pos)
    }
}
```

Let's stop for a moment and admire the creation. We can now know the coordinate
space of any given `Point` just by checking its type, so that's a lot of mental
overhead gone.

We're also unable to accidently call the wrong conversion method
(since `ScreenPoint` doesn't implement `ToScreen` and `CanvasPoint` doesn't implement `ToCanvas`).
The idea that certain methods are only available if an object is in a given "state"
is very powerful. Consider for example the [builder pattern](https://rust-unofficial.github.io/patterns/patterns/creational/builder.html). It can prevent the user from calling the same setter twice or calling `build`
before certain required fields have been set.

::: sidenote
Check out the [typed-builder](https://github.com/idanarye/rust-typed-builder)
crate that implements a builder using this idea.
:::

## Interacting with the rest of the world

All seems nice while we're in our little newtypes bubble. But the truth is that
we have to somehow interact with other apis. 
Remember how [earlier](#the-problem) we had a `Circle` struct that we wanted to
draw on the screen. The `draw` function is probably provided by some kind of
external library and the author of that library doesn't care about our newtype
abstraction. Here are some path we could take.

The easy way is to just expose the underlying `Vector2` as public or add a getter.
This is not bad but I feel like it takes us away from the whole *type safety* thing
we had going on here. For example, we'd still have the problem of forgetting to
call `to_screen` before calling `draw`.

We could write wrappers for those functions that accept our new types but that feels
excessive and we'd still have to expose a getter to use the value inside those functions.

Since it only makes sense to draw something that is in the *screen* coordinate space,
we'll only implement the conversion method for the `ScreenPoint` type.

```rust
impl From<ScreenPoint> for Vector2 {
    fn from(value: ScreenPoint) -> Self {
        value.v
    }
}
```

::: sidenote
Implementing `From` gives you the corresponding `Into` for free so you should
pretty much always implement `From` instead of `Into` (though it's
[not that simple](https://users.rust-lang.org/t/from-into-confusion-why-do-we-need-both/80181)).
:::

Bring up the `draw` call again.

```rust
draw(circle.pos.to_screen(&camera).into(), circle.r.to_screen(&camera).into());
```

Now we can interact with our drawing lib and are unable to pass a position in
an incorrect coordinate space!

## More types!

Notice how we've already addressed all the problems stated [earlier](#the-problem).
All that's left is to add some more types.

::: sidenote
I promise there is still some interesting stuff to cover...
:::

Let's introduce a new type for the `Circle`'s radius, which is still just an
innocent little `f32` (I won't be showing the details anymore).

```rust
struct Length<Space> { /* ... */ }
```

And the conversion is just multiplying/dividing by `camera.zoom`.

What's nice is that now we can expose `Point`'s fields without compromising
the *type safety*.

```rust
impl<Space> Point<Space> {
    fn x(&self) -> Length<Space> {
        Length::new(self.v.x)
    }

    fn y(&self) -> Length<Space> {
        Length::new(self.v.y)
    }
}
```

Neat! But this is only useful if we're actually able to *do* something with them,
like, say, perform arithmetic.

We can use the same *impl generic over `Space`* technique to ensure we don't accidentally
add a `ScreenLength` to a `CanvasLength`. 

```rust
impl<Space> ops::Add<Length<Space>> for Length<Space> {
    type Output = Self;
    fn add(self, rhs: Length<Space>) -> Self::Output {
        Self::new(self.v + rhs.v)
    }
}
```

The arithmetic operators' implementations get more interesting if we add more
types, so let's do just that.

Consider the panning functionality of our drawing app.

```rust
impl Camera {
    pub fn update_pos(&mut self, mouse_delta: ScreenPoint) {
        self.pos -= mouse_delta.to_canvas(self);
    }
}
```

The `camera.pos` was in `CanvasSpace` and the mouse movement happened in the `ScreenSpace`.
Our types saved us from forgetting to convert the `mouse_delta` to `CanvasSpace` coordinates!
Hold up... The conversion is wrong -- we're dividing by `camera.zoom` and adding `camera.pos` --
The camera's position should have nothing to do with the vector by which the mouse moved
through the canvas -- just dividing by `camera.zoom` is the correct conversion here.
Which leads us to the conclusion that we need another type (for a type we've already
wrapped in a newtype btw.).

::: sidenote
Without newtypes the problem here would not only be "in which coordinate space is
this `Vector2`?" but also "does this `Vector2` represent a position or a displacement?".
:::

```rust
struct Vector<Space> { /* ... */ }
```

With conversions being just multiplying/dividing both components of the `Vector2`
by `camera.zoom`. Thinking about implementing arithmetic operators -- the result of
subtracting two `Point`s should be a `Vector` and you should probably only be able
to add/subtract a `Vector` (not a `Point`) from a `Point`.

This is a nice example of how different types interact through arithmetic operators.
Now for an example of interaction between types of *different coordinate spaces*.

Right now the `camera.zoom` field is still an `f32` (yuck). Make it a `Length`?
But in which coordinate space? Doesn't fit in what we got so let's cook up a new type.

```rust
struct Scale<FromSpace, ToSpace> { /* ... */ }

type CanvasToScreenScale = Scale<CanvasSpace, ScreenSpace>;
```

::: sidenote
That's a long name for a type, but I think it describes it well.
:::

Think about it -- this is exactly what `camera.zoom` is. It's a *scale* from
`CanvasSpace` to `ScreenSpace` -- multiplying a `CanvasLength` by `camera.zoom`
gets us a `ScreenLength`.

All the appropriate arithmetic operators' and standard library's traits'
implementations follow simply from all our previous considerations and we got
ourselves a pretty convenient, robust api.

## Ending notes

As I said at the beginning the example was taken from my [drawing app](https://github.com/FreePlacki/kajet).
I extracted the camera part to a [separate crate](https://github.com/FreePlacki/widok) and
ended up using [euclid](https://github.com/servo/euclid) to save
myself from having to implement all the common traits and operators.


