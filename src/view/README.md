# 第一部分：构建用户界面

在本书的第一部分，我们将学习使用 Leptos 在客户端构建用户界面。在底层，Leptos 和 Trunk 正在打包一段 JavaScript 代码片段，它将加载已编译为 WebAssembly 的 Leptos UI，以驱动您的 CSR（客户端渲染）网站中的交互性。

第一部分将向您介绍构建由 Leptos 和 Rust 驱动的响应式用户界面所需的基本工具。在第一部分结束时，您应该能够构建一个在浏览器中渲染的快速同步网站，并且可以部署在任何静态站点托管服务上，如 Github Pages 或 Vercel。

```admonish info
为了充分利用本书，我们鼓励您跟随提供的示例进行编码。
在[入门指南](https://book.leptos.dev/getting_started/)和 [Leptos DX](https://book.leptos.dev/getting_started/leptos_dx.html) 章节中，我们向您展示了如何使用 Leptos 和 Trunk 设置基本项目，包括浏览器中的 WASM 错误处理。
这个基本设置足以让您开始使用 Leptos 进行开发。

如果您更愿意使用功能更全面的模板开始，该模板演示了如何设置真实 Leptos 项目中会看到的一些基础知识，如路由（本书后面会介绍）、向页面头部注入 `<Title>` 和 `<Meta>` 标签，以及一些其他便利功能，那么请随时使用 [leptos-rs `start-trunk`](https://github.com/leptos-rs/start-trunk) 模板仓库来启动和运行。

`start-trunk` 模板需要您安装 `Trunk` 和 `cargo-generate`，您可以通过运行 `cargo install trunk` 和 `cargo install cargo-generate` 来获得。

要使用模板设置您的项目，只需运行

`cargo generate --git https://github.com/leptos-rs/start-trunk`

然后运行

`trunk serve --port 3000 --open`

在新创建的应用程序目录中开始开发您的应用程序。
Trunk 服务器将在文件更改时重新加载您的应用程序，使开发相对无缝。

```