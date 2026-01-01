# 使用`<For/>`迭代更复杂的数据

本章更深入地讨论了对嵌套数据结构的迭代。它属于这里与其他迭代章节一起，但如果您想坚持更简单的主题，请随时跳过它并稍后回来。

## 问题

我刚刚说过，框架不会重新渲染行中的任何项目，除非键已更改。这在一开始可能有道理，但很容易让您困惑。

让我们考虑一个例子，其中我们行中的每个项目都是某种数据结构。例如，想象项目来自某个键和值的JSON数组：

```rust
#[derive(Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: i32,
}
```

让我们定义一个简单的组件，它将迭代行并显示每一行：

```rust
#[component]
pub fn App() -> impl IntoView {
    // 从三行开始
    let (data, set_data) = signal(vec![
        DatabaseEntry {
            key: "foo".to_string(),
            value: 10,
        },
        DatabaseEntry {
            key: "bar".to_string(),
            value: 20,
        },
        DatabaseEntry {
            key: "baz".to_string(),
            value: 15,
        },
    ]);
    view! {
        // 当我们点击时，更新每一行，
        // 将其值加倍
        <button on:click=move |_| {
            set_data.update(|data| {
                for row in data {
                    row.value *= 2;
                }
            });
            // 记录signal的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代行并显示每个值
        <For
            each=move || data.get()
            key=|state| state.key.clone()
            let(child)
        >
            <p>{child.value}</p>
        </For>
    }
}
```

> 注意这里的`let(child)`语法。在上一章中，我们介绍了带有`children` prop的`<For/>`。我们实际上可以直接在`<For/>`组件的子元素中创建这个值，而不需要跳出`view`宏：上面的`let(child)`结合`<p>{child.value}</p>`等价于
>
> ```rust
> children=|child| view! { <p>{child.value}</p> }
> ```
>
> 为了方便，您也可以选择解构数据的模式：
>
> ```rust
> <For
>     each=move || data.get()
>     key=|state| state.key.clone()
>     let(DatabaseEntry { key, value })
> >
> ```

当您点击`Update Values`按钮时...什么都没有发生。或者说：signal被更新了，新值被记录了，但每行的`{child.value}`没有更新。

让我们看看：这是因为我们忘记添加闭包使其响应式吗？让我们试试`{move || child.value}`。

...不行。仍然什么都没有。

问题是：正如我所说，每行只有在键更改时才重新渲染。我们更新了每行的值，但没有更新任何行的键，所以什么都没有重新渲染。如果您查看`child.value`的类型，它是一个普通的`i32`，而不是响应式的`ReadSignal<i32>`或类似的东西。这意味着即使我们在其周围包装一个闭包，这一行中的值也永远不会更新。

我们有三种可能的解决方案：

1. 更改`key`，使其在数据结构更改时始终更新
2. 更改`value`，使其是响应式的
3. 取数据结构的响应式切片，而不是直接使用每行

## 选项1：更改键

每行只有在键更改时才重新渲染。我们上面的行没有重新渲染，因为键没有更改。那么：为什么不强制键更改呢？

```rust
<For
	each=move || data.get()
	key=|state| (state.key.clone(), state.value)
	let(child)
>
	<p>{child.value}</p>
</For>
```

现在我们在`key`中包含键和值。这意味着每当行的值更改时，`<For/>`将把它视为完全新的行，并替换前一个。

### 优点

这非常简单。我们可以通过在`DatabaseEntry`上派生`PartialEq`、`Eq`和`Hash`来使其更简单，在这种情况下我们可以只使用`key=|state| state.clone()`。

### 缺点

**这是三个选项中效率最低的。**每次行的值更改时，它都会丢弃前一个`<p>`元素并用全新的元素替换它。换句话说，它不是对文本节点进行细粒度更新，而是真正在每次更改时重新渲染整行，这与行的UI复杂程度成正比地昂贵。

您还会注意到我们最终克隆了整个数据结构，以便`<For/>`可以保留键的副本。对于更复杂的结构，这很快就会成为一个坏主意！

## 选项2：嵌套Signal

如果我们确实想要值的细粒度响应性，一个选项是将每行的`value`包装在signal中。

```rust
#[derive(Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: RwSignal<i32>,
}
```

`RwSignal<_>`是一个"读写signal"，它将getter和setter组合在一个对象中。我在这里使用它是因为它比单独的getter和setter更容易存储在结构中。

```rust
#[component]
pub fn App() -> impl IntoView {
    // 从三行开始
    let (data, _set_data) = signal(vec![
        DatabaseEntry {
            key: "foo".to_string(),
            value: RwSignal::new(10),
        },
        DatabaseEntry {
            key: "bar".to_string(),
            value: RwSignal::new(20),
        },
        DatabaseEntry {
            key: "baz".to_string(),
            value: RwSignal::new(15),
        },
    ]);
    view! {
        // 当我们点击时，更新每一行，
        // 将其值加倍
        <button on:click=move |_| {
            for row in &*data.read() {
                row.value.update(|value| *value *= 2);
            }
            // 记录signal的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代行并显示每个值
        <For
            each=move || data.get()
            key=|state| state.key.clone()
            let(child)
        >
            <p>{child.value}</p>
        </For>
    }
}
```

这个版本有效！如果您在浏览器的DOM检查器中查看，您会看到与前一个版本不同，在这个版本中只有单个文本节点被更新。将signal直接传递到`{child.value}`中有效，因为如果您将signal传递到视图中，它们确实保持其响应性。

注意我将`set_data.update()`更改为`data.read()`。`.read()`是访问signal值的非克隆方式。在这种情况下，我们只更新内部值，而不更新值列表：因为signal维护自己的状态，我们实际上根本不需要更新`data` signal，所以不可变的`.read()`在这里很好。

> 实际上，这个版本不更新`data`，所以`<For/>`本质上是一个静态列表，就像上一章一样，这可能只是一个普通的迭代器。但如果我们将来想要添加或删除行，`<For/>`很有用。

### 优点

这是最有效的选项，直接符合框架的其余心理模型：随时间变化的值被包装在signal中，以便界面可以响应它们。

### 缺点

如果您从API或您不控制的其他数据源接收数据，并且您不想创建一个将每个字段包装在signal中的不同结构，嵌套响应性可能很麻烦。

## 选项3：记忆化切片

Leptos提供了一个称为[`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html)的原语，它创建一个派生计算，只有在其值发生变化时才触发响应式更新。

这允许您为较大数据结构的子字段创建响应式值，而无需将该结构的字段包装在signal中。结合[`<ForEnumerate/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.ForEnumerate.html)，这将允许我们只重新渲染更改的数据值。

应用程序的大部分可以与初始（损坏的）版本保持相同，但`<For/>`将更新为：

```rust
<ForEnumerate
    each=move || data.get()
    key=|state| state.key.clone()
    children=move |index, _| {
        let value = Memo::new(move |_| {
            data.with(|data| data.get(index.get()).map(|d| d.value).unwrap_or(0))
        });
        view! {
            <p>{value}</p>
        }
    }
/>
```

您会注意到这里有几个不同之处：

- 我们使用`ForEnumerate`而不是`For`，所以我们可以访问`index` signal
- 我们明确使用`children` prop，以便更容易运行一些非`view`代码
- 我们定义一个`value` memo并在视图中使用它。这个`value`字段实际上不使用传递到每行的`child`。相反，它使用索引并回到原始`data`中获取值。

现在每次`data`更改时，每个memo都会重新计算。如果其值已更改，它将更新其文本节点，而不重新渲染整行。

**注意**：对于此示例的早期版本中的枚举迭代器，使用`For`是不安全的：

```rust
<For
    each=move || data.get().into_iter().enumerate()
    key=|(_, state)| state.key.clone()
    children=move |(index, _)| {
        let value = Memo::new(move |_| {
            data.with(|data| data.get(index).map(|d| d.value).unwrap_or(0))
        });
        view! {
            <p>{value}</p>
        }
    }
/>
```

在这种情况下，对`data`中值的更改会有反应，但对排序的更改不会，因为Memo将始终使用它最初创建时的`index`。如果任何项目被移动，这将导致渲染输出中的重复条目。

### 优点

我们获得了与signal包装版本相同的细粒度响应性，而无需将数据包装在signal中。

### 缺点

在`<ForEnumerate/>`循环内设置这个每行memo比使用嵌套signal稍微复杂一些。例如，您会注意到我们必须防止`data[index.get()]`会panic的可能性，通过使用`data.get(index.get())`，因为这个memo可能在行被删除后被触发重新运行一次。（这是因为每行的memo和整个`<ForEnumerate/>`都依赖于相同的`data` signal，并且依赖于相同signal的多个响应式值的执行顺序不能保证。）

还要注意，虽然memo记忆化它们的响应式更改，但每次都需要重新运行相同的计算来检查值，所以嵌套响应式signal对于这里的精确更新仍然更有效。

## 选项4：Store

> 这些内容中的一些在[这里](../15_global_state.md#option-3-create-a-global-state-store)的全局状态管理与store部分中重复。两个部分都是中级/可选内容，所以我认为一些重复不会有害。

Leptos 0.7引入了一个称为"store"的新响应式原语。Store旨在解决本章到目前为止描述的问题。它们有点实验性，所以它们需要在您的`Cargo.toml`中添加一个名为`reactive_stores`的额外依赖项。

Store为您提供对结构的各个字段以及集合（如`Vec<_>`）中各个项目的细粒度响应式访问，而无需像上面给出的选项那样手动创建嵌套signal或memo。

Store建立在`Store`派生宏之上，它为结构的每个字段创建一个getter。调用此getter可以响应式访问该特定字段。从中读取将只跟踪该字段及其父/子字段，更新它将只通知该字段及其父/子字段，但不通知兄弟字段。换句话说，变更`value`不会通知`key`，依此类推。

我们可以调整上面示例中使用的数据类型。

store的顶层总是需要是一个结构，所以我们将创建一个带有单个`rows`字段的`Data`包装器。

```rust
#[derive(Store, Debug, Clone)]
pub struct Data {
    #[store(key: String = |row| row.key.clone())]
    rows: Vec<DatabaseEntry>,
}

#[derive(Store, Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: i32,
}
```

将`#[store(key)]`添加到`rows`字段允许我们对store的字段进行键控访问，这在下面的`<For/>`组件中很有用。我们可以简单地使用`key`，与我们在`<For/>`中使用的相同键。

`<For/>`组件非常直接：

```rust
<For
    each=move || data.rows()
    key=|row| row.read().key.clone()
    children=|child| {
        let value = child.value();
        view! { <p>{move || value.get()}</p> }
    }
/>
```

因为`rows`是一个键控字段，它实现了`IntoIterator`，我们可以简单地使用`move || data.rows()`作为`each` prop。这将对`rows`列表的任何更改做出反应，就像我们嵌套signal版本中的`move || data.get()`一样。

`key`字段调用`.read()`来访问行的当前值，然后克隆并返回`key`字段。

在`children` prop中，调用`child.value()`为我们提供对具有此键的行的`value`字段的响应式访问。如果行被重新排序、添加或删除，键控store字段将保持同步，以便此`value`始终与正确的键关联。

在更新按钮处理程序中，我们将迭代`rows`中的条目，更新每一个：

```rust
for row in data.rows().iter_unkeyed() {
    *row.value().write() *= 2;
}
```

### 优点

我们获得了嵌套signal和memo版本的细粒度响应性，而无需手动创建嵌套signal或记忆化切片。我们可以使用普通数据（结构和`Vec<_>`），用派生宏注释，而不是特殊的嵌套响应式类型。

就个人而言，我认为store版本是这里最好的。毫不奇怪，因为它是最新的API。我们有几年时间来思考这些事情，store包含了我们学到的一些经验教训！

### 缺点

另一方面，它是最新的API。在写这句话时（2024年12月），store只发布了几周；我确信仍有一些错误或边缘情况需要解决。

### 完整示例

这是完整的store示例。您可以在[这里](https://github.com/leptos-rs/leptos/blob/main/examples/stores/src/lib.rs)找到另一个更完整的示例，在书中[这里](../15_global_state.md)有更多讨论。

```rust
use reactive_stores::Store;

#[derive(Store, Debug, Clone)]
pub struct Data {
    #[store(key: String = |row| row.key.clone())]
    rows: Vec<DatabaseEntry>,
}

#[derive(Store, Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: i32,
}

#[component]
pub fn App() -> impl IntoView {
    // 而不是带有行的signal，我们为Data创建一个store
    let data = Store::new(Data {
        rows: vec![
            DatabaseEntry {
                key: "foo".to_string(),
                value: 10,
            },
            DatabaseEntry {
                key: "bar".to_string(),
                value: 20,
            },
            DatabaseEntry {
                key: "baz".to_string(),
                value: 15,
            },
        ],
    });

    view! {
        // 当我们点击时，更新每一行，
        // 将其值加倍
        <button on:click=move |_| {
            // 允许迭代可迭代store字段中的条目
            use reactive_stores::StoreFieldIterator;

            // 调用rows()给我们访问行
            for row in data.rows().iter_unkeyed() {
                *row.value().write() *= 2;
            }
            // 记录signal的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代行并显示每个值
        <For
            each=move || data.rows()
            key=|row| row.read().key.clone()
            children=|child| {
                let value = child.value();
                view! { <p>{move || value.get()}</p> }
            }
        />
    }
}
```