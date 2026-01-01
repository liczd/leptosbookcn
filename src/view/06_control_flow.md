# 控制流

在大多数应用程序中，您有时需要做出决定：我应该渲染视图的这一部分吗？我应该渲染 `<ButtonA/>` 还是 `<WidgetB/>`？这就是**控制流**。

## 一些提示

在考虑如何使用 Leptos 做到这一点时，重要的是要记住几件事：

1. Rust 是一种面向表达式的语言：像 `if x() { y } else { z }` 和 `match x() { ... }` 这样的控制流表达式返回它们的值。这使它们对声明式用户界面非常有用。
2. 对于任何实现 `IntoView` 的 `T`——换句话说，对于 Leptos 知道如何渲染的任何类型——`Option<T>` 和 `Result<T, impl Error>` _也_实现 `IntoView`。就像 `Fn() -> T` 渲染响应式 `T` 一样，`Fn() -> Option<T>` 和 `Fn() -> Result<T, impl Error>` 是响应式的。
3. Rust 有很多方便的助手，如 [Option::map](https://doc.rust-lang.org/std/option/enum.Option.html#method.map)、[Option::and_then](https://doc.rust-lang.org/std/option/enum.Option.html#method.and_then)、[Option::ok_or](https://doc.rust-lang.org/std/option/enum.Option.html#method.ok_or)、[Result::map](https://doc.rust-lang.org/std/result/enum.Result.html#method.map)、[Result::ok](https://doc.rust-lang.org/std/result/enum.Result.html#method.ok) 和 [bool::then](https://doc.rust-lang.org/std/primitive.bool.html#method.then)，允许您以声明式方式在几种不同的标准类型之间转换，所有这些都可以渲染。特别是花时间在 `Option` 和 `Result` 文档中是提升您的 Rust 技能的最佳方法之一。
4. 并且始终记住：要是响应式的，值必须是函数。您会看到我在下面不断地将事物包装在 `move ||` 闭包中。这是为了确保当它们依赖的 signal 更改时它们实际重新运行，保持 UI 响应式。

## 那又怎样？

为了稍微连接一下点：这意味着您实际上可以使用原生 Rust 代码实现大部分控制流，而无需任何控制流组件或特殊知识。

例如，让我们从一个简单的 signal 和派生 signal 开始：

```rust
let (value, set_value) = signal(0);
let is_odd = move || value.get() % 2 != 0;
```

我们可以使用这些 signals 和普通的 Rust 来构建大部分控制流。

### `if` 语句

假设我想在数字为奇数时渲染一些文本，在偶数时渲染其他文本。好吧，这样如何？

```rust
view! {
    <p>
        {move || if is_odd() {
            "Odd"
        } else {
            "Even"
        }}
    </p>
}
```

`if` 表达式返回其值，`&str` 实现 `IntoView`，所以 `Fn() -> &str` 实现 `IntoView`，所以这...就是工作的！

### `Option<T>`

假设我们想在奇数时渲染一些文本，在偶数时什么都不渲染。

```rust
let message = move || {
    if is_odd() {
        Some("Ding ding ding!")
    } else {
        None
    }
};

view! {
    <p>{message}</p>
}
```

这工作得很好。如果我们愿意，我们可以使用 `bool::then()` 使其更短一些。

```rust
let message = move || is_odd().then(|| "Ding ding ding!");
view! {
    <p>{message}</p>
}
```

如果您愿意，您甚至可以内联这个，尽管我个人有时喜欢通过将事物从 `view` 中拉出来获得更好的 `cargo fmt` 和 `rust-analyzer` 支持。

### `match` 语句

我们仍然只是在编写普通的 Rust 代码，对吧？所以您拥有 Rust 模式匹配的所有能力。

```rust
let message = move || {
    match value.get() {
        0 => "Zero",
        1 => "One",
        n if is_odd() => "Odd",
        _ => "Even"
    }
};
view! {
    <p>{message}</p>
}
```

为什么不呢？YOLO，对吧？

## 防止过度渲染

不那么 YOLO。

我们刚才做的一切基本上都很好。但有一件事您应该记住并尽量小心。我们到目前为止创建的每个控制流函数基本上都是一个派生 signal：它将在值每次更改时重新运行。在上面的示例中，值在每次更改时从偶数切换到奇数，这很好。

但考虑以下示例：

```rust
let (value, set_value) = signal(0);

let message = move || if value.get() > 5 {
    "Big"
} else {
    "Small"
};

view! {
    <p>{message}</p>
}
```

这_工作_，当然。但如果您添加了日志，您可能会感到惊讶

```rust
let message = move || if value.get() > 5 {
    logging::log!("{}: rendering Big", value.get());
    "Big"
} else {
    logging::log!("{}: rendering Small", value.get());
    "Small"
};
```

当用户重复点击增加 `value` 的按钮时，您会看到类似这样的内容：

```
1: rendering Small
2: rendering Small
3: rendering Small
4: rendering Small
5: rendering Small
6: rendering Big
7: rendering Big
8: rendering Big
... 无穷无尽
```

每次 `value` 更改时，它重新运行 `if` 语句。这是有道理的，响应性就是这样工作的。但它有一个缺点。对于简单的文本节点，重新运行 `if` 语句和重新渲染不是什么大问题。但想象一下如果是这样的：

```rust
let message = move || if value.get() > 5 {
    <Big/>
} else {
    <Small/>
};
```

这重新渲染 `<Small/>` 五次，然后无限重新渲染 `<Big/>`。如果它们正在加载资源、创建 signals，或者甚至只是创建 DOM 节点，这是不必要的工作。

### `<Show/>`

[`<Show/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.Show.html) 组件是答案。您向它传递一个 `when` 条件函数，一个在 `when` 函数返回 `false` 时显示的 `fallback`，以及在 `when` 为 `true` 时要渲染的子元素。

```rust
let (value, set_value) = signal(0);

view! {
  <Show
    when=move || { value.get() > 5 }
    fallback=|| view! { <Small/> }
  >
    <Big/>
  </Show>
}
```

`<Show/>` 记忆化 `when` 条件，所以它只渲染其 `<Small/>` 一次，继续显示相同的组件，直到 `value` 大于五；然后它渲染 `<Big/>` 一次，继续无限显示它，或者直到 `value` 低于五，然后再次渲染 `<Small/>`。

这是避免在使用动态 `if` 表达式时重新渲染的有用工具。一如既往，有一些开销：对于非常简单的节点（如更新单个文本节点，或更新类或属性），`move || if ...` 会更高效。但如果渲染任一分支都有点昂贵，请使用 `<Show/>`。

## 注意：类型转换

在本节中有一件最后的重要事情要说。

Leptos 使用静态类型的视图树。`view` 宏为不同类型的视图返回不同的类型。

这不会编译，因为不同的 HTML 元素是不同的类型。

```rust,compile_error
view! {
    <main>
        {move || match is_odd() {
            true if value.get() == 1 => {
                view! { <pre>"One"</pre> }
            },
            false if value.get() == 2 => {
                view! { <p>"Two"</p> }
            }
            // 返回 HtmlElement<Textarea>
            _ => view! { <textarea>{value.get()}</textarea> }
        }}
    </main>
}
```

这种强类型非常强大，因为它启用了各种编译时优化。但在像这样的条件逻辑中可能有点烦人，因为您不能在 Rust 中从条件的不同分支返回不同类型。有两种方法可以让自己摆脱这种情况：

1. 使用枚举 `Either`（和 `EitherOf3`、`EitherOf4` 等）将不同类型转换为相同类型。
2. 使用 `.into_any()` 将多种类型转换为一个类型擦除的 `AnyView`。

这是同样的示例，添加了转换：

```rust,compile_error
view! {
    <main>
        {move || match is_odd() {
            true if value.get() == 1 => {
                // 返回 HtmlElement<Pre>
                view! { <pre>"One"</pre> }.into_any()
            },
            false if value.get() == 2 => {
                // 返回 HtmlElement<P>
                view! { <p>"Two"</p> }.into_any()
            }
            // 返回 HtmlElement<Textarea>
            _ => view! { <textarea>{value.get()}</textarea> }.into_any()
        }}
    </main>
}
```

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/6-control-flow-0-7-3m4c9j?file=%2Fsrc%2Fmain.rs%3A1%2C1-91%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/6-control-flow-0-7-3m4c9j?file=%2Fsrc%2Fmain.rs%3A1%2C1-91%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (value, set_value) = signal(0);
    let is_odd = move || value.get() & 1 == 1;
    let odd_text = move || if is_odd() {
        Some("How odd!")
    } else {
        None
    };

    view! {
        <h1>"Control Flow"</h1>

        // 更新和显示值的简单 UI
        <button on:click=move |_| *set_value.write() += 1>
            "+1"
        </button>
        <p>"Value is: " {value}</p>

        <hr/>

        <h2><code>"Option<T>"</code></h2>
        // 对于任何实现 `IntoView` 的 `T`，
        // `Option<T>` 也是如此

        <p>{odd_text}</p>
        // 这意味着您可以在其上使用 `Option` 方法
        <p>{move || odd_text().map(|text| text.len())}</p>

        <h2>"Conditional Logic"</h2>
        // 您可以以几种方式进行动态条件 if-then-else 逻辑
        //
        // a. 函数中的 "if" 表达式
        //    这将在值每次更改时简单地重新渲染，
        //    这使其适用于轻量级 UI
        <p>
            {move || if is_odd() {
                "Odd"
            } else {
                "Even"
            }}
        </p>

        // b. 切换某种类
        //    这对于经常切换的元素很聪明，
        //    因为它不会在状态之间销毁它
        //    （您可以在 `index.html` 中找到 `hidden` 类）
        <p class:hidden=is_odd>"Appears if even."</p>

        // c. <Show/> 组件
        //    这只渲染 fallback 和子元素一次，惰性地，
        //    并在需要时在它们之间切换。
        //    这在许多情况下比 {move || if ...} 块更高效
        <Show when=is_odd
            fallback=|| view! { <p>"Even steven"</p> }
        >
            <p>"Oddment"</p>
        </Show>

        // d. 因为 `bool::then()` 将 `bool` 转换为 `Option`，
        //    您可以使用它来创建显示/隐藏切换
        {move || is_odd().then(|| view! { <p>"Oddity!"</p> })}

        <h2>"Converting between Types"</h2>
        // e. 注意：如果分支返回不同类型，
        //    您可以使用 `.into_any()` 或使用 `Either` 枚举
        //    （`Either`、`EitherOf3`、`EitherOf4` 等）在它们之间转换
        {move || match is_odd() {
            true if value.get() == 1 => {
                // <pre> 返回 HtmlElement<Pre>
                view! { <pre>"One"</pre> }.into_any()
            },
            false if value.get() == 2 => {
                // <p> 返回 HtmlElement<P>
                // 所以我们转换为更通用的类型
                view! { <p>"Two"</p> }.into_any()
            }
            _ => view! { <textarea>{value.get()}</textarea> }.into_any()
        }}
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>