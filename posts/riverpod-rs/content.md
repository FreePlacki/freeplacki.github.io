---
title: Riverpod from scratch
---

## Riverpod

[Riverpod](https://riverpod.dev/) describes itself as

> A Reactive Caching and Data-binding Framework

(for [Flutter](https://flutter.dev/)). But what's most interesting
<small>for me</small> is how it simplifies dependency injection and reactivity
by leveraging the idea of a Provider.

::: sidenote
The name riverpod is formed by rearanging the letters of
<div class="morph" data-state="source">
  <span class="char col0 c0">p</span>
  <span class="char col1 c1">r</span>
  <span class="char col2 c2">o</span>
  <span class="char col3 c3">v</span>
  <span class="char col4 c4">i</span>
  <span class="char col5 c5">d</span>
  <span class="char col6 c6">e</span>
  <span class="char col7 c7">r</span>
</div>
:::

Just take this example:

```dart
final apiClientProvider = Provider((ref) => ApiClient());

final counterProvider = StateProvider<int>((ref) => 0);

final repositoryProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider); // dependency injection
  final count = ref.watch(counterProvider); // reactive dependency

  return Repository(api: api, count: count);
});
```

And then read and update the state:

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(counterProvider);

    return Column(
      children: [
        Text(value.toString()),
        ElevatedButton(
          onPressed: () {
            ref.read(counterProvider.notifier).state++;
          },
          child: const Text("Increment"),
        ),
      ],
    );
  }
}
```

I guess you'd have to develop an app with flutter and riverpod to feel why it's
such a cool idea.

And maybe develop some larger apps to see why not so much...

::: sidenote
Which I have not, so let's move on.
:::

# A Memoized Function

Our goal here is not to explore flutter design patters but to instead understand
how this *provider* mechanism works. And the best way to learn is to implement
it yourself (see my full implementation [here](https://github.com/FreePlacki/riverpod-rs).

```rust
type ProviderFun<T> = fn(&Container) -> T;

struct Provider<T> {
    f: ProviderFun<T>,
}
```

ex.
```rust
static PROVIDER: Provider<f32> = Provider::new(|_| 42.0);
```

Our provider will be just a wrapper around a function that takes a reference
to some `Container` (like the `ref` in the flutter example above) and returns
some value.

The `Container` is the one that will cache the providers' values.
To enable this, we have to have some kind of way of identifying our providers.

```rust
struct Container {
    providers: HashMap<ProviderId, ProviderNode>,
}

impl<T> Provider<T> {
    // --snip--
    pub fn id(&self) -> ProviderId {
        todo!("???")
    }
}
```

Do we keep some kind of global state of `last_id` and increment it every time
a new provider is created? Or maybe just assign a random value and hope for no
conflicts?

Fortunately, since the provider is ment to be used as a static constant, a simple
pointer to it, will make a great id.

```rust
struct ProviderId(usize);

impl<T> Provider<T> {
    // --snip--
    pub fn id(&self) -> ProviderId {
        ProviderId(self as *const _ as usize)
    }
}
```

To be continued...

