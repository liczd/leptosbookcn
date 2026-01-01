# 插曲：响应式和函数

我们的一位核心贡献者最近对我说："在开始使用Leptos之前，我从来没有这么频繁地使用闭包。"这是真的。闭包是任何Leptos应用程序的核心。有时看起来有点愚蠢：

```rust
// signal保存一个值，可以被更新
let (count, set_count) = signal(0);

// 派生signal是一个访问其他signal的函数
let double_count = move || count.get() * 2;
let count_is_odd = move || count.get() & 1 == 1;
let text = move || if count_is_odd() {
    "odd"
} else {
    "even"
};

// effect自动跟踪它依赖的signal
// 并在它们改变时重新运行
Effect::new(move |_| {
    logging::log!("text = {}", text());
});

view! {
    <p>{move || text().to_uppercase()}</p>
}
```

到处都是闭包！

但为什么？

## 函数和UI框架

函数是每个UI框架的核心。这完全有道理。创建用户界面基本上分为两个阶段：

1. 初始渲染
2. 更新

在Web框架中，框架进行某种初始渲染。然后它将控制权交还给浏览器。当某些事件触发（如鼠标点击）或异步任务完成（如HTTP请求完成）时，浏览器唤醒框架来更新某些内容。框架运行某种代码来更新您的用户界面，然后回到睡眠状态，直到浏览器再次唤醒它。

这里的关键短语是"运行某种代码"。在任意时间点"运行某种代码"的自然方式——在Rust或任何其他编程语言中——是调用函数。实际上，每个UI框架都基于一遍又一遍地重新运行某种函数：

1. 虚拟DOM（VDOM）框架如React、Yew或Dioxus一遍又一遍地重新运行组件或渲染函数，以生成可以与先前结果协调以修补DOM的虚拟DOM树
2. 编译框架如Angular和Svelte将您的组件模板分为"创建"和"更新"函数，当它们检测到组件状态的变化时重新运行更新函数
3. 在细粒度响应式框架如SolidJS、Sycamore或Leptos中，_您_定义重新运行的函数

这就是我们所有组件正在做的事情。

以最简单形式的典型`<SimpleCounter/>`示例为例：

```rust
#[component]
pub fn SimpleCounter() -> impl IntoView {
    let (value, set_value) = signal(0);

    let increment = move |_| *set_value.write() += 1;

    view! {
        <button on:click=increment>
            {value}
        </button>
    }
}
```

`SimpleCounter`函数本身运行一次。`value` signal创建一次。框架将`increment`函数作为事件监听器交给浏览器。当您点击按钮时，浏览器调用`increment`，它通过`set_value`更新`value`。这更新了我们视图中由`{value}`表示的单个文本节点。

函数是响应式的关键。它们为框架提供了响应变化重新运行应用程序最小可能单元的能力。

所以记住两件事：

1. 您的组件函数是设置函数，不是渲染函数：它只运行一次。
2. 为了让视图模板中的值是响应式的，它们必须是响应式函数：要么是signal，要么是捕获并从signal读取的闭包。

```admonish note
这实际上是Leptos稳定版和nightly版之间的主要区别。如您所知，使用nightly编译器和`nightly`功能允许您直接调用signal作为函数：所以，`value()`而不是`value.get()`。

但这不仅仅是语法糖。它允许一个极其一致的语义模型：响应式的东西是函数。Signal通过调用函数来访问。要说"给我一个signal作为参数"，您可以接受任何`impl Fn() -> T`。这个基于函数的接口在signal、memo和派生signal之间没有区别：任何一个都可以通过将它们作为函数调用来访问。

不幸的是，在像signal这样的任意结构上实现`Fn` trait需要nightly Rust，尽管这个特定功能大多只是停滞不前，不太可能很快改变（或稳定化）。许多人出于这样或那样的原因避免nightly。所以，随着时间的推移，我们已经将文档等内容的默认值转向稳定版。不幸的是，这使得"signal是函数"的简单心理模型不那么直接。
```