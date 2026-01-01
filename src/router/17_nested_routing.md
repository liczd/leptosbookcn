# 嵌套路由

我们刚刚定义了以下路由集合：

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

这里有一定程度的重复：`/users`和`/users/:id`。对于小应用程序来说这很好，但您可能已经可以看出它不会很好地扩展。如果我们可以嵌套这些路由不是很好吗？

嗯...您可以！

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <ParentRoute path=path!("/users") view=Users>
    <Route path=path!(":id") view=UserProfile/>
  </ParentRoute>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

您可以在`<ParentRoute/>`内嵌套`<Route/>`。看起来很直接。

但是等等。我们刚刚巧妙地改变了我们的应用程序所做的事情。

下一节是本指南整个路由部分中最重要的部分之一。仔细阅读，如果有任何您不理解的地方，请随时提问。

# 嵌套路由作为布局

嵌套路由是一种布局形式，而不是路由定义的方法。

让我换一种说法：定义嵌套路由的目标主要不是为了避免在路由定义中键入路径时重复自己。它实际上是告诉路由器同时在页面上并排显示多个`<Route/>`。

让我们回顾一下我们的实际例子。

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
</Routes>
```

这意味着：

- 如果我转到`/users`，我得到`<Users/>`组件。
- 如果我转到`/users/3`，我得到`<UserProfile/>`组件（参数`id`设置为`3`；稍后会详细介绍）

假设我使用嵌套路由：

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/users") view=Users>
    <Route path=path!(":id") view=UserProfile/>
  </ParentRoute>
</Routes>
```

这意味着：

- 如果我转到`/users/3`，路径匹配两个`<Route/>`：`<Users/>`和`<UserProfile/>`。
- 如果我转到`/users`，路径不匹配。

我实际上需要添加一个fallback路由

```rust
<Routes>
  <ParentRoute path=path!("/users") view=Users>
    <Route path=path!(":id") view=UserProfile/>
    <Route path=path!("") view=NoUser/>
  </ParentRoute>
</Routes>
```

现在：

- 如果我转到`/users/3`，路径匹配`<Users/>`和`<UserProfile/>`。
- 如果我转到`/users`，路径匹配`<Users/>`和`<NoUser/>`。

换句话说，当我使用嵌套路由时，每个**路径**可以匹配多个**路由**：每个URL可以同时在同一页面上渲染多个`<Route/>`组件提供的视图。

这可能是反直觉的，但它非常强大，原因您希望在几分钟内看到。

## 为什么要嵌套路由？

为什么要费心这样做？

大多数Web应用程序包含对应于布局不同部分的导航级别。例如，在电子邮件应用程序中，您可能有一个像`/contacts/greg`这样的URL，它在屏幕左侧显示联系人列表，在屏幕右侧显示Greg的联系人详细信息。联系人列表和联系人详细信息应该始终同时出现在屏幕上。如果没有选择联系人，也许您想显示一些说明文本。

您可以轻松地用嵌套路由定义这个

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/contacts") view=ContactList>
    <Route path=path!(":id") view=ContactInfo/>
    <Route path=path!("") view=|| view! {
      <p>"Select a contact to view more info."</p>
    }/>
  </ParentRoute>
</Routes>
```

您可以走得更深。假设您想为每个联系人的地址、电子邮件/电话和您与他们的对话设置选项卡。您可以在`:id`内添加_另一组_嵌套路由：

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/contacts") view=ContactList>
    <ParentRoute path=path!(":id") view=ContactInfo>
      <Route path=path!("") view=EmailAndPhone/>
      <Route path=path!("address") view=Address/>
      <Route path=path!("messages") view=Messages/>
    </ParentRoute>
    <Route path=path!("") view=|| view! {
      <p>"Select a contact to view more info."</p>
    }/>
  </ParentRoute>
</Routes>
```

> [Remix网站](https://remix.run/)的主页（React Router创建者的React框架）如果您向下滚动，有一个很好的视觉示例，有三个级别的嵌套路由：Sales > Invoices > an invoice。

## `<Outlet/>`

父路由不会自动渲染其嵌套路由。毕竟，它们只是组件；它们不知道应该在哪里渲染其子组件，"只是把它粘在父组件的末尾"不是一个好答案。

相反，您使用`<Outlet/>`组件告诉父组件在哪里渲染任何嵌套组件。`<Outlet/>`简单地渲染两种情况之一：

- 如果没有匹配的嵌套路由，它什么也不显示
- 如果有匹配的嵌套路由，它显示其`view`

就是这样！但重要的是要知道和记住，因为这是"为什么这不工作？"挫折的常见来源。如果您不提供`<Outlet/>`，嵌套路由将不会显示。

```rust
#[component]
pub fn ContactList() -> impl IntoView {
  let contacts = todo!();

  view! {
    <div style="display: flex">
      // 联系人列表
      <For each=contacts
        key=|contact| contact.id
        children=|contact| todo!()
      />
      // 嵌套子项，如果有的话
      // 不要忘记这个！
      <Outlet/>
    </div>
  }
}
```

## 重构路由定义

如果您不想，您不需要在一个地方定义所有路由。您可以将任何`<Route/>`及其子项重构为单独的组件。

例如，您可以重构上面的示例以使用两个单独的组件：

```rust
#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <Routes fallback=|| "Not found.">
          <ParentRoute path=path!("/contacts") view=ContactList>
            <ContactInfoRoutes/>
            <Route path=path!("") view=|| view! {
              <p>"Select a contact to view more info."</p>
            }/>
          </ParentRoute>
        </Routes>
      </Router>
    }
}

#[component(transparent)]
fn ContactInfoRoutes() -> impl MatchNestedRoutes + Clone {
    view! {
      <ParentRoute path=path!(":id") view=ContactInfo>
        <Route path=path!("") view=EmailAndPhone/>
        <Route path=path!("address") view=Address/>
        <Route path=path!("messages") view=Messages/>
      </ParentRoute>
    }
    .into_inner()
}
```

第二个组件是`#[component(transparent)]`，意味着它只返回其数据，而不是视图；同样，它使用`.into_inner()`来删除`view`宏添加的一些调试信息，只返回`<ParentRoute/>`创建的路由定义。

## 嵌套路由和性能

从概念上讲，所有这些都很好，但再次——有什么大不了的？

性能。

在像Leptos这样的细粒度响应式库中，做尽可能少的渲染工作总是很重要的。因为我们使用真实的DOM节点而不是diff虚拟DOM，我们希望尽可能少地"重新渲染"组件。嵌套路由使这变得极其容易。

想象我的联系人列表示例。如果我从Greg导航到Alice到Bob再回到Greg，联系人信息需要在每次导航时更改。但`<ContactList/>`永远不应该重新渲染。这不仅节省了渲染性能，还维护了UI中的状态。例如，如果我在`<ContactList/>`顶部有一个搜索栏，从Greg导航到Alice到Bob不会清除搜索。

实际上，在这种情况下，我们甚至不需要在联系人之间移动时重新渲染`<Contact/>`组件。路由器只会在我们导航时响应式地更新`:id`参数，允许我们进行细粒度更新。当我们在联系人之间导航时，我们将更新单个文本节点以更改联系人的姓名、地址等，而不进行_任何_额外的重新渲染。

> 这个沙盒包括本节和上一节中讨论的几个功能（如嵌套路由），以及我们将在本章其余部分中涵盖的几个功能。路由器是一个如此集成的系统，提供一个单一的示例是有意义的，所以如果有任何您不理解的地方，请不要感到惊讶。

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