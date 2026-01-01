# `<Suspense/>`

在上一章中，我们展示了如何创建一个简单的加载屏幕，在 resource 加载时显示一些后备内容。

```rust
let (count, set_count) = signal(0);
let once = Resource::new(move || count.get(), |count| async move { load_a(count).await });

view! {
    <h1>"My Data"</h1>
    {move || match once.get() {
        None => view! { <p>"Loading..."</p> }.into_any(),
        Some(data) => view! { <ShowData data/> }.into_any()
    }}
}
```

但是如果我们有两个 resources，并且想要等待它们两个呢？

```rust
let (count, set_count) = signal(0);
let (count2, set_count2) = signal(0);
let a = Resource::new(move || count.get(), |count| async move { load_a(count).await });
let b = Resource::new(move || count2.get(), |count| async move { load_b(count).await });

view! {
    <h1>"My Data"</h1>
    {move || match (a.get(), b.get()) {
        (Some(a), Some(b)) => view! {
            <ShowA a/>
            <ShowA b/>
        }.into_any(),
        _ => view! { <p>"Loading..."</p> }.into_any()
    }}
}
```

这并不_那么_糟糕，但有点烦人。如果我们可以反转控制流会怎么样？

[`<Suspense/>`](https://docs.rs/leptos/latest/leptos/suspense/fn.Suspense.html) 组件让我们可以做到这一点。您给它一个 `fallback` prop 和子元素，其中一个或多个通常涉及从 resource 读取。在 `<Suspense/>` "下"（即在其子元素之一中）读取 resource 会将该 resource 注册到 `<Suspense/>`。如果它仍在等待 resources 加载，它会显示 `fallback`。当它们全部加载完成时，它会显示子元素。

```rust
let (count, set_count) = signal(0);
let (count2, set_count2) = signal(0);
let a = Resource::new(count, |count| async move { load_a(count).await });
let b = Resource::new(count2, |count| async move { load_b(count).await });

view! {
    <h1>"My Data"</h1>
    <Suspense
        fallback=move || view! { <p>"Loading..."</p> }
    >
        <h2>"My Data"</h2>
        <h3>"A"</h3>
        {move || {
            a.get()
                .map(|a| view! { <ShowA a/> })
        }}
        <h3>"B"</h3>
        {move || {
            b.get()
                .map(|b| view! { <ShowB b/> })
        }}
    </Suspense>
}
```

每次其中一个 resources 重新加载时，`"Loading..."` 后备内容将再次显示。

这种控制流的反转使得添加或删除单个 resources 变得更容易，因为您不需要自己处理匹配。它还在服务端渲染期间解锁了一些巨大的性能改进，我们将在后面的章节中讨论。

使用 `<Suspense/>` 还为我们提供了一种直接 `.await` resources 的有用方法，允许我们减少上面的嵌套层级。`Suspend` 类型让我们创建一个可渲染的 `Future`，可以在视图中使用：

```rust
view! {
    <h1>"My Data"</h1>
    <Suspense
        fallback=move || view! { <p>"Loading..."</p> }
    >
        <h2>"My Data"</h2>
        {move || Suspend::new(async move {
            let a = a.await;
            let b = b.await;
            view! {
                <h3>"A"</h3>
                <ShowA a/>
                <h3>"B"</h3>
                <ShowB b/>
            }
        })}
    </Suspense>
}
```

`Suspend` 允许我们避免对每个 resource 进行空值检查，并减少代码的额外复杂性。

## `<Await/>`

如果您只是想等待某个 `Future` 解析后再渲染，您可能会发现 `<Await/>` 组件有助于减少样板代码。`<Await/>` 本质上将 `OnceResource` 与没有 fallback 的 `<Suspense/>` 结合起来。

换句话说：

1. 它只轮询 `Future` 一次，不响应任何响应式更改。
2. 在 `Future` 解析之前它不渲染任何内容。
3. `Future` 解析后，它将数据绑定到您选择的任何变量名，然后在该变量的作用域内渲染其子元素。

```rust
async fn fetch_monkeys(monkey: i32) -> i32 {
    // 也许这不需要是异步的
    monkey * 2
}
view! {
    <Await
        // `future` 提供要解析的 `Future`
        future=fetch_monkeys(3)
        // 数据绑定到您提供的任何变量名
        let:data
    >
        // 您通过引用接收数据，可以在这里的视图中使用它
        <p>{*data} " little monkeys, jumping on the bed."</p>
    </Await>
}
```

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/11-suspense-0-7-sr2srk?file=%2Fsrc%2Fmain.rs%3A1%2C1-55%2C1)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/11-suspense-0-7-sr2srk?file=%2Fsrc%2Fmain.rs%3A1%2C1-55%2C1" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

async fn important_api_call(name: String) -> String {
    TimeoutFuture::new(1_000).await;
    name.to_ascii_uppercase()
}

#[component]
pub fn App() -> impl IntoView {
    let (name, set_name) = signal("Bill".to_string());

    // 这将在每次 `name` 更改时重新加载
    let async_data = LocalResource::new(move || important_api_call(name.get()));

    view! {
        <input
            on:change:target=move |ev| {
                set_name.set(ev.target().value());
            }
            prop:value=name
        />
        <p><code>"name:"</code> {name}</p>
        <Suspense
            // 每当在 suspense "下"读取的 resource
            // 正在加载时，fallback 将显示
            fallback=move || view! { <p>"Loading..."</p> }
        >
            // Suspend 允许您在视图中使用异步块
            <p>
                "Your shouting name is "
                {move || Suspend::new(async move {
                    async_data.await
                })}
            </p>
        </Suspense>
        <Suspense
            // 每当在 suspense "下"读取的 resource
            // 正在加载时，fallback 将显示
            fallback=move || view! { <p>"Loading..."</p> }
        >
            // 子元素将最初渲染一次，
            // 然后在任何 resources 解析时再次渲染
            <p>
                "Which should be the same as... "
                {move || async_data.get().as_deref().map(ToString::to_string)}
            </p>
        </Suspense>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>