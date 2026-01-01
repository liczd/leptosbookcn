# 插曲：样式

任何创建网站或应用程序的人很快就会遇到样式问题。对于小型应用程序，单个 CSS 文件可能足以为您的用户界面设置样式。但随着应用程序的增长，许多开发人员发现普通 CSS 变得越来越难以管理。

一些前端框架（如 Angular、Vue 和 Svelte）提供了内置的方法来将 CSS 限定到特定组件，使得在整个应用程序中管理样式变得更容易，而不会让用于修改一个小组件的样式产生全局影响。其他框架（如 React 或 Solid）不提供内置的 CSS 作用域，而是依赖生态系统中的库来为它们做这件事。Leptos 属于后一阵营：框架本身对 CSS 没有任何意见，但提供了一些工具和原语，允许其他人构建样式库。

以下是为您的 Leptos 应用程序设置样式的几种不同方法，从普通 CSS 开始。

## 普通 CSS

### 使用 Trunk 的客户端渲染

`trunk` 可用于将 CSS 文件和图像与您的站点捆绑在一起。为此，您可以通过在 `<head>` 中的 `index.html` 中定义它们来将它们添加为 Trunk 资产。例如，要添加位于 `style.css` 的 CSS 文件，您可以添加标签 `<link data-trunk rel="css" href="./style.css"/>`。

您可以在 Trunk 文档的[资产](https://trunkrs.dev/assets/)部分找到更多信息。

### 使用 `cargo-leptos` 的服务端渲染

`cargo-leptos` 模板默认配置为使用 SASS 来捆绑 CSS 文件并在 `/pkg/{project_name}.css` 输出它们。如果您想加载额外的 CSS 文件，您可以通过将它们导入到该 `style.scss` 文件中，或者将它们添加到 `public` 目录来做到这一点。（例如，`public/foo.css` 的文件在 `/foo.css` 提供服务。）

要在组件中加载样式表，您可以使用 [`Stylesheet`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Stylesheet.html) 组件。

## TailwindCSS：实用优先的 CSS

[TailwindCSS](https://tailwindcss.com/) 是一个流行的实用优先 CSS 库。它允许您通过使用内联实用类来为应用程序设置样式，使用自定义 CLI 工具扫描您的文件以查找 Tailwind 类名并捆绑必要的 CSS。

这允许您编写这样的组件：

```rust
#[component]
fn Home() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <main class="my-0 mx-auto max-w-3xl text-center">
            <h2 class="p-6 text-4xl">"Welcome to Leptos with Tailwind"</h2>
            <p class="px-10 pb-10 text-left">"Tailwind will scan your Rust files for Tailwind class names and compile them into a CSS file."</p>
            <button
                class="bg-sky-600 hover:bg-sky-700 px-5 py-3 text-white rounded-lg"
                on:click=move |_| *set_count.write() += 1
            >
                {move || if count.get() == 0 {
                    "Click me!".to_string()
                } else {
                    count.get().to_string()
                }}
            </button>
        </main>
    }
}
```

一开始设置 Tailwind 集成可能有点复杂，但您可以查看我们的两个示例，了解如何将 Tailwind 与[客户端渲染的 `trunk` 应用程序](https://github.com/leptos-rs/leptos/tree/main/examples/tailwind_csr)或[服务端渲染的 `cargo-leptos` 应用程序](https://github.com/leptos-rs/leptos/tree/main/examples/tailwind_actix)一起使用。`cargo-leptos` 还有一些[内置的 Tailwind 支持](https://github.com/leptos-rs/cargo-leptos#site-parameters)，您可以将其用作 Tailwind CLI 的替代方案。

## Stylers：编译时 CSS 提取

[Stylers](https://github.com/abishekatp/stylers) 是一个编译时作用域 CSS 库，让您在组件主体中声明作用域 CSS。Stylers 将在编译时将此 CSS 提取到 CSS 文件中，然后您可以将其导入到您的应用程序中，这意味着它不会向您的应用程序的 WASM 二进制大小添加任何内容。

这允许您编写这样的组件：

```rust
use stylers::style;

#[component]
pub fn App() -> impl IntoView {
    let styler_class = style! { "App",
        ##two{
            color: blue;
        }
        div.one{
            color: red;
            content: raw_str(r#"\hello"#);
            font: "1.3em/1.2" Arial, Helvetica, sans-serif;
        }
        div {
            border: 1px solid black;
            margin: 25px 50px 75px 100px;
            background-color: lightblue;
        }
        h2 {
            color: purple;
        }
        @media only screen and (max-width: 1000px) {
            h3 {
                background-color: lightblue;
                color: blue
            }
        }
    };

    view! { class = styler_class,
        <div class="one">
            <h1 id="two">"Hello"</h1>
            <h2>"World"</h2>
            <h2>"and"</h2>
            <h3>"friends!"</h3>
        </div>
    }
}
```

## Stylance：在 CSS 文件中编写的作用域 CSS

Stylers 让您在 Rust 代码中内联编写 CSS，在编译时提取它，并限定其作用域。[Stylance](https://github.com/basro/stylance-rs) 允许您在组件旁边的 CSS 文件中编写 CSS，将这些文件导入到您的组件中，并将 CSS 类限定到您的组件。

这与 `trunk` 和 `cargo-leptos` 的实时重新加载功能配合得很好，因为编辑的 CSS 文件可以立即在浏览器中更新。

```rust
import_style!(style, "app.module.scss");

#[component]
fn HomePage() -> impl IntoView {
    view! {
        <div class=style::jumbotron/>
    }
}
```

您可以直接编辑 CSS 而不会导致 Rust 重新编译。

```css
.jumbotron {
  background: blue;
}
```

## Styled：运行时 CSS 作用域

[Styled](https://github.com/eboody/styled) 是一个与 Leptos 很好集成的运行时作用域 CSS 库。它让您在组件函数主体中声明作用域 CSS，然后在运行时应用这些样式。

```rust
use styled::style;

#[component]
pub fn MyComponent() -> impl IntoView {
    let styles = style!(
      div {
        background-color: red;
        color: white;
      }
    );

    styled::view! { styles,
        <div>"This text should be red with white text."</div>
    }
}
```

## 欢迎贡献

Leptos 对您如何为网站或应用程序设置样式没有意见，但我们很乐意为您试图创建的任何工具提供支持，以使其更容易。如果您正在开发想要添加到此列表中的 CSS 或样式方法，请告诉我们！