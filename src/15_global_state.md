# 全局状态管理

到目前为止，我们只在组件中使用本地状态，并且已经了解了如何在父子组件之间协调状态。有时，人们会寻找一个更通用的全局状态管理解决方案，可以在整个应用程序中使用。

一般来说，**您不需要这一章**。典型的模式是将应用程序组合成组件，每个组件管理自己的本地状态，而不是将所有状态存储在全局结构中。但是，在某些情况下（如主题设置、保存用户设置或在 UI 不同部分的组件之间共享数据），您可能希望使用某种全局状态管理。

全局状态的三种最佳方法是：

1. 使用路由器通过 URL 驱动全局状态
2. 通过 context 传递 signals
3. 使用 stores 创建全局状态结构

## 选项 #1：URL 作为全局状态

在许多方面，URL 实际上是存储全局状态的最佳方式。它可以从树中任何地方的任何组件访问。有像 `<form>` 和 `<a>` 这样的原生 HTML 元素专门用于更新 URL。它在页面重新加载和设备之间持久存在；您可以与朋友分享 URL 或从手机发送到笔记本电脑，存储在其中的任何状态都会被复制。

教程的接下来几个部分将介绍路由器，我们将更深入地讨论这些主题。

但现在，我们只看选项 #2 和 #3。

## 选项 #2：通过 Context 传递 Signals

在[父子通信](view/08_parent_child.md)部分，我们看到您可以使用 `provide_context` 将 signal 从父组件传递给子组件，并使用 `use_context` 在子组件中读取它。但 `provide_context` 可以跨任何距离工作。如果您想创建一个保存某些状态的全局 signal，您可以提供它并通过 context 在提供它的组件的任何后代中访问它。

通过 context 提供的 signal 只在读取它的地方引起响应式更新，而不是在中间的任何组件中，因此即使在远距离也保持了细粒度响应式更新的能力。

我们首先在应用程序的根部创建一个 signal，并使用 `provide_context` 将其提供给所有子组件和后代。

```rust
#[component]
fn App() -> impl IntoView {
    // 在这里我们在根部创建一个可以在应用程序任何地方
    // 消费的 signal
    let (count, set_count) = signal(0);
    // 我们将 setter 传递给特定组件，
    // 但通过 context 将 count 本身提供给整个应用程序
    provide_context(count);

    view! {
        // SetterButton 被允许修改 count
        <SetterButton set_count/>
        // 这些消费者只能从中读取
        // 但如果我们想要，我们可以通过传递 `set_count` 给它们写访问权限
        <FancyMath/>
        <ListItems/>
    }
}
```

`<SetterButton/>` 是我们已经写过几次的那种计数器。

`<FancyMath/>` 和 `<ListItems/>` 都通过 `use_context` 消费我们提供的 signal 并对其进行某些操作。

```rust
/// 一个对全局 count signal 进行一些"花哨"数学运算的组件
#[component]
fn FancyMath() -> impl IntoView {
    // 在这里我们使用 `use_context` 消费全局 count signal
    let count = use_context::<ReadSignal<u32>>()
        // 我们知道我们刚刚在父组件中提供了这个
        .expect("there to be a `count` signal provided");
    let is_even = move || count.get() & 1 == 0;

    view! {
        <div class="consumer blue">
            "The number "
            <strong>{count}</strong>
            {move || if is_even() {
                " is"
            } else {
                " is not"
            }}
            " even."
        </div>
    }
}
```

## 选项 #3：创建全局状态 Store

> 这部分内容与[这里](../view/04b_iteration.md#option-4-stores)关于使用 stores 进行复杂迭代的部分有重复。两个部分都是中级/可选内容，所以我认为一些重复不会有害。

Stores 是一个新的响应式原语，在 Leptos 0.7 中通过附带的 `reactive_stores` crate 提供。（这个 crate 现在单独发布，这样我们可以继续开发它而不需要对整个框架进行版本更改。）

Stores 允许您包装整个结构体，并响应式地读取和更新单个字段，而不跟踪对其他字段的更改。

它们通过在结构体上添加 `#[derive(Store)]` 来使用。（您可以 `use reactive_stores::Store;` 来导入宏。）这会创建一个扩展 trait，当结构体被包装在 `Store<_>` 中时，为结构体的每个字段提供一个 getter。

```rust
#[derive(Clone, Debug, Default, Store)]
struct GlobalState {
    count: i32,
    name: String,
}
```

这创建了一个名为 `GlobalStateStoreFields` 的 trait，它为 `Store<GlobalState>` 添加了 `count` 和 `name` 方法。每个方法返回一个响应式 store *字段*。

```rust
#[component]
fn App() -> impl IntoView {
    provide_context(Store::new(GlobalState::default()));

    // 等等...
}

/// 更新全局状态中 count 的组件
#[component]
fn GlobalStateCounter() -> impl IntoView {
    let state = expect_context::<Store<GlobalState>>();

    // 这只给我们对 `count` 字段的响应式访问
    let count = state.count();

    view! {
        <div class="consumer blue">
            <button
                on:click=move |_| {
                    *count.write() += 1;
                }
            >
                "Increment Global Count"
            </button>
            <br/>
            <span>"Count is: " {move || count.get()}</span>
        </div>
    }
}
```

点击这个按钮只更新 `state.count`。如果我们在其他地方读取 `state.name`，点击按钮不会通知它。这允许您结合自顶向下数据流和细粒度响应式更新的好处。

查看仓库中的 [`stores` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/stores/src/lib.rs) 以获得更广泛的示例。