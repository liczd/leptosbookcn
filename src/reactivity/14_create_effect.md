# 使用 Effects 响应变化

我们已经走了这么远而没有提到响应式系统的一半：effects。

响应性分为两半：更新单个响应式值（"signals"）通知依赖于它们的代码片段（"effects"）它们需要再次运行。响应式系统的这两半是相互依赖的。没有 effects，signals 可以在响应式系统内改变，但永远不会以与外部世界交互的方式被观察到。没有 signals，effects 运行一次但永远不会再次运行，因为没有可观察的值可以订阅。Effects 实际上是响应式系统的"副作用"：它们存在是为了将响应式系统与其外部的非响应式世界同步。

渲染器使用 effects 来响应 signals 的变化更新 DOM 的部分。您可以创建自己的 effects 来以其他方式将响应式系统与外部世界同步。

[`Effect::new`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html) 接受一个函数作为其参数。它在响应式系统的下一个"tick"上运行此函数。（例如，如果您在组件中使用它，它将在该组件被渲染_之后_运行。）如果您在该函数内访问任何响应式 signal，它会注册 effect 依赖于该 signal 的事实。每当 effect 依赖的 signals 之一发生变化时，effect 就会再次运行。

```rust
let (a, set_a) = signal(0);
let (b, set_b) = signal(0);

Effect::new(move |_| {
  // 立即打印 "Value: 0" 并订阅 `a`
  logging::log!("Value: {}", a.get());
});
```

effect 函数使用包含它上次运行时返回的任何值的参数调用。在初始运行时，这是 `None`。

默认情况下，effects **不在服务器上运行**。这意味着您可以在 effect 函数内调用特定于浏览器的 API 而不会引起问题。如果您需要 effect 在服务器上运行，请使用 [`Effect::new_isomorphic`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html#method.new_isomorphic)。

## 自动跟踪和动态依赖

如果您熟悉像 React 这样的框架，您可能会注意到一个关键区别。React 和类似框架通常要求您传递"依赖数组"，这是一个明确的变量集合，用于确定 effect 何时应该重新运行。

因为 Leptos 来自同步响应式编程的传统，我们不需要这个明确的依赖列表。相反，我们根据在 effect 内访问哪些 signals 自动跟踪依赖。

这有两个效果（没有双关语的意思）。依赖是：

1. **自动的**：您不需要维护依赖列表，或担心应该或不应该包含什么。框架简单地跟踪哪些 signals 可能导致 effect 重新运行，并为您处理它。
2. **动态的**：依赖列表在每次 effect 运行时被清除和更新。如果您的 effect 包含条件（例如），只有在当前分支中使用的 signals 被跟踪。这意味着 effects 重新运行的次数绝对最少。

> 如果这听起来像魔法，如果您想深入了解自动依赖跟踪如何工作，[查看这个视频](https://www.youtube.com/watch?v=GWB3vTWeLd4)。（为低音量道歉！）

## Effects 作为零成本抽象

虽然它们在最技术意义上不是"零成本抽象"——它们需要一些额外的内存使用，在运行时存在等等——在更高层次上，从您在其中进行的任何昂贵 API 调用或其他工作的角度来看，effects 是零成本抽象。考虑到您如何描述它们，它们重新运行绝对必要的最少次数。

想象我正在创建某种聊天软件，我希望人们能够显示他们的全名或只是他们的名字，并在他们的名字更改时通知服务器：

```rust
let (first, set_first) = signal(String::new());
let (last, set_last) = signal(String::new());
let (use_last, set_use_last) = signal(true);

// 这将在任何源 signals 更改时将名称添加到日志中
Effect::new(move |_| {
    logging::log!(
        "{}", if use_last.get() {
            format!("{} {}", first.get(), last.get())
        } else {
            first.get()
        },
    )
});
```

如果 `use_last` 是 `true`，effect 应该在 `first`、`last` 或 `use_last` 更改时重新运行。但如果我将 `use_last` 切换为 `false`，`last` 的更改永远不会导致全名更改。实际上，`last` 将从依赖列表中删除，直到 `use_last` 再次切换。这节省了我们在 `use_last` 仍然是 `false` 时多次更改 `last` 时向 API 发送多个不必要请求的情况。

## 创建 effect，还是不创建 effect？

Effects 旨在将响应式系统与外部的非响应式世界同步，而不是在不同响应式值之间同步。换句话说：使用 effect 从一个 signal 读取值并在另一个 signal 中设置它总是次优的。

如果您需要定义一个依赖于其他 signals 值的 signal，请使用派生 signal 或 [`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html)。在 effect 内写入 signal 不是世界末日，它不会导致您的计算机着火，但派生 signal 或 memo 总是更好——不仅因为数据流清晰，而且因为性能更好。

```rust
let (a, set_a) = signal(0);

// ⚠️ 不太好
let (b, set_b) = signal(0);
Effect::new(move |_| {
    set_b.set(a.get() * 2);
});

// ✅ 太棒了！
let b = move || a.get() * 2;
```

如果您需要将某些响应式值与外部的非响应式世界同步——如 Web API、控制台、文件系统或 DOM——在 effect 中写入 signal 是一种很好的方法。但在许多情况下，您会发现您实际上是在事件监听器或其他东西内部写入 signal，而不是在 effect 内部。在这些情况下，您应该查看 [`leptos-use`](https://leptos-use.rs/) 看看它是否已经提供了响应式包装原语来做到这一点！

> 如果您想了解更多关于何时应该和不应该使用 `create_effect` 的信息，[查看这个视频](https://www.youtube.com/watch?v=aQOFJQ2JkvQ) 进行更深入的考虑！

## Effects 和渲染

我们已经走了这么远而没有提到 effects，因为它们内置在 Leptos DOM 渲染器中。我们已经看到您可以创建一个 signal 并将其传递到 `view` 宏中，它将在 signal 更改时更新相关的 DOM 节点：

```rust
let (count, set_count) = signal(0);

view! {
    <p>{count}</p>
}
```

这之所以有效，是因为框架本质上创建了一个包装此更新的 effect。您可以想象 Leptos 将此视图转换为类似这样的东西：

```rust
let (count, set_count) = signal(0);

// 创建 DOM 元素
let document = leptos::document();
let p = document.create_element("p").unwrap();

// 创建 effect 来响应式更新文本
Effect::new(move |prev_value| {
    // 首先，访问 signal 的值并将其转换为字符串
    let text = count.get().to_string();

    // 如果这与之前的值不同，更新节点
    if prev_value != Some(text) {
        p.set_text_content(&text);
    }

    // 返回此值，以便我们可以记忆化下一次更新
    text
});
```

每次 `count` 更新时，此 effect 将重新运行。这就是允许对 DOM 进行响应式、细粒度更新的原因。

## 使用 `Effect::watch()` 显式跟踪

除了 `Effect::new()` 之外，Leptos 还提供了一个 [`Effect::watch()`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html#method.watch) 函数，可用于通过显式传入一组要跟踪的值来分离跟踪和响应变化。

`watch` 接受三个参数。`dependency_fn` 参数被响应式跟踪，而 `handler` 和 `immediate` 不被跟踪。每当 `dependency_fn` 更改时，`handler` 就会运行。如果 `immediate` 是 false，`handler` 只会在检测到在 `dependency_fn` 中访问的任何 signal 的第一次更改后运行。`watch` 返回一个 `Effect`，可以用 `.stop()` 调用来停止跟踪依赖。

```rust
let (num, set_num) = signal(0);

let effect = Effect::watch(
    move || num.get(),
    move |num, prev_num, _| {
        leptos::logging::log!("Number: {}; Prev: {:?}", num, prev_num);
    },
    false,
);

set_num.set(1); // > "Number: 1; Prev: Some(0)"

effect.stop(); // 停止监视

set_num.set(2); // （什么都不发生）
```

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/14-effect-0-7-fxpy2d?file=%2Fsrc%2Fmain.rs%3A21%2C28&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/14-effect-0-7-fxpy2d?file=%2Fsrc%2Fmain.rs%3A21%2C28&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::html::Input;
use leptos::prelude::*;

#[derive(Copy, Clone)]
struct LogContext(RwSignal<Vec<String>>);

#[component]
fn App() -> impl IntoView {
    // 只是在这里制作一个可见的日志
    // 您可以忽略这个...
    let log = RwSignal::<Vec<String>>::new(vec![]);
    let logged = move || log.get().join("\n");

    // newtype 模式在这里不是*必需的*，但是一个好的实践
    // 它避免了与其他可能的未来 `RwSignal<Vec<String>>` contexts 的混淆
    // 并使引用它变得更容易
    provide_context(LogContext(log));

    view! {
        <CreateAnEffect/>
        <pre>{logged}</pre>
    }
}

#[component]
fn CreateAnEffect() -> impl IntoView {
    let (first, set_first) = signal(String::new());
    let (last, set_last) = signal(String::new());
    let (use_last, set_use_last) = signal(true);

    // 这将在任何源 signals 更改时将名称添加到日志中
    Effect::new(move |_| {
        log(if use_last.get() {
            let first = first.read();
            let last = last.read();
            format!("{first} {last}")
        } else {
            first.get()
        })
    });

    view! {
        <h1>
            <code>"create_effect"</code>
            " Version"
        </h1>
        <form>
            <label>
                "First Name"
                <input
                    type="text"
                    name="first"
                    prop:value=first
                    on:change:target=move |ev| set_first.set(ev.target().value())
                />
            </label>
            <label>
                "Last Name"
                <input
                    type="text"
                    name="last"
                    prop:value=last
                    on:change:target=move |ev| set_last.set(ev.target().value())
                />
            </label>
            <label>
                "Show Last Name"
                <input
                    type="checkbox"
                    name="use_last"
                    prop:checked=use_last
                    on:change:target=move |ev| set_use_last.set(ev.target().checked())
                />
            </label>
        </form>
    }
}

#[component]
fn ManualVersion() -> impl IntoView {
    let first = NodeRef::<Input>::new();
    let last = NodeRef::<Input>::new();
    let use_last = NodeRef::<Input>::new();

    let mut prev_name = String::new();
    let on_change = move |_| {
        log("      listener");
        let first = first.get().unwrap();
        let last = last.get().unwrap();
        let use_last = use_last.get().unwrap();
        let this_one = if use_last.checked() {
            format!("{} {}", first.value(), last.value())
        } else {
            first.value()
        };

        if this_one != prev_name {
            log(&this_one);
            prev_name = this_one;
        }
    };

    view! {
        <h1>"Manual Version"</h1>
        <form on:change=on_change>
            <label>"First Name" <input type="text" name="first" node_ref=first/></label>
            <label>"Last Name" <input type="text" name="last" node_ref=last/></label>
            <label>
                "Show Last Name" <input type="checkbox" name="use_last" checked node_ref=use_last/>
            </label>
        </form>
    }
}

fn log(msg: impl std::fmt::Display) {
    let log = use_context::<LogContext>().unwrap().0;
    log.update(|log| log.push(msg.to_string()));
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>