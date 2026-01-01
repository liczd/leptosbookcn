# 附录：响应式系统是如何工作的？

为了成功使用库，您不需要了解响应式系统实际如何工作的太多细节。但是，一旦您开始在高级水平上使用框架，了解幕后发生的事情总是有用的。

您使用的响应式原语分为三组：

- **Signal**（`ReadSignal`/`WriteSignal`、`RwSignal`、`Resource`、`Trigger`）您可以主动更改以触发响应式更新的值。
- **计算**（`Memo`）依赖于signal（或其他计算）并通过一些纯计算派生新响应式值的值。
- **Effect** 监听某些signal或计算中的变化并运行函数，产生一些副作用的观察者。

派生signal是一种非原语计算：作为普通闭包，它们只是允许您将一些重复的基于signal的计算重构为可重用的函数，可以在多个地方调用，但它们在响应式系统本身中不被表示。

所有其他原语实际上作为响应式图中的节点存在于响应式系统中。

响应式系统的大部分工作包括将变化从signal传播到effect，可能通过一些中间的memo。

响应式系统的假设是effect（如渲染到DOM或发出网络请求）比应用程序内部更新Rust数据结构等事情昂贵几个数量级。

因此，响应式系统的**主要目标**是**尽可能少地运行effect**。

Leptos通过构建响应式图来做到这一点。

> Leptos当前的响应式系统很大程度上基于JavaScript的[Reactively](https://github.com/modderme123/reactively)库。您可以阅读Milo的文章"[Super-Charging Fine-Grained Reactivity](https://dev.to/modderme123/super-charging-fine-grained-reactive-performance-47ph)"，了解其算法的出色描述，以及细粒度响应式的一般情况——包括一些漂亮的图表！

## 响应式图

Signal、memo和effect都共享三个特征：

- **值** 它们有一个当前值：要么是signal的值，要么是（对于memo和effect）前一次运行返回的值（如果有的话）。
- **源** 它们依赖的任何其他响应式原语。（对于signal，这是一个空集。）
- **订阅者** 依赖于它们的任何其他响应式原语。（对于effect，这是一个空集。）

实际上，signal、memo和effect只是响应式图中"节点"这一通用概念的常规名称。Signal总是"根节点"，没有源/父节点。Effect总是"叶节点"，没有订阅者。Memo通常既有源又有订阅者。

> 在以下示例中，我将使用`nightly`语法，只是为了减少这个供您阅读而不是复制粘贴的文档中的冗长！

### 简单依赖

想象以下代码：

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
Effect::new(move |_| {
	log!("{}", name_upper());
});

set_name("Bob");
```

您可以轻松想象这里的响应式图：`name`是唯一的signal/起源节点，`Effect::new`是唯一的effect/终端节点，中间有一个memo。

```
A   (name)
|
B   (name_upper)
|
C   (the effect)
```

### 分支拆分

让我们让它稍微复杂一些。

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
let name_len = Memo::new(move |_| name.len());

// D
Effect::new(move |_| {
	log!("len = {}", name_len());
});

// E
Effect::new(move |_| {
	log!("name = {}", name_upper());
});
```

这也很直接：一个signal源signal（`name`/`A`）分为两个并行轨道：`name_upper`/`B`和`name_len`/`C`，每个都有一个依赖于它的effect。

```
 __A__
|     |
B     C
|     |
E     D
```

现在让我们更新signal。

```rust
set_name("Bob");
```

我们立即记录

```
len = 3
name = BOB
```

让我们再做一次。

```rust
set_name("Tim");
```

日志应该显示

```
name = TIM
```

`len = 3`不会再次记录。

记住：响应式系统的目标是尽可能少地运行effect。将`name`从`"Bob"`更改为`"Tim"`将导致每个memo重新运行。但它们只有在值实际发生变化时才会通知其订阅者。`"BOB"`和`"TIM"`是不同的，所以该effect再次运行。但两个名称的长度都是`3`，所以它们不会再次运行。

### 重新合并分支

再举一个例子，有时称为**钻石问题**。

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
let name_len = Memo::new(move |_| name.len());

// D
Effect::new(move |_| {
	log!("{} is {} characters long", name_upper(), name_len());
});
```

这个图看起来是什么样的？

```
 __A__
|     |
B     C
|     |
|__D__|
```

您可以看到为什么它被称为"钻石问题"。如果我用直线而不是糟糕的ASCII艺术连接节点，它会形成一个钻石：两个memo，每个都依赖于一个signal，它们都输入到同一个effect中。

一个天真的、基于推送的响应式实现会导致这个effect运行两次，这会很糟糕。（记住，我们的目标是尽可能少地运行effect。）例如，您可以实现一个响应式系统，使得signal和memo立即将其变化一直传播到图的下方，通过每个依赖项，本质上是深度优先遍历图。换句话说，更新`A`会通知`B`，然后`B`会通知`D`；然后`A`会通知`C`，然后`C`会再次通知`D`。这既低效（`D`运行两次）又有故障（`D`实际上在第一次运行期间使用第二个memo的不正确值运行）。

## 解决钻石问题

任何值得称道的响应式实现都致力于解决这个问题。有许多不同的方法（再次，[参见Milo的文章](https://dev.to/modderme123/super-charging-fine-grained-reactive-performance-47ph)以获得出色的概述）。

以下是我们的工作方式，简而言之。

响应式节点总是处于三种状态之一：

- `Clean`：已知没有改变
- `Check`：可能已经改变
- `Dirty`：肯定已经改变

更新signal `Dirty`将该signal标记为`Dirty`，并递归地将其所有后代标记为`Check`。其任何作为effect的后代都会被添加到队列中以重新运行。

```
    ____A (DIRTY)___
   |               |
B (CHECK)    C (CHECK)
   |               |
   |____D (CHECK)__|
```

现在运行这些effect。（此时所有effect都将被标记为`Check`。）在重新运行其计算之前，effect检查其父节点是否脏。

- 所以`D`去`B`并检查它是否是`Dirty`。
- 但`B`也被标记为`Check`。所以`B`做同样的事情：
  - `B`去`A`，发现它是`Dirty`。
  - 这意味着`B`需要重新运行，因为它的一个源已经改变。
  - `B`重新运行，生成一个新值，并将自己标记为`Clean`
  - 因为`B`是一个memo，它然后检查其先前值与新值。
  - 如果它们相同，`B`返回"没有变化"。否则，它返回"是的，我改变了"。
- 如果`B`返回"是的，我改变了"，`D`知道它肯定需要运行，并在检查任何其他源之前立即重新运行。
- 如果`B`返回"不，我没有改变"，`D`继续检查`C`（参见上面`B`的过程）。
- 如果`B`和`C`都没有改变，effect不需要重新运行。
- 如果`B`或`C`中的任何一个确实改变了，effect现在重新运行。

因为effect只被标记为`Check`一次，只排队一次，所以它只运行一次。

如果天真版本是"基于推送"的响应式系统，简单地将响应式变化一直推送到图的下方，因此运行effect两次，这个版本可以称为"推拉"。它将`Check`状态一直推送到图的下方，但然后"拉"回上方。实际上，对于大图，它可能最终在图上来回弹跳，左右弹跳，试图确定哪些节点需要重新运行。

**注意这个重要的权衡**：基于推送的响应式更快地传播signal变化，但代价是过度重新运行memo和effect。记住：响应式系统旨在最小化您重新运行effect的频率，基于（准确的）假设，即副作用比完全在库的Rust代码内部发生的这种缓存友好的图遍历昂贵几个数量级。一个好的响应式系统的衡量标准不是它传播变化的速度，而是它传播变化的速度_而不过度通知_。

## Memo vs. Signal

注意signal总是通知其子节点；即，signal在更新时总是被标记为`Dirty`，即使其新值与旧值相同。否则，我们必须在signal上要求`PartialEq`，这在某些类型上实际上是相当昂贵的检查。（例如，当很明显它确实已经改变时，向`some_vec_signal.update(|n| n.pop())`这样的东西添加不必要的相等检查。）

另一方面，Memo在通知其子节点之前检查它们是否改变。无论您`.get()`结果多少次，它们只运行一次计算，但每当其signal源改变时它们就会运行。这意味着如果memo的计算_非常_昂贵，您可能实际上也想要记忆化其输入，以便memo只有在确定其输入已改变时才重新计算。

## Memo vs. 派生Signal

所有这些都很酷，memo非常棒。但大多数实际应用程序的响应式图相当浅且相当宽：您可能有100个源signal和500个effect，但没有memo，或者在罕见情况下，signal和effect之间有三或四个memo。Memo在它们所做的事情上极其出色：限制它们通知订阅者它们已经改变的频率。但正如对响应式系统的这种描述应该显示的那样，它们带来两种形式的开销：

1. `PartialEq`检查，可能昂贵也可能不昂贵。
2. 在响应式系统中存储另一个节点的额外内存成本。
3. 响应式图遍历的额外计算成本。

在计算本身比这种响应式工作更便宜的情况下，您应该避免用memo"过度包装"，而只是使用派生signal。这是一个您永远不应该使用memo的很好例子：

```rust
let (a, set_a) = signal(1);
// 这些都不适合作为memo
let b = move || a() + 2;
let c = move || b() % 2 == 0;
let d = move || if c() { "even" } else { "odd" };

set_a(2);
set_a(3);
set_a(5);
```

即使记忆化在技术上会在将`a`设置为`3`和`5`之间节省`d`的额外计算，这些计算本身比响应式算法更便宜。

最多，您可能考虑在运行一些昂贵的副作用之前记忆化最终节点：

```rust
let text = Memo::new(move |_| {
    d()
});
Effect::new(move |_| {
    engrave_text_into_bar_of_gold(&text());
});
```