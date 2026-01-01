# 介绍`cargo-leptos`

到目前为止，我们只是在浏览器中运行代码，并使用Trunk来协调构建过程和运行本地开发过程。如果我们要添加服务器端渲染，我们还需要在服务器上运行应用程序代码。这意味着我们需要构建两个单独的二进制文件，一个编译为本机代码并运行服务器，另一个编译为WebAssembly（WASM）并在用户的浏览器中运行。此外，服务器需要知道如何将此WASM版本（以及初始化它所需的JavaScript）提供给浏览器。

这不是一个不可克服的任务，但它增加了一些复杂性。为了方便和更好的开发者体验，我们构建了[`cargo-leptos`](https://github.com/leptos-rs/cargo-leptos)构建工具。`cargo-leptos`基本上存在于协调应用程序的构建过程，处理在您进行更改时重新编译服务器和客户端部分，并为Tailwind、SASS和测试等内容添加一些内置支持。

开始使用非常简单。只需运行

```bash
cargo install --locked cargo-leptos
```

然后要创建新项目，您可以运行

```bash
# 对于Actix模板
cargo leptos new --git https://github.com/leptos-rs/start-actix
```

或

```bash
# 对于Axum模板
cargo leptos new --git https://github.com/leptos-rs/start-axum
```

确保您已添加wasm32-unknown-unknown目标，以便Rust可以将您的代码编译为WebAssembly以在浏览器中运行。
```bash
rustup target add wasm32-unknown-unknown
```

现在`cd`进入您创建的目录并运行

```bash
cargo leptos watch
```

一旦您的应用程序编译完成，您可以打开浏览器到[`http://localhost:3000`](http://localhost:3000)查看它。

`cargo-leptos`有很多额外的功能和内置工具。您可以[在其`README`中](https://github.com/leptos-rs/cargo-leptos/blob/main/README.md)了解更多。

但是当您打开浏览器到`localhost:3000`时到底发生了什么？好吧，继续阅读找出答案。