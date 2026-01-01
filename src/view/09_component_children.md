# 组件子元素

将子元素传递到组件中是很常见的，就像您可以将子元素传递到 HTML 元素中一样。例如，想象我有一个增强 HTML `<form>` 的 `<FancyForm/>` 组件。我需要某种方法来传递所有的输入。

```rust
view! {
    <FancyForm>
        <fieldset>
            <label>
                "Some Input"
                <input type="text" name="something"/>
            </label>
        </fieldset>
        <button>"Submit"</button>
    </FancyForm>
}
```

在 Leptos 中如何做到这一点？基本上有两种方法将组件传递给其他组件：

1. **render props**：返回视图的函数属性
2. **`children`** prop：一个特殊的组件属性，包括您作为子元素传递给组件的任何内容。

实际上，您已经在 [`<Show/>`](/view/06_control_flow.html#show) 组件中看到了这两种方法的实际应用：

```rust
view! {
  <Show
    // `when` 是一个普通 prop
    when=move || value.get() > 5
    // `fallback` 是一个 "render prop"：返回视图的函数
    fallback=|| view! { <Small/> }
  >
    // `<Big/>` （以及这里的任何其他内容）
    // 将被给予 `children` prop
    <Big/>
  </Show>
}
```

让我们定义一个接受一些子元素和 render prop 的组件。

```rust
/// 在标记内显示 `render_prop` 和一些子元素。
#[component]
pub fn TakesChildren<F, IV>(
    /// 接受一个函数（类型 F），返回任何可以转换为 View 的内容（类型 IV）
    render_prop: F,
    /// `children` 可以接受几种不同的类型，每种都是返回某种视图类型的函数
    children: Children,
) -> impl IntoView
where
    F: Fn() -> IV,
    IV: IntoView,
{
    view! {
        <h1><code>"<TakesChildren/>"</code></h1>
        <h2>"Render Prop"</h2>
        {render_prop()}
        <hr/>
        <h2>"Children"</h2>
        {children()}
    }
}
```

`render_prop` 和 `children` 都是函数，所以我们可以调用它们来生成适当的视图。特别是 `children` 是 `Box<dyn FnOnce() -> AnyView>` 的别名。（您不是很高兴我们将其命名为 `Children` 而不是这个吗？）这里返回的 `AnyView` 是一个不透明的、类型擦除的视图：您无法检查它。还有各种其他子元素类型：例如，`ChildrenFragment` 将返回一个 `Fragment`，这是一个可以迭代其子元素的集合。

> 如果您在这里需要 `Fn` 或 `FnMut`，因为您需要多次调用 `children`，我们还提供了 `ChildrenFn` 和 `ChildrenMut` 别名。

我们可以这样使用组件：

```rust
view! {
    <TakesChildren render_prop=|| view! { <p>"Hi, there!"</p> }>
        // 这些被传递给 `children`
        "Some text"
        <span>"A span"</span>
    </TakesChildren>
}
```

## 类型化子元素：Slots

到目前为止，我们讨论了具有单个 `children` prop 的组件，但有时创建具有不同类型的多个子元素的组件很有用。例如：
```rust
view! {
    <If condition=a_is_true>
        <Then>"Show content when a is true"</Then>
        <ElseIf condition=b_is_true>"b is true"</ElseIf>
        <ElseIf condition=c_is_true>"c is true"</ElseIf>
        <Else>"None of the above are true"</Else>
    </If>
}
```
`If` 组件总是期望一个 `Then` 子元素，可选的多个 `ElseIf` 子元素和一个可选的 `Else` 子元素。为了处理这个，Leptos 提供了 [slot](https://docs.rs/leptos/latest/leptos/attr.slot.html)。

`#[slot]` 宏将普通的 Rust 结构体注释为组件 slot：
```rust
// 用 `#[slot]` 注释的简单结构体，
// 期望子元素
#[slot]
struct Then {
    children: ChildrenFn,
}
```

这个 slot 可以用作组件中的 prop：
```rust
#[component]
fn If(
    condition: Signal<bool>,
    // 组件 slot，应该通过 <Then slot> 语法传递
    then_slot: Then,
) -> impl IntoView {
    move || {
        if condition.get() {
            (then_slot.children)().into_any()
        } else {
            ().into_any()
        }
    }
}
```

现在，`If` 组件期望一个 `Then` 类型的子元素。您需要用 `slot:<prop_name>` 注释使用的 slot：
```rust
view! {
    <If condition=a_is_true>
        // `If` 组件总是期望 `then_slot` 的 `Then` 子元素
        <Then slot:then_slot>"Show content when a is true"</Then>
    </If>
}
```

> 指定不带名称的 `slot` 将默认选择的 slot 为结构体名称的蛇形命名版本。所以在这种情况下 `<Then slot>` 等同于 `<Then slot:then>`。

有关完整示例，请参阅 [slots 示例](https://github.com/leptos-rs/leptos/tree/main/examples/slots)。

### Slots 上的事件处理程序

事件处理程序不能直接在 slots 上指定，如下所示：
```rust
<ComponentWithSlot>
    // ⚠️ 直接在 slot 上的事件处理程序 `on:click` 是不允许的
    <SlotWithChildren slot:slot on:click=move |_| {}> 
        <h1>"Hello, World!"</h1>
    </SlotWithChildren>
</ComponentWithSlot>
```

相反，将 slot 内容包装在常规元素中并在那里附加事件处理程序：
```rust
<ComponentWithSlot>
    <SlotWithChildren slot:slot>
        // ✅ 事件处理程序不是直接在 slot 上定义的
        <div on:click=move |_| {}>
            <h1>"Hello, World!"</h1>
        </div>
    </SlotWithChildren>
</ComponentWithSlot>
```

## 操作子元素

[`Fragment`](https://docs.rs/leptos/latest/leptos/tachys/view/fragment/struct.Fragment.html) 类型基本上是包装 `Vec<AnyView>` 的方法。您可以将其插入到视图中的任何地方。

但您也可以直接访问这些内部视图来操作它们。例如，这是一个接受其子元素并将它们转换为无序列表的组件。

```rust
/// 将每个子元素包装在 `<li>` 中并将它们嵌入到 `<ul>` 中。
#[component]
pub fn WrapsChildren(children: ChildrenFragment) -> impl IntoView {
    // children() 返回一个 `Fragment`，它有一个
    // `nodes` 字段，包含 Vec<View>
    // 这意味着我们可以迭代子元素
    // 来创建新的东西！
    let children = children()
        .nodes
        .into_iter()
        .map(|child| view! { <li>{child}</li> })
        .collect::<Vec<_>>();

    view! {
        <h1><code>"<WrapsChildren/>"</code></h1>
        // 将我们包装的子元素包装在 UL 中
        <ul>{children}</ul>
    }
}
```

像这样调用它将创建一个列表：

```rust
view! {
    <WrapsChildren>
        "A"
        "B"
        "C"
    </WrapsChildren>
}
```

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/9-component-children-0-7-736s9r?file=%2Fsrc%2Fmain.rs%3A1%2C1-90%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/9-component-children-0-7-736s9r?file=%2Fsrc%2Fmain.rs%3A1%2C1-90%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

// 通常，您想要将某种子视图传递给另一个组件。
// 有两种基本模式来做到这一点：
// - "render props"：创建一个接受创建视图的函数的组件 prop
// - `children` prop：一个特殊属性，包含作为组件子元素传递的内容
//   在您的视图中，而不是作为属性

#[component]
pub fn App() -> impl IntoView {
    let (items, set_items) = signal(vec![0, 1, 2]);
    let render_prop = move || {
        let len = move || items.read().len();
        view! {
            <p>"Length: " {len}</p>
        }
    };

    view! {
        // 这个组件只是显示两种类型的子元素，
        // 将它们嵌入到其他一些标记中
        <TakesChildren
            // 对于组件 props，您可以简写
            // `render_prop=render_prop` => `render_prop`
            // （这对 HTML 元素属性不起作用）
            render_prop
        >
            // 这些看起来就像 HTML 元素的子元素
            <p>"Here's a child."</p>
            <p>"Here's another child."</p>
        </TakesChildren>
        <hr/>
        // 这个组件实际上迭代并包装子元素
        <WrapsChildren>
            <p>"Here's a child."</p>
            <p>"Here's another child."</p>
        </WrapsChildren>
    }
}

/// 在标记内显示 `render_prop` 和一些子元素。
#[component]
pub fn TakesChildren<F, IV>(
    /// 接受一个函数（类型 F），返回任何可以转换为 View 的内容（类型 IV）
    render_prop: F,
    /// `children` 接受 `Children` 类型
    /// 这是 `Box<dyn FnOnce() -> Fragment>` 的别名
    /// ... 您不是很高兴我们将其命名为 `Children` 而不是这个吗？
    children: Children,
) -> impl IntoView
where
    F: Fn() -> IV,
    IV: IntoView,
{
    view! {
        <h1><code>"<TakesChildren/>"</code></h1>
        <h2>"Render Prop"</h2>
        {render_prop()}
        <hr/>
        <h2>"Children"</h2>
        {children()}
    }
}

/// 将每个子元素包装在 `<li>` 中并将它们嵌入到 `<ul>` 中。
#[component]
pub fn WrapsChildren(children: ChildrenFragment) -> impl IntoView {
    // children() 返回一个 `Fragment`，它有一个
    // `nodes` 字段，包含 Vec<View>
    // 这意味着我们可以迭代子元素
    // 来创建新的东西！
    let children = children()
        .nodes
        .into_iter()
        .map(|child| view! { <li>{child}</li> })
        .collect::<Vec<_>>();

    view! {
        <h1><code>"<WrapsChildren/>"</code></h1>
        // 将我们包装的子元素包装在 UL 中
        <ul>{children}</ul>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>