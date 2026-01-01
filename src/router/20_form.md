# `<Form/>`组件

链接和表单有时看起来完全不相关。但实际上，它们的工作方式非常相似。

在纯HTML中，有三种导航到另一个页面的方法：

1. 链接到另一个页面的`<a>`元素：使用`GET` HTTP方法导航到其`href`属性中的URL。
2. `<form method="GET">`：使用`GET` HTTP方法导航到其`action`属性中的URL，并将其输入的表单数据编码在URL查询字符串中。
3. `<form method="POST">`：使用`POST` HTTP方法导航到其`action`属性中的URL，并将其输入的表单数据编码在请求正文中。

由于我们有客户端路由器，我们可以进行客户端链接导航而不重新加载页面，即，不需要完整的往返服务器。以同样的方式进行客户端表单导航是有意义的。

路由器提供了一个[`<Form>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Form.html)组件，它像HTML `<form>`元素一样工作，但使用客户端导航而不是完整的页面重新加载。`<Form/>`与`GET`和`POST`请求都兼容。使用`method="GET"`，它将导航到表单数据中编码的URL。使用`method="POST"`，它将发出`POST`请求并处理服务器的响应。

`<Form/>`为我们将在后面章节中看到的一些组件（如`<ActionForm/>`和`<MultiActionForm/>`）提供了基础。但它也启用了一些强大的模式。

例如，想象您想创建一个搜索字段，在用户搜索时实时更新搜索结果，无需页面重新加载，但也将搜索存储在URL中，以便用户可以复制并粘贴它与其他人分享结果。

事实证明，我们到目前为止学到的模式使这很容易实现。

```rust
async fn fetch_results() {
    // 一些异步函数来获取我们的搜索结果
}

#[component]
pub fn FormExample() -> impl IntoView {
    // 对URL查询字符串的响应式访问
    let query = use_query_map();
    // 搜索存储为?q=
    let search = move || query.read().get("q").unwrap_or_default();
    // 由搜索字符串驱动的资源
    let search_results = Resource::new(search, |_| fetch_results());

    view! {
        <Form method="GET" action="">
            <input type="search" name="q" value=search/>
            <input type="submit"/>
        </Form>
        <Transition fallback=move || ()>
            /* 渲染搜索结果 */
            {todo!()}
        </Transition>
    }
}
```

每当您点击`Submit`时，`<Form/>`将"导航"到`?q={search}`。但因为这种导航是在客户端完成的，所以没有页面闪烁或重新加载。URL查询字符串更改，这触发`search`更新。因为`search`是`search_results`资源的源signal，这触发`search_results`重新加载其资源。`<Transition/>`继续显示当前搜索结果，直到新结果加载完成。当它们完成时，它切换到显示新结果。

这是一个很好的模式。数据流极其清晰：所有数据从URL流向资源再流向UI。应用程序的当前状态存储在URL中，这意味着您可以刷新页面或将链接发送给朋友，它将显示您期望的内容。一旦我们引入服务器渲染，这种模式也将被证明是真正容错的：因为它在底层使用`<form>`元素和URL，即使不在客户端加载您的WASM，它实际上也能很好地工作。

我们实际上可以更进一步，做一些聪明的事情：

```rust
view! {
	<Form method="GET" action="">
		<input type="search" name="q" value=search
			oninput="this.form.requestSubmit()"
		/>
	</Form>
}
```

您会注意到这个版本删除了`Submit`按钮。相反，我们向输入添加了一个`oninput`属性。注意这_不是_`on:input`，它会监听`input`事件并运行一些Rust代码。没有冒号，`oninput`是纯HTML属性。所以字符串实际上是JavaScript字符串。`this.form`给我们输入附加到的表单。`requestSubmit()`在`<form>`上触发`submit`事件，它被`<Form/>`捕获，就像我们点击了`Submit`按钮一样。现在表单将在每次按键或输入时"导航"，以保持URL（因此搜索）与用户输入在他们键入时完全同步。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/20-form-0-7-m73jsz)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/20-form-0-7-m73jsz" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;
use leptos_router::components::{Form, Route, Router, Routes};
use leptos_router::hooks::use_query_map;
use leptos_router::path;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <Router>
            <h1><code>"<Form/>"</code></h1>
            <main>
                <Routes fallback=|| "Not found.">
                    <Route path=path!("") view=FormExample/>
                </Routes>
            </main>
        </Router>
    }
}

#[component]
pub fn FormExample() -> impl IntoView {
    // 对URL查询的响应式访问
    let query = use_query_map();
    let name = move || query.read().get("name").unwrap_or_default();
    let number = move || query.read().get("number").unwrap_or_default();
    let select = move || query.read().get("select").unwrap_or_default();

    view! {
        // 读取URL查询字符串
        <table>
            <tr>
                <td><code>"name"</code></td>
                <td>{name}</td>
            </tr>
            <tr>
                <td><code>"number"</code></td>
                <td>{number}</td>
            </tr>
            <tr>
                <td><code>"select"</code></td>
                <td>{select}</td>
            </tr>
        </table>
        // <Form/>将在提交时导航
        <h2>"Manual Submission"</h2>
        <Form method="GET" action="">
            // 输入名称确定查询字符串键
            <input type="text" name="name" value=name/>
            <input type="number" name="number" value=number/>
            <select name="select">
                // `selected`将设置哪个开始被选中
                <option selected=move || select() == "A">
                    "A"
                </option>
                <option selected=move || select() == "B">
                    "B"
                </option>
                <option selected=move || select() == "C">
                    "C"
                </option>
            </select>
            // 提交应该导致客户端导航，
            // 而不是完整重新加载
            <input type="submit"/>
        </Form>
        // 这个<Form/>使用一些JavaScript在
        // 每次输入时提交
        <h2>"Automatic Submission"</h2>
        <Form method="GET" action="">
            <input
                type="text"
                name="name"
                value=name
                // 这个oninput属性将导致表单
                // 在每次输入字段时提交
                oninput="this.form.requestSubmit()"
            />
            <input
                type="number"
                name="number"
                value=number
                oninput="this.form.requestSubmit()"
            />
            <select name="select"
                onchange="this.form.requestSubmit()"
            >
                <option selected=move || select() == "A">
                    "A"
                </option>
                <option selected=move || select() == "B">
                    "B"
                </option>
                <option selected=move || select() == "C">
                    "C"
                </option>
            </select>
            // 提交应该导致客户端导航，
            // 而不是完整重新加载
            <input type="submit"/>
        </Form>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>