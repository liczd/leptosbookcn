# 测试您的组件

测试用户界面可能相对棘手，但非常重要。本文将讨论测试 Leptos 应用程序的几个原则和方法。

## 1. 使用普通的 Rust 测试来测试业务逻辑

在许多情况下，将逻辑从组件中提取出来并单独测试是有意义的。对于一些简单的组件，没有特别的逻辑需要测试，但对于许多组件来说，值得使用可测试的包装类型并在普通的 Rust `impl` 块中实现逻辑。

例如，不要像这样直接在组件中嵌入逻辑：

```rust
#[component]
pub fn TodoApp() -> impl IntoView {
    let (todos, set_todos) = signal(vec![Todo { /* ... */ }]);
    // ⚠️ 这很难测试，因为它嵌入在组件中
    let num_remaining = move || todos.read().iter().filter(|todo| !todo.completed).sum();
}
```

您可以将该逻辑提取到单独的数据结构中并进行测试：

```rust
pub struct Todos(Vec<Todo>);

impl Todos {
    pub fn num_remaining(&self) -> usize {
        self.0.iter().filter(|todo| !todo.completed).sum()
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_remaining() {
        // ...
    }
}

#[component]
pub fn TodoApp() -> impl IntoView {
    let (todos, set_todos) = signal(Todos(vec![Todo { /* ... */ }]));
    // ✅ 这有一个与之关联的测试
    let num_remaining = move || todos.read().num_remaining();
}
```

一般来说，包装在组件本身中的逻辑越少，您的代码就会感觉越符合惯用法，也越容易测试。

## 2. 使用端到端（`e2e`）测试来测试组件

我们的 [`examples`](https://github.com/leptos-rs/leptos/tree/main/examples) 目录有几个使用不同测试工具进行广泛端到端测试的示例。

了解如何使用这些工具的最简单方法是查看测试示例本身：

### 使用 [`counter`](https://github.com/leptos-rs/leptos/blob/main/examples/counter/tests/web.rs) 的 `wasm-bindgen-test`

这是一个相当简单的手动测试设置，使用 [`wasm-pack test`](https://rustwasm.github.io/wasm-pack/book/commands/test.html) 命令。

#### 示例测试

```rust
#[wasm_bindgen_test]
async fn clear() {
    let document = document();
    let test_wrapper = document.create_element("section").unwrap();
    let _ = document.body().unwrap().append_child(&test_wrapper);

    // 首先渲染我们的计数器并将其挂载到 DOM
    // 注意我们从初始值 10 开始
    let _dispose = mount_to(
        test_wrapper.clone().unchecked_into(),
        || view! { <SimpleCounter initial_value=10 step=1/> },
    );

    // 现在我们通过遍历 DOM 来提取按钮
    // 如果它们有 ID 会更容易
    let div = test_wrapper.query_selector("div").unwrap().unwrap();
    let clear = test_wrapper
        .query_selector("button")
        .unwrap()
        .unwrap()
        .unchecked_into::<web_sys::HtmlElement>();

    // 现在让我们点击 `clear` 按钮
    clear.click();

    // 响应式系统建立在异步系统之上，所以更改不会同步反映在 DOM 中
    // 为了在这里检测更改，我们只需在每次更改后短暂让出，
    // 允许更新视图的 effects 运行
    tick().await;

    // 现在让我们根据预期值测试 <div>
    // 我们可以通过测试其 `outerHTML` 来做到这一点
    assert_eq!(div.outer_html(), {
        // 就像我们用值 0 创建它一样，对吧？
        let (value, _set_value) = signal(0);

        // 我们可以移除事件监听器，因为它们不会渲染到 HTML
        view! {
            <div>
                <button>"Clear"</button>
                <button>"-1"</button>
                <span>"Value: " {value} "!"</span>
                <button>"+1"</button>
            </div>
        }
        // Leptos 支持 HTML 元素的多个后端渲染器
        // 这里的 .into_view() 只是指定"使用常规 DOM 渲染器"的便捷方式
        .into_view()
        // views 是惰性的——它们描述 DOM 树但还没有创建它
        // 调用 .build() 将实际构建 DOM 元素
        .build()
        // .build() 返回了一个 ElementState，它是 DOM 元素的智能指针
        // 所以我们仍然可以调用 .outer_html()，它访问实际 DOM 元素上的 outerHTML
        .outer_html()
    });

    // 实际上有一个更简单的方法来做这件事...
    // 我们可以只是针对初始值为 0 的 <SimpleCounter/> 进行测试
    assert_eq!(test_wrapper.inner_html(), {
        let comparison_wrapper = document.create_element("section").unwrap();
        let _dispose = mount_to(
            comparison_wrapper.clone().unchecked_into(),
            || view! { <SimpleCounter initial_value=0 step=1/>},
        );
        comparison_wrapper.inner_html()
    });
}
```

### [使用 `counters` 的 Playwright](https://github.com/leptos-rs/leptos/tree/main/examples/counters/e2e)

这些测试使用常见的 JavaScript 测试工具 Playwright 在同一个示例上运行端到端测试，使用许多前端开发人员熟悉的库和测试方法。

#### 示例测试

```js
test.describe("Increment Count", () => {
  test("should increase the total count", async ({ page }) => {
    const ui = new CountersPage(page);
    await ui.goto();
    await ui.addCounter();

    await ui.incrementCount();
    await ui.incrementCount();
    await ui.incrementCount();

    await expect(ui.total).toHaveText("3");
  });
});
```

### [使用 `todo_app_sqlite` 的 Gherkin/Cucumber 测试](https://github.com/leptos-rs/leptos/blob/main/examples/todo_app_sqlite/e2e/README.md)

您可以将任何您喜欢的测试工具集成到这个流程中。这个示例使用 Cucumber，一个基于自然语言的测试框架。

```
@add_todo
Feature: Add Todo

    Background:
        Given I see the app

    @add_todo-see
    Scenario: Should see the todo
        Given I set the todo as Buy Bread
        When I click the Add button
        Then I see the todo named Buy Bread

    # @allow.skipped
    @add_todo-style
    Scenario: Should see the pending todo
        When I add a todo as Buy Oranges
        Then I see the pending todo
```

这些操作的定义在 Rust 代码中定义。

```rust
use crate::fixtures::{action, world::AppWorld};
use anyhow::{Ok, Result};
use cucumber::{given, when};

#[given("I see the app")]
#[when("I open the app")]
async fn i_open_the_app(world: &mut AppWorld) -> Result<()> {
    let client = &world.client;
    action::goto_path(client, "").await?;

    Ok(())
}

#[given(regex = "^I add a todo as (.*)$")]
#[when(regex = "^I add a todo as (.*)$")]
async fn i_add_a_todo_titled(world: &mut AppWorld, text: String) -> Result<()> {
    let client = &world.client;
    action::add_todo(client, text.as_str()).await?;

    Ok(())
}

// 等等...
```

### 了解更多

请随时查看 Leptos 仓库中的 CI 设置，了解如何在您自己的应用程序中使用这些工具。所有这些测试方法都定期针对实际的 Leptos 示例应用程序运行。