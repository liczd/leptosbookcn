# 与 JavaScript 集成：`wasm-bindgen`、`web_sys` 和 `HtmlElement`

Leptos 提供了各种工具，让您可以构建声明式 Web 应用程序而无需离开框架的世界。响应式系统、`component` 和 `view` 宏以及路由器等功能让您可以构建用户界面而无需直接与浏览器提供的 Web API 交互。它们让您可以直接在 Rust 中完成所有这些工作，这很棒——假设您喜欢 Rust。（如果您已经读到了本书的这一部分，我们假设您喜欢 Rust。）

生态系统 crates 如 [`leptos-use`](https://leptos-use.rs/) 提供的出色实用工具集可以让您走得更远，通过为许多 Web API 提供 Leptos 特定的响应式包装器。

尽管如此，在许多情况下您需要直接访问 JavaScript 库或 Web API。本章可以提供帮助。

## 使用 `wasm-bindgen` 使用 JS 库

您的 Rust 代码可以编译为 WebAssembly (WASM) 模块并加载到浏览器中运行。但是，WASM 无法直接访问浏览器 API。相反，Rust/WASM 生态系统依赖于从您的 Rust 代码生成绑定到托管它的 JavaScript 浏览器环境。

[`wasm-bindgen`](https://rustwasm.github.io/docs/wasm-bindgen/) crate 是该生态系统的核心。它提供了一个接口，用于标记 Rust 代码的部分，并用注释告诉它如何调用 JS，以及一个用于生成必要的 JS 胶水代码的 CLI 工具。您一直在不知不觉中使用它：`trunk` 和 `cargo-leptos` 都在底层依赖 `wasm-bindgen`。

如果有一个您想从 Rust 调用的 JavaScript 库，您应该参考 `wasm-bindgen` 文档中关于[从 JS 导入函数](https://rustwasm.github.io/docs/wasm-bindgen/examples/import-js.html)的内容。从 JavaScript 导入单个函数、类或值以在您的 Rust 应用程序中使用相对容易。

将 JS 库直接集成到您的应用程序中并不总是容易的。特别是，任何依赖于特定 JS 框架（如 React）的库可能很难集成。以某种方式操作 DOM 状态的库（例如，富文本编辑器）也应该谨慎使用：Leptos 和 JS 库可能都会假设它们是应用程序状态的最终真相来源，因此您应该小心分离它们的职责。

## 使用 `web-sys` 访问 Web API

如果您只需要访问一些浏览器 API 而不引入单独的 JS 库，您可以使用 [`web_sys`](https://docs.rs/web-sys/latest/web_sys/) crate 来做到这一点。这为浏览器提供的所有 Web API 提供绑定，从浏览器类型和函数到 Rust 结构体和方法的 1:1 映射。

一般来说，如果您问"如何用 Leptos _做 X_？"其中 _做 X_ 是访问某些 Web API，查找原生 JavaScript 解决方案并使用 [`web-sys` 文档](https://docs.rs/web-sys/latest/web_sys/)将其翻译为 Rust 是一个好方法。

> 在本节之后，您可能会发现[`wasm-bindgen` 指南中关于 `web-sys` 的章节](https://rustwasm.github.io/docs/wasm-bindgen/web-sys/index.html)对于额外阅读很有用。

### 启用功能

`web_sys` 大量使用功能门控以保持编译时间较低。如果您想使用其众多 API 之一，您可能需要启用一个功能来使用它。

使用项目所需的功能总是在其文档中列出。例如，要使用 [`Element::get_bounding_rect_client`](https://docs.rs/web-sys/latest/web_sys/struct.Element.html#method.get_bounding_client_rect)，您需要启用 `DomRect` 和 `Element` 功能。

Leptos 已经启用了[一大堆](https://github.com/leptos-rs/leptos/blob/main/leptos_dom/Cargo.toml#L41)功能 - 如果所需的功能已经在这里启用，您就不必在自己的应用程序中启用它。否则，将其添加到您的 `Cargo.toml` 中，您就可以开始了！

```toml
[dependencies.web-sys]
version = "0.3"
features = ["DomRect"]
```

但是，随着 JavaScript 标准的发展和 API 的编写，您可能想要使用技术上还不完全稳定的浏览器功能，例如 [WebGPU](https://docs.rs/web-sys/latest/web_sys/struct.Gpu.html)。`web_sys` 将遵循（可能经常变化的）标准，这意味着不提供稳定性保证。

为了使用这个，您需要添加 `RUSTFLAGS=--cfg=web_sys_unstable_apis` 作为环境变量。这可以通过将其添加到每个命令或添加到您仓库中的 `.cargo/config.toml` 来完成。

作为命令的一部分：

```sh
RUSTFLAGS=--cfg=web_sys_unstable_apis cargo # ...
```

在 `.cargo/config.toml` 中：

```toml
[env]
RUSTFLAGS = "--cfg=web_sys_unstable_apis"
```

## 从您的 `view` 访问原始 `HtmlElement`

框架的声明式风格意味着您不需要直接操作 DOM 节点来构建用户界面。但是，在某些情况下，您希望直接访问代表视图一部分的底层 DOM 元素。本书关于["非受控输入"](/view/05_forms.html?highlight=NodeRef#uncontrolled-inputs)的部分展示了如何使用 [`NodeRef`](https://docs.rs/leptos/latest/leptos/tachys/reactive_graph/node_ref/struct.NodeRef.html) 类型来做到这一点。

`NodeRef::get` 返回一个正确类型的 `web-sys` 元素，可以直接操作。

例如，考虑以下内容：

```rust
#[component]
pub fn App() -> impl IntoView {
    let node_ref = NodeRef::<Input>::new();

    Effect::new(move |_| {
        if let Some(node) = node_ref.get() {
            leptos::logging::log!("value = {}", node.value());
        }
    });

    view! {
        <input node_ref=node_ref/>
    }
}
```

在这里的 effect 内部，`node` 只是一个 `web_sys::HtmlInputElement`。这允许我们调用任何适当的方法。

（注意这里 `.get()` 返回一个 `Option`，因为 `NodeRef` 在实际创建 DOM 元素时被填充之前是空的。Effects 在组件运行后一个 tick 运行，所以在大多数情况下，当 effect 运行时 `<input>` 已经被创建了。）