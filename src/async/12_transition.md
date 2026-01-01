# `<Transition/>`

您会注意到在 `<Suspense/>` 示例中，如果您继续重新加载数据，它会一直闪烁回到 `"Loading..."`。有时这很好。对于其他时候，有 [`<Transition/>`](https://docs.rs/leptos/latest/leptos/suspense/fn.Transition.html)。

`<Transition/>` 的行为与 `<Suspense/>` 完全相同，但不是每次都回退，它只在第一次显示 fallback。在所有后续加载中，它继续显示旧数据，直到新数据准备好。这对于防止闪烁效果和允许用户继续与您的应用程序交互非常有用。

这个示例展示了如何使用 `<Transition/>` 创建一个简单的选项卡式联系人列表。当您选择新选项卡时，它继续显示当前联系人，直到新数据加载。这可能比不断回退到加载消息提供更好的用户体验。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/12-transition-0-7-ln2hgd?file=%2Fsrc%2Fmain.rs%3A1%2C1-69%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/12-transition-0-7-ln2hgd?file=%2Fsrc%2Fmain.rs%3A1%2C1-69%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

async fn important_api_call(id: usize) -> String {
    TimeoutFuture::new(1_000).await;
    match id {
        0 => "Alice",
        1 => "Bob",
        2 => "Carol",
        _ => "User not found",
    }
    .to_string()
}

#[component]
fn App() -> impl IntoView {
    let (tab, set_tab) = signal(0);
    let (pending, set_pending) = signal(false);

    // 这将在每次 `tab` 更改时重新加载
    let user_data = LocalResource::new(move || important_api_call(tab.get()));

    view! {
        <div class="buttons">
            <button
                on:click=move |_| set_tab.set(0)
                class:selected=move || tab.get() == 0
            >
                "Tab A"
            </button>
            <button
                on:click=move |_| set_tab.set(1)
                class:selected=move || tab.get() == 1
            >
                "Tab B"
            </button>
            <button
                on:click=move |_| set_tab.set(2)
                class:selected=move || tab.get() == 2
            >
                "Tab C"
            </button>
        </div>
        <p>
            {move || if pending.get() {
                "Hang on..."
            } else {
                "Ready."
            }}
        </p>
        <Transition
            // fallback 将最初显示
            // 在后续重新加载时，当前子元素将
            // 继续显示
            fallback=move || view! { <p>"Loading initial data..."</p> }
            // 每当转换正在进行时，这将设置为 `true`
            set_pending
        >
            <p>
                {move || user_data.read().as_deref().map(ToString::to_string)}
            </p>
        </Transition>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>