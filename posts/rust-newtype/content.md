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
between the *camera* and *canvas* coordinate systems. The canvas is the space where
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
trait CameraCanvasCoords {
    fn to_camera(self, camera: &Camera) -> Self;
    fn to_canvas(self, camera: &Camera) -> Self;
}

impl CameraCanvasCoords for Vector2 {
    fn to_camera(self, camera: &Camera) -> Self {
        (self - camera.pos) * camera.zoom
    }

    fn to_canvas(self, camera: &Camera) -> Self {
        self / camera.zoom + camera.pos
    }
}

impl CameraCanvasCoords for f32 {
    fn to_camera(self, camera: &Camera) -> Self {
        self * camera.zoom
    }

    fn to_canvas(self, camera: &Camera) -> Self {
        self / camera.zoom
    }
}
```

Now the api will look like this:

```rust
draw(circle.pos.to_camera(&camera), circle.r.to_camera(&camera));
```

Done. This works well and the api seems ergonomic so what's the problem?

Here are some of them:

1. Forgetting to convert to camera coordinates before calling draw.
2. Converting something that was aleardy in the correct coordinate space.
3. Increasing mental overhead (in which coordinate space is this `Vector2` that got passed to this function?).

And the problems get worse as the codebase grows.

The newtype pattern adresses all of them (and more).

::: sidenote
For the low (?) price of a little boilerplate.
:::

## The new types

TODO
