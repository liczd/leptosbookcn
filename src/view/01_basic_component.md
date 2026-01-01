# 基础组件

那个 "Hello, world!" 是一个_非常_简单的例子。让我们转向更像普通应用程序的东西。

首先，让我们编辑 `main` 函数，使其不渲染整个应用程序，而只是渲染一个 `<App/>` 组件。组件是大多数 Web 框架中组合和设计的基本单元，Leptos 也不例外。从概念上讲，它们类似于 HTML 元素：它们代表 DOM 的一个部分，具有自包含的、定义的行为。与 HTML 元素不同，它们使用 `PascalCase`，所以大多数 Leptos 应用程序都会从类似 `<App/>` 组件的东西开始。

```rust
use leptos::mount::mount_to_body;

fn main() {
    mount_to_body(App);
}
```

现在让我们定义我们的 `App` 组件本身。因为它相对简单，我会先给您完整的代码，然后逐行解释。

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button
            on:click=move |_| set_count.set(3)
        >
            "Click me: "
            {count}
        </button>
        <p>
            "Double count: "
            {move || count.get() * 2}
        </p>
    }
}
```

## 导入 Prelude

```rust
use leptos::prelude::*;
```

Leptos 提供了一个 prelude，其中包括常用的 traits 和函数。如果您更愿意使用单独的导入，请随意这样做；编译器将为每个导入提供有用的建议。

## 组件签名

```rust
#[component]
```

像所有组件定义一样，这以 [`#[component]`](https://docs.rs/leptos/latest/leptos/attr.component.html) 宏开始。`#[component]` 注释一个函数，使其可以在您的 Leptos 应用程序中用作组件。我们将在几章后看到这个宏的其他一些功能。

```rust
fn App() -> impl IntoView
```

每个组件都是具有以下特征的函数：

1. 它接受零个或多个任何类型的参数。
2. 它返回 `impl IntoView`，这是一个不透明类型，包括您可以从 Leptos `view` 返回的任何内容。

> 组件函数参数被收集到一个单一的 props 结构体中，该结构体由 `view` 宏根据需要构建。

## 组件主体

组件函数的主体是一个运行一次的设置函数，而不是多次重新运行的渲染函数。您通常会使用它来创建一些响应式变量，定义响应这些值变化而运行的任何副作用，并描述用户界面。

```rust
let (count, set_count) = signal(0);
```

[`signal`](https://docs.rs/leptos/latest/leptos/reactive/signal/fn.signal.html) 创建一个 signal，这是 Leptos 中响应式变化和状态管理的基本单元。这返回一个 `(getter, setter)` 元组。要访问当前值，您将使用 `count.get()`（或者，在 `nightly` Rust 上，简写 `count()`）。要设置当前值，您将调用 `set_count.set(...)`（或者，在 nightly 上，`set_count(...)`）。

> `.get()` 克隆值，`.set()` 覆盖它。在许多情况下，使用 `.with()` 或 `.update()` 更高效；如果您想在此时了解更多关于这些权衡的信息，请查看 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html) 和 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html) 的文档。

## 视图

Leptos 通过 [`view`](https://docs.rs/leptos/latest/leptos/macro.view.html) 宏使用类似 JSX 的格式定义用户界面。

```rust
view! {
    <button
        // 使用 on: 定义事件监听器
        on:click=move |_| set_count.set(3)
    >
        // 文本节点用引号包装
        "Click me: "

        // 块包含 Rust 代码
        // 在这种情况下，它渲染 signal 的值
        {count}
    </button>
    <p>
        "Double count: "
        {move || count.get() * 2}
    </p>
}
```

这应该大部分都容易理解：它看起来主要像 HTML，有一个特殊的 `on:click` 语法来定义 `click` 事件监听器和一些看起来像 Rust 字符串的文本节点。支持所有 HTML 元素，包括内置元素（如 `<p>`）和自定义元素/Web 组件（如 `<my-custom-element>`）。

```admonish info
**无引号文本**：`view` 宏确实对无引号文本节点有一些支持，这在 HTML 或 JSX 中是常见的（即 `<p>Hello!</p>` 而不是 `<p>"Hello!"</p>`）。由于 Rust proc 宏的限制，使用无引号文本偶尔会在标点符号周围造成间距问题，并且不支持所有 Unicode 字符串。如果这是您的偏好，您可以使用无引号文本；请注意，如果您遇到任何问题，总是可以通过将文本节点引用为普通 Rust 字符串来解决。
```

然后有两个大括号中的值：一个，`{count}`，似乎很容易理解（它只是我们 signal 的值），然后...

```rust
{move || count.get() * 2}
```

不管那是什么。

人们有时开玩笑说，他们在第一个 Leptos 应用程序中使用的闭包比他们一生中使用的都多。这很公平。

将函数传递到视图中告诉框架："嘿，这是可能会改变的东西。"

当我们点击按钮并调用 `set_count` 时，`count` signal 被更新。这个 `move || count.get() * 2` 闭包，其值依赖于 `count` 的值，重新运行，框架对该特定文本节点进行有针对性的更新，不触及应用程序中的任何其他内容。这就是允许对 DOM 进行极其高效更新的原因。

记住——这_非常重要_——只有 signals 和函数在视图中被视为响应式值。

这意味着 `{count}` 和 `{count.get()}` 在您的视图中做非常不同的事情。`{count}` 传入一个 signal，告诉框架每次 `count` 更改时更新视图。`{count.get()}` 访问 `count` 的值一次，并将 `i32` 传递到视图中，渲染一次，非响应式地。

同样，`{move || count.get() * 2}` 和 `{count.get() * 2}` 的行为不同。第一个是函数，所以它是响应式渲染的。第二个是值，所以它只渲染一次，当 `count` 更改时不会更新。

您可以在下面的 CodeSandbox 中看到差异！

让我们做最后一个更改。`set_count.set(3)` 对于点击处理程序来说是一个相当无用的事情。让我们将"将此值设置为 3"替换为"将此值增加 1"：

```rust
move |_| {
    *set_count.write() += 1;
}
```

您可以在这里看到，虽然 `set_count` 只是设置值，`set_count.write()` 给我们一个可变引用并就地改变值。任何一个都会在我们的 UI 中触发响应式更新。

> 在整个教程中，我们将使用 CodeSandbox 来显示交互式示例。
> 悬停在任何变量上以显示 Rust-Analyzer 详细信息
> 和正在发生的事情的文档。随时 fork 示例来自己玩！

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/1-basic-component-0-7-qvgdxs?file=%2Fsrc%2Fmain.rs%3A1%2C1-59%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

> 要在沙盒中显示浏览器，您可能需要点击 `Add DevTools >
Other Previews > 8080.`

<template>
  <iframe src="https://codesandbox.io/p/devbox/1-basic-component-0-7-qvgdxs?file=%2Fsrc%2Fmain.rs%3A1%2C1-59%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

// #[component] 宏将函数标记为可重用组件
// 组件是用户界面的构建块
// 它们定义了一个可重用的行为单元
#[component]
fn App() -> impl IntoView {
    // 在这里我们创建一个响应式 signal
    // 并获得一个 (getter, setter) 对
    // signals 是框架中变化的基本单元
    // 我们稍后会更多地讨论它们
    let (count, set_count) = signal(0);

    // `view` 宏是我们定义用户界面的方式
    // 它使用类似 HTML 的格式，可以接受某些 Rust 值
    view! {
        <button
            // on:click 将在 `click` 事件触发时运行
            // 每个事件处理程序都定义为 `on:{eventname}`

            // 我们能够将 `set_count` 移动到闭包中
            // 因为 signals 是 Copy 和 'static 的

            on:click=move |_| *set_count.write() += 1
        >
            // RSX 中的文本节点应该用引号包装，
            // 像普通的 Rust 字符串
            "Click me: "
            {count}
        </button>
        <p>
            <strong>"Reactive: "</strong>
            // 您可以通过将 Rust 表达式包装在大括号中
            // 将它们作为值插入到 DOM 中
            // 如果您传入一个函数，它将响应式更新
            {move || count.get()}
        </p>
        <p>
            <strong>"Reactive shorthand: "</strong>
            // 您可以直接在视图中使用 signals，作为
            // 只包装 getter 的函数的简写
            {count}
        </p>
        <p>
            <strong>"Not reactive: "</strong>
            // 注意：如果您只写 {count.get()}，这将*不*是响应式的
            // 它只是获取 count 的值一次
            {count.get()}
        </p>
    }
}

// 这个 `main` 函数是应用程序的入口点
// 它只是将我们的组件挂载到 <body>
// 因为我们将其定义为 `fn App`，我们现在可以在
// 模板中使用它作为 <App/>
fn main() {
    leptos::mount::mount_to_body(App)
}
```
</details>