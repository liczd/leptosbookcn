# 组件和 Props

到目前为止，我们一直在单个组件中构建整个应用程序。这对于非常小的示例来说是可以的，但在任何真实的应用程序中，您需要将用户界面分解为多个组件，这样您就可以将界面分解为更小的、可重用的、可组合的块。

让我们以进度条示例为例。想象一下您想要两个进度条而不是一个：一个每次点击前进一个刻度，一个每次点击前进两个刻度。

您_可以_通过创建两个 `<progress>` 元素来做到这一点：

```rust
let (count, set_count) = signal(0);
let double_count = move || count.get() * 2;

view! {
    <progress
        max="50"
        value=count
    />
    <progress
        max="50"
        value=double_count
    />
}
```

但当然，这不能很好地扩展。如果您想添加第三个进度条，您需要再次添加此代码。如果您想编辑任何相关内容，您需要三次编辑它。

相反，让我们创建一个 `<ProgressBar/>` 组件。

```rust
#[component]
fn ProgressBar() -> impl IntoView {
    view! {
        <progress
            max="50"
            // 嗯...我们从哪里得到这个？
            value=progress
        />
    }
}
```

只有一个问题：`progress` 没有定义。它应该从哪里来？当我们手动定义所有内容时，我们只是使用了本地变量名。现在我们需要某种方法将参数传递到组件中。

## 组件 Props

我们使用组件属性或"props"来做到这一点。如果您使用过其他前端框架，这可能是一个熟悉的概念。基本上，属性对于组件就像属性对于 HTML 元素一样：它们让您将附加信息传递到组件中。

在 Leptos 中，您通过为组件函数提供附加参数来定义 props。

```rust
#[component]
fn ProgressBar(
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max="50"
            // 现在这可以工作了
            value=progress
        />
    }
}
```

现在我们可以在主 `<App/>` 组件的视图中使用我们的组件。

```rust
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    view! {
        <button on:click=move |_| *set_count.write() += 1>
            "Click me"
        </button>
        // 现在我们使用我们的组件！
        <ProgressBar progress=count/>
    }
}
```

在视图中使用组件看起来很像使用 HTML 元素。您会注意到您可以轻松区分元素和组件，因为组件总是有 `PascalCase` 名称。您将 `progress` prop 传入，就像它是 HTML 元素属性一样。简单。

### 响应式和静态 Props

您会注意到在整个示例中，`progress` 接受响应式 `ReadSignal<i32>`，而不是普通的 `i32`。这**非常重要**。

组件 props 没有附加特殊含义。组件只是运行一次以设置用户界面的函数。告诉界面响应更改的唯一方法是传递 signal 类型。所以如果您有一个会随时间变化的组件属性，比如我们的 `progress`，它应该是一个 signal。

### `optional` Props

现在 `max` 设置是硬编码的。让我们也将其作为 prop。但让我们使这个 prop 可选。我们可以通过用 `#[prop(optional)]` 注释它来做到这一点。

```rust
#[component]
fn ProgressBar(
    // 将此 prop 标记为可选
    // 您可以在使用 <ProgressBar/> 时指定它或不指定
    #[prop(optional)]
    max: u16,
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
    }
}
```

现在，我们可以使用 `<ProgressBar max=50 progress=count/>`，或者我们可以省略 `max` 来使用默认值（即 `<ProgressBar progress=count/>`）。`optional` 的默认值是其 `Default::default()` 值，对于 `u16` 来说是 `0`。在进度条的情况下，最大值为 `0` 不是很有用。

所以让我们给它一个特定的默认值。

### `default` props

您可以使用 `#[prop(default = ...)]` 相当简单地指定除 `Default::default()` 之外的默认值。

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
    }
}
```

### 泛型 Props

这很好。但我们开始时有两个计数器，一个由 `count` 驱动，一个由派生 signal `double_count` 驱动。让我们通过在另一个 `<ProgressBar/>` 上使用 `double_count` 作为 `progress` prop 来重新创建它。

```rust,compile_fail
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    let double_count = move || count.get() * 2;

    view! {
        <button on:click=move |_| { set_count.update(|n| *n += 1); }>
            "Click me"
        </button>
        <ProgressBar progress=count/>
        // 添加第二个进度条
        <ProgressBar progress=double_count/>
    }
}
```

嗯...这不会编译。应该很容易理解为什么：我们已经声明 `progress` prop 接受 `ReadSignal<i32>`，而 `double_count` 不是 `ReadSignal<i32>`。正如 rust-analyzer 会告诉您的，它的类型是 `|| -> i32`，即它是一个返回 `i32` 的闭包。

有几种方法来处理这个问题。一种是说："好吧，我知道为了让视图是响应式的，它需要接受一个函数或一个 signal。我总是可以通过将 signal 包装在闭包中来将 signal 转换为函数...也许我可以只接受任何函数？"

如果您使用带有 `nightly` 功能的 nightly Rust，signals 是函数，所以您可以使用泛型组件并接受任何 `Fn() -> i32`：

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    progress: impl Fn() -> i32 + Send + Sync + 'static
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
        // 添加换行符以避免重叠
        <br/>
    }
}
```

> 泛型 props 也可以使用 `where` 子句指定，或使用内联泛型如 `ProgressBar<F: Fn() -> i32 + 'static>`。

泛型需要在组件 props 中的某个地方使用。这是因为 props 被构建到结构体中，所以所有泛型类型都必须在结构体中的某个地方使用。这通常通过使用可选的 `PhantomData` prop 轻松实现。然后您可以使用表达类型的语法在视图中指定泛型：`<Component<T>/>`（不是 turbofish 风格的 `<Component::<T>/>`）。

```rust
#[component]
fn SizeOf<T: Sized>(#[prop(optional)] _ty: PhantomData<T>) -> impl IntoView {
    std::mem::size_of::<T>()
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <SizeOf<usize>/>
        <SizeOf<String>/>
    }
}
```

> 注意有一些限制。例如，我们的视图宏解析器无法处理嵌套泛型如 `<SizeOf<Vec<T>>/>`。

### `into` Props

如果您使用稳定版 Rust，signals 不直接实现 `Fn()`。我们可以将 signal 包装在闭包中（`move || progress.get()`），但这有点混乱。

我们可以实现这个的另一种方法是使用 `#[prop(into)]`。此属性自动在您作为 props 传递的值上调用 `.into()`，这允许您轻松传递具有不同值的 props。

在这种情况下，了解 [`Signal`](https://docs.rs/leptos/latest/leptos/reactive/wrappers/read/struct.Signal.html) 类型很有帮助。`Signal` 是一个枚举类型，表示任何类型的可读响应式 signal 或普通值。在定义您想要重用的组件 API 时，它可能很有用，同时传递不同类型的 signals。

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    #[prop(into)]
    progress: Signal<i32>
) -> impl IntoView
{
    view! {
        <progress
            max=max
            value=progress
        />
        <br/>
    }
}

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    let double_count = move || count.get() * 2;

    view! {
        <button on:click=move |_| *set_count.write() += 1>
            "Click me"
        </button>
        // .into() 将 `ReadSignal` 转换为 `Signal`
        <ProgressBar progress=count/>
        // 使用 `Signal::derive()` 将派生 signal 包装为 `Signal` 类型
        <ProgressBar progress=Signal::derive(double_count)/>
    }
}
```

### 可选泛型 Props

注意您不能为组件指定可选泛型 props。让我们看看如果您尝试会发生什么：

```rust,compile_fail
#[component]
fn ProgressBar<F: Fn() -> i32 + Send + Sync + 'static>(
    #[prop(optional)] progress: Option<F>,
) -> impl IntoView {
    progress.map(|progress| {
        view! {
            <progress
                max=100
                value=progress
            />
            <br/>
        }
    })
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <ProgressBar/>
    }
}
```

Rust 有用地给出错误

```
xx |         <ProgressBar/>
   |          ^^^^^^^^^^^ cannot infer type of the type parameter `F` declared on the function `ProgressBar`
   |
help: consider specifying the generic argument
   |
xx |         <ProgressBar::<F>/>
   |                     +++++
```

您可以使用 `<ProgressBar<F>/>` 语法在组件上指定泛型（在 `view` 宏中没有 turbofish）。在这里指定正确的类型是不可能的；闭包和函数通常是不可命名的类型。编译器可以用简写显示它们，但您无法指定它们。

但是，您可以通过使用 `Box<dyn _>` 或 `&dyn _` 提供具体类型来解决这个问题：

```rust
#[component]
fn ProgressBar(
    #[prop(optional)] progress: Option<Box<dyn Fn() -> i32 + Send + Sync>>,
) -> impl IntoView {
    progress.map(|progress| {
        view! {
            <progress
                max=100
                value=progress
            />
            <br/>
        }
    })
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <ProgressBar/>
    }
}
```

因为 Rust 编译器现在知道 prop 的具体类型，因此即使在 `None` 情况下也知道其在内存中的大小，这编译得很好。

> 在这种特殊情况下，`&dyn Fn() -> i32` 会导致生命周期问题，但在其他情况下，它可能是一种可能性。

## 记录组件

这是本书中最不重要但最重要的部分之一。严格来说，记录您的组件及其 props 并不是必需的。根据您的团队和应用程序的大小，这可能非常重要。但这很容易，并且立即产生效果。

要记录组件及其 props，您可以简单地在组件函数和每个 props 上添加文档注释：

```rust
/// 显示朝向目标的进度。
#[component]
fn ProgressBar(
    /// 进度条的最大值。
    #[prop(default = 100)]
    max: u16,
    /// 应该显示多少进度。
    #[prop(into)]
    progress: Signal<i32>,
) -> impl IntoView {
    /* ... */
}
```

这就是您需要做的全部。这些行为像普通的 Rust 文档注释，除了您可以记录单个组件 props，这在 Rust 函数参数中是做不到的。

这将自动为您的组件、其 `Props` 类型和用于添加 props 的每个字段生成文档。在您悬停在组件名称或 props 上并看到 `#[component]` 宏与 rust-analyzer 结合的强大功能之前，可能有点难以理解这有多强大。

## 将属性展开到组件上

有时您希望用户能够向组件添加附加属性。例如，您可能希望用户能够为样式或其他目的添加自己的 `class` 或 `id` 属性。

您_可以_通过创建 `class` 或 `id` props 然后将它们应用到适当的元素来做到这一点。但 Leptos 也支持将附加属性"展开"到组件上。添加到组件的属性将应用于从其视图返回的所有顶级 HTML 元素。

```rust
// 您可以通过使用视图宏和展开 {..} 作为标签名来创建属性列表
let spread_onto_component = view! {
    <{..} aria-label="a component with attribute spreading"/>
};


view! {
    // 展开到组件上的属性将应用于作为
    // 组件视图一部分返回的*所有*元素。要将属性应用于组件的子集，请通过组件 prop 传递它们
    <ComponentThatTakesSpread
        // 普通标识符用于 props
        some_prop="foo"
        another_prop=42

        // class:, style:, prop:, on: 语法就像在元素上一样工作
        class:foo=true
        style:font-weight="bold"
        prop:cool=42
        on:click=move |_| alert("clicked ComponentThatTakesSpread")

        // 要传递普通 HTML 属性，请用 attr: 前缀
        attr:id="foo"

        // 或者，如果您想包含多个属性，而不是用 attr: 前缀每个属性，
        // 您可以用展开 {..} 将它们与组件 props 分开
        {..} // 此后的所有内容都被视为 HTML 属性
        title="ooh, a title!"

        // 我们可以添加上面定义的整个属性列表
        {..spread_onto_component}
    />
}
```

``````admonish note
如果您想将属性提取到函数中以便在多个组件中使用，您可以通过实现返回 `impl Attribute` 的函数来做到这一点。

这将使上面的示例看起来像这样：

```rust
fn spread_onto_component() -> impl Attribute {
    view!{
        <{..} aria-label="a component with attribute spreading"/>
    }
}

view!{
    <SomeComponent {..spread_onto_component()} />
}
```
``````

如果您想将属性展开到组件上，但想将属性应用于除所有顶级元素之外的其他内容，请使用 [`AttributeInterceptor`](https://docs.rs/leptos/latest/leptos/attribute_interceptor/fn.AttributeInterceptor.html)。

有关更多示例，请参阅 [`spread` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/spread/src/lib.rs)。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/3-components-0-7-rkjn3j?file=%2Fsrc%2Fmain.rs%3A39%2C10)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/3-components-0-7-rkjn3j?file=%2Fsrc%2Fmain.rs%3A39%2C10" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

// 将不同的组件组合在一起是我们构建
// 用户界面的方式。在这里，我们将定义一个可重用的 <ProgressBar/>。
// 您将看到如何使用文档注释来记录组件
// 及其属性。

/// 显示朝向目标的进度。
#[component]
fn ProgressBar(
    // 将此标记为可选 prop。它将默认为其类型的默认值，即 0。
    #[prop(default = 100)]
    /// 进度条的最大值。
    max: u16,
    // 将在传递给 prop 的值上运行 `.into()`。
    #[prop(into)]
    // `Signal<T>` 是几种响应式类型的包装器。
    // 它在像这样的组件 API 中很有用，我们
    // 可能想要接受任何类型的响应式值
    /// 应该显示多少进度。
    progress: Signal<i32>,
) -> impl IntoView {
    view! {
        <progress
            max={max}
            value=progress
        />
        <br/>
    }
}

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    let double_count = move || count.get() * 2;

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
        >
            "Click me"
        </button>
        <br/>
        // 如果您在 CodeSandbox 或支持 rust-analyzer 的编辑器中打开此文件，
        // 尝试悬停在 `ProgressBar`、`max` 或 `progress` 上
        // 以查看我们上面定义的文档
        <ProgressBar max=50 progress=count/>
        // 让我们在这个上使用默认的最大值
        // 默认值是 100，所以它应该移动得慢一半
        <ProgressBar progress=count/>
        // Signal::derive 从我们的派生 signal 创建 Signal 包装器
        // 使用 double_count 意味着它应该移动得快两倍
        <ProgressBar max=50 progress=Signal::derive(double_count)/>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>