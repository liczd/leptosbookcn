# 指南：Islands

Leptos 0.5引入了新的`islands`功能。本指南将介绍islands功能和核心概念，同时使用islands架构实现一个演示应用程序。

## Islands架构

主流的JavaScript前端框架（React、Vue、Svelte、Solid、Angular）都起源于构建客户端渲染单页应用程序（SPA）的框架。初始页面加载被渲染为HTML，然后进行水合，后续导航直接在客户端处理。（因此称为"单页"：一切都从服务器的单次页面加载开始，即使后来有客户端路由。）这些框架中的每一个后来都添加了服务器端渲染以改善初始加载时间、SEO和用户体验。

这意味着默认情况下，整个应用程序都是交互式的。这也意味着整个应用程序必须作为JavaScript发送到客户端才能进行水合。Leptos遵循了相同的模式。

> 您可以在[服务器端渲染](./ssr/22_life_cycle.md)章节中阅读更多内容。

但也可以朝相反的方向工作。与其采用完全交互式的应用程序，在服务器上将其渲染为HTML，然后在浏览器中进行水合，您可以从普通HTML页面开始，添加小的交互区域。这是2010年代之前任何网站或应用程序的传统格式：您的浏览器向服务器发出一系列请求，并返回每个新页面的HTML作为响应。在"单页应用程序"（SPA）兴起之后，这种方法有时被称为"多页应用程序"（MPA）作为对比。

"islands架构"这个短语最近出现，用来描述从服务器渲染HTML页面的"海洋"开始，并在整个页面中添加交互性"岛屿"的方法。

> ### 额外阅读
>
> 本指南的其余部分将介绍如何在Leptos中使用islands。有关该方法的更多背景信息，请查看以下文章：
>
> - Jason Miller，["Islands Architecture"](https://jasonformat.com/islands-architecture/)
> - Ryan Carniato，["Islands & Server Components & Resumability, Oh My!"](https://dev.to/this-is-learning/islands-server-components-resumability-oh-my-319d)
> - patterns.dev上的["Islands Architectures"](https://www.patterns.dev/posts/islands-architecture)
> - [Astro Islands](https://docs.astro.build/en/concepts/islands/)

## 激活Islands模式

让我们从一个新的`cargo-leptos`应用程序开始：

```bash
cargo leptos new --git leptos-rs/start-axum
```

> 在这个例子中，Actix和Axum之间应该没有真正的区别。

我只是要运行

```bash
cargo leptos build
```

在后台，同时启动我的编辑器并继续写作。

我要做的第一件事是在我的`Cargo.toml`中添加`islands`功能。我只需要将其添加到`leptos` crate中。

```toml
leptos = { version = "0.7", features = ["islands"] }
```

接下来，我将修改从`src/lib.rs`导出的`hydrate`函数。我将删除调用`leptos::mount::hydrate_body(App)`的行，并将其替换为

```rust
leptos::mount::hydrate_islands();
```

与其运行整个应用程序并水合它创建的视图，这将按顺序水合每个单独的island。

在`app.rs`中，在`shell`函数中，我们还需要在`HydrationScripts`组件中添加`islands=true`：

```rust
<HydrationScripts options islands=true/>
```

好的，现在启动您的`cargo leptos watch`并转到[`http://localhost:3000`](http://localhost:3000)（或其他地方）。

点击按钮，然后...

什么都没有发生！

完美。

```admonish note
起始模板在其`hydrate()`函数定义中包含`use app::*;`。一旦您切换到islands模式，您就不再使用导入的主`App`函数，所以您可能认为可以删除它。（实际上，Rust lint工具可能会发出警告，如果您不这样做！）

但是，如果您使用工作区设置，这可能会导致问题。我们使用`wasm-bindgen`为每个函数独立导出入口点。根据我的经验，如果您使用工作区设置，并且您的`frontend` crate中没有任何东西实际使用`app` crate，那些绑定将不会正确生成。[有关更多信息，请参见此讨论](https://github.com/leptos-rs/leptos/issues/2083#issuecomment-1868053733)。
```

## 使用Islands

什么都没有发生，因为我们刚刚完全颠倒了应用程序的心理模型。与其默认交互并水合所有内容，应用程序现在默认是普通HTML，我们需要选择加入交互性。

这对WASM二进制大小有很大影响：如果我在发布模式下编译，这个应用程序只有24kb的WASM（未压缩），而在非islands模式下是274kb。（274kb对于"Hello, world!"来说相当大。这实际上只是与客户端路由相关的所有代码，在演示中没有使用。）

当我们点击按钮时，什么都没有发生，因为我们的整个页面都是静态的。

那么我们如何让某些事情发生呢？

让我们将`HomePage`组件变成一个island！

这是非交互式版本：

```rust
#[component]
fn HomePage() -> impl IntoView {
    // 创建一个响应式值来更新按钮
    let count = RwSignal::new(0);
    let on_click = move |_| *count.write() += 1;

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

这是交互式版本：

```rust
#[island]
fn HomePage() -> impl IntoView {
    // 创建一个响应式值来更新按钮
    let count = RwSignal::new(0);
    let on_click = move |_| *count.write() += 1;

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

现在当我点击按钮时，它工作了！

`#[island]`宏的工作方式与`#[component]`宏完全相同，只是在islands模式下，它将此指定为交互式island。如果我们再次检查二进制大小，这在发布模式下是166kb未压缩；比24kb完全静态版本大得多，但比355kb完全水合版本小得多。

如果您现在打开页面的源代码，您会看到您的`HomePage` island已被渲染为特殊的`<leptos-island>` HTML元素，该元素指定应该使用哪个组件来水合它：

```html
<leptos-island data-component="HomePage_7432294943247405892">
  <h1>Welcome to Leptos!</h1>
  <button>
    Click Me:
    <!>0
  </button>
</leptos-island>
```

只有这个`<leptos-island>`内部的代码被编译为WASM，只有该代码在水合时运行。

## 有效使用Islands

记住_只有_`#[island]`内的代码需要编译为WASM并发送到浏览器。这意味着islands应该尽可能小和具体。例如，我的`HomePage`最好分解为常规组件和island：

```rust
#[component]
fn HomePage() -> impl IntoView {
    view! {
        <h1>"Welcome to Leptos!"</h1>
        <Counter/>
    }
}

#[island]
fn Counter() -> impl IntoView {
    // 创建一个响应式值来更新按钮
    let (count, set_count) = signal(0);
    let on_click = move |_| *set_count.write() += 1;

    view! {
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

现在`<h1>`不需要包含在客户端包中，或进行水合。这现在看起来像是一个愚蠢的区别；但请注意，您现在可以向`HomePage`本身添加任意多的惰性HTML内容，WASM二进制大小将保持完全相同。

在常规水合模式下，您的WASM二进制大小随着应用程序的大小/复杂性而增长。在islands模式下，您的WASM二进制随着应用程序中交互性的数量而增长。您可以在islands之外添加任意多的非交互式内容，它不会增加二进制大小。

## 解锁超能力

所以，这50%的WASM二进制大小减少很好。但真的，重点是什么？

重点在于结合两个关键事实：

1. `#[component]`函数内的代码现在_只_在服务器上运行，除非您在island中使用它。\*
2. 子元素和props可以从服务器传递到islands，而无需包含在WASM二进制中。

这意味着您可以直接在组件主体中运行仅服务器代码，并将其直接传递到子元素中。在完全水合应用程序中需要复杂的服务器函数和Suspense混合的某些任务可以在islands中内联完成。

> \* 这个"除非您在island中使用它"很重要。`#[component]`组件_不是_只在服务器上运行。相反，它们是"共享组件"，只有在`#[island]`主体中使用时才会编译到WASM二进制中。但如果您不在island中使用它们，它们就不会在浏览器中运行。

我们将在本演示的其余部分依赖第三个事实：

3. Context可以在其他独立的islands之间传递。

所以，与其我们的计数器演示，让我们做一些更有趣的事情：一个从服务器上的文件读取数据的选项卡界面。

## 将服务器子元素传递给Islands

关于islands最强大的事情之一是您可以将服务器渲染的子元素传递到island中，而island不需要了解它们的任何信息。Islands水合它们自己的内容，但不水合传递给它们的子元素。

正如React的Dan Abramov所说（在RSC的非常相似的上下文中），islands实际上不是islands：它们是甜甜圈。您可以将仅服务器内容直接传递到"甜甜圈洞"中，可以说，允许您创建微小的交互性环礁，被惰性服务器HTML的海洋_两边_包围。

> 在下面包含的演示代码中，我添加了一些样式，将所有服务器内容显示为浅蓝色"海洋"，所有islands显示为浅绿色"陆地"。希望这有助于描绘我在说什么！

继续演示：我将创建一个`Tabs`组件。在选项卡之间切换需要一些交互性，所以当然这将是一个island。让我们现在开始简单：

```rust
#[island]
fn Tabs(labels: Vec<String>) -> impl IntoView {
    let buttons = labels
        .into_iter()
        .map(|label| view! { <button>{label}</button> })
        .collect_view();
    view! {
        <div style="display: flex; width: 100%; justify-content: space-between;">
            {buttons}
        </div>
    }
}
```

哎呀。这给了我一个错误

```
error[E0463]: can't find crate for `serde`
  --> src/app.rs:43:1
   |
43 | #[island]
   | ^^^^^^^^^ can't find crate
```

简单修复：让我们`cargo add serde --features=derive`。`#[island]`宏想要引入`serde`，因为它需要序列化和反序列化`labels` prop。

现在让我们更新`HomePage`以使用`Tabs`。

```rust
#[component]
fn HomePage() -> impl IntoView {
	// 这些是我们要读取的文件
    let files = ["a.txt", "b.txt", "c.txt"];
	// 选项卡标签将只是文件名
	let labels = files.iter().copied().map(Into::into).collect();
    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels/>
    }
}
```

如果您在DOM检查器中查看，您会看到island现在类似于

```html
<leptos-island
  data-component="Tabs_1030591929019274801"
  data-props='{"labels":["a.txt","b.txt","c.txt"]}'
>
  <div style="display: flex; width: 100%; justify-content: space-between;;">
    <button>a.txt</button>
    <button>b.txt</button>
    <button>c.txt</button>
    <!---->
  </div>
</leptos-island>
```

我们的`labels` prop被序列化为JSON并存储在HTML属性中，以便可以用于水合island。

现在让我们添加一些选项卡。目前，`Tab` island将非常简单：

```rust
#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    view! {
        <div>{children()}</div>
    }
}
```

目前，每个选项卡只是一个包装其子元素的`<div>`。

我们的`Tabs`组件也将获得一些子元素：现在，让我们只显示它们全部。

```rust
#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let buttons = labels
        .into_iter()
        .map(|label| view! { <button>{label}</button> })
        .collect_view();
    view! {
        <div style="display: flex; width: 100%; justify-content: space-around;">
            {buttons}
        </div>
        {children()}
    }
}
```

好的，现在让我们回到`HomePage`。我们将创建要放入选项卡框中的选项卡列表。

```rust
#[component]
fn HomePage() -> impl IntoView {
    let files = ["a.txt", "b.txt", "c.txt"];
    let labels = files.iter().copied().map(Into::into).collect();
	let tabs = move || {
        files
            .into_iter()
            .enumerate()
            .map(|(index, filename)| {
                let content = std::fs::read_to_string(filename).unwrap();
                view! {
                    <Tab index>
                        <h2>{filename.to_string()}</h2>
                        <p>{content}</p>
                    </Tab>
                }
            })
            .collect_view()
    };

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels>
            <div>{tabs()}</div>
        </Tabs>
    }
}
```

呃...什么？

如果您习惯使用Leptos，您知道您就是不能这样做。组件主体中的所有代码都必须在服务器上运行（以渲染为HTML）和在浏览器中运行（以水合），所以您不能只调用`std::fs`；它会panic，因为在浏览器中没有访问本地文件系统（当然也没有访问服务器文件系统！）的权限。这将是一个安全噩梦！

除了...等等。我们在islands模式下。这个`HomePage`组件_真的_只在服务器上运行。所以我们实际上可以使用这样的普通服务器代码。

> **这是一个愚蠢的例子吗？**是的！在`.map()`中同步从三个不同的本地文件读取在现实生活中不是一个好选择。这里的重点只是演示这确实是仅服务器内容。

继续在项目根目录中创建三个名为`a.txt`、`b.txt`和`c.txt`的文件，并用您喜欢的任何内容填充它们。

刷新页面，您应该在浏览器中看到内容。编辑文件并再次刷新；它将被更新。

您可以将仅服务器内容从`#[component]`传递到`#[island]`的子元素中，而island不需要了解如何访问该数据或渲染该内容的任何信息。

**这真的很重要。**将服务器`children`传递给islands意味着您可以保持islands小。理想情况下，您不希望在页面的整个块周围放置`#[island]`。您希望将该块分解为交互式部分（可以是`#[island]`）和大量可以传递给该island作为`children`的额外服务器内容，以便页面交互部分的非交互子部分可以保持在WASM二进制之外。

## 在Islands之间传递Context

这些还不是真正的"选项卡"：它们只是一直显示每个选项卡。所以让我们为我们的`Tabs`和`Tab`组件添加一些简单的逻辑。

我们将修改`Tabs`以创建一个简单的`selected` signal。我们通过context提供读取部分，并在有人点击我们的按钮之一时设置signal的值。

```rust
#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let (selected, set_selected) = signal(0);
    provide_context(selected);

    let buttons = labels
        .into_iter()
        .enumerate()
        .map(|(index, label)| view! {
            <button on:click=move |_| set_selected.set(index)>
                {label}
            </button>
        })
        .collect_view();
// ...
```

让我们修改`Tab` island以使用该context来显示或隐藏自己：

```rust
#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    let selected = expect_context::<ReadSignal<usize>>();
    view! {
        <div
            style:background-color="lightgreen"
            style:padding="10px"
            style:display=move || if selected.get() == index {
                "block"
            } else {
                "none"
            }
        >
            {children()}
        </div>
    }
}
```

现在选项卡的行为完全符合我的预期。`Tabs`通过context将signal传递给每个`Tab`，`Tab`使用它来确定是否应该打开。

> 这就是为什么在`HomePage`中，我让`let tabs = move ||`成为一个函数，并像`{tabs()}`这样调用它：以这种懒惰的方式创建选项卡意味着`Tabs` island已经在每个`Tab`寻找`selected` context时提供了它。

我们完整的选项卡演示大约是200kb未压缩：不是世界上最小的演示，但仍然比我们开始的使用客户端路由的"Hello, world"小得多！只是为了好玩，我使用`#[server]`函数和`Suspense`构建了相同的演示，没有islands模式，它超过400kb。所以再次，这大约节省了50%的二进制大小。这个应用程序包含相当少的仅服务器内容：记住，当我们添加额外的仅服务器组件和页面时，这200kb不会增长。

## 概述

这个演示可能看起来很基础。确实如此。但有许多直接的收获：

- **50% WASM二进制大小减少**，这意味着客户端的交互时间和初始加载时间有可测量的改善。
- **减少数据序列化成本。**创建资源并在客户端读取它意味着您需要序列化数据，以便可以用于水合。如果您还读取了该数据以在`Suspense`中创建HTML，您最终会得到"双重数据"，即相同的确切数据既渲染为HTML又序列化为JSON，增加响应的大小，因此减慢它们。
- **轻松在`#[component]`内使用仅服务器API**，就像它是在服务器上运行的普通本机Rust函数一样——在islands模式下，它就是！
- **减少加载服务器数据的`#[server]`/`create_resource`/`Suspense`样板代码**。

## 未来探索

`islands`功能反映了前端Web框架目前正在探索的前沿工作。就目前而言，我们的islands方法与Astro非常相似（在其最近的View Transitions支持之前）：它允许您构建传统的服务器渲染、多页应用程序，并非常无缝地集成交互性islands。

有一些小的改进很容易添加。例如，我们可以做一些非常类似于Astro的View Transitions方法的事情：

- 通过从服务器获取后续导航并用新的HTML文档替换HTML文档，为islands应用程序添加客户端路由
- 使用View Transitions API在旧文档和新文档之间添加动画过渡
- 支持显式持久islands，即您可以用唯一ID标记的islands（类似于视图中组件上的`persist:searchbar`），可以从旧文档复制到新文档而不丢失其当前状态

还有其他更大的架构变化，我[还没有被说服](https://github.com/leptos-rs/leptos/issues/1830)。

## 额外信息

查看[`islands`示例](https://github.com/leptos-rs/leptos/blob/main/examples/islands/src/app.rs)、[路线图](https://github.com/leptos-rs/leptos/issues/1830)和[Hackernews演示](https://github.com/leptos-rs/leptos/tree/leptos_0.6/examples/hackernews_islands_axum)以获得额外讨论。

## 演示代码

```rust
use leptos::prelude::*;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <main style="background-color: lightblue; padding: 10px">
            <HomePage/>
        </main>
    }
}

/// 渲染应用程序的主页。
#[component]
fn HomePage() -> impl IntoView {
    let files = ["a.txt", "b.txt", "c.txt"];
    let labels = files.iter().copied().map(Into::into).collect();
    let tabs = move || {
        files
            .into_iter()
            .enumerate()
            .map(|(index, filename)| {
                let content = std::fs::read_to_string(filename).unwrap();
                view! {
                    <Tab index>
                        <div style="background-color: lightblue; padding: 10px">
                            <h2>{filename.to_string()}</h2>
                            <p>{content}</p>
                        </div>
                    </Tab>
                }
            })
            .collect_view()
    };

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels>
            <div>{tabs()}</div>
        </Tabs>
    }
}

#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let (selected, set_selected) = signal(0);
    provide_context(selected);

    let buttons = labels
        .into_iter()
        .enumerate()
        .map(|(index, label)| {
            view! {
                <button on:click=move |_| set_selected.set(index)>
                    {label}
                </button>
            }
        })
        .collect_view();
    view! {
        <div
            style="display: flex; width: 100%; justify-content: space-around;\
            background-color: lightgreen; padding: 10px;"
        >
            {buttons}
        </div>
        {children()}
    }
}

#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    let selected = expect_context::<ReadSignal<usize>>();
    view! {
        <div
            style:background-color="lightgreen"
            style:padding="10px"
            style:display=move || if selected.get() == index {
                "block"
            } else {
                "none"
            }
        >
            {children()}
        </div>
    }
}
```