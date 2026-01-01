# 父子组件通信

您可以将应用程序视为组件的嵌套树。每个组件处理自己的本地状态并管理用户界面的一个部分，因此组件往往相对自包含。

但有时，您会想要在父组件和其子组件之间进行通信。例如，想象您已经定义了一个 `<FancyButton/>` 组件，它为 `<button/>` 添加了一些样式、日志记录或其他功能。您想在 `<App/>` 组件中使用 `<FancyButton/>`。但您如何在两者之间进行通信呢？

从父组件向子组件传递状态很容易。我们在[组件和 props](./03_components.md) 的材料中涵盖了其中一些内容。基本上，如果您希望父组件与子组件通信，您可以将 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html) 或 [`Signal`](https://docs.rs/leptos/latest/leptos/reactive/wrappers/read/struct.Signal.html) 作为 prop 传递。

但另一个方向呢？子组件如何将事件或状态更改的通知发送回父组件？

在 Leptos 中有四种基本的父子通信模式。

## 1. 传递 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html)

一种方法是简单地将 `WriteSignal` 从父组件传递到子组件，并在子组件中更新它。这让您可以从子组件操作父组件的状态。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"Toggled? " {toggled}</p>
        <ButtonA setter=set_toggled/>
    }
}

#[component]
pub fn ButtonA(setter: WriteSignal<bool>) -> impl IntoView {
    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle"
        </button>
    }
}
```

这种模式很简单，但您应该小心使用它：传递 `WriteSignal` 可能会使您的代码难以推理。在这个示例中，当您阅读 `<App/>` 时，很清楚您正在交出改变 `toggled` 的能力，但完全不清楚它何时或如何改变。在这个小的、本地的示例中很容易理解，但如果您发现自己在整个代码中传递这样的 `WriteSignal`，您应该真正考虑这是否使编写意大利面条代码变得太容易了。

## 2. 使用回调

另一种方法是将回调传递给子组件：比如 `on_click`。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"Toggled? " {toggled}</p>
        <ButtonB on_click=move |_| set_toggled.update(|value| *value = !*value)/>
    }
}

#[component]
pub fn ButtonB(on_click: impl FnMut(MouseEvent) + 'static) -> impl IntoView {
    view! {
        <button on:click=on_click>
            "Toggle"
        </button>
    }
}
```

您会注意到，`<ButtonA/>` 被给予了一个 `WriteSignal` 并决定如何改变它，而 `<ButtonB/>` 只是触发一个事件：改变发生在 `<App/>` 中。这有保持本地状态本地化的优势，防止了意大利面条式改变的问题。但这也意味着改变该 signal 的逻辑需要存在于 `<App/>` 中，而不是在 `<ButtonB/>` 中。这些是真正的权衡，不是简单的对错选择。

## 3. 使用事件监听器

您实际上可以用稍微不同的方式编写选项 2。如果回调直接映射到原生 DOM 事件，您可以直接在 `<App/>` 中的 `view` 宏中使用组件的地方添加 `on:` 监听器。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"Toggled? " {toggled}</p>
        // 注意 on:click 而不是 on_click
        // 这与 HTML 元素事件监听器的语法相同
        <ButtonC on:click=move |_| set_toggled.update(|value| *value = !*value)/>
    }
}

#[component]
pub fn ButtonC() -> impl IntoView {
    view! {
        <button>"Toggle"</button>
    }
}
```

这让您在 `<ButtonC/>` 中编写的代码比在 `<ButtonB/>` 中少得多，并且仍然为监听器提供正确类型的事件。这通过向 `<ButtonC/>` 返回的每个元素添加 `on:` 事件监听器来工作：在这种情况下，只是一个 `<button>`。

当然，这只适用于您直接传递给在组件中渲染的元素的实际 DOM 事件。对于不直接映射到元素的更复杂逻辑（比如您创建 `<ValidatedForm/>` 并想要 `on_valid_form_submit` 回调），您应该使用选项 2。

## 4. 提供 Context

这个版本实际上是选项 1 的变体。假设您有一个深度嵌套的组件树：

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"Toggled? " {toggled}</p>
        <Layout/>
    }
}

#[component]
pub fn Layout() -> impl IntoView {
    view! {
        <header>
            <h1>"My Page"</h1>
        </header>
        <main>
            <Content/>
        </main>
    }
}

#[component]
pub fn Content() -> impl IntoView {
    view! {
        <div class="content">
            <ButtonD/>
        </div>
    }
}

#[component]
pub fn ButtonD() -> impl IntoView {
    todo!()
}

```

现在 `<ButtonD/>` 不再是 `<App/>` 的直接子组件，所以您不能简单地将 `WriteSignal` 传递给它的 props。您可以做有时称为"prop drilling"的事情，向两者之间的每一层添加 prop：

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"Toggled? " {toggled}</p>
        <Layout set_toggled/>
    }
}

#[component]
pub fn Layout(set_toggled: WriteSignal<bool>) -> impl IntoView {
    view! {
        <header>
            <h1>"My Page"</h1>
        </header>
        <main>
            <Content set_toggled/>
        </main>
    }
}

#[component]
pub fn Content(set_toggled: WriteSignal<bool>) -> impl IntoView {
    view! {
        <div class="content">
            <ButtonD set_toggled/>
        </div>
    }
}

#[component]
pub fn ButtonD(set_toggled: WriteSignal<bool>) -> impl IntoView {
    todo!()
}
```

这是一团糟。`<Layout/>` 和 `<Content/>` 不需要 `set_toggled`；它们只是将其传递给 `<ButtonD/>`。但我需要三次声明 prop。这不仅烦人而且难以维护：想象我们添加一个"半切换"选项，`set_toggled` 的类型需要更改为 `enum`。我们必须在三个地方更改它！

难道没有某种方法可以跳过层级吗？

有的！

### 4.1 Context API

您可以使用 [`provide_context`](https://docs.rs/leptos/latest/leptos/context/fn.provide_context.html) 和 [`use_context`](https://docs.rs/leptos/latest/leptos/context/fn.use_context.html) 提供跳过层级的数据。Contexts 由您提供的数据类型标识（在这个示例中是 `WriteSignal<bool>`），它们存在于遵循 UI 树轮廓的自顶向下树中。在这个示例中，我们可以使用 context 来跳过不必要的 prop drilling。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);

    // 与此组件的所有子组件共享 `set_toggled`
    provide_context(set_toggled);

    view! {
        <p>"Toggled? " {toggled}</p>
        <Layout/>
    }
}

// <Layout/> 和 <Content/> 省略
// 要在此版本中工作，请删除每个上的 `set_toggled` 参数

#[component]
pub fn ButtonD() -> impl IntoView {
    // use_context 在 context 树中向上搜索，希望找到 `WriteSignal<bool>`
    // 在这种情况下，我使用 .expect() 因为我知道我提供了它
    let setter = use_context::<WriteSignal<bool>>().expect("to have found the setter provided");

    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle"
        </button>
    }
}

```

与 `<ButtonA/>` 相同的注意事项适用于此：传递 `WriteSignal` 应该谨慎进行，因为它允许您从代码的任意部分改变状态。但当谨慎进行时，这可能是 Leptos 中全局状态管理最有效的技术之一：简单地在您需要它的最高级别提供状态，并在您需要它的较低级别使用它。

注意这种方法没有性能缺点。因为您传递的是细粒度响应式 signal，当您更新它时，中间组件（`<Layout/>` 和 `<Content/>`）中_什么都不会发生_。您直接在 `<ButtonD/>` 和 `<App/>` 之间通信。实际上——这就是细粒度响应性的力量——您直接在 `<ButtonD/>` 中的按钮点击和 `<App/>` 中的单个文本节点之间通信。就好像组件本身根本不存在一样。嗯，实际上...在运行时，它们不存在。一直都是 signals 和 effects。

注意这种方法做出了重要的权衡：您在 `provide_context` 和 `use_context` 之间不再有类型安全。在子组件中接收正确的 context 是运行时检查（参见 `use_context.expect(...)`）。编译器不会在重构期间指导您，就像早期方法那样。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/8-parent-child-0-7-cgcgk9?file=%2Fsrc%2Fmain.rs%3A1%2C1-116%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/8-parent-child-0-7-cgcgk9?file=%2Fsrc%2Fmain.rs%3A1%2C1-116%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::{ev::MouseEvent, prelude::*};

// 这突出了子组件与其父组件通信的四种不同方式：
// 1) <ButtonA/>：将 WriteSignal 作为子组件 props 之一传递，
//    供子组件写入，父组件读取
// 2) <ButtonB/>：将闭包作为子组件 props 之一传递，
//    供子组件调用
// 3) <ButtonC/>：向组件添加 `on:` 事件监听器
// 4) <ButtonD/>：提供在组件中使用的 context（而不是 prop drilling）

#[derive(Copy, Clone)]
struct SmallcapsContext(WriteSignal<bool>);

#[component]
pub fn App() -> impl IntoView {
    // 只是一些 signals 来切换我们 <p> 上的四个类
    let (red, set_red) = signal(false);
    let (right, set_right) = signal(false);
    let (italics, set_italics) = signal(false);
    let (smallcaps, set_smallcaps) = signal(false);

    // newtype 模式在这里不是*必需的*，但是一个好的实践
    // 它避免了与其他可能的未来 `WriteSignal<bool>` contexts 的混淆
    // 并使在 ButtonD 中引用它变得更容易
    provide_context(SmallcapsContext(set_smallcaps));

    view! {
        <main>
            <p
                // class: 属性接受 F: Fn() => bool，这些 signals 都实现了 Fn()
                class:red=red
                class:right=right
                class:italics=italics
                class:smallcaps=smallcaps
            >
                "Lorem ipsum sit dolor amet."
            </p>

            // Button A：传递 signal setter
            <ButtonA setter=set_red/>

            // Button B：传递闭包
            <ButtonB on_click=move |_| set_right.update(|value| *value = !*value)/>

            // Button C：使用常规事件监听器
            // 在这样的组件上设置事件监听器将其应用于
            // 组件返回的每个顶级元素
            <ButtonC on:click=move |_| set_italics.update(|value| *value = !*value)/>

            // Button D 从 context 而不是 props 获取其 setter
            <ButtonD/>
        </main>
    }
}

/// Button A 接收 signal setter 并自己更新 signal
#[component]
pub fn ButtonA(
    /// 点击按钮时将被切换的 Signal。
    setter: WriteSignal<bool>,
) -> impl IntoView {
    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle Red"
        </button>
    }
}

/// Button B 接收闭包
#[component]
pub fn ButtonB(
    /// 点击按钮时将被调用的回调。
    on_click: impl FnMut(MouseEvent) + 'static,
) -> impl IntoView
{
    view! {
        <button
            on:click=on_click
        >
            "Toggle Right"
        </button>
    }
}

/// Button C 是一个虚拟组件：它渲染一个按钮但不处理
/// 其点击。相反，父组件添加事件监听器。
#[component]
pub fn ButtonC() -> impl IntoView {
    view! {
        <button>
            "Toggle Italics"
        </button>
    }
}

/// Button D 与 Button A 非常相似，但不是将 setter 作为 prop 传递
/// 我们从 context 获取它
#[component]
pub fn ButtonD() -> impl IntoView {
    let setter = use_context::<SmallcapsContext>().unwrap().0;

    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle Small Caps"
        </button>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>