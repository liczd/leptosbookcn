# 迭代

无论您是列出待办事项、显示表格还是展示产品图片，遍历项目列表都是 Web 应用程序中的常见任务。协调不断变化的项目集合之间的差异也可能是框架处理好的最棘手的任务之一。

Leptos 支持两种不同的迭代项目模式：

1. 对于静态视图：`Vec<_>`
2. 对于动态列表：`<For/>`

## 使用 `Vec<_>` 的静态视图

有时您需要重复显示一个项目，但您绘制的列表不经常更改。在这种情况下，重要的是要知道您可以将任何 `Vec<IV> where IV: IntoView` 插入到您的视图中。换句话说，如果您可以渲染 `T`，您就可以渲染 `Vec<T>`。

```rust
let values = vec![0, 1, 2];
view! {
    // 这将只渲染 "012"
    <p>{values.clone()}</p>
    // 或者我们可以将它们包装在 <li> 中
    <ul>
        {values.into_iter()
            .map(|n| view! { <li>{n}</li>})
            .collect::<Vec<_>>()}
    </ul>
}
```

Leptos 还提供了一个 `.collect_view()` 辅助函数，允许您将任何 `T: IntoView` 的迭代器收集到 `Vec<View>` 中。

```rust
let values = vec![0, 1, 2];
view! {
    // 这将只渲染 "012"
    <p>{values.clone()}</p>
    // 或者我们可以将它们包装在 <li> 中
    <ul>
        {values.into_iter()
            .map(|n| view! { <li>{n}</li>})
            .collect_view()}
    </ul>
}
```

_列表_是静态的这一事实并不意味着界面需要是静态的。您可以将动态项目作为静态列表的一部分渲染。

```rust
// 创建 5 个 signals 的列表
let length = 5;
let counters = (1..=length).map(|idx| RwSignal::new(idx));
```

注意这里我们没有调用 `signal()` 来获得带有 reader 和 writer 的元组，而是使用 `RwSignal::new()` 来获得单个读写 signal。这对于我们否则会传递元组的情况更方便。

```rust
// 每个项目管理一个响应式视图
// 但列表本身永远不会改变
let counter_buttons = counters
    .map(|count| {
        view! {
            <li>
                <button
                    on:click=move |_| *count.write() += 1
                >
                    {count}
                </button>
            </li>
        }
    })
    .collect_view();

view! {
    <ul>{counter_buttons}</ul>
}
```

您_也可以_响应式地渲染 `Fn() -> Vec<_>`。但请注意，这是一个无键列表更新：它将重用现有的 DOM 元素，并根据它们在新 `Vec<_>` 中的顺序用新值更新它们。如果您只是在列表末尾添加和删除项目，这工作得很好，但如果您移动项目或将项目插入列表中间，这将导致浏览器做比需要更多的工作，并且可能对输入状态和 CSS 动画等产生令人惊讶的影响。（有关"键控"与"无键"区别的更多信息，以及一些实际示例，您可以阅读[这篇文章](https://www.stefankrause.net/wp/?p=342)。）

幸运的是，也有一种高效的键控列表迭代方法。

## 使用 `<For/>` 组件的动态渲染

[`<For/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.For.html) 组件是一个键控动态列表。它接受三个 props：

- `each`：返回要迭代的项目 `T` 的响应式函数
- `key`：接受 `&T` 并返回稳定、唯一键或 ID 的键函数
- `children`：将每个 `T` 渲染为视图

`key` 是，嗯，关键。您可以在列表中添加、删除和移动项目。只要每个项目的键随时间稳定，框架就不需要重新渲染任何项目，除非它们是新添加的，并且它可以非常高效地添加、删除和移动项目。这允许对列表进行极其高效的更新，随着它的变化，额外的工作最少。

创建一个好的 `key` 可能有点棘手。您通常_不_想为此目的使用索引，因为它不稳定——如果您删除或移动项目，它们的索引会改变。

但是为每行生成唯一 ID 并将其用作键函数的 ID 是一个好主意。

查看下面的 `<DynamicList/>` 组件以获取示例。

```admonish sandbox title="Live example" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/4-iteration-0-7-dw4dfl?file=%2Fsrc%2Fmain.rs%3A1%2C1-159%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/4-iteration-0-7-dw4dfl?file=%2Fsrc%2Fmain.rs%3A1%2C1-159%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::prelude::*;

// 迭代是大多数应用程序中非常常见的任务。
// 那么如何获取数据列表并在 DOM 中渲染它？
// 这个示例将向您展示两种方法：
// 1) 对于大部分静态的列表，使用 Rust 迭代器
// 2) 对于增长、缩小或移动项目的列表，使用 <For/>

#[component]
fn App() -> impl IntoView {
    view! {
        <h1>"Iteration"</h1>
        <h2>"Static List"</h2>
        <p>"Use this pattern if the list itself is static."</p>
        <StaticList length=5/>
        <h2>"Dynamic List"</h2>
        <p>"Use this pattern if the rows in your list will change."</p>
        <DynamicList initial_length=5/>
    }
}

/// 计数器列表，没有添加或删除任何计数器的能力。
#[component]
fn StaticList(
    /// 此列表中包含多少个计数器。
    length: usize,
) -> impl IntoView {
    // 创建从递增数字开始的计数器 signals
    let counters = (1..=length).map(|idx| RwSignal::new(idx));

    // 当您有一个不变的列表时，您可以
    // 使用普通的 Rust 迭代器操作它
    // 并将其收集到 Vec<_> 中以插入到 DOM 中
    let counter_buttons = counters
        .map(|count| {
            view! {
                <li>
                    <button
                        on:click=move |_| *count.write() += 1
                    >
                        {count}
                    </button>
                </li>
            }
        })
        .collect::<Vec<_>>();

    // 注意如果 `counter_buttons` 是响应式列表
    // 并且其值发生变化，这将非常低效：
    // 每次列表变化时它都会重新渲染每一行。
    view! {
        <ul>{counter_buttons}</ul>
    }
}

/// 允许您添加或删除计数器的计数器列表。
#[component]
fn DynamicList(
    /// 开始时的计数器数量。
    initial_length: usize,
) -> impl IntoView {
    // 这个动态列表将使用 <For/> 组件。
    // <For/> 是一个键控列表。这意味着每一行
    // 都有一个定义的键。如果键不变，行
    // 将不会重新渲染。当列表变化时，只有
    // 最少数量的变化会应用到 DOM。

    // `next_counter_id` 将让我们生成唯一 ID
    // 我们通过简单地每次创建计数器时将 ID 增加一来做到这一点
    let mut next_counter_id = initial_length;

    // 我们生成一个初始列表，如在 <StaticList/> 中
    // 但这次我们包含 ID 和 signal
    // 请参阅下面 add_counter 中关于 ArcRwSignal 的注释
    let initial_counters = (0..initial_length)
        .map(|id| (id, ArcRwSignal::new(id + 1)))
        .collect::<Vec<_>>();

    // 现在我们将初始列表存储在 signal 中
    // 这样，我们就能够随时间修改列表，
    // 添加和删除计数器，它将响应式地变化
    let (counters, set_counters) = signal(initial_counters);

    let add_counter = move |_| {
        // 为新计数器创建 signal
        // 我们在这里使用 ArcRwSignal，而不是 RwSignal
        // ArcRwSignal 是引用计数类型，而不是我们到目前为止一直使用的
        // arena 分配的 signal 类型。
        // 当我们创建这样的 signals 集合时，使用 ArcRwSignal
        // 允许每个 signal 在其行被删除时被释放。
        let sig = ArcRwSignal::new(next_counter_id + 1);
        // 将此计数器添加到计数器列表
        set_counters.update(move |counters| {
            // 由于 `.update()` 给我们 `&mut T`
            // 我们可以只使用普通的 Vec 方法如 `push`
            counters.push((next_counter_id, sig))
        });
        // 增加 ID 使其始终唯一
        next_counter_id += 1;
    };

    view! {
        <div>
            <button on:click=add_counter>
                "Add Counter"
            </button>
            <ul>
                // <For/> 组件在这里是核心
                // 这允许高效的键控列表渲染
                <For
                    // `each` 接受任何返回迭代器的函数
                    // 这通常应该是 signal 或派生 signal
                    // 如果它不是响应式的，只需渲染 Vec<_> 而不是 <For/>
                    each=move || counters.get()
                    // 键应该对每行是唯一且稳定的
                    // 使用索引通常是一个坏主意，除非您的列表
                    // 只能增长，因为在列表内移动项目
                    // 意味着它们的索引会改变，它们都会重新渲染
                    key=|counter| counter.0
                    // `children` 从您的 `each` 迭代器接收每个项目
                    // 并返回一个视图
                    children=move |(id, count)| {
                        // 我们可以将 ArcRwSignal 转换为可复制的 RwSignal
                        // 以便在将其移动到视图中时获得更好的 DX
                        let count = RwSignal::from(count);
                        view! {
                            <li>
                                <button
                                    on:click=move |_| *count.write() += 1
                                >
                                    {count}
                                </button>
                                <button
                                    on:click=move |_| {
                                        set_counters
                                            .write()
                                            .retain(|(counter_id, _)| {
                                                counter_id != &id
                                            });
                                    }
                                >
                                    "Remove"
                                </button>
                            </li>
                        }
                    }
                />
            </ul>
        </div>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>

### 使用 `<ForEnumerate/>` 在迭代时访问索引

对于需要在迭代时访问实时索引的情况，Leptos 提供了 [`<ForEnumerate/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.ForEnumerate.html) 组件。

props 与 [`<For/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.For.html) 组件相同，但在渲染 `children` 时，它还提供一个 `ReadSignal<usize>` 参数作为索引：

```rust
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
struct Counter {
  id: usize,
  count: RwSignal<i32>
}

<ForEnumerate
    each=move || counters.get() // 与 <For/> 相同
    key=|counter| counter.id    // 与 <For/> 相同
    // 提供索引作为 signal 和子 T
    children={move |index: ReadSignal<usize>, counter: Counter| {
        view! {
            <button>{move || index.get()} ". Value: " {move || counter.count.get()}</button>
        }
    }}
/>
```

或者也可以使用更方便的 `let` 语法：
```rust
<ForEnumerate
    each=move || counters.get() // 与 <For/> 相同
    key=|counter| counter.id    // 与 <For/> 相同
    let(idx, counter)           // let 语法
>
    <button>{move || idx.get()} ". Value: " {move || counter.count.get()}</button>
</ ForEnumerate>
```