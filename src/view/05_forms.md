# 表单和输入

表单和表单输入是交互式应用程序的重要组成部分。在 Leptos 中与输入交互有两种基本模式，如果您熟悉 React、SolidJS 或类似框架，您可能会认识：使用**受控**或**非受控**输入。

## 受控输入

在"受控输入"中，框架控制输入元素的状态。在每个 `input` 事件上，它更新一个保存当前状态的本地 signal，这反过来更新输入的 `value` prop。

有两件重要的事情要记住：

1. `input` 事件在元素的（几乎）每次更改时触发，而 `change` 事件在您取消焦点输入时触发（或多或少）。您可能想要 `on:input`，但我们给您选择的自由。
2. `value` _属性_只设置输入的初始值，即它只在您开始输入之前更新输入。`value` _属性_在那之后继续更新输入。出于这个原因，您通常想要设置 `prop:value`。（对于 `<input type="checkbox">` 上的 `checked` 和 `prop:checked` 也是如此。）

```rust
let (name, set_name) = signal("Controlled".to_string());

view! {
    <input type="text"
        // 添加 :target 给我们对触发事件的元素的类型化访问
        on:input:target=move |ev| {
            // .value() 返回 HTML 输入元素的当前值
            set_name.set(ev.target().value());
        }

        // `prop:` 语法让您更新 DOM 属性，
        // 而不是属性。
        prop:value=name
    />
    <p>"Name is: " {name}</p>
}
```

> #### 为什么需要 `prop:value`？
>
> Web 浏览器是渲染图形用户界面最普遍和稳定的平台。它们在三十年的存在中也保持了令人难以置信的向后兼容性。不可避免地，这意味着有一些怪癖。
>
> 一个奇怪的怪癖是 HTML 属性和 DOM 元素属性之间有区别，即从 HTML 解析并可以使用 `.setAttribute()` 在 DOM 元素上设置的"属性"和作为该解析 HTML 元素的 JavaScript 类表示的字段的"属性"之间的区别。
>
> 在 `<input value=...>` 的情况下，设置 `value` _属性_被定义为设置输入的初始值，设置 `value` _属性_设置其当前值。通过打开 `about:blank` 并在浏览器控制台中逐行运行以下 JavaScript 可能更容易理解这一点：
>
> ```js
> // 创建输入并将其附加到 DOM
> const el = document.createElement("input");
> document.body.appendChild(el);
>
> el.setAttribute("value", "test"); // 更新输入
> el.setAttribute("value", "another test"); // 再次更新输入
>
> // 现在去输入：删除一些字符等
>
> el.setAttribute("value", "one more time?");
> // 什么都不应该改变。设置"初始值"现在什么都不做
>
> // 但是...
> el.value = "But this works";
> ```
>
> 许多其他前端框架混淆属性和属性，或为正确设置值的输入创建特殊情况。也许 Leptos 也应该这样做，但现在，我更喜欢给用户最大程度的控制，让他们决定是设置属性还是属性，并尽我所能教育人们实际的底层浏览器行为，而不是掩盖它。

### 使用 `bind:` 简化受控输入

遵守 Web 标准和"从 signal 读取"和"写入 signal"之间的明确划分是好的，但以这种方式创建受控输入有时可能看起来比真正必要的样板代码更多。

Leptos 还包括一个特殊的 `bind:` 语法，用于允许您自动将 signals 绑定到输入的输入。它们做的事情与上面的"受控输入"模式完全相同：创建一个更新 signal 的事件监听器，以及一个从 signal 读取的动态属性。您可以对文本输入使用 `bind:value`，对复选框使用 `bind:checked`，对单选按钮组使用 `bind:group`。

```rust
let (name, set_name) = signal("Controlled".to_string());
let email = RwSignal::new("".to_string());
let favorite_color = RwSignal::new("red".to_string());
let spam_me = RwSignal::new(true);

view! {
    <input type="text"
        bind:value=(name, set_name)
    />
    <input type="email"
        bind:value=email
    />
    <label>
        "Please send me lots of spam email."
        <input type="checkbox"
            bind:checked=spam_me
        />
    </label>
    <fieldset>
        <legend>"Favorite color"</legend>
        <label>
            "Red"
            <input
                type="radio"
                name="color"
                value="red"
                bind:group=favorite_color
            />
        </label>
        <label>
            "Green"
            <input
                type="radio"
                name="color"
                value="green"
                bind:group=favorite_color
            />
        </label>
        <label>
            "Blue"
            <input
                type="radio"
                name="color"
                value="blue"
                bind:group=favorite_color
            />
        </label>
    </fieldset>
    <p>"Your favorite color is " {favorite_color} "."</p>
    <p>"Name is: " {name}</p>
    <p>"Email is: " {email}</p>
    <Show when=move || spam_me.get()>
        <p>"You'll receive cool bonus content!"</p>
    </Show>
}
```

## 非受控输入

在"非受控输入"中，浏览器控制输入元素的状态。我们不是持续更新 signal 来保存其值，而是使用 [`NodeRef`](https://docs.rs/leptos/latest/leptos/tachys/reactive_graph/node_ref/struct.NodeRef.html) 在我们想要获取其值时访问输入。

在这个示例中，我们只在 `<form>` 触发 `submit` 事件时通知框架。注意使用 [`leptos::html`](https://docs.rs/leptos/latest/leptos/html/index.html) 模块，它为每个 HTML 元素提供了一堆类型。

```rust
let (name, set_name) = signal("Uncontrolled".to_string());

let input_element: NodeRef<html::Input> = NodeRef::new();

view! {
    <form on:submit=on_submit> // on_submit 在下面定义
        <input type="text"
            value=name
            node_ref=input_element
        />
        <input type="submit" value="Submit"/>
    </form>
    <p>"Name is: " {name}</p>
}
```

视图现在应该是相当不言自明的。注意两件事：

1. 与受控输入示例不同，我们使用 `value`（不是 `prop:value`）。这是因为我们只是设置输入的初始值，让浏览器控制其状态。（我们也可以使用 `prop:value`。）
2. 我们使用 `node_ref=...` 来填充 `NodeRef`。（较旧的示例有时使用 `_ref`。它们是同一件事，但 `node_ref` 有更好的 rust-analyzer 支持。）

`NodeRef` 是一种响应式智能指针：我们可以使用它来访问底层 DOM 节点。当元素被渲染时，它的值将被设置。

```rust
let on_submit = move |ev: SubmitEvent| {
    // 阻止页面重新加载！
    ev.prevent_default();

    // 在这里，我们将从输入中提取值
    let value = input_element
        .get()
        // 事件处理程序只能在视图挂载到 DOM 后触发，
        // 所以 `NodeRef` 将是 `Some`
        .expect("<input> should be mounted")
        // `leptos::HtmlElement<html::Input>` 实现 `Deref`
        // 到 `web_sys::HtmlInputElement`。
        // 这意味着我们可以调用 `HtmlInputElement::value()`
        // 来获取输入的当前值
        .value();
    set_name.set(value);
};
```

我们的 `on_submit` 处理程序将访问输入的值并使用它来调用 `set_name.set()`。要访问存储在 `NodeRef` 中的 DOM 节点，我们可以简单地将其作为函数调用（或使用 `.get()`）。这将返回 `Option<leptos::HtmlElement<html::Input>>`，但我们知道元素已经被挂载（否则您如何触发这个事件！），所以在这里解包是安全的。

然后我们可以调用 `.value()` 来从输入中获取值，因为 `NodeRef` 给我们访问正确类型的 HTML 元素。

查看 [`web_sys` 和 `HtmlElement`](../web_sys.md) 了解更多关于使用 `leptos::HtmlElement` 的信息。另外，请参阅本页末尾的完整 CodeSandbox 示例。

## 特殊情况：`<textarea>` 和 `<select>`

两个表单元素往往以不同的方式引起一些混乱。

### `<textarea>`

与 `<input>` 不同，`<textarea>` 元素在 HTML 中不支持 `value` 属性。相反，它接收其初始值作为其 HTML 子元素中的纯文本节点。

所以如果您想要服务器渲染初始值，并且值也在浏览器中响应，您可以既将初始文本节点作为子元素传递给它，又使用 `prop:value` 来设置其当前值。

```rust
view! {
    <textarea
        prop:value=move || some_value.get()
        on:input:target=move |ev| some_value.set(ev.target().value())
    >
        {some_value}
    </textarea>
}
```

### `<select>`

`<select>` 元素同样可以通过 `<select>` 本身的 `value` 属性控制，这将选择具有该值的任何 `<option>`。

```rust
let (value, set_value) = signal(0i32);
view! {
  <select
    on:change:target=move |ev| {
      set_value.set(ev.target().value().parse().unwrap());
    }
    prop:value=move || value.get().to_string()
  >
    <option value="0">"0"</option>
    <option value="1">"1"</option>
    <option value="2">"2"</option>
  </select>
  // 一个将循环选项的按钮
  <button on:click=move |_| set_value.update(|n| {
    if *n == 2 {
      *n = 0;
    } else {
      *n += 1;
    }
  })>
    "Next Option"
  </button>
}
```

```admonish sandbox title="受控与非受控表单 CodeSandbox" collapsible=true

[点击打开 CodeSandbox。](https://codesandbox.io/p/devbox/5-forms-0-7-l5hktg?file=%2Fsrc%2Fmain.rs&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  请启用 JavaScript 查看示例。
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/5-forms-0-7-l5hktg?file=%2Fsrc%2Fmain.rs&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源码</summary>

```rust
use leptos::{ev::SubmitEvent};
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    view! {
        <h2>"Controlled Component"</h2>
        <ControlledComponent/>
        <h2>"Uncontrolled Component"</h2>
        <UncontrolledComponent/>
    }
}

#[component]
fn ControlledComponent() -> impl IntoView {
    // 创建一个 signal 来保存值
    let (name, set_name) = signal("Controlled".to_string());

    view! {
        <input type="text"
            // 每当输入更改时触发事件
            // 在事件后添加 :target 给我们访问
            // ev.target() 处正确类型的元素
            on:input:target=move |ev| {
                set_name.set(ev.target().value());
            }

            // `prop:` 语法让您更新 DOM 属性，
            // 而不是属性。
            //
            // 重要：`value` *属性*只设置
            // 初始值，直到您进行更改。
            // `value` *属性*设置当前值。
            // 这是 DOM 的怪癖；我没有发明它。
            // 其他框架掩盖了这一点；我认为
            // 更重要的是让您访问浏览器
            // 的真实工作方式。
            //
            // 简而言之：对表单输入使用 prop:value
            prop:value=name
        />
        <p>"Name is: " {name}</p>
    }
}

#[component]
fn UncontrolledComponent() -> impl IntoView {
    // 导入 <input> 的类型
    use leptos::html::Input;

    let (name, set_name) = signal("Uncontrolled".to_string());

    // 我们将使用 NodeRef 来存储对输入元素的引用
    // 这将在元素创建时被填充
    let input_element: NodeRef<Input> = NodeRef::new();

    // 当表单 `submit` 事件发生时触发
    // 这将在我们的 signal 中存储 <input> 的值
    let on_submit = move |ev: SubmitEvent| {
        // 阻止页面重新加载！
        ev.prevent_default();

        // 在这里，我们将从输入中提取值
        let value = input_element.get()
            // 事件处理程序只能在视图挂载到 DOM 后触发，
            // 所以 `NodeRef` 将是 `Some`
            .expect("<input> to exist")
            // `NodeRef` 为 DOM 元素类型实现 `Deref`
            // 这意味着我们可以调用 `HtmlInputElement::value()`
            // 来获取输入的当前值
            .value();
        set_name.set(value);
    };

    view! {
        <form on:submit=on_submit>
            <input type="text"
                // 在这里，我们使用 `value` *属性*只设置
                // 初始值，让浏览器在那之后维护状态
                value=name

                // 在 `input_element` 中存储对此输入的引用
                node_ref=input_element
            />
            <input type="submit" value="Submit"/>
        </form>
        <p>"Name is: " {name}</p>
    }
}

// 这个 `main` 函数是应用程序的入口点
// 它只是将我们的组件挂载到 <body>
// 因为我们将其定义为 `fn App`，我们现在可以在
// 模板中使用它作为 <App/>
fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>