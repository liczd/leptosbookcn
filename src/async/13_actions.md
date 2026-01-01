# 使用 Actions 修改数据

我们已经讨论了如何使用 resources 加载 `async` 数据。Resources 立即加载数据并与 `<Suspense/>` 和 `<Transition/>` 组件密切配合，以显示您的应用程序中数据是否正在加载。但是如果您只想调用一些任意的 `async` 函数并跟踪它在做什么呢？

好吧，您总是可以使用 [`spawn_local`](https://docs.rs/leptos/latest/leptos/task/fn.spawn_local.html)。这允许您通过将 `Future` 交给浏览器（或在服务器上，Tokio 或您正在使用的任何其他运行时）在同步环境中生成 `async` 任务。但是您如何知道它是否仍在等待？好吧，您可以设置一个 signal 来显示它是否正在加载，另一个来显示结果...

所有这些都是正确的。或者您可以使用最终的 `async` 原语：[`Action`](https://docs.rs/leptos/latest/leptos/reactive/actions/struct.Action.html)。

Actions 和 resources 看起来相似，但它们代表根本不同的东西。如果您试图通过运行 `async` 函数来加载数据，无论是一次还是当其他值更改时，您可能想要使用 resource。如果您试图偶尔运行 `async` 函数以响应用户点击按钮之类的事情，您可能想要使用 `Action`。

假设我们有一些想要运行的 `async` 函数。

```rust
async fn add_todo_request(new_title: &str) -> Uuid {
    /* 在服务器上做一些事情来添加新的 todo */
}
```

`Action::new()` 接受一个 `async` 函数，该函数接受对单个参数的引用，您可以将其视为"输入类型"。

> 输入始终是单一类型。如果您想传入多个参数，可以使用结构体或元组来完成。
>
> ```rust
> // 如果有单个参数，只需使用它
> let action1 = Action::new(|input: &String| {
>    let input = input.clone();
>    async move { todo!() }
> });
>
> // 如果没有参数，使用单元类型 `()`
> let action2 = Action::new(|input: &()| async { todo!() });
>
> // 如果有多个参数，使用元组
> let action3 = Action::new(
>   |input: &(usize, String)| async { todo!() }
> );
> ```
>
> 因为 action 函数接受引用但 `Future` 需要有 `'static` 生命周期，您通常需要克隆值以将其传递到 `Future` 中。这确实有点笨拙，但它解锁了一些强大的功能，如乐观 UI。我们将在未来的章节中看到更多相关内容。

所以在这种情况下，我们创建 action 所需要做的就是

```rust
let add_todo_action = Action::new(|input: &String| {
    let input = input.to_owned();
    async move { add_todo_request(&input).await }
});
```

我们不会直接调用 `add_todo_action`，而是使用 `.dispatch()` 调用它，如

```rust
add_todo_action.dispatch("Some value".to_string());
```

您可以从事件监听器、超时或任何地方执行此操作；因为 `.dispatch()` 不是 `async` 函数，它可以从同步上下文中调用。

Actions 提供对几个 signals 的访问，这些 signals 在您调用的异步 action 和同步响应式系统之间同步：

```rust
let submitted = add_todo_action.input(); // RwSignal<Option<String>>
let pending = add_todo_action.pending(); // ReadSignal<bool>
let todo_id = add_todo_action.value(); // RwSignal<Option<Uuid>>
```

这使得跟踪请求的当前状态、显示加载指示器或基于提交将成功的假设进行"乐观 UI"变得容易。

```rust
let input_ref = NodeRef::<Input>::new();

view! {
    <form
        on:submit=move |ev| {
            ev.prevent_default(); // 不要重新加载页面...
            let input = input_ref.get().expect("input to exist");
            add_todo_action.dispatch(input.value());
        }
    >
        <label>
            "What do you need to do?"
            <input type="text"
                node_ref=input_ref
            />
        </label>
        <button type="submit">"Add Todo"</button>
    </form>
    // 使用我们的加载状态
    <p>{move || pending.get().then_some("Loading...")}</p>
}
```

现在，这一切可能看起来有点过于复杂，或者可能过于受限。我想在这里包含 actions，与 resources 一起，作为拼图的缺失部分。在真正的 Leptos 应用程序中，您实际上最常将 actions 与 server functions、[`ServerAction`](https://docs.rs/leptos/latest/leptos/server/struct.ServerAction.html) 和 [`<ActionForm/>`](https://docs.rs/leptos/latest/leptos/form/fn.ActionForm.html) 组件一起使用，以创建真正强大的渐进增强表单。所以如果这个原语对您来说似乎没用...不要担心！也许稍后会有意义。（或者现在查看我们的 [`todo_app_sqlite`](https://github.com/leptos-rs/leptos/blob/main/examples/todo_app_sqlite/src/todo.rs) 示例。）

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/13-action-0-7-g73rl9?file=%2Fsrc%2Fmain.rs)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/13-action-0-7-g73rl9?file=%2Fsrc%2Fmain.rs" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::{html::Input, prelude::*};
use uuid::Uuid;

// 在这里我们定义一个异步函数
// 这可以是任何东西：网络请求、数据库读取等
// 将其视为变更：您运行的一些命令式异步操作，
// 而 resource 将是您加载的一些异步数据
async fn add_todo(text: &str) -> Uuid {
    _ = text;
    // 模拟一秒延迟
    // SendWrapper 允许我们使用这个 !Send 浏览器 API；不用担心
    send_wrapper::SendWrapper::new(TimeoutFuture::new(1_000)).await;
    // 假装这是一个帖子 ID 或其他什么
    Uuid::new_v4()
}

#[component]
pub fn App() -> impl IntoView {
    // action 接受一个带有单个参数的异步函数
    // 它可以是简单类型、结构体或 ()
    let add_todo = Action::new(|input: &String| {
        // 输入是引用，但我们需要 Future 拥有它
        // 这很重要：我们需要克隆并移动到 Future 中
        // 这样它就有了 'static 生命周期
        let input = input.to_owned();
        async move { add_todo(&input).await }
    });

    // actions 提供一堆同步的响应式变量
    // 告诉我们 action 状态的不同信息
    let submitted = add_todo.input();
    let pending = add_todo.pending();
    let todo_id = add_todo.value();

    let input_ref = NodeRef::<Input>::new();

    view! {
        <form
            on:submit=move |ev| {
                ev.prevent_default(); // 不要重新加载页面...
                let input = input_ref.get().expect("input to exist");
                add_todo.dispatch(input.value());
            }
        >
            <label>
                "What do you need to do?"
                <input type="text"
                    node_ref=input_ref
                />
            </label>
            <button type="submit">"Add Todo"</button>
        </form>
        <p>{move || pending.get().then_some("Loading...")}</p>
        <p>
            "Submitted: "
            <code>{move || format!("{:#?}", submitted.get())}</code>
        </p>
        <p>
            "Pending: "
            <code>{move || format!("{:#?}", pending.get())}</code>
        </p>
        <p>
            "Todo ID: "
            <code>{move || format!("{:#?}", todo_id.get())}</code>
        </p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>