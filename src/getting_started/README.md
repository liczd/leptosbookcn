# 开始使用

开始使用Leptos有两个基本路径：

1. **使用[Trunk](https://trunkrs.dev/)进行客户端渲染（CSR）** - 如果您只想用Leptos制作一个快速网站，或与现有服务器或API一起工作，这是一个很好的选择。
   在CSR模式下，Trunk将您的Leptos应用程序编译为WebAssembly（WASM）并在浏览器中运行，就像典型的Javascript单页应用程序（SPA）一样。Leptos CSR的优势包括更快的构建时间和更快的迭代开发周期，以及更简单的心理模型和更多部署应用程序的选项。CSR应用程序确实有一些缺点：与服务器端渲染方法相比，最终用户的初始加载时间较慢，使用JS单页应用程序模型带来的常见SEO挑战也适用于Leptos CSR应用程序。还要注意，在底层，使用自动生成的JS片段来加载Leptos WASM包，因此客户端设备上_必须_启用JS，您的CSR应用程序才能正确显示。与所有软件工程一样，这里有您需要考虑的权衡。

2. **使用[`cargo-leptos`](https://github.com/leptos-rs/cargo-leptos)进行全栈服务器端渲染（SSR）** - 如果您希望Rust为前端和后端提供动力，SSR是构建CRUD风格网站和自定义Web应用程序的绝佳选择。
   使用Leptos SSR选项，您的应用程序在服务器上渲染为HTML并发送到浏览器；然后，使用WebAssembly来检测HTML，使您的应用程序变得交互式 - 这个过程称为"水合"。在服务器端，Leptos SSR应用程序与您选择的[Actix-web](https://docs.rs/leptos_actix/latest/leptos_actix/)或[Axum](https://docs.rs/leptos_axum/latest/leptos_axum/)服务器库紧密集成，因此您可以利用这些社区的crate来帮助构建您的Leptos服务器。
   使用Leptos采用SSR路线的优势包括帮助您获得最佳的初始加载时间和Web应用程序的最佳SEO分数。SSR应用程序还可以通过称为"服务器函数"的Leptos功能大大简化跨服务器/客户端边界的工作，该功能允许您从客户端代码透明地调用服务器上的函数（稍后会详细介绍此功能）。不过，全栈SSR并不全是彩虹和蝴蝶 - 缺点包括较慢的开发者迭代循环（因为在进行Rust代码更改时需要重新编译服务器和客户端），以及水合带来的一些额外复杂性。

在本书结束时，您应该很好地了解要做出哪些权衡以及采取哪条路线 - CSR或SSR - 取决于您项目的要求。

在本书的第1部分中，我们将从客户端渲染Leptos站点开始，使用`Trunk`将我们的JS和WASM包提供给浏览器来构建响应式UI。

我们将在本书的第2部分中介绍`cargo-leptos`，这完全是关于在其全栈SSR模式下使用Leptos的全部功能。

```admonish note
如果您来自Javascript世界，并且客户端渲染（CSR）和服务器端渲染（SSR）等术语对您来说不熟悉，理解差异的最简单方法是通过类比：

Leptos的CSR模式类似于使用React（或基于"signal"的框架如SolidJS），专注于生成客户端UI，您可以在服务器上与任何技术栈一起使用。

使用Leptos的SSR模式类似于使用全栈框架，如React世界中的Next.js（或Solid的"SolidStart"框架） - SSR帮助您构建在服务器上渲染然后发送到客户端的站点和应用程序。SSR可以帮助改善您站点的加载性能和可访问性，并使一个人更容易同时在*客户端*和服务器端工作，而无需在前端和后端的不同语言之间进行上下文切换。

Leptos框架可以在CSR模式下使用来制作UI（如React），或者您可以在全栈SSR模式下使用Leptos（如Next.js），以便您可以用一种语言构建UI和服务器：Rust。

```

## Hello World! 为Leptos CSR开发做好准备

首先，确保Rust已安装并且是最新的（[如果您需要说明，请参见此处](https://www.rust-lang.org/tools/install)）。

如果您还没有安装，可以通过在命令行上运行以下命令来安装用于运行Leptos CSR站点的"Trunk"工具：

```bash
cargo install trunk
```

然后创建一个基本的Rust项目

```bash
cargo init leptos-tutorial
```

`cd`进入您的新`leptos-tutorial`项目并添加`leptos`作为依赖项

```bash
cargo add leptos --features=csr
```

确保您已添加`wasm32-unknown-unknown`目标，以便Rust可以将您的代码编译为WebAssembly以在浏览器中运行。

```bash
rustup target add wasm32-unknown-unknown
```

在`leptos-tutorial`目录的根目录中创建一个简单的`index.html`

```html
<!DOCTYPE html>
<html>
  <head></head>
  <body></body>
</html>
```

并在您的`main.rs`中添加一个简单的"Hello, world!"

```rust
use leptos::prelude::*;

fn main() {
    leptos::mount::mount_to_body(|| view! { <p>"Hello, world!"</p> })
}
```

您的目录结构现在应该看起来像这样

```
leptos_tutorial
├── src
│   └── main.rs
├── Cargo.toml
├── index.html
```

现在从`leptos-tutorial`目录的根目录运行`trunk serve --open`。
Trunk应该自动编译您的应用程序并在默认浏览器中打开它。
如果您对`main.rs`进行编辑，Trunk将重新编译您的源代码并
实时重新加载页面。

欢迎来到使用Rust和WebAssembly（WASM）进行UI开发的世界，由Leptos和Trunk提供支持！

```admonish note
如果您使用Windows，请注意`trunk serve --open`可能不起作用。如果您在使用`--open`时遇到问题，
只需使用`trunk serve`并手动打开浏览器选项卡。
```

---

现在，在我们开始使用Leptos构建您的第一个真正的应用程序之前，有几件事您可能想知道，以帮助使您使用Leptos的体验更轻松一些。