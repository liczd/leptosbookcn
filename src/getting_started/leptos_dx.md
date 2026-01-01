# Leptos开发者体验改进

您可以做几件事来改善使用Leptos开发网站和应用程序的体验。您可能想花几分钟时间设置您的环境以优化您的开发体验，特别是如果您想跟着本书中的示例一起编码。

## 1) 设置`console_error_panic_hook`

默认情况下，在浏览器中运行WASM代码时发生的panic只会在浏览器中抛出一个错误，显示像`Unreachable executed`这样的无用消息和指向您的WASM二进制文件的堆栈跟踪。

使用`console_error_panic_hook`，您可以获得包含Rust源代码中行的实际Rust堆栈跟踪。

设置非常简单：

1. 在您的项目中运行`cargo add console_error_panic_hook`
2. 在您的main函数中，添加`console_error_panic_hook::set_once();`

> 如果这不清楚，[点击这里查看示例](https://github.com/leptos-rs/leptos/blob/main/examples/counter/src/main.rs#L6)。

现在您应该在浏览器控制台中有更好的panic消息！

## 2) 在`#[component]`和`#[server]`内的编辑器自动完成

由于宏的性质（它们可以从任何东西扩展到任何东西，但只有在输入在那个瞬间完全正确时），rust-analyzer很难进行适当的自动完成和其他支持。

如果您在编辑器中使用这些宏时遇到问题，您可以明确告诉rust-analyzer忽略某些过程宏。特别是对于`#[server]`宏，它注释函数体但实际上不转换函数体内的任何内容，这可能非常有帮助。

```admonish note 
从Leptos版本0.5.3开始，为`#[component]`宏添加了rust-analyzer支持，但如果您遇到问题，您可能也想将`#[component]`添加到宏忽略列表中（见下文）。
请注意，这意味着rust-analyzer不知道您的组件props，这可能在IDE中生成自己的错误或警告集。
```

VSCode `settings.json`：

```json
"rust-analyzer.procMacro.ignored": {
	"leptos_macro": [
        // 可选：
		// "component",
		"server"
	],
}
```

VSCode with cargo-leptos `settings.json`：
```json
"rust-analyzer.procMacro.ignored": {
	"leptos_macro": [
        // 可选：
		// "component",
		"server"
	],
},
// 如果为`ssr`功能cfg-gated的代码显示为非活动状态，
// 您可能想告诉rust-analyzer默认启用`ssr`功能
//
// 您也可以使用`rust-analyzer.cargo.allFeatures`来启用所有功能
"rust-analyzer.cargo.features": ["ssr"]
```

Neovim：

```lua
vim.lsp.config('rust_analyzer', {
  -- Other Configs ...
  settings = {
    ["rust-analyzer"] = {
      -- Other Settings ...
      procMacro = {
        ignored = {
          leptos_macro = {
            -- 可选： --
            -- "component",
            "server",
          },
        },
      },
    },
  }
})
```

Helix，在`.helix/languages.toml`中：

```toml
[[language]]
name = "rust"

[language-server.rust-analyzer]
config = { procMacro = { ignored = { leptos_macro = [
	# 可选：
	# "component",
	"server"
] } } }
```

Zed，在`settings.json`中：

```json
{
  -- Other Settings ...
  "lsp": {
    "rust-analyzer": {
      "procMacro": {
        "ignored": [
          // 可选：
          // "component",
          "server"
        ]
      }
    }
  }
}
```

SublimeText 3，在`Goto Anything...`菜单下的`LSP-rust-analyzer.sublime-settings`中：

```json
// 这里的设置覆盖"LSP-rust-analyzer/LSP-rust-analyzer.sublime-settings"中的设置
{
  "rust-analyzer.procMacro.ignored": {
    "leptos_macro": [
      // 可选：
      // "component",
      "server"
    ],
  },
}
```

## 3) 在编辑器的Rust-Analyzer中启用功能（可选）
默认情况下，rust-analyzer只会针对Rust项目中的默认功能运行。Leptos使用不同的功能来控制编译。对于客户端渲染项目，我们在不同地方使用`csr`，对于服务器端渲染应用程序，它们可以包括用于服务器代码的`ssr`和用于我们只在浏览器中运行的代码的`hydrate`。

如何启用这些功能因您的IDE而异，我们在下面列出了一些常见的。如果您的IDE未列出，您通常可以通过搜索`rust-analyzer.cargo.features`或`rust-analyzer.cargo.allFeatures`找到设置。

VSCode，在`settings.json`中：
```json
{
  "rust-analyzer.cargo.features": "all",  // 启用所有功能
}
```

Neovim，在`init.lua`中：
```lua
vim.lsp.config('rust_analyzer', {
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        features = "all", -- 启用所有功能
      },
    },
  }
})

```
helix，在`.helix/languages.toml`或每个项目的`.helix/config.toml`中：
```toml
[[language]]
name = "rust"

[language-server.rust-analyzer.config.cargo]
allFeatures = true
```

Zed，在`settings.json`中：

```json
{
  -- Other Settings ...
  "lsp": {
    "rust-analyzer": {
      "initialization_options": {
        "cargo": {
          "allFeatures": true // 启用所有功能
        }
      }
	}
  }
}
```

SublimeText 3，在LSP-rust-analyzer-settings.json的用户设置中：
```json
 {
        "settings": {
            "LSP": {
                "rust-analyzer": {
                    "settings": {
                        "cargo": {
                            "features": "all"
                        }
                    }
                }
            }
        }
    }
```

## 4) 设置`leptosfmt`（可选）

`leptosfmt`是Leptos `view!`宏的格式化程序（您通常会在其中编写UI代码）。因为`view!`宏启用了编写UI的'RSX'（类似JSX）风格，cargo-fmt在自动格式化`view!`宏内的代码时遇到困难。`leptosfmt`是一个解决格式化问题并保持RSX风格UI代码看起来美观整洁的crate！

`leptosfmt`可以通过命令行或从代码编辑器内安装和使用：

首先，使用`cargo install leptosfmt`安装工具。

如果您只想从命令行使用默认选项，只需从项目根目录运行`leptosfmt ./**/*.rs`来使用`leptosfmt`格式化所有rust文件。

### 在Rust Analyzer IDE中自动运行

如果您希望设置编辑器与`leptosfmt`一起工作，或者如果您希望自定义您的`leptosfmt`体验，请参见[`leptosfmt` github repo的README.md页面](https://github.com/bram209/leptosfmt)上提供的说明。

只需注意，建议在每个工作区的基础上设置您的编辑器与`leptosfmt`以获得最佳结果。

### 在RustRover中自动运行

不幸的是，RustRover不支持Rust Analyzer，因此需要不同的方法来自动运行`leptosfmt`。一种方法是使用[FileWatchers](https://plugins.jetbrains.com/plugin/7177-file-watchers)插件，配置如下：

- Name: Leptosfmt
- File type: Rust files
- Program: `/path/to/leptosfmt`（如果它在您的`$PATH`环境变量中，可以简单地是`leptosfmt`）
- Arguments: `$FilePath$`
- Output paths to refresh: `$FilePath$`

## 5) 在开发期间使用`--cfg=erase_components`

Leptos 0.7对渲染器进行了许多更改，更多地依赖类型系统。对于较大的项目，这可能导致编译时间变慢。编译时间的大部分减慢可以通过在开发期间使用自定义配置标志`--cfg=erase_components`来缓解。（这会擦除一些类型信息以减少编译器完成的工作量和发出的调试信息，但代价是额外的二进制大小和运行时成本，因此最好不要在发布模式下使用它。）

从cargo-leptos v0.2.40开始，这在开发模式下自动为您启用。如果您使用trunk，不使用cargo-leptos，或想为非开发用途启用它，您可以在命令行中轻松设置（`RUSTFLAGS="--cfg erase_components" trunk serve`或`RUSTFLAGS="--cfg erase_components" cargo leptos watch`），或在您的`.cargo/config.toml`中：
```toml
# 使用您自己的本机目标
[target.aarch64-apple-darwin]
rustflags = [
  "--cfg",
  "erase_components",
]

[target.wasm32-unknown-unknown]
rustflags = [
   "--cfg",
   "erase_components",
]
```