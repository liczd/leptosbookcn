# 使用 Signals

到目前为止，我们使用了一些简单的 [`signal`](https://docs.rs/leptos/latest/leptos/reactive/signal/fn.signal.html) 示例，它返回一个 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html) getter 和一个 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html) setter。

## 获取和设置

有几个基本的 signal 操作：

### 获取

1. [`.read()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-Read-for-T) 返回一个读取守卫，它解引用到 signal 的值，并响应式地跟踪 signal 值的任何未来更改。注意，在此守卫被丢弃之前，您无法更新 signal 的值，否则会导致运行时错误。
1. [`.with()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-With-for-T) 接受一个函数，该函数通过引用（`&T`）接收 signal 的当前值，并跟踪 signal。
1. [`.get()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-Get-for-T) 克隆 signal 的当前值并跟踪值的进一步更改。

`.get()` 是访问 signal 最常见的方法。`.read()` 对于接受不可变引用的方法很有用，无需克隆值（`my_vec_signal.read().len()`）。`.with()` 在您需要对该引用做更多事情但想确保不会比需要的时间更长地持有锁时很有用。

### 设置

1. [`.write()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Write-for-WriteSignal%3CT,+S%3E) 返回一个写入守卫，它是对 signal 值的可变引用，并通知任何订阅者它们需要更新。注意，在此守卫被丢弃之前，您无法从 signal 的值读取，否则会导致运行时错误。
1. [`.update()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Update-for-T) 接受一个函数，该函数接收对 signal 当前值的可变引用（`&mut T`），并通知订阅者。（`.update()` 不返回闭包返回的值，但如果需要，您可以使用 [`.try_update()`](https://docs.rs/leptos/latest/leptos/trait.SignalUpdate.html#tymethod.try_update)；例如，如果您从 `Vec<_>` 中删除项目并想要被删除的项目。）
1. [`.set()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Set-for-T) 替换 signal 的当前值并通知订阅者。

`.set()` 最常用于设置新值；`.write()` 对于就地更新值非常有用。就像 `.read()` 和 `.with()` 的情况一样，`.update()` 在您想避免比预期更长时间持有写锁的可能性时很有用。

```admonish note
这些 traits 基于 trait 组合并由毯子实现提供。例如，`Read` 为任何实现 `Track` 和 `ReadUntracked` 的类型实现。`With` 为任何实现 `Read` 的类型实现。`Get` 为任何实现 `With` 和 `Clone` 的类型实现。等等。

`Write`、`Update` 和 `Set` 存在类似的关系。

在阅读文档时值得注意这一点：如果您只看到 `ReadUntracked` 和 `Track` 作为已实现的 traits，您仍然能够使用 `.with()`、`.get()`（如果 `T: Clone`）等等。
```

## 使用 Signals

您可能注意到 `.get()` 和 `.set()` 可以用 `.read()` 和 `.write()`，或 `.with()` 和 `.update()` 来实现。换句话说，`count.get()` 与 `count.with(|n| n.clone())` 或 `count.read().clone()` 相同，`count.set(1)` 通过执行 `count.update(|n| *n = 1)` 或 `*count.write() = 1` 来实现。

但当然，`.get()` 和 `.set()` 是更好的语法。

但是，其他方法有一些非常好的用例。

例如，考虑一个持有 `Vec<String>` 的 signal。

```rust
let (names, set_names) = signal(Vec::new());
if names.get().is_empty() {
	set_names(vec!["Alice".to_string()]);
}
```

在逻辑方面，这足够简单，但它隐藏了一些重大的低效率。记住 `names.get().is_empty()` 克隆值。这意味着我们克隆整个 `Vec<String>`，运行 `is_empty()`，然后立即丢弃克隆。

同样，`set_names` 用全新的 `Vec<_>` 替换值。这很好，但我们不妨就地改变原始 `Vec<_>`。

```rust
let (names, set_names) = signal(Vec::new());
if names.read().is_empty() {
	set_names.write().push("Alice".to_string());
}
```

现在我们的函数简单地通过引用获取 `names` 来运行 `is_empty()`，避免了那个克隆，然后就地改变 `Vec<_>`。

## 线程安全和线程本地值

您可能已经注意到，无论是通过阅读文档还是通过试验自己的应用程序，存储在 signals 中的值必须是 `Send + Sync`。这是因为响应式系统实际上支持多线程：signals 可以跨线程发送，整个响应式图可以跨多个线程工作。（这在使用像 Axum 这样使用 Tokio 多线程执行器的服务器框架进行[服务端渲染](../ssr/)时特别有用。）在大多数情况下，这对您所做的事情没有影响：普通的 Rust 数据类型默认是 `Send + Sync`。

但是，浏览器环境只是单线程的，除非您使用 Web Worker，`wasm-bindgen` 和 `web-sys` 提供的 JavaScript 类型都明确是 `!Send`。这意味着它们不能存储在普通 signals 中。

因此，我们为每个 signal 原语提供"本地"替代方案，可用于存储 `!Send` 数据。只有当您有需要存储在 signal 中的 `!Send` 浏览器类型时，您才应该使用这些。

| 标准 | 本地 |
| -------- | ----- |
| [`signal`](https://docs.rs/leptos/latest/leptos/reactive/signal/fn.signal.html) | [`signal_local`](https://docs.rs/leptos/latest/leptos/prelude/fn.signal_local.html) |
| [`RwSignal::new`](https://docs.rs/leptos/latest/leptos/prelude/struct.RwSignal.html#method.new) | [`RwSignal::new_local`](https://docs.rs/leptos/latest/leptos/prelude/struct.RwSignal.html#method.new_local) |
| [`Resource`](https://docs.rs/leptos/latest/leptos/prelude/struct.Resource.html) | [`LocalResource`](https://docs.rs/leptos/latest/leptos/prelude/struct.LocalResource.html) |
| [`Action::new`](https://docs.rs/leptos/latest/leptos/prelude/struct.Action.html#method.new) | [`Action::new_local`](https://docs.rs/leptos/latest/leptos/prelude/struct.Action.html#method.new_local), [`Action::new_unsync`](https://docs.rs/leptos/latest/leptos/prelude/struct.Action.html#method.new_unsync) |

## Nightly 语法

当使用 `nightly` 功能和 `nightly` 语法时，将 `ReadSignal` 作为函数调用是 `.get()` 的语法糖。将 `WriteSignal` 作为函数调用是 `.set()` 的语法糖。所以

```rust
let (count, set_count) = signal(0);
set_count(1);
logging::log!(count());
```

与以下相同

```rust
let (count, set_count) = signal(0);
set_count.set(1);
logging::log!(count.get());
```

这不仅仅是语法糖，而是通过使 signals 在语义上与函数相同来提供更一致的 API：请参阅[插曲](./interlude_functions.md)。

## 使 signals 相互依赖

人们经常询问某个 signal 需要根据其他 signal 的值而改变的情况。有三种好方法来做到这一点，还有一种在受控情况下不太理想但可以的方法。

### 好的选择

**1) B 是 A 的函数。** 为 A 创建一个 signal，为 B 创建一个派生 signal 或 memo。

```rust
// A
let (count, set_count) = signal(1);
// B 是 A 的函数
let derived_signal_double_count = move || count.get() * 2;
// B 是 A 的函数
let memoized_double_count = Memo::new(move |_| count.get() * 2);
```

> 有关是否使用派生 signal 或 memo 的指导，请参阅 [`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html) 的文档

**2) C 是 A 和其他东西 B 的函数。** 为 A 和 B 创建 signals，为 C 创建派生 signal 或 memo。

```rust
// A
let (first_name, set_first_name) = signal("Bridget".to_string());
// B
let (last_name, set_last_name) = signal("Jones".to_string());
// C 是 A 和 B 的函数
let full_name = move || format!("{} {}", &*first_name.read(), &*last_name.read());
```

**3) A 和 B 是独立的 signals，但有时同时更新。** 当您调用更新 A 时，单独调用更新 B。

```rust
// A
let (age, set_age) = signal(32);
// B
let (favorite_number, set_favorite_number) = signal(42);
// 使用这个来处理 `Clear` 按钮的点击
let clear_handler = move |_| {
  // 更新 A 和 B
  set_age.set(0);
  set_favorite_number.set(0);
};
```

### 如果您真的必须...

**4) 创建一个 effect 在 A 更改时写入 B。** 这是官方不鼓励的，有几个原因：
a) 它总是效率较低，因为这意味着每次 A 更新时，您都要完整地通过响应式过程两次。（您设置 A，这导致 effect 运行，以及依赖于 A 的任何其他 effects。然后您设置 B，这导致依赖于 B 的任何 effects 运行。）
b) 它增加了意外创建无限循环或过度重新运行 effects 等情况的机会。这是 2010 年代初常见的那种乒乓球式响应式意大利面条代码，我们试图通过读写分离和不鼓励从 effects 写入 signals 等方式来避免。

在大多数情况下，最好重写事物，使基于派生 signals 或 memos 有清晰的自顶向下数据流。但这不是世界末日。

> 我故意不在这里提供示例。阅读 [`Effect`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html) 文档来弄清楚这如何工作。