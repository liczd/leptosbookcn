# 响应和重定向

提取器提供了在服务器函数内访问请求数据的简单方法。Leptos还提供了修改HTTP响应的方法，使用`ResponseOptions`类型（参见[Actix](https://docs.rs/leptos_actix/latest/leptos_actix/struct.ResponseOptions.html)或[Axum](https://docs.rs/leptos_axum/latest/leptos_axum/struct.ResponseOptions.html)类型的文档）和`redirect`辅助函数（参见[Actix](https://docs.rs/leptos_actix/latest/leptos_actix/fn.redirect.html)或[Axum](https://docs.rs/leptos_axum/latest/leptos_axum/fn.redirect.html)的文档）。

## `ResponseOptions`

`ResponseOptions`在初始服务器渲染响应期间和任何后续服务器函数调用期间通过上下文提供。它允许您轻松设置HTTP响应的状态码，或向HTTP响应添加标头，例如，设置cookie。

```rust
#[server]
pub async fn tea_and_cookies() -> Result<(), ServerFnError> {
    use actix_web::{
        cookie::Cookie,
        http::header::HeaderValue,
        http::{header, StatusCode},
    };
    use leptos_actix::ResponseOptions;

    // 从上下文中拉取ResponseOptions
    let response = expect_context::<ResponseOptions>();

    // 设置HTTP状态码
    response.set_status(StatusCode::IM_A_TEAPOT);

    // 在HTTP响应中设置cookie
    let cookie = Cookie::build("biscuits", "yes").finish();
    if let Ok(cookie) = HeaderValue::from_str(&cookie.to_string()) {
        response.insert_header(header::SET_COOKIE, cookie);
    }
    Ok(())
}
```

## `redirect`

对HTTP响应的一个常见修改是重定向到另一个页面。Actix和Axum集成提供了`redirect`函数来使这变得容易。

```rust
#[server]
pub async fn login(
    username: String,
    password: String,
    remember: Option<String>,
) -> Result<(), ServerFnError> {
    // 从上下文中拉取DB池和认证提供者
    let pool = pool()?;
    let auth = auth()?;

    // 检查用户是否存在
    let user: User = User::get_from_username(username, &pool)
        .await
        .ok_or_else(|| {
            ServerFnError::ServerError("User does not exist.".into())
        })?;

    // 检查用户是否提供了正确的密码
    match verify(password, &user.password)? {
        // 如果密码正确...
        true => {
            // 登录用户
            auth.login_user(user.id);
            auth.remember_user(remember.is_some());

            // 并重定向到主页
            leptos_axum::redirect("/");
            Ok(())
        }
        // 如果不正确，返回错误
        false => Err(ServerFnError::ServerError(
            "Password does not match.".to_string(),
        )),
    }
}
```

然后可以从您的应用程序使用此服务器函数。这个`redirect`与渐进增强的`<ActionForm/>`组件配合得很好：没有JS/WASM时，服务器响应将因为状态码和标头而重定向。有JS/WASM时，`<ActionForm/>`将检测服务器函数响应中的重定向，并使用客户端导航重定向到新页面。