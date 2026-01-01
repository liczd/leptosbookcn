# 无宏：View Builder 语法

> 如果您对到目前为止描述的 `view!` 宏语法完全满意，欢迎跳过本章。本节中描述的 builder 语法始终可用，但从不是必需的。

出于某种原因，许多开发人员更愿意避免宏。也许您不喜欢有限的 `rustfmt` 支持。（不过，您应该查看 [`leptosfmt`](https://github.com/bram209/leptosfmt)，这是一个优秀的工具！）也许您担心宏对编译时间的影响。也许您更喜欢纯 Rust 语法的美学，或者您在类似 HTML 的语法和 Rust 代码之间的上下文切换有困难。或者也许您想要比 `view` 宏提供的更多灵活性来创建和操作 HTML 元素。

如果您属于这些阵营中的任何一个，builder 语法可能适合您。

`view` 宏将类似 HTML 的语法展开为一系列 Rust 函数和方法调用。如果您不想使用 `view` 宏，您可以简单地自己使用那个展开的语法。而且它实际上相当不错！

首先，如果您愿意，您甚至可以放弃 `#[component]` 宏：组件只是创建视图的设置函数，所以您可以将组件定义为简单的函数调用：

```rust
pub fn counter(initial_value: i32, step: u32) -> impl IntoView { }
```

元素通过调用与 HTML 元素同名的函数创建：

```rust
p()
```

自定义元素/Web 组件可以通过使用带有其名称的 [`custom()`](https://docs.rs/leptos/latest/leptos/html/fn.custom.html) 函数创建：
```rust
custom("my-custom-element")
```

您可以使用 [`.child()`](https://docs.rs/leptos/latest/leptos/html/trait.ElementChild.html#tymethod.child) 向元素添加子元素，它接受单个子元素或实现 [`IntoView`](https://docs.rs/leptos/latest/leptos/trait.IntoView.html) 的类型的元组或数组。

```rust
p().child((em().child("Big, "), strong().child("bold "), "text"))
```

属性使用 [`.attr()`](https://docs.rs/leptos/latest/leptos/attr/custom/trait.CustomAttribute.html#method.attr) 添加。这可以接受您可以作为属性传递到视图宏中的任何相同类型（实现 [`Attribute`](https://docs.rs/leptos/latest/leptos/attr/trait.Attribute.html) 的类型）。

```rust
p().attr("id", "foo")
    .attr("data-count", move || count.get().to_string())
```

它们也可以使用属性方法添加，这些方法对任何内置 HTML 属性名称都可用：

```rust
p().id("foo")
    .attr("data-count", move || count.get().to_string())
```

类似地，`class:`、`prop:` 和 `style:` 语法直接映射到 [`.class()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.ClassAttribute.html#tymethod.class)、[`.prop()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.PropAttribute.html#tymethod.prop) 和 [`.style()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.StyleAttribute.html#tymethod.style) 方法。

事件监听器可以使用 [`.on()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.OnAttribute.html#tymethod.on) 添加。在 [`leptos::ev`](https://docs.rs/leptos/latest/leptos/tachys/html/event/index.html) 中找到的类型化事件防止事件名称中的拼写错误，并允许在回调函数中进行正确的类型推断。

```rust
button()
    .on(ev::click, move |_| set_count.set(0))
    .child("Clear")
```

所有这些加起来形成了一个非常 Rusty 的语法来构建功能齐全的视图，如果您喜欢这种风格的话。

```rust
/// 一个简单的计数器视图。
// 组件实际上只是一个函数调用：它运行一次来创建 DOM 和响应式系统
pub fn counter(initial_value: i32, step: i32) -> impl IntoView {
    let (count, set_count) = signal(initial_value);
    div().child((
        button()
            // leptos::ev 中找到的类型化事件
            // 1) 防止事件名称中的拼写错误
            // 2) 允许在回调中进行正确的类型推断
            .on(ev::click, move |_| set_count.set(0))
            .child("Clear"),
        button()
            .on(ev::click, move |_| *set_count.write() -= step)
            .child("-1"),
        span().child(("Value: ", move || count.get(), "!")),
        button()
            .on(ev::click, move |_| *set_count.write() += step)
            .child("+1"),
    ))
}
```

## 使用 Builder 语法的组件

要使用 builder 语法创建自己的组件，您可以简单地使用普通函数（见上文）。要使用其他组件（例如，内置的 `For` 或 `Show` 控制流组件），您可以利用每个组件都是一个组件 props 参数的函数这一事实，组件 props 有自己的 builder。

您可以使用组件 props builder：
```rust
use leptos::html::p;

let (value, set_value) = signal(0);

Show(
    ShowProps::builder()
        .when(move || value.get() > 5)
        .fallback(|| p().child("I will appear if `value` is 5 or lower"))
        .children(ToChildren::to_children(|| {
            p().child("I will appear if `value` is above 5")
        }))
        .build(),
)
```
或者您可以直接构建 props 结构体：
```rust
use leptos::html::p;

let (value, set_value) = signal(0);

Show(ShowProps {
    when: move || value.get() > 5,
    fallback: (|| p().child("I will appear if `value` is 5 or lower")).into(),
    children: ToChildren::to_children(|| p().child("I will appear if `value` is above 5")),
})
```
使用组件 builder 正确应用各种修饰符如 `#[prop(into)]`；使用结构体语法，我们通过自己调用 `.into()` 手动应用了这个。

## 展开宏

这里并没有详细描述 `view` 宏或 `component` 宏语法的每个功能。但是，Rust 为您提供了理解任何宏正在发生什么所需的工具。具体来说，rust-analyzer 的["递归展开宏"功能](https://rust-analyzer.github.io/book/features.html#expand-macro-recursively)允许您展开任何宏以显示它生成的代码，[`cargo-expand`](https://crates.io/crates/cargo-expand) 将项目中的所有宏展开为常规 Rust 代码。本书的其余部分将继续使用 `view` 宏语法，但如果您不确定如何将其转换为 builder 语法，您可以使用这些工具来探索生成的代码。