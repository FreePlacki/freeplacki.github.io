---
title: On rust's newtype pattern
---

## Quick introduction

If you're already familiar with the pattern please skip to the [next section](#the-problem).

The [newtype](https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html)
pattern refers to wrapping a type in a single field [tuple struct](https://doc.rust-lang.org/book/ch05-01-defining-structs.html#using-tuple-structs-without-named-fields-to-create-different-types). For example:

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
compile but with probably unintended behaviour.

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
2. Converting something that was aleardy in the correct coordinate space.
3. Increasing mental overhead (in which coordinate space is this `Vector2`
that got passed to this function?).

And the problems get worse as the codebase grows.

The newtype pattern adresses all of them (and more).

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
to avoid repeating the same functions. We can also easily make other structs generic over the space
if needed (for example `Circle<Space>` if we need some circles to live in the screen space and other on the canvas).

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
space of any given `Point` just by checking it's type, so that's a lot of mental
overhead gone. We're also unable to accidently call the wrong conversion method
(since `ScreenPoint` doesn't implement `ToScreen` and `CanvasPoint` doesn't implement `ToCanvas`).
