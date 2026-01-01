# 附录：Signal的生命周期

在使用Leptos的中级阶段，通常会出现三个问题：
1. 如何连接到组件生命周期，在组件挂载或卸载时运行一些代码？
2. 如何知道signal何时被释放，为什么在尝试访问已释放的signal时偶尔会出现panic？
3. signal如何能够是`Copy`的，并且可以移动到闭包和其他结构中而无需显式克隆？

这三个问题的答案密切相关，每个都有些复杂。本附录将尝试为您提供理解答案的背景，以便您能够正确推理应用程序的代码及其运行方式。

## 组件树 vs. 决策树

考虑以下简单的Leptos应用：

```rust
use leptos::logging::log;
use leptos::prelude::*;

#[component]
pub fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button on:click=move |_| *set_count.write() += 1>"+1"</button>
        {move || if count.get() % 2 == 0 {
            view! { <p>"Even numbers are fine."</p> }.into_any()
        } else {
            view! { <InnerComponent count/> }.into_any()
        }}
    }
}

#[component]
pub fn InnerComponent(count: ReadSignal<usize>) -> impl IntoView {
    Effect::new(move |_| {
        log!("count is odd and is {}", count.get());
    });

    view! {
        <OddDuck/>
        <p>{count}</p>
    }
}

#[component]
pub fn OddDuck() -> impl IntoView {
    view! {
        <p>"You're an odd duck."</p>
    }
}
```

它所做的就是显示一个计数器按钮，如果是偶数则显示一条消息，如果是奇数则显示不同的消息。如果是奇数，它还会在控制台中记录值。

映射这个简单应用程序的一种方法是绘制嵌套组件树：
```
App 
|_ InnerComponent
   |_ OddDuck
```

另一种方法是绘制决策点树：
```
root
|_ is count even?
   |_ yes
   |_ no
```

如果将两者结合起来，您会注意到它们并不完全映射。决策树将我们在`InnerComponent`中创建的视图切分为三个部分，并将`InnerComponent`的一部分与`OddDuck`组件结合：
```
DECISION            COMPONENT           DATA    SIDE EFFECTS
root                <App/>              (count) render <button>
|_ is count even?   <InnerComponent/>
   |_ yes                                       render even <p>
   |_ no                                        start logging the count 
                    <OddDuck/>                  render odd <p> 
                                                render odd <p> (in <InnerComponent/>!)
```

查看这个表格，我注意到以下几点：
1. 组件树和决策树彼此不匹配："count是否为偶数？"决策将`<InnerComponent/>`分为三个部分（一个永不改变的部分，一个偶数部分，一个奇数部分），并将其中一个与`<OddDuck/>`组件合并。
2. 决策树和副作用列表完全对应：每个副作用都在特定的决策点创建。
3. 决策树和数据树也对齐。虽然表格中只有一个signal很难看出，但与组件不同（组件是一个可以包含多个决策或不包含决策的函数），signal总是在决策树的特定行创建。

关键是：数据结构和副作用结构影响应用程序的实际功能。组件结构只是编写的便利。您不关心，也不应该关心哪个组件渲染了哪个`<p>`标签，或哪个组件创建了记录值的effect。重要的是它们在正确的时间发生。

在Leptos中，*组件不存在*。也就是说：您可以将应用程序编写为组件树，因为这很方便，我们提供了一些围绕组件构建的调试工具和日志记录，因为这也很方便。但您的组件在运行时不存在：组件不是变更检测或渲染的单位。它们只是函数调用。您可以在一个大组件中编写整个应用程序，或将其拆分为一百个组件，这不会影响运行时行为，因为组件并不真正存在。

另一方面，决策树*确实存在*。而且它非常重要！

## 决策树、渲染和所有权

每个决策点都是某种响应式语句：一个可以随时间变化的signal或函数。当您将signal或函数传递给渲染器时，它会自动将其包装在一个effect中，该effect订阅它包含的任何signal，并相应地随时间更新视图。

这意味着当您的应用程序被渲染时，它会创建一个完全镜像决策树的嵌套effect树。在伪代码中：
```rust
// root
let button = /* render the <button> once */;

// the renderer wraps an effect around the `move || if count() ...`
Effect::new(|_| {
    if count.get() % 2 == 0 {
        let p = /* render the even <p> */;
    } else {
        // the user created an effect to log the count
        Effect::new(|_| {
            log!("count is odd and is {}", count.get());
        });

        let p1 = /* render the <p> from OddDuck */;
        let p2 = /* render the second <p> */ 

        // the renderer creates an effect to update the second <p>
        Effect::new(|_| {
            // update the content of the <p> with the signal
            p2.set_text_content(count.get());
        });
    }
})
```

每个响应式值都被包装在自己的effect中以更新DOM，或运行signal变化的任何其他副作用。但您不需要这些effect永远运行。例如，当`count`从奇数切换回偶数时，第二个`<p>`不再存在，因此继续更新它的effect不再有用。effect不会永远运行，而是在创建它们的决策发生变化时被取消。换句话说，更准确地说：当创建effect时正在运行的effect重新运行时，effect会被取消。如果它们是在条件分支中创建的，并且重新运行effect通过相同的分支，effect将再次创建：如果不是，则不会。

从响应式系统本身的角度来看，您的应用程序的"决策树"实际上是一个响应式"所有权树"。简单地说，响应式"所有者"是当前正在运行的effect或memo。它拥有在其内部创建的effect，它们拥有自己的子项，依此类推。当effect即将重新运行时，它首先"清理"其子项，然后再次运行。

到目前为止，这个模型与JavaScript框架（如S.js或Solid）中存在的响应式系统共享，其中所有权概念的存在是为了自动取消effect。

Leptos添加的是我们为所有权添加了第二个类似的含义：响应式所有者不仅拥有其子effect，以便它可以取消它们；它还拥有其signal（memo等），以便它可以释放它们。

## 所有权和`Copy` Arena

这是使Leptos能够作为Rust UI框架使用的创新。传统上，在Rust中管理UI状态一直很困难，因为UI都是关于共享可变性的。（一个简单的计数器按钮就足以看出问题：您需要不可变访问来设置显示计数器值的文本节点，以及在点击处理程序中的可变访问，每个Rust UI框架都是围绕Rust旨在防止这种情况而设计的！）在Rust中使用事件处理程序等传统上依赖于通过具有内部可变性的共享内存（`Rc<RefCell<_>>`、`Arc<Mutex<_>>`）或通过通道进行共享内存通信的原语，其中任何一种通常都需要显式`.clone()`才能移动到事件监听器中。这还算可以，但也是一个巨大的不便。

Leptos一直使用signal的arena分配形式。signal本身本质上是保存在其他地方的数据结构的索引。它是一个廉价复制的整数类型，不会自己进行引用计数，因此可以被复制、移动到事件监听器等，而无需显式克隆。

这些signal的生命周期由所有权树确定，而不是Rust生命周期或引用计数。

正如所有effect都属于拥有的父effect，并且当所有者重新运行时子项被取消一样，所有signal也都属于所有者，并且当父项重新运行时被释放。

在大多数情况下，这完全没问题。想象一下，在我们上面的例子中，`<OddDuck/>`创建了一些其他signal，用于更新其UI的一部分。在大多数情况下，该signal将用于该组件中的本地状态，或者可能作为prop传递给另一个组件。它很少被提升到决策树之外并在应用程序的其他地方使用。当`count`切换回偶数时，它不再需要并且可以被释放。

但是，这意味着可能出现两个问题。

### Signal可能在被释放后使用

您持有的`ReadSignal`或`WriteSignal`只是一个整数：比如说，如果它是应用程序中的第3个signal，就是3。（一如既往，现实稍微复杂一些，但不多。）您可以将该数字复制到各处，并用它来说"嘿，给我signal 3。"当所有者清理时，signal 3的*值*将被无效化；但您复制到各处的数字3无法被无效化。（没有整个垃圾收集器是不行的！）这意味着如果您将signal向"上"推回决策树，并将它们存储在概念上比创建它们的地方"更高"的应用程序中的某个地方，它们可能在被释放后被访问。

如果您尝试在signal被释放后*更新*它，实际上不会发生什么坏事。框架只会警告您尝试更新一个不再存在的signal。但如果您尝试*访问*一个，除了panic之外没有连贯的答案：没有可以返回的值。（`.get()`和`.with()`方法有`try_`等价物，如果signal已被释放，它们将简单地返回`None`）。

### 如果您在更高的作用域中创建signal并且从不释放它们，signal可能会泄漏

相反的情况也是如此，特别是在处理signal集合时会出现，比如`RwSignal<Vec<RwSignal<_>>>`。如果您在更高级别创建signal，并将其传递给较低级别的组件，它不会被释放，直到更高级别的所有者被清理。

例如，如果您有一个todo应用程序，为每个todo创建一个新的`RwSignal<Todo>`，将其存储在`RwSignal<Vec<RwSignal<Todo>>>`中，然后将其传递给`<Todo/>`，当您从列表中删除todo时，该signal不会自动释放，而必须手动释放，否则它将在其所有者仍然存活的时间内"泄漏"。（有关更多讨论，请参见[TodoMVC示例](https://github.com/leptos-rs/leptos/blob/main/examples/todomvc/src/lib.rs#L77-L85)。）

这只有在您创建signal、将它们存储在集合中，并从集合中删除它们而不同时手动释放它们时才是问题。

### 使用引用计数Signal解决这些问题

0.7引入了每个arena分配原语的引用计数等价物：对于每个`RwSignal`，都有一个`ArcRwSignal`（`ArcReadSignal`、`ArcWriteSignal`、`ArcMemo`等）。

这些通过引用计数而不是所有权树来管理它们的内存和释放。

这意味着它们可以安全地用于arena分配等价物会被泄漏或在被释放后使用的情况。

这在创建signal集合时特别有用：例如，您可能创建`ArcRwSignal<_>`而不是`RwSignal<_>`，然后在表格的每一行中将其转换为`RwSignal<_>`。

有关更具体的示例，请参见[`counters`示例](https://github.com/leptos-rs/leptos/blob/main/examples/counters/src/lib.rs)中`ArcRwSignal<i32>`的使用。

## 连接各个要点

我们开始时提出的问题的答案现在应该有一些意义了。

### 组件生命周期

没有组件生命周期，因为组件并不真正存在。但有一个所有权生命周期，您可以使用它来完成相同的事情：
- *挂载前*：简单地在组件主体中运行代码将在"组件挂载前"运行它
- *挂载时*：`create_effect`在组件的其余部分之后运行一个tick，因此它对于需要等待视图挂载到DOM的effect很有用。
- *卸载时*：您可以使用`on_cleanup`为响应式系统提供应该在当前所有者清理时运行的代码，在再次运行之前。因为所有者围绕"决策"，这意味着`on_cleanup`将在您的组件卸载时运行：如果某些东西可以卸载，渲染器必须创建一个正在卸载它的effect！

### 已释放Signal的问题

一般来说，只有当您在所有权树的较低位置创建signal并将其存储在较高位置时，才会出现问题。如果您在这里遇到问题，您应该将signal创建"提升"到父级中，然后将创建的signal传递下去——确保在需要时在删除时释放它们！

### `Copy` signal

整个`Copy`able包装器类型系统（signal、`StoredValue`等）使用所有权树作为UI不同部分生命周期的近似。实际上，它将Rust语言基于代码块的生命周期系统与基于UI部分的生命周期系统并行。这不能总是在编译时完美检查，但总的来说我们认为这是一个净正面。
