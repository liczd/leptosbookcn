# 异步渲染和SSR"模式"

服务器渲染仅使用同步数据的页面非常简单：您只需遍历组件树，将每个元素渲染为HTML字符串。但这是一个相当大的警告：它没有回答我们应该如何处理包含异步数据的页面的问题，即在客户端上会在`<Suspense/>`节点下渲染的那种内容。

当页面加载需要渲染的异步数据时，我们应该怎么做？我们应该等待所有异步数据加载，然后一次渲染所有内容吗？（让我们称之为"异步"渲染）我们应该走向完全相反的方向，只是立即将我们拥有的HTML发送到客户端，让客户端加载资源并填充它们吗？（让我们称之为"同步"渲染）或者有一些中间解决方案以某种方式击败它们两个？（提示：有的。）

如果您曾经听过流媒体音乐或在线观看视频，我相信您意识到HTTP支持流式传输，允许单个连接一个接一个地发送数据块，而无需等待完整内容加载。您可能没有意识到浏览器也非常擅长渲染部分HTML页面。综合起来，这意味着您实际上可以通过**流式HTML**来增强用户体验：这是Leptos开箱即用支持的，无需任何配置。实际上有不止一种流式HTML的方法：您可以按顺序流式传输构成页面的HTML块，就像视频帧一样，或者您可以...嗯，无序地流式传输它们。

让我多说一点我的意思。

Leptos支持所有包含异步数据的HTML渲染的主要方式：

1. [同步渲染](#同步渲染)
1. [异步渲染](#异步渲染)
1. [按序流式传输](#按序流式传输)
1. [无序流式传输](#无序流式传输)（和部分阻塞变体）

## 同步渲染

1. **同步**：提供包含任何`<Suspense/>`的`fallback`的HTML外壳。使用`create_local_resource`在客户端加载数据，一旦资源加载就替换`fallback`。

- _优点_：应用外壳出现得非常快：很好的TTFB（首字节时间）。
- _缺点_
  - 资源加载相对较慢；您需要等待JS + WASM加载后才能发出请求。
  - 无法在`<title>`或其他`<meta>`标签中包含来自异步资源的数据，损害SEO和社交媒体链接预览等功能。

如果您使用服务器端渲染，从性能角度来看，同步模式几乎从来不是您真正想要的。这是因为它错过了一个重要的优化。如果您在服务器渲染期间加载异步资源，您实际上可以开始在服务器上加载数据。而不是等待客户端接收HTML响应，然后加载其JS + WASM，_然后_意识到它需要资源并开始加载它们，服务器渲染实际上可以在客户端首次发出响应时开始加载资源。从这个意义上说，在服务器渲染期间，异步资源就像一个在服务器上开始加载并在客户端解析的`Future`。只要资源实际上是可序列化的，这总是会导致更快的总加载时间。

> 这就是为什么`Resource`需要其数据是可序列化的，以及为什么您应该对任何不可序列化的异步数据使用`LocalResource`，因此应该只在浏览器本身中加载。当您可以创建可序列化资源时创建本地资源总是一种去优化。

## 异步渲染

<video controls>
	<source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/async.mov?raw=true" type="video/mp4">
</video>

2. **`async`**：在服务器上加载所有资源。等到所有数据加载完毕，然后一次性渲染HTML。

- _优点_：更好地处理meta标签（因为您甚至在渲染`<head>`之前就知道异步数据）。比**同步**更快的完整加载，因为异步资源在服务器上开始加载。
- _缺点_：较慢的加载时间/TTFB：您需要等待所有异步资源加载后才能在客户端显示任何内容。页面完全空白，直到所有内容加载完毕。

## 按序流式传输

<video controls>
	<source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/in-order.mov?raw=true" type="video/mp4">
</video>

3. **按序流式传输**：遍历组件树，渲染HTML直到遇到`<Suspense/>`。将到目前为止获得的所有HTML作为流中的块发送下去，等待在`<Suspense/>`下访问的所有资源加载，然后将其渲染为HTML并继续遍历，直到遇到另一个`<Suspense/>`或页面结束。

- _优点_：而不是空白屏幕，在数据准备好之前至少显示_某些内容_。
- _缺点_
  - 比同步渲染（或无序流式传输）加载外壳更慢，因为它需要在每个`<Suspense/>`处暂停。
  - 无法显示`<Suspense/>`的fallback状态。
  - 在整个页面加载完毕之前无法开始水合，因此页面的早期部分在挂起的块加载之前不会是交互式的。

## 无序流式传输

<video controls>
	<source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/out-of-order.mov?raw=true" type="video/mp4">
</video>

4. **无序流式传输**：像同步渲染一样，提供包含任何`<Suspense/>`的`fallback`的HTML外壳。但在**服务器**上加载数据，在解析时将其流式传输到客户端，并为`<Suspense/>`节点流式传输HTML，这被交换以替换fallback。

- _优点_：结合了**同步**和**`async`**的最佳特性。
  - 快速的初始响应/TTFB，因为它立即发送整个同步外壳
  - 快速的总时间，因为资源在服务器上开始加载。
  - 能够显示fallback加载状态并动态替换它，而不是为未加载的数据显示空白部分。
- _缺点_：需要启用JavaScript才能使挂起的片段以正确顺序出现。（这个小的JS块与包含渲染的`<Suspense/>`片段的`<template>`标签一起在`<script>`标签中流式传输，因此它不需要加载任何额外的JS文件。）

5. **部分阻塞流式传输**：当您在页面上有多个单独的`<Suspense/>`组件时，"部分阻塞"流式传输很有用。它通过在路由上设置`ssr=SsrMode::PartiallyBlocked`并依赖视图内的阻塞资源来触发。如果其中一个`<Suspense/>`组件从一个或多个"阻塞资源"（见下文）读取，fallback将不会被发送；相反，服务器将等待直到该`<Suspense/>`解析，然后在服务器上用解析的片段替换fallback，这意味着它包含在初始HTML响应中，即使JavaScript被禁用或不支持也会出现。其他`<Suspense/>`无序流入，类似于`SsrMode::OutOfOrder`默认值。

当您在页面上有多个`<Suspense/>`，其中一个比另一个更重要时，这很有用：想想博客文章和评论，或产品信息和评论。如果只有一个`<Suspense/>`，或者每个`<Suspense/>`都从阻塞资源读取，这_不_有用。在这些情况下，它是`async`渲染的较慢形式。

- _优点_：如果JavaScript在用户设备上被禁用或不支持，仍然有效。
- _缺点_
  - 比无序更慢的初始响应时间。
  - 由于服务器上的额外工作，总体响应稍慢。
  - 不显示fallback状态。

## 使用SSR模式

因为它提供了最佳的性能特征组合，Leptos默认为无序流式传输。但选择这些不同模式真的很简单。您通过在一个或多个`<Route/>`组件上添加`ssr`属性来做到这一点，就像在[`ssr_modes`示例](https://github.com/leptos-rs/leptos/blob/main/examples/ssr_modes/src/app.rs)中一样。

```rust
<Routes fallback=|| "Not found.">
	// 我们将使用无序流式传输和<Suspense/>加载主页
	<Route path=path!("") view=HomePage/>

	// 我们将使用异步渲染加载帖子，这样它们可以在
	// 加载数据*之后*设置标题和元数据
	<Route
		path=path!("/post/:id")
		view=BlogPost
		ssr=SsrMode::Async
	/>
</Routes>
```

对于包含多个嵌套路由的路径，将使用最严格的模式：即，如果甚至单个嵌套路由要求`async`渲染，整个初始请求将被`async`渲染。`async`是最严格的要求，其次是按序，然后是无序。（如果您考虑几分钟，这可能是有道理的。）

## 阻塞资源

阻塞资源可以用`Resource::new_blocking`创建。阻塞资源仍然像Rust中的任何其他`async`/`.await`一样异步加载。它不会阻塞服务器线程或类似的东西。相反，在`<Suspense/>`下从阻塞资源读取会阻塞HTML_流_返回任何内容，包括其初始同步外壳，直到该`<Suspense/>`解析。

从性能角度来看，这不是理想的。您页面的同步外壳都不会加载，直到该资源准备好。但是，不渲染任何内容意味着您可以在实际HTML中设置`<head>`中的`<title>`或`<meta>`标签等内容。这听起来很像`async`渲染，但有一个大区别：如果您有多个`<Suspense/>`部分，您可以阻塞_其中一个_，但仍然渲染占位符，然后流入另一个。

例如，想想博客文章。对于SEO和社交分享，我绝对希望我的博客文章标题和元数据在初始HTML `<head>`中。但我真的不关心评论是否已经加载；我想尽可能懒惰地加载它们。

使用阻塞资源，我可以做这样的事情：

```rust
#[component]
pub fn BlogPost() -> impl IntoView {
    let post_data = Resource::new_blocking(/* 加载博客文章 */);
    let comments_data = Resource::new(/* 加载博客评论 */);
    view! {
        <Suspense fallback=|| ()>
            {move || Suspend::new(async move {
                let data = post_data.await;
                view! {
                    <Title text=data.title/>
                    <Meta name="description" content=data.excerpt/>
                    <article>
                        /* 渲染文章内容 */
                    </article>
                }
            })}
        </Suspense>
        <Suspense fallback=|| "Loading comments...">
            {move || Suspend::new(async move {
                let comments = comments_data.await;
                todo!()
            })}
        </Suspense>
    }
}
```

第一个`<Suspense/>`，包含博客文章的正文，将阻塞我的HTML流，因为它从阻塞资源读取。等待阻塞资源的Meta标签和其他head元素将在流发送之前渲染。

结合以下路由定义，使用`SsrMode::PartiallyBlocked`，阻塞资源将在服务器端完全渲染，使禁用WebAssembly或JavaScript的用户可以访问它。

```rust
<Routes fallback=|| "Not found.">
	// 我们将使用无序流式传输和<Suspense/>加载主页
	<Route path=path!("") view=HomePage/>

	// 我们将使用异步渲染加载帖子，这样它们可以在
	// 加载数据*之后*设置标题和元数据
	<Route
		path=path!("/post/:id")
		view=BlogPost
		ssr=SsrMode::PartiallyBlocked
	/>
</Routes>
```

第二个`<Suspense/>`，包含评论，不会阻塞流。阻塞资源给了我优化页面SEO和用户体验所需的确切功能和粒度。