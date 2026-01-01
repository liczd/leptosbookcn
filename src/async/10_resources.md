# 使用 Resources 加载数据

Resources 是异步任务的响应式包装器，允许您将异步 `Future` 集成到同步响应式系统中。

它们有效地允许您加载一些异步数据，然后同步或异步地响应式访问它。您可以像普通 `Future` 一样 `.await` 一个 resource，这将跟踪它。但您也可以使用 `.get()` 和其他 signal 访问方法访问 resource，就好像 resource 是一个在已解析时返回 `Some(T)`、仍在等待时返回 `None` 的 signal。

Resources 有两种主要类型：`Resource` 和 `LocalResource`。如果您使用服务端渲染（本书稍后会讨论），您应该默认使用 `Resource`。如果您使用客户端渲染与 `!Send` API（如许多浏览器 API），或者如果您使用 SSR 但有一些只能在浏览器上完成的异步任务（例如，访问异步浏览器 API），那么您应该使用 `LocalResource`。

## Local Resources

`LocalResource::new()` 接受一个参数：一个返回 `Future` 的"fetcher"函数。

`Future` 可以是 `async` 块、`async fn` 调用的结果或任何其他 Rust `Future`。该函数将像派生 signal 或我们迄今为止看到的其他响应式闭包一样工作：您可以在其中读取 signals，每当 signal 更改时，函数将再次运行，创建一个新的 `Future` 来运行。

```rust
// 这个 count 是我们的同步本地状态
let (count, set_count) = signal(0);

// 跟踪 `count`，并通过调用 `load_data` 重新加载
// 每当它改变时
let async_data = LocalResource::new(move || load_data(count.get()));
```

创建 resource 会立即调用其 fetcher 并开始轮询 `Future`。从 resource 读取将返回 `None`，直到异步任务完成，此时它将通知其订阅者，现在有 `Some(value)`。

您也可以 `.await` 一个 resource。这可能看起来毫无意义——为什么要创建一个 `Future` 的包装器，然后再 `.await` 它？我们将在下一章中看到原因。

## Resources

如果您使用 SSR，在大多数情况下您应该使用 `Resource` 而不是 `LocalResource`。

这个 API 略有不同。`Resource::new()` 接受两个函数作为参数：

1. 一个 source 函数，包含"输入"。这个输入被记忆化，每当其值更改时，fetcher 将被调用。
2. 一个 fetcher 函数，接受来自 source 函数的数据并返回一个 `Future`

与 `LocalResource` 不同，`Resource` 将其值从服务器序列化到客户端。然后，在客户端，当首次加载页面时，初始值将被反序列化而不是异步任务再次运行。这非常重要且非常有用：这意味着不是等待客户端 WASM 包加载并开始运行应用程序，数据加载在服务器上开始。（在后面的章节中会有更多关于这一点的内容。）

这也是为什么 API 分为两部分的原因：*source* 函数中的 signals 被跟踪，但 *fetcher* 中的 signals 不被跟踪，因为这允许 resource 保持响应性而无需在客户端初始 hydration 期间再次运行 fetcher。

这是同样的示例，使用 `Resource` 而不是 `LocalResource`：

```rust
// 这个 count 是我们的同步本地状态
let (count, set_count) = signal(0);

// 我们的 resource
let async_data = Resource::new(
    move || count.get(),
    // 每次 `count` 更改时，这将运行
    |count| load_data(count) 
);
```

Resources 还提供了一个 `refetch()` 方法，允许您手动重新加载数据（例如，响应按钮点击）。

要创建一个只运行一次的 resource，您可以使用 `OnceResource`，它只接受一个 `Future`，并添加一些来自知道它只会加载一次的优化。

```rust
let once = OnceResource::new(load_data(42));
```

## 访问 Resources

`LocalResource` 和 `Resource` 都实现了各种 signal 访问方法（`.read()`、`.with()`、`.get()`），但返回 `Option<T>` 而不是 `T`；在异步数据加载之前它们将是 `None`。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/10-resource-0-7-q5xr9m?file=%2Fsrc%2Fmain.rs%3A7%2C30)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/10-resource-0-7-q5xr9m?file=%2Fsrc%2Fmain.rs%3A7%2C30" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

// 在这里我们定义一个异步函数
// 这可以是任何东西：网络请求、数据库读取等
// 在这里，我们只是将一个数字乘以 10
async fn load_data(value: i32) -> i32 {
    // 模拟一秒延迟
    TimeoutFuture::new(1_000).await;
    value * 10
}

#[component]
pub fn App() -> impl IntoView {
    // 这个 count 是我们的同步本地状态
    let (count, set_count) = signal(0);

    // 跟踪 `count`，并通过调用 `load_data` 重新加载
    // 每当它改变时
    let async_data = LocalResource::new(move || load_data(count.get()));

    // 如果 resource 不读取任何响应式数据，它只会加载一次
    let stable = LocalResource::new(|| load_data(1));

    // 我们可以使用 .get() 访问 resource 值
    // 这将在 Future 解析之前响应式返回 None
    // 并在解析时更新为 Some(T)
    let async_result = move || {
        async_data
            .get()
            .map(|value| format!("Server returned {value:?}"))
            // 这个加载状态只会在第一次加载之前显示
            .unwrap_or_else(|| "Loading...".into())
    };

    view! {
        <button
            on:click=move |_| *set_count.write() += 1
        >
            "Click me"
        </button>
        <p>
            <code>"stable"</code>": " {move || stable.get()}
        </p>
        <p>
            <code>"count"</code>": " {count}
        </p>
        <p>
            <code>"async_value"</code>": "
            {async_result}
            <br/>
        </p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>