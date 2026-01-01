# 参数和查询

静态路径对于区分不同页面很有用，但几乎每个应用程序都希望在某个时候通过URL传递数据。

您可以通过两种方式做到这一点：

1. 命名路由**参数**，如`/users/:id`中的`id`
2. 命名路由**查询**，如`/search?q=Foo`中的`q`

由于URL的构建方式，您可以从_任何_`<Route/>`视图访问查询。您可以从定义它们的`<Route/>`或其任何嵌套子项访问路由参数。

使用几个hook访问参数和查询非常简单：

- [`use_query`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_query.html)或[`use_query_map`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_query_map.html)
- [`use_params`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_params.html)或[`use_params_map`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_params_map.html)

每个都有一个类型化选项（`use_query`和`use_params`）和一个非类型化选项（`use_query_map`和`use_params_map`）。

非类型化版本保存一个简单的键值映射。要使用类型化版本，在结构体上派生[`Params`](https://docs.rs/leptos_router/latest/leptos_router/params/trait.Params.html) trait。

> `Params`是一个非常轻量级的trait，通过对每个字段应用`FromStr`将字符串的扁平键值映射转换为结构体。由于路由参数和URL查询的扁平结构，它比`serde`等东西灵活性要低得多；它也为您的二进制文件增加的重量要少得多。

```rust
use leptos::Params;
use leptos_router::params::Params;

#[derive(Params, PartialEq)]
struct ContactParams {
    id: Option<usize>,
}

#[derive(Params, PartialEq)]
struct ContactSearch {
    q: Option<String>,
}
```

> 注意：`Params`派生宏位于`leptos_router::params::Params`。
>
> 使用stable，您只能在参数中使用`Option<T>`。如果您使用`nightly`功能，
> 您可以使用`T`或`Option<T>`。

现在我们可以在组件中使用它们。想象一个既有参数又有查询的URL，如`/contacts/:id?q=Search`。

类型化版本返回`Memo<Result<T, _>>`。它是一个`Memo`，所以它对URL的变化做出反应。它是一个`Result`，因为参数或查询需要从URL解析，可能有效也可能无效。

```rust
use leptos_router::hooks::{use_params, use_query};

let params = use_params::<ContactParams>();
let query = use_query::<ContactSearch>();

// id: || -> usize
let id = move || {
    params
        .read()
        .as_ref()
        .ok()
        .and_then(|params| params.id)
        .unwrap_or_default()
};
```

非类型化版本返回`Memo<ParamsMap>`。再次，它是一个`Memo`来对URL的变化做出反应。[`ParamsMap`](https://docs.rs/leptos_router/latest/leptos_router/params/struct.ParamsMap.html)的行为很像任何其他映射类型，有一个返回`Option<String>`的`.get()`方法。

```rust
use leptos_router::hooks::{use_params_map, use_query_map};

let params = use_params_map();
let query = use_query_map();

// id: || -> Option<String>
let id = move || params.read().get("id");
```

这可能会变得有点混乱：派生一个包装`Option<_>`或`Result<_>`的signal可能涉及几个步骤。但这样做是值得的，原因有两个：

1. 它是正确的，即，它强制您考虑这些情况，"如果用户没有为这个查询字段传递值怎么办？如果他们传递无效值怎么办？"
2. 它是高性能的。具体来说，当您在匹配相同`<Route/>`的不同路径之间导航，只有参数或查询发生变化时，您可以对应用程序的不同部分进行细粒度更新而无需重新渲染。例如，在我们的联系人列表示例中在不同联系人之间导航会对名称字段（以及最终的联系人信息）进行有针对性的更新，而无需替换或重新渲染包装的`<Contact/>`。这就是细粒度响应式的用途。

> 这是上一节的相同示例。路由器是一个如此集成的系统，提供一个突出多个功能的单一示例是有意义的，即使我们还没有解释所有功能。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/16-router-0-7-csm8t5?file=%2Fsrc%2Fmain.rs)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/16-router-0-7-csm8t5?file=%2Fsrc%2Fmain.rs" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;
use leptos_router::components::{Outlet, ParentRoute, Route, Router, Routes, A};
use leptos_router::hooks::use_params_map;
use leptos_router::path;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <Router>
            <h1>"Contact App"</h1>
            // 这个<nav>将在每个路由上显示，
            // 因为它在<Routes/>之外
            // 注意：我们可以只使用普通的<a>标签
            // 路由器将使用客户端导航
            <nav>
                <a href="/">"Home"</a>
                <a href="/contacts">"Contacts"</a>
            </nav>
            <main>
                <Routes fallback=|| "Not found.">
                    // / 只有一个非嵌套的"Home"
                    <Route path=path!("/") view=|| view! {
                        <h3>"Home"</h3>
                    }/>
                    // /contacts 有嵌套路由
                    <ParentRoute
                        path=path!("/contacts")
                        view=ContactList
                      >
                        // 如果没有指定id，回退
                        <ParentRoute path=path!(":id") view=ContactInfo>
                            <Route path=path!("") view=|| view! {
                                <div class="tab">
                                    "(Contact Info)"
                                </div>
                            }/>
                            <Route path=path!("conversations") view=|| view! {
                                <div class="tab">
                                    "(Conversations)"
                                </div>
                            }/>
                        </ParentRoute>
                        // 如果没有指定id，回退
                        <Route path=path!("") view=|| view! {
                            <div class="select-user">
                                "Select a user to view contact info."
                            </div>
                        }/>
                    </ParentRoute>
                </Routes>
            </main>
        </Router>
    }
}

#[component]
fn ContactList() -> impl IntoView {
    view! {
        <div class="contact-list">
            // 这里是我们的联系人列表组件本身
            <h3>"Contacts"</h3>
            <div class="contact-list-contacts">
                <A href="alice">"Alice"</A>
                <A href="bob">"Bob"</A>
                <A href="steve">"Steve"</A>
            </div>

            // <Outlet/>将显示嵌套的子路由
            // 我们可以在布局中的任何地方定位这个outlet
            <Outlet/>
        </div>
    }
}

#[component]
fn ContactInfo() -> impl IntoView {
    // 我们可以使用`use_params_map`响应式地访问:id参数
    let params = use_params_map();
    let id = move || params.read().get("id").unwrap_or_default();

    // 想象我们在这里从API加载数据
    let name = move || match id().as_str() {
        "alice" => "Alice",
        "bob" => "Bob",
        "steve" => "Steve",
        _ => "User not found.",
    };

    view! {
        <h4>{name}</h4>
        <div class="contact-info">
            <div class="tabs">
                <A href="" exact=true>"Contact Info"</A>
                <A href="conversations">"Conversations"</A>
            </div>

            // 这里的<Outlet/>是嵌套在
            // /contacts/:id路由下的选项卡
            <Outlet/>
        </div>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>