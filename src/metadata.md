# 元数据

到目前为止，我们渲染的所有内容都在 HTML 文档的 `<body>` 内。这是有道理的。毕竟，您在网页上看到的所有内容都存在于 `<body>` 内。

但是，有很多场合您可能想要使用与 UI 相同的响应式原语和组件模式来更新文档 `<head>` 内的某些内容。

这就是 [`leptos_meta`](https://docs.rs/leptos_meta/latest/leptos_meta/) 包的用武之地。

## 元数据组件

`leptos_meta` 提供特殊组件，让您从应用程序中任何地方的组件内部将数据注入到 `<head>` 中：

[`<Title/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Title.html) 允许您从任何组件设置文档的标题。它还接受一个 `formatter` 函数，可用于对其他页面设置的标题应用相同的格式。例如，如果您在 `<App/>` 组件中放置 `<Title formatter=|text| format!("{text} — My Awesome Site")/>`，然后在您的路由上放置 `<Title text="Page 1"/>` 和 `<Title text="Page 2"/>`，您将得到 `Page 1 — My Awesome Site` 和 `Page 2 — My Awesome Site`。

[`<Link/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Link.html) 将 `<link>` 元素注入到 `<head>` 中。

[`<Stylesheet/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Stylesheet.html) 使用您提供的 `href` 创建 `<link rel="stylesheet">`。

[`<Style/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Style.html) 使用您传入的子元素（通常是字符串）创建 `<style>`。您可以使用它在编译时从另一个文件导入一些自定义 CSS `<Style>{include_str!("my_route.css")}</Style>`。

[`<Meta/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Meta.html) 让您设置带有描述和其他元数据的 `<meta>` 标签。

```admonish warning
注意：这些组件应该在应用程序的主体中使用，在组件的某个地方。它们不应该在 `<head>` 中使用（例如，如果您使用服务端渲染）。与其将 `leptos_meta` 组件放入 `<head>` 中，您可以并且应该简单地使用相应的 HTML 元素。
```

## `<Script/>` 和 `<script>`

`leptos_meta` 还提供了一个 [`<Script/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Script.html) 组件，这里值得暂停一下。我们考虑的所有其他组件都在 `<head>` 中注入仅限 `<head>` 的元素。但 `<script>` 也可以包含在 body 中。

有一个非常简单的方法来确定您应该使用大写 S 的 `<Script/>` 组件还是小写 s 的 `<script>` 元素：`<Script/>` 组件将在 `<head>` 中渲染，而 `<script>` 元素将在您将其放置在用户界面 `<body>` 中的任何地方渲染，与其他普通 HTML 元素一起。这些会导致 JavaScript 在不同时间加载和运行，所以使用适合您需求的那个。

## `<Body/>` 和 `<Html/>`

甚至还有几个元素旨在使语义 HTML 和样式更容易。`<Body/>` 和 `<Html/>` 旨在允许您向页面上的 `<html>` 和 `<body>` 标签添加任意属性。您可以在展开运算符（`{..}`）之后使用通常的 Leptos 语法添加任意数量的属性，这些属性将直接添加到适当的元素中。

```rust
<Html
    {..}
    lang="he"
    dir="rtl"
    data-theme="dark"
/>
```

## 元数据和服务端渲染

现在，其中一些在任何场景中都很有用，但其中一些对于搜索引擎优化（SEO）特别重要。确保您有适当的 `<title>` 和 `<meta>` 标签等内容是至关重要的。现代搜索引擎爬虫确实处理客户端渲染，即作为空 `index.html` 发送并完全在 JS/WASM 中渲染的应用程序。但它们更喜欢接收您的应用程序已渲染为实际 HTML 的页面，在 `<head>` 中有元数据。

这正是 `leptos_meta` 的用途。实际上，在服务端渲染期间，这正是它所做的：收集您通过在整个应用程序中使用其组件声明的所有 `<head>` 内容，然后将其注入到实际的 `<head>` 中。

但我有点超前了。我们实际上还没有谈论服务端渲染。下一章将讨论与 JavaScript 库的集成。然后我们将结束客户端的讨论，转向服务端渲染。