# 定义路由

## 开始使用

使用路由器很容易上手。

首先，确保您已将`leptos_router`包添加到您的依赖项中。与`leptos`不同，这没有单独的`csr`和`hydrate`功能；它确实有一个`ssr`功能，仅用于服务器端，因此为您的服务器端构建激活它。

> 路由器是与`leptos`本身分离的包，这很重要。这意味着路由器中的所有内容都可以在用户代码中定义。如果您想创建自己的路由器，或不使用路由器，您完全可以自由地这样做！

并从路由器导入相关类型，例如

```rust
use leptos_router::components::{Router, Route, Routes};
```

## 提供`<Router/>`

路由行为由[`<Router/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Router.html)组件提供。这通常应该在应用程序的根部附近，包装应用程序的其余部分。

> 您不应该尝试在应用程序中使用多个`<Router/>`。记住路由器驱动全局状态：如果您有多个路由器，当URL更改时哪一个决定要做什么？

让我们从使用路由器的简单`<App/>`组件开始：

```rust
use leptos::prelude::*;
use leptos_router::components::Router;

#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <nav>
          /* ... */
        </nav>
        <main>
          /* ... */
        </main>
      </Router>
    }
}

```

## 定义`<Routes/>`

[`<Routes/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Routes.html)组件是您定义用户可以在应用程序中导航到的所有路由的地方。每个可能的路由都由[`<Route/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Route.html)组件定义。

您应该将`<Routes/>`组件放置在应用程序中希望渲染路由的位置。`<Routes/>`之外的所有内容都将出现在每个页面上，因此您可以将导航栏或菜单等内容留在`<Routes/>`之外。

```rust
use leptos::prelude::*;
use leptos_router::components::*;

#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <nav>
          /* ... */
        </nav>
        <main>
          // 我们所有的路由都将出现在<main>内
          <Routes fallback=|| "Not found.">
            /* ... */
          </Routes>
        </main>
      </Router>
    }
}
```

`<Routes/>`还应该有一个`fallback`，一个定义如果没有路由匹配时应该显示什么的函数。

单个路由通过使用`<Route/>`组件为`<Routes/>`提供子元素来定义。`<Route/>`接受`path`和`view`。当当前位置匹配`path`时，将创建并显示`view`。

`path`最容易使用`path`宏定义，可以包括

- 静态路径（`/users`），
- 以冒号开头的动态命名参数（`/:id`），
- 和/或以星号开头的通配符（`/user/*any`）

`view`是返回视图的函数。任何没有props的组件都可以在这里工作，返回某些视图的闭包也可以。

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

> `view`接受`Fn() -> impl IntoView`。如果组件没有props，它可以直接传递到`view`中。在这种情况下，`view=Home`只是`view=|| view! { <Home/> }`的简写。

现在，如果您导航到`/`或`/users`，您将获得主页或`<Users/>`。如果您转到`/users/3`或`/blahblah`，您将获得用户配置文件或您的404页面（`<NotFound/>`）。在每次导航时，路由器确定应该匹配哪个`<Route/>`，因此应该在定义`<Routes/>`组件的位置显示什么内容。

够简单吧？