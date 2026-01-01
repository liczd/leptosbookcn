# 投影子元素

在构建组件时，您可能偶尔会发现自己想要通过多层组件"投影"子元素。

## 问题

考虑以下情况：

```rust
pub fn NestedShow<F, IV>(fallback: F, children: ChildrenFn) -> impl IntoView
where
    F: Fn() -> IV + Send + Sync + 'static,
    IV: IntoView + 'static,
{
    view! {
        <Show
            when=|| todo!()
            fallback=|| ()
        >
            <Show
                when=|| todo!()
                fallback=fallback
            >
                {children()}
            </Show>
        </Show>
    }
}
```

这非常直接：如果内部条件为 `true`，我们想要显示 `children`。如果不是，我们想要显示 `fallback`。如果外部条件为 `false`，我们只渲染 `()`，即什么都不渲染。

换句话说，我们想要将 `<NestedShow/>` 的子元素_通过_外部 `<Show/>` 组件传递，成为内部 `<Show/>` 的子元素。这就是我所说的"投影"。

这不会编译。

```
error[E0525]: expected a closure that implements the `Fn` trait, but this closure only implements `FnOnce`
```

每个 `<Show/>` 需要能够多次构造其 `children`。第一次构造外部 `<Show/>` 的子元素时，它获取 `fallback` 和 `children` 将它们移动到内部 `<Show/>` 的调用中，但然后它们就不可用于未来的外部 `<Show/>` 子元素构造了。

## 详细信息

> 随时跳到解决方案。

如果您想真正理解这里的问题，查看展开的 `view` 宏可能会有帮助。这是一个清理过的版本：

```rust
Show(
    ShowProps::builder()
        .when(|| todo!())
        .fallback(|| ())
        .children({
            // children 和 fallback 在这里被移动到闭包中
            ::leptos::children::ToChildren::to_children(move || {
                Show(
                    ShowProps::builder()
                        .when(|| todo!())
                        // fallback 在这里被消费
                        .fallback(fallback)
                        .children({
                            // children 在这里被捕获
                            ::leptos::children::ToChildren::to_children(
                                move || children(),
                            )
                        })
                        .build(),
                )
            })
        })
        .build(),
)
```

所有组件都拥有它们的 props；所以在这种情况下 `<Show/>` 不能被调用，因为它只捕获了对 `fallback` 和 `children` 的引用。

## 解决方案

但是，`<Suspense/>` 和 `<Show/>` 都接受 `ChildrenFn`，即它们的 `children` 应该实现 `Fn` 类型，这样它们可以只用不可变引用被多次调用。这意味着我们不需要拥有 `children` 或 `fallback`；我们只需要能够传递对它们的 `'static` 引用。

我们可以通过使用 [`StoredValue`](https://docs.rs/leptos/latest/leptos/reactive/owner/struct.StoredValue.html) 原语来解决这个问题。这本质上将值存储在响应式系统中，将所有权交给框架，换取一个像 signals 一样是 `Copy` 和 `'static` 的引用，我们可以通过某些方法访问或修改它。

在这种情况下，这真的很简单：

```rust
pub fn NestedShow<F, IV>(fallback: F, children: ChildrenFn) -> impl IntoView
where
    F: Fn() -> IV + Send + Sync + 'static,
    IV: IntoView + 'static,
{
    let fallback = StoredValue::new(fallback);
    let children = StoredValue::new(children);

    view! {
        <Show
            when=|| todo!()
            fallback=|| ()
        >
            <Show
                // 通过从 resource 读取来检查用户是否已验证
                when=move || todo!()
                fallback=move || fallback.read_value()()
            >
                {children.read_value()()}
            </Show>
        </Show>
    }
}
```

在顶层，我们将 `fallback` 和 `children` 都存储在 `NestedShow` 拥有的响应式作用域中。现在我们可以简单地将这些引用向下移动通过其他层到 `<Show/>` 组件中并在那里调用它们。

## 最后说明

注意这之所以有效，是因为 `<Show/>` 只需要对其子元素的不可变引用（`.read_value` 可以提供），而不是所有权。

在其他情况下，您可能需要通过一个接受 `ChildrenFn` 的函数投影拥有的 props，因此需要被多次调用。在这种情况下，您可能会发现 `view` 宏中的 `clone:` 助手很有用。

考虑这个示例

```rust
#[component]
pub fn App() -> impl IntoView {
    let name = "Alice".to_string();
    view! {
        <Outer>
            <Inner>
                <Inmost name=name.clone()/>
            </Inner>
        </Outer>
    }
}

#[component]
pub fn Outer(children: ChildrenFn) -> impl IntoView {
    children()
}

#[component]
pub fn Inner(children: ChildrenFn) -> impl IntoView {
    children()
}

#[component]
pub fn Inmost(name: String) -> impl IntoView {
    view! {
        <p>{name}</p>
    }
}
```

即使使用 `name=name.clone()`，这也会给出错误

```
cannot move out of `name`, a captured variable in an `Fn` closure
```

它通过需要运行多次的多层子元素被捕获，并且没有明显的方法将其克隆_到_子元素中。

在这种情况下，`clone:` 语法就派上用场了。调用 `clone:name` 将在将 `name` 移动到 `<Inner/>` 的子元素之前克隆它，这解决了我们的所有权问题。

```rust
view! {
	<Outer>
		<Inner clone:name>
			<Inmost name=name.clone()/>
		</Inner>
	</Outer>
}
```

由于 `view` 宏的不透明性，这些问题可能有点难以理解或调试。但一般来说，它们总是可以解决的。