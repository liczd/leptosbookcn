# `view`：动态类、样式和属性

到目前为止，我们已经看到了如何使用 `view` 宏创建事件监听器，以及如何通过将函数（如 signal）传递到视图中来创建动态文本。

但当然，您可能想要在用户界面中更新其他内容。在本节中，我们将看看如何动态更新类、样式和属性，我们将介绍**派生 signal** 的概念。

让我们从一个应该很熟悉的简单组件开始：点击按钮来增加计数器。

```rust
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
        >
            "Click me: "
            {count}
        </button>
    }
}
```

到目前为止，我们在上一章中已经涵盖了所有这些内容。

## 动态类

现在假设我想动态更新此元素上的 CSS 类列表。例如，假设我想在计数为奇数时添加类 `red`。我可以使用 `class:` 语法来做到这一点。

```rust
class:red=move || count.get() % 2 == 1
```

`class:` 属性接受

1. 类名，跟在冒号后面（`red`）
2. 一个值，可以是 `bool` 或返回 `bool` 的函数

当值为 `true` 时，添加类。当值为 `false` 时，移除类。如果值是访问 signal 的函数，类将在 signal 更改时响应式更新。

现在每次我点击按钮，文本应该在红色和黑色之间切换，因为数字在偶数和奇数之间切换。

```rust
<button
    on:click=move |_| {
        *set_count.write() += 1;
    }
    // class: 语法响应式更新单个类
    // 在这里，当 `count` 为奇数时我们将设置 `red` 类
    class:red=move || count.get() % 2 == 1
>
    "Click me"
</button>
```

> 如果您正在跟随，请确保进入您的 `index.html` 并添加类似这样的内容：
>
> ```html
> <style>
>   .red {
>     color: red;
>   }
> </style>
> ```

一些 CSS 类名不能被 `view` 宏直接解析，特别是如果它们包含破折号和数字或其他字符的混合。在这种情况下，您可以使用元组语法：`class=("name", value)` 仍然直接更新单个类。

```rust
class=("button-20", move || count.get() % 2 == 1)
```

元组语法还允许使用数组作为第一个元组元素在单个条件下指定多个类。

```rust
class=(["button-20", "rounded"], move || count.get() % 2 == 1)
```

## 动态样式

可以使用类似的 `style:` 语法直接更新单个 CSS 属性。

```rust
let (count, set_count) = signal(0);

view! {
    <button
        on:click=move |_| {
            *set_count.write() += 10;
        }
        // 设置 `style` 属性
        style="position: absolute"
        // 并使用 `style:` 切换单个 CSS 属性
        style:left=move || format!("{}px", count.get() + 100)
        style:background-color=move || format!("rgb({}, {}, 100)", count.get(), 100)
        style:max-width="400px"
        // 为样式表使用设置 CSS 变量
        style=("--columns", move || count.get().to_string())
    >
        "Click to Move"
    </button>
}
```

## 动态属性

同样适用于普通属性。将普通字符串或原始值传递给属性会给它一个静态值。将函数（包括 signal）传递给属性会使其响应式更新其值。让我们向视图添加另一个元素：

```rust
<progress
    max="50"
    // signals 是函数，所以 `value=count` 和 `value=move || count.get()`
    // 是可互换的。
    value=count
/>
```

现在每次我们设置计数时，不仅 `<button>` 的 `class` 会被切换，而且 `<progress>` 条的 `value` 会增加，这意味着我们的进度条会向前移动。

## 派生 Signals

让我们再深入一层，只是为了好玩。

您已经知道我们只需将函数传递到 `view` 中就可以创建响应式界面。这意味着我们可以轻松更改我们的进度条。例如，假设我们希望它移动得快两倍：

```rust
<progress
    max="50"
    value=move || count.get() * 2
/>
```

但想象一下我们想在多个地方重用该计算。您可以使用**派生 signal** 来做到这一点：访问 signal 的闭包。

```rust
let double_count = move || count.get() * 2;

/* 插入视图的其余部分 */
<progress
    max="50"
    // 我们在这里使用它一次
    value=double_count
/>
<p>
    "Double Count: "
    // 在这里再次使用
    {double_count}
</p>
```

派生 signals 让您创建可以在应用程序的多个地方使用的响应式计算值，开销最小。

注意：像这样使用派生 signal 意味着计算每次 signal 更改时运行一次（当 `count()` 更改时）和每次我们访问 `double_count` 时运行一次；换句话说，两次。这是一个非常便宜的计算，所以没关系。我们将在后面的章节中查看 memos，它们是为了解决昂贵计算的这个问题而设计的。

> #### 高级主题：注入原始 HTML
>
> `view` 宏为附加属性 `inner_html` 提供支持，可用于直接设置任何元素的 HTML 内容，清除您给它的任何其他子元素。请注意，这_不会_转义您提供的 HTML。您应该确保它只包含受信任的输入或任何 HTML 实体都被转义，以防止跨站脚本（XSS）攻击。
>
> ```rust
> let html = "<p>This HTML will be injected.</p>";
> view! {
>   <div inner_html=html/>
> }
> ```
>
> [点击这里查看完整的 `view` 宏文档](https://docs.rs/leptos/latest/leptos/macro.view.html)。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/2-dynamic-attributes-0-7-wddqfp?file=%2Fsrc%2Fmain.rs%3A1%2C1-58%2C1)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/2-dynamic-attributes-0-7-wddqfp?file=%2Fsrc%2Fmain.rs%3A1%2C1-58%2C1" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    // "派生 signal" 是访问其他 signals 的函数
    // 我们可以使用它来创建依赖于
    // 一个或多个其他 signals 值的响应式值
    let double_count = move || count.get() * 2;

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
            // class: 语法响应式更新单个类
            // 在这里，当 `count` 为奇数时我们将设置 `red` 类
            class:red=move || count.get() % 2 == 1
            class=("button-20", move || count.get() % 2 == 1)
        >
            "Click me"
        </button>
        // 注意：像 <br> 这样的自闭合标签需要显式的 /
        <br/>

        // 每次 `count` 更改时我们都会更新这个进度条
        <progress
            // 静态属性像在 HTML 中一样工作
            max="50"

            // 将函数传递给属性
            // 响应式设置该属性
            // signals 是函数，所以 `value=count` 和 `value=move || count.get()`
            // 是可互换的。
            value=count
        >
        </progress>
        <br/>

        // 这个进度条将使用 `double_count`
        // 所以它应该移动得快两倍！
        <progress
            max="50"
            // 派生 signals 是函数，所以它们也可以
            // 响应式更新 DOM
            value=double_count
        >
        </progress>
        <p>"Count: " {count}</p>
        <p>"Double Count: " {double_count}</p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>