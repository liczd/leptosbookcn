# 错误处理

[在上一章中](./06_control_flow.md)，我们看到您可以渲染 `Option<T>`：在 `None` 情况下，它将不渲染任何内容，在 `Some(T)` 情况下，它将渲染 `T`（即，如果 `T` 实现 `IntoView`）。您实际上可以对 `Result<T, E>` 做非常类似的事情。在 `Err(_)` 情况下，它将不渲染任何内容。在 `Ok(T)` 情况下，它将渲染 `T`。

让我们从一个简单的组件开始来捕获数字输入。

```rust
#[component]
fn NumericInput() -> impl IntoView {
    let (value, set_value) = signal(Ok(0));

    view! {
        <label>
            "Type an integer (or not!)"
            <input type="number" on:input:target=move |ev| {
              // 当输入更改时，尝试从输入解析数字
              set_value.set(ev.target().value().parse::<i32>())
            }/>
            <p>
                "You entered "
                <strong>{value}</strong>
            </p>
        </label>
    }
}
```

每次您更改输入时，`on_input` 将尝试将其值解析为 32 位整数（`i32`），并将其存储在我们的 `value` signal 中，这是一个 `Result<i32, _>`。如果您输入数字 `42`，UI 将显示

```
You entered 42
```

但如果您输入字符串 `foo`，它将显示

```
You entered
```

这不太好。它省去了我们使用 `.unwrap_or_default()` 或其他东西，但如果我们能捕获错误并对其做些什么会好得多。

您可以使用 [`<ErrorBoundary/>`](https://docs.rs/leptos/latest/leptos/error/fn.ErrorBoundary.html) 组件来做到这一点。

```admonish note
人们经常试图指出 `<input type="number">` 阻止您输入像 `foo` 这样的字符串，或任何其他不是数字的东西。这在某些浏览器中是正确的，但不是在所有浏览器中！此外，有各种可以输入到普通数字输入中但不是 `i32` 的东西：浮点数、大于 32 位的数字、字母 `e` 等等。浏览器可以被告知维护其中一些不变量，但浏览器行为仍然不同：自己解析很重要！
```

## `<ErrorBoundary/>`

`<ErrorBoundary/>` 有点像我们在上一章中看到的 `<Show/>` 组件。如果一切正常——也就是说，如果一切都是 `Ok(_)`——它渲染其子元素。但如果在这些子元素中渲染了 `Err(_)`，它将触发 `<ErrorBoundary/>` 的 `fallback`。

让我们向这个示例添加一个 `<ErrorBoundary/>`。

```rust
#[component]
fn NumericInput() -> impl IntoView {
        let (value, set_value) = signal(Ok(0));

    view! {
        <h1>"Error Handling"</h1>
        <label>
            "Type a number (or something that's not a number!)"
            <input type="number" on:input:target=move |ev| {
                // 当输入更改时，尝试从输入解析数字
                set_value.set(ev.target().value().parse::<i32>())
            }/>
            // 如果在 <ErrorBoundary/> 内渲染了 `Err(_)`，
            // 将显示 fallback。否则，将显示 <ErrorBoundary/> 的子元素。
            <ErrorBoundary
                // fallback 接收包含当前错误的 signal
                fallback=|errors| view! {
                    <div class="error">
                        <p>"Not a number! Errors: "</p>
                        // 如果我们愿意，我们可以将错误列表渲染为字符串
                        <ul>
                            {move || errors.get()
                                .into_iter()
                                .map(|(_, e)| view! { <li>{e.to_string()}</li>})
                                .collect::<Vec<_>>()
                            }
                        </ul>
                    </div>
                }
            >
                <p>
                    "You entered "
                    // 因为 `value` 是 `Result<i32, _>`，
                    // 如果它是 `Ok`，它将渲染 `i32`，
                    // 如果它是 `Err`，它将不渲染任何内容并触发错误边界。
                    // 它是一个 signal，所以当 `value` 更改时这将动态更新
                    <strong>{value}</strong>
                </p>
            </ErrorBoundary>
        </label>
    }
}
```

现在，如果您输入 `42`，`value` 是 `Ok(42)`，您将看到

```
You entered 42
```

如果您输入 `foo`，value 是 `Err(_)`，`fallback` 将渲染。我们选择将错误列表渲染为 `String`，所以您将看到类似

```
Not a number! Errors:
- cannot parse integer from empty string
```

如果您修复错误，错误消息将消失，您在 `<ErrorBoundary/>` 中包装的内容将再次出现。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/7-errors-0-7-qqywqz?file=%2Fsrc%2Fmain.rs%3A5%2C1-46%2C6&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/7-errors-0-7-qqywqz?file=%2Fsrc%2Fmain.rs%3A5%2C1-46%2C6&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (value, set_value) = signal(Ok(0));

    view! {
        <h1>"Error Handling"</h1>
        <label>
            "Type a number (or something that's not a number!)"
            <input type="number" on:input:target=move |ev| {
                // 当输入更改时，尝试从输入解析数字
                set_value.set(ev.target().value().parse::<i32>())
            }/>
            // 如果在 <ErrorBoundary/> 内渲染了 `Err(_)`，
            // 将显示 fallback。否则，将显示 <ErrorBoundary/> 的子元素。
            <ErrorBoundary
                // fallback 接收包含当前错误的 signal
                fallback=|errors| view! {
                    <div class="error">
                        <p>"Not a number! Errors: "</p>
                        // 如果我们愿意，我们可以将错误列表渲染为字符串
                        <ul>
                            {move || errors.get()
                                .into_iter()
                                .map(|(_, e)| view! { <li>{e.to_string()}</li>})
                                .collect::<Vec<_>>()
                            }
                        </ul>
                    </div>
                }
            >
                <p>
                    "You entered "
                    // 因为 `value` 是 `Result<i32, _>`，
                    // 如果它是 `Ok`，它将渲染 `i32`，
                    // 如果它是 `Err`，它将不渲染任何内容并触发错误边界。
                    // 它是一个 signal，所以当 `value` 更改时这将动态更新
                    <strong>{value}</strong>
                </p>
            </ErrorBoundary>
        </label>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>