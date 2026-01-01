# 服务器函数

如果您正在创建任何超出玩具应用程序的东西，您将需要一直在服务器上运行代码：从只在服务器上运行的数据库读取或写入，使用您不想发送到客户端的库运行昂贵的计算，访问由于CORS原因需要从服务器而不是客户端调用的API，或者因为您需要存储在服务器上的秘密API密钥，绝对不应该发送到用户的浏览器。

传统上，这是通过分离服务器和客户端代码，并设置REST API或GraphQL API之类的东西来允许客户端获取和变更服务器上的数据来完成的。这很好，但它要求您在多个单独的地方编写和维护代码（用于获取的客户端代码，要运行的服务器端函数），以及创建第三个要管理的东西，即两者之间的API契约。

Leptos是引入**服务器函数**概念的许多现代框架之一。服务器函数有两个关键特征：

1. 服务器函数与您的组件代码**共同定位**，以便您可以按功能而不是按技术组织工作。例如，您可能有一个"暗模式"功能，应该在会话之间持久化用户的暗/亮模式偏好，并在服务器渲染期间应用，这样就没有闪烁。这需要一个需要在客户端交互的组件，以及一些要在服务器上完成的工作（设置cookie，甚至可能在数据库中存储用户）。传统上，这个功能可能最终被分割在代码的两个不同位置，一个在您的"前端"，一个在您的"后端"。使用服务器函数，您可能只需在一个`dark_mode.rs`中编写它们，然后忘记它。

2. 服务器函数是**同构的**，即，它们可以从服务器或浏览器调用。这是通过为两个平台生成不同的代码来完成的。在服务器上，服务器函数简单地运行。在浏览器中，服务器函数的主体被替换为实际向服务器发出fetch请求的存根，将参数序列化到请求中，并从响应中反序列化返回值。但在任一端，函数都可以简单地调用：您可以创建一个写入数据库的`add_todo`函数，并简单地从浏览器中按钮的点击处理程序调用它！

## 使用服务器函数

实际上，我有点喜欢那个例子。它会是什么样子？实际上很简单。

```rust
// todo.rs

#[server]
pub async fn add_todo(title: String) -> Result<(), ServerFnError> {
    let mut conn = db().await?;

    match sqlx::query("INSERT INTO todos (title, completed) VALUES ($1, false)")
        .bind(title)
        .execute(&mut conn)
        .await
    {
        Ok(_row) => Ok(()),
        Err(e) => Err(ServerFnError::ServerError(e.to_string())),
    }
}

#[component]
pub fn BusyButton() -> impl IntoView {
	view! {
        <button on:click=move |_| {
            spawn_local(async {
                add_todo("So much to do!".to_string()).await;
            });
        }>
            "Add Todo"
        </button>
	}
}
```

您会立即注意到几件事：

- 服务器函数可以使用仅服务器依赖项，如`sqlx`，并可以访问仅服务器资源，如我们的数据库。
- 服务器函数是`async`的。即使它们只在服务器上进行同步工作，函数签名仍然需要是`async`，因为从浏览器调用它们_必须_是异步的。
- 服务器函数返回`Result<T, ServerFnError>`。再次，即使它们只在服务器上进行不会失败的工作，这也是真的，因为`ServerFnError`的变体包括在发出网络请求过程中可能出错的各种事情。
- 服务器函数可以从客户端调用。看看我们的点击处理程序。这是_只会_在客户端运行的代码。但它可以调用函数`add_todo`（使用`spawn_local`运行`Future`），就像它是一个普通的异步函数一样：

```rust
move |_| {
	spawn_local(async {
		add_todo("So much to do!".to_string()).await;
	});
}
```

- 服务器函数是用`fn`定义的顶级函数。与事件监听器、派生signal和Leptos中的大多数其他东西不同，它们不是闭包！作为`fn`调用，它们无法访问应用程序的响应式状态或任何其他未作为参数传入的内容。再次，这完全有道理：当您向服务器发出请求时，服务器无法访问客户端状态，除非您明确发送它。（否则我们必须序列化整个响应式系统并在每个请求中通过网络发送它。这不是一个好主意。）
- 服务器函数参数和返回值都需要是可序列化的。再次，希望这有道理：虽然函数参数通常不需要序列化，但从浏览器调用服务器函数意味着序列化参数并通过HTTP发送它们。

关于定义服务器函数的方式，也有一些需要注意的事情。

- 服务器函数是通过使用[`#[server]`宏](https://docs.rs/leptos/latest/leptos/attr.server.html)注释顶级函数来创建的，该函数可以在任何地方定义。

服务器函数通过使用条件编译工作。在服务器上，服务器函数创建一个HTTP端点，该端点接收其参数作为HTTP请求，并将其结果作为HTTP响应返回。对于客户端/浏览器构建，服务器函数的主体被HTTP请求存根替换。

```admonish warning
### 关于安全性的重要说明

服务器函数是一项很酷的技术，但记住这一点非常重要。**服务器函数不是魔法；它们是定义公共API的语法糖。**服务器函数的_主体_永远不会公开；它只是服务器二进制文件的一部分。但服务器函数是一个可公开访问的API端点，其返回值只是JSON或类似的blob。除非信息是公开的，或者您已经实施了适当的安全程序，否则不要从服务器函数返回信息。这些程序可能包括验证传入请求、确保适当的加密、限制访问速率等。
```

## 自定义服务器函数

默认情况下，服务器函数将其参数编码为HTTP POST请求（使用`serde_qs`），将其返回值编码为JSON（使用`serde_json`）。此默认值旨在促进与`<form>`元素的兼容性，该元素对发出POST请求有本机支持，即使在WASM被禁用、不支持或尚未加载时也是如此。它们将其端点挂载在旨在防止名称冲突的哈希URL上。

但是，有许多方法可以自定义服务器函数，支持各种输入和输出编码，设置特定端点的能力等等。

查看[`#[server]`宏](https://docs.rs/leptos/latest/leptos/attr.server.html)和[`server_fn` crate](https://docs.rs/server_fn/latest/server_fn/)的文档，以及repo中广泛的[`server_fns_axum`示例](https://github.com/leptos-rs/leptos/blob/main/examples/server_fns_axum/src/app.rs)，以获取更多信息和示例。

## 使用自定义错误

服务器函数可以返回任何实现`FromServerFnError` trait的错误类型。
这使错误处理更加符合人体工程学，并允许您向客户端提供特定于域的错误信息：

```rust
use leptos::prelude::*;
use server_fn::codec::JsonEncoding;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub enum AppError {
    ServerFnError(ServerFnErrorErr),
    DbError(String),
}

impl FromServerFnError for AppError {
    type Encoder = JsonEncoding;

    fn from_server_fn_error(value: ServerFnErrorErr) -> Self {
        AppError::ServerFnError(value)
    }
}

#[server]
pub async fn create_user(name: String, email: String) -> Result<User, AppError> {
    // 尝试在数据库中创建用户
    match insert_user_into_db(&name, &email).await {
        Ok(user) => Ok(user),
        Err(e) => Err(AppError::DbError(e.to_string())),
    }
}
```

## 需要注意的怪癖

服务器函数有一些值得注意的怪癖：

- 使用指针大小的整数类型（如`isize`和`usize`）在32位WASM架构和64位服务器架构之间进行调用时可能导致错误；如果服务器响应的值不适合32位，这将导致反序列化错误。使用固定大小类型（如`i32`或`i64`）来缓解此问题。
- 默认情况下，发送到服务器的参数使用`serde_qs`进行URL编码。这允许它们与`<form>`元素很好地配合使用，但可能有一些怪癖：例如，当前版本的`serde_qs`并不总是与可选类型很好地配合使用（参见[这里](https://github.com/leptos-rs/leptos/issues/3832)或[这里](https://github.com/leptos-rs/leptos/issues/4016)）或与具有元组变体的枚举配合使用（参见[这里](https://github.com/leptos-rs/leptos/issues/4464)）。您可以使用这些问题中描述的解决方法，或[切换到替代输入编码](https://docs.rs/leptos/latest/leptos/attr.server.html#named-arguments)。

## 将服务器函数与Leptos集成

到目前为止，我所说的一切实际上都是框架无关的。（实际上，Leptos服务器函数crate也已经集成到Dioxus中！）服务器函数只是定义类似函数的RPC调用的一种方式，它依赖于HTTP请求和URL编码等Web标准。

但在某种程度上，它们也提供了我们到目前为止故事中最后缺失的原语。因为服务器函数只是一个普通的Rust异步函数，它与我们[之前](../async/index.html)讨论的异步Leptos原语完美集成。所以您可以轻松地将服务器函数与应用程序的其余部分集成：

- 创建调用服务器函数从服务器加载数据的**资源**
- 在`<Suspense/>`或`<Transition/>`下读取这些资源，以启用流式SSR和数据加载时的回退状态。
- 创建调用服务器函数在服务器上变更数据的**操作**

本书的最后一节将通过引入使用渐进增强HTML表单运行这些服务器操作的模式，使这一点更加具体。

但在接下来的几章中，我们实际上将看看您可能想要对服务器函数做的一些细节，包括与Actix和Axum服务器框架提供的强大提取器集成的最佳方法。