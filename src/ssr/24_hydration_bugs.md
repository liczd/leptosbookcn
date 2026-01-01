# 水合错误 _（以及如何避免它们）_

## 思想实验

让我们尝试一个实验来测试您的直觉。打开一个您正在使用`cargo-leptos`进行服务器渲染的应用程序。（如果您到目前为止只是使用`trunk`来玩示例，请[克隆一个`cargo-leptos`模板](./21_cargo_leptos.md)，仅为了这个练习。）

在您的根组件中放置一个日志。（我通常称我的为`<App/>`，但任何都可以。）

```rust
#[component]
pub fn App() -> impl IntoView {
	logging::log!("where do I run?");
	// ... 其他内容
}
```

让我们启动它

```bash
cargo leptos watch
```

您期望`where do I run?`在哪里记录？

- 在您运行服务器的命令行中？
- 在您加载页面时的浏览器控制台中？
- 都不是？
- 两者都是？

试试看。

...

...

...

好的，考虑剧透警告。

您当然会注意到它在两个地方都记录，假设一切按计划进行。实际上在服务器上它记录两次——首先在初始服务器启动期间，当Leptos渲染您的应用程序一次以提取路由树时，然后在您发出请求时第二次。每次您重新加载页面时，`where do I run?`应该在服务器上记录一次，在客户端记录一次。

如果您考虑最后几节中的描述，希望这是有道理的。您的应用程序在服务器上运行一次，在那里它构建一个发送到客户端的HTML树。在这个初始渲染期间，`where do I run?`在服务器上记录。

一旦WASM二进制文件在浏览器中加载，您的应用程序运行第二次，遍历相同的用户界面树并添加交互性。

> 这听起来像浪费吗？从某种意义上说，是的。但减少这种浪费是一个真正困难的问题。这是一些JS框架（如Qwik）旨在解决的问题，尽管现在判断它是否比其他方法带来净性能增益可能还为时过早。

## 错误的可能性

好的，希望所有这些都有意义。但这与本章标题"水合错误（以及如何避免它们）"有什么关系？

记住应用程序需要在服务器和客户端上运行。这产生了几组不同的潜在问题，您需要知道如何避免。

### 服务器和客户端代码之间的不匹配

创建错误的一种方法是在服务器发送的HTML和客户端渲染的内容之间创建不匹配。我认为无意中做到这一点实际上相当困难（至少根据我从人们那里得到的错误报告来判断）。但想象我做这样的事情

```rust
#[component]
pub fn App() -> impl IntoView {
    let data = if cfg!(target_arch = "wasm32") {
        vec![0, 1, 2]
    } else {
        vec![]
    };
    data.into_iter()
        .map(|value| view! { <span>{value}</span> })
        .collect_view()
}
```

换句话说，如果这被编译为WASM，它有三个项目；否则它是空的。

当我在浏览器中加载页面时，我什么也看不到。如果我打开控制台，我看到一个panic：

```
ssr_modes.js:423 panicked at /.../tachys/src/html/element/mod.rs:352:14:
called `Option::unwrap()` on a `None` value
```

在浏览器中运行的应用程序的WASM版本期望找到一个元素（实际上，它期望三个元素！）但从服务器发送的HTML没有。

#### 解决方案

您很少故意这样做，但这可能发生在服务器和浏览器上运行不同逻辑的情况下。如果您看到这样的警告并且您认为这不是您的错，更可能是`<Suspense/>`或其他东西的错误。请随时在GitHub上开启[问题](https://github.com/leptos-rs/leptos/issues)或[讨论](https://github.com/leptos-rs/leptos/discussions)寻求帮助。

### 无效/边缘情况HTML，以及HTML和DOM之间的不匹配

服务器用HTML响应请求。然后浏览器将该HTML解析为称为文档对象模型（DOM）的树。在水合期间，Leptos遍历应用程序的视图树，水合一个元素，然后移动到其子元素，水合第一个子元素，然后移动到其兄弟元素，依此类推。这假设您的应用程序在服务器上产生的HTML树直接映射到浏览器解析该HTML的DOM树。

有几种情况需要注意，其中您的`view`创建的HTML树和DOM树可能不完全对应：这些可能导致水合错误。

#### 无效HTML

这是一个导致水合错误的非常简单的应用程序：
```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <p>
            <div class:blue=move || count.get() == 2>
                 "First"
            </div>
        </p>
    }
}
```

这将给出类似这样的错误消息
```
A hydration error occurred while trying to hydrate an element defined at src/app.rs:6:14.

The framework expected a text node, but found this instead:  <p></p>

The hydration mismatch may have occurred slightly earlier, but this is the first time the framework found a node of an unexpected type.
```

（在大多数浏览器开发工具中，您可以右键单击该`<p></p>`以显示它在DOM中出现的位置，这很方便。）

如果您在DOM检查器中查看，您会看到它不是`<p>`内的`<div>`，而是显示：
```html
<p></p>
<div>First</div>
<p></p>
```
这是因为这是无效的HTML！`<div>`不能放在`<p>`内。当浏览器解析该`<div>`时，它实际上关闭了前面的`<p>`，然后打开`<div>`；然后，当它看到（现在不匹配的）关闭`</p>`时，它将其视为新的空`<p>`。

结果，我们的DOM树不再匹配预期的视图树，水合错误随之而来。

不幸的是，使用我们当前的模型在编译时确保视图中HTML的有效性是困难的，并且不会对整体编译时间产生影响。现在，如果您遇到这样的问题，请考虑通过验证器运行HTML输出。（在上面的情况下，W3C HTML验证器确实显示了错误！）

```admonish info
您可能会注意到从0.6迁移到0.7时出现一些这样的错误。这是由于水合工作方式的变化。

Leptos 0.1-0.6使用了一种水合方法，其中每个HTML元素都被赋予一个唯一的ID，然后用于通过ID在DOM中找到它。Leptos 0.7开始直接遍历DOM，在遇到每个元素时进行水合。这具有更好的性能特征（更短、更清洁的HTML输出和更快的水合时间），但对上述无效或边缘情况HTML示例的弹性较差。也许更重要的是，这种方法还修复了水合中的许多*其他*边缘情况和错误，使框架总体上更具弹性。
```

#### 没有`<tbody>`的`<table>`

我知道还有一个额外的边缘情况，其中*有效*HTML产生与视图树不同的DOM树，那就是`<table>`。当（大多数）浏览器解析HTML `<table>`时，它们会在DOM中插入`<tbody>`，无论您是否包含它。

```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <table>
            <tr>
                <td class:blue=move || count.get() == 0>"First"</td>
            </tr>
        </table>
    }
}
```

再次，这产生了水合错误，因为浏览器在DOM树中插入了一个额外的`<tbody>`，而这不在您的视图中。

这里，修复很简单：添加`<tbody>`：
```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <table>
            <tbody>
                <tr>
                    <td class:blue=move || count.get() == 0>"First"</td>
                </tr>
            </tbody>
        </table>
    }
}
```

（将来值得探索我们是否可以比检查有效HTML更容易地检查这个特定的怪癖。）

#### 一般建议

这种不匹配可能很棘手。一般来说，我的调试建议：
1. 右键单击消息中的元素，查看框架首次*注意到*问题的位置。
2. 比较该点及其上方的DOM，检查与您的视图树的不匹配。是否有额外的元素？缺少元素？

### 不是所有客户端代码都能在服务器上运行

想象您愉快地导入一个像`gloo-net`这样的依赖项，您习惯于在浏览器中使用它来发出请求，并在服务器渲染应用程序的`create_resource`中使用它。

您可能会立即看到可怕的消息

```
panicked at 'cannot call wasm-bindgen imported functions on non-wasm targets'
```

哦不。

但当然这是有道理的。我们刚刚说过您的应用程序需要在客户端和服务器上运行。

#### 解决方案

有几种方法可以避免这种情况：

1. 只使用可以在服务器和客户端上运行的库。例如，[`reqwest`](https://docs.rs/reqwest/latest/reqwest/)适用于在两种设置中发出HTTP请求。
2. 在服务器和客户端上使用不同的库，并使用`#[cfg]`宏对它们进行门控。（[点击这里查看示例](https://github.com/leptos-rs/leptos/blob/main/examples/hackernews/src/api.rs)。）
3. 将仅客户端代码包装在`Effect::new`中。因为effect只在客户端运行，这可以是访问初始渲染不需要的浏览器API的有效方法。

例如，假设我想在signal更改时在浏览器的`localStorage`中存储某些内容。

```rust
#[component]
pub fn App() -> impl IntoView {
    use gloo_storage::Storage;
	let storage = gloo_storage::LocalStorage::raw();
	logging::log!("{storage:?}");
}
```

这会panic，因为我无法在服务器渲染期间访问`LocalStorage`。

但如果我将其包装在effect中...

```rust
#[component]
pub fn App() -> impl IntoView {
    use gloo_storage::Storage;
    Effect::new(move |_| {
        let storage = gloo_storage::LocalStorage::raw();
		log!("{storage:?}");
    });
}
```

没问题！这将在服务器上适当渲染，忽略仅客户端代码，然后在浏览器上访问存储并记录消息。

### 不是所有服务器代码都能在客户端上运行

在浏览器中运行的WebAssembly是一个相当有限的环境。您无法访问文件系统或标准库可能习惯拥有的许多其他东西。不是每个crate都可以编译为WASM，更不用说在WASM环境中运行了。

特别是，您有时会看到关于crate `mio`或`core`中缺少内容的错误。这通常表明您正在尝试将无法编译为WASM的内容编译为WASM。如果您要添加仅服务器依赖项，您需要在`Cargo.toml`中将它们标记为`optional = true`，然后在`ssr`功能定义中启用它们。（查看模板`Cargo.toml`文件之一以查看更多详细信息。）

您可以创建一个[`Effect`](https://docs.rs/leptos/latest/leptos/prelude/struct.Effect.html)来指定某些内容应该只在客户端运行，而不在服务器上运行。有没有办法指定某些内容应该只在服务器上运行，而不在客户端上运行？

实际上，有的。下一章将详细介绍服务器函数的主题。（与此同时，您可以在[这里](https://docs.rs/leptos/latest/leptos/attr.server.html)查看它们的文档。）