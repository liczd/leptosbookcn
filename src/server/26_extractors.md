# 提取器

我们在上一章中看到的服务器函数展示了如何在服务器上运行代码，并将其与您在浏览器中渲染的用户界面集成。但它们没有向您展示如何真正充分利用服务器的潜力。

## 服务器框架

我们称Leptos为"全栈"框架，但"全栈"总是用词不当（毕竟，它从来不意味着从浏览器到您的电力公司的一切）。对我们来说，"全栈"意味着您的Leptos应用程序可以在浏览器中运行，可以在服务器上运行，并且可以集成两者，汇集每个中可用的独特功能；正如我们在本书中到目前为止所看到的，浏览器上的按钮点击可以驱动服务器上的数据库读取，两者都写在同一个Rust模块中。但Leptos本身不提供服务器（或数据库，或操作系统，或固件，或电缆...）

相反，Leptos为两个最流行的Rust Web服务器框架提供集成，Actix Web（[`leptos_actix`](https://docs.rs/leptos_actix/latest/leptos_actix/)）和Axum（[`leptos_axum`](https://docs.rs/leptos_axum/latest/leptos_axum/)）。我们已经与每个服务器的路由器构建了集成，以便您可以简单地使用`.leptos_routes()`将Leptos应用程序插入现有服务器，并轻松处理服务器函数调用。

> 如果您还没有看过我们的[Actix](https://github.com/leptos-rs/start-actix)和[Axum](https://github.com/leptos-rs/start-axum)模板，现在是查看它们的好时机。

## 使用提取器

Actix和Axum处理程序都建立在**提取器**的相同强大理念上。提取器从HTTP请求中"提取"类型化数据，允许您轻松访问特定于服务器的数据。

Leptos提供`extract`辅助函数，让您直接在服务器函数中使用这些提取器，语法非常方便，与每个框架的处理程序非常相似。

### Actix提取器

[`leptos_actix`中的`extract`函数](https://docs.rs/leptos_actix/latest/leptos_actix/fn.extract.html)将处理程序函数作为其参数。处理程序遵循与Actix处理程序类似的规则：它是一个异步函数，接收将从请求中提取的参数并返回某个值。处理程序函数接收提取的数据作为其参数，并可以在`async move`块的主体内对它们进行进一步的`async`工作。它返回您返回到服务器函数中的任何值。

```rust
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct MyQuery {
    foo: String,
}

#[server]
pub async fn actix_extract() -> Result<String, ServerFnError> {
    use actix_web::dev::ConnectionInfo;
    use actix_web::web::Query;
    use leptos_actix::extract;

    let (Query(search), connection): (Query<MyQuery>, ConnectionInfo) = extract().await?;
    Ok(format!("search = {search:?}\nconnection = {connection:?}",))
}
```

### Axum提取器

[`leptos_axum::extract`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract.html)函数的语法非常相似。

```rust
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct MyQuery {
    foo: String,
}

#[server]
pub async fn axum_extract() -> Result<String, ServerFnError> {
    use axum::{extract::Query, http::Method};
    use leptos_axum::extract;

    let (method, query): (Method, Query<MyQuery>) = extract().await?;

    Ok(format!("{method:?} and {query:?}"))
}
```

这些是访问服务器基本数据的相对简单的示例。但您可以使用提取器访问标头、cookie、数据库连接池等内容，使用完全相同的`extract()`模式。

Axum `extract`函数仅支持状态为`()`的提取器。如果您需要使用`State`的提取器，您应该使用[`extract_with_state`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract_with_state.html)。这要求您提供状态。您可以通过使用Axum `FromRef`模式扩展现有的`LeptosOptions`状态来做到这一点，该模式在渲染和具有自定义处理程序的服务器函数期间将状态作为上下文提供。

```rust
use axum::extract::FromRef;

/// 派生FromRef以允许状态中的多个项目，使用Axum的
/// SubStates模式。
#[derive(FromRef, Debug, Clone)]
pub struct AppState{
    pub leptos_options: LeptosOptions,
    pub pool: SqlitePool
}
```

[点击这里查看在自定义处理程序中提供上下文的示例](https://github.com/leptos-rs/leptos/blob/19ea6fae6aec2a493d79cc86612622d219e6eebb/examples/session_auth_axum/src/main.rs#L24-L44)。

#### Axum状态

Axum的典型依赖注入模式是提供`State`，然后可以在路由处理程序中提取。Leptos通过上下文提供自己的依赖注入方法。上下文通常可以用来代替`State`来提供共享服务器数据（例如，数据库连接池）。

```rust
let connection_pool = /* 这里是一些共享状态 */;

let app = Router::new()
    .leptos_routes_with_context(
        &leptos_options,
        routes,
        move || provide_context(connection_pool.clone()),
        {
            let leptos_options = leptos_options.clone();
            move || shell(leptos_options.clone())
        },
    )
    // 等等。
```

然后可以在服务器函数内使用简单的`use_context::<T>()`访问此上下文。

如果您_需要_在服务器函数中使用`State`——例如，如果您有一个需要`State`的现有Axum提取器——这也可以使用Axum的[`FromRef`](https://docs.rs/axum/latest/axum/extract/derive.FromRef.html)模式和[`extract_with_state`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract_with_state.html)。基本上，您需要通过上下文和Axum路由器状态提供状态：

```rust
#[derive(FromRef, Debug, Clone)]
pub struct MyData {
    pub value: usize,
    pub leptos_options: LeptosOptions,
}

let app_state = MyData {
    value: 42,
    leptos_options,
};

// 构建我们的应用程序与路由
let app = Router::new()
    .leptos_routes_with_context(
        &app_state,
        routes,
        {
            let app_state = app_state.clone();
            move || provide_context(app_state.clone())
        },
        App,
    )
    .fallback(file_and_error_handler)
    .with_state(app_state);

// ...
#[server]
pub async fn uses_state() -> Result<(), ServerFnError> {
    let state = expect_context::<AppState>();
    let SomeStateExtractor(data) = extract_with_state(&state).await?;
    // todo
}
```

## 关于数据加载模式的说明

因为Actix和（特别是）Axum建立在单次往返HTTP请求和响应的理念上，您通常在应用程序的"顶部"（即，在开始渲染之前）运行提取器，并使用提取的数据来确定应该如何渲染。在渲染`<button>`之前，您加载应用程序可能需要的所有数据。任何给定的路由处理程序都需要知道该路由需要提取的所有数据。

但Leptos集成了客户端和服务器，重要的是能够使用来自服务器的新数据刷新UI的小部分，而不强制完全重新加载所有数据。所以Leptos喜欢将数据加载"向下"推到您的应用程序中，尽可能接近用户界面的叶子。当您点击`<button>`时，它可以只刷新它需要的数据。这正是服务器函数的用途：它们为您提供对要加载和重新加载的数据的细粒度访问。

`extract()`函数让您通过在服务器函数中使用提取器来结合两种模型。您可以访问路由提取器的全部功能，同时将需要提取的内容的知识分散到各个组件中。这使得重构和重新组织路由变得更容易：您不需要预先指定路由需要的所有数据。