# actor_* cookie / session 字段关系说明

## 1. 背景

Ash Admin 在后台中使用一组 `actor_*` 字段来维护“当前模拟的 actor（操作人）”以及“当前是否执行权限校验”。这些值不仅出现在 LiveView 的 assigns 中，也会持续写入 session / cookie，以便在后续请求和导航中保持上下文一致。

核心文件：

- `lib/ash_admin/session_plug.ex`
- `lib/ash_admin/router.ex`
- `lib/ash_admin/actor_plug/plug.ex`
- `lib/ash_admin/pages/page_live.ex`
- `lib/ash_admin/components/sidebar.ex`

---

## 2. 字段分类

### 2.1 身份快照字段

这些字段描述当前选择的 actor 和其上下文：

- `actor_resource`
- `actor_domain`
- `actor_action`
- `actor_primary_key`
- `actor_tenant`

它们用于恢复“当前是谁在做操作”，以及该 actor 所属的资源 / domain / tenant。

### 2.2 运行时开关字段

这些字段控制是否真正参与权限校验：

- `actor_authorizing`
- `actor_paused`

其中：

- `actor_authorizing` 决定是否执行 `authorize?`
- `actor_paused` 决定是否让当前 actor 失效（设为 `nil`）

---

## 3. 复制到 session 的入口

在 `lib/ash_admin/session_plug.ex` 中，`@cookies_to_replicate` 定义了要复制进 session 的字段：

```elixir
@cookies_to_replicate [
  "tenant",
  "actor_resource",
  "actor_primary_key",
  "actor_action",
  "actor_domain",
  "actor_authorizing",
  "actor_paused"
]
```

`call/2` 会遍历这些字段，从 `conn.req_cookies` 取值，并写入 `Plug.Conn.put_session/3`。

这意味着：

- 这些值并不只是前端状态
- 它们会被保留到下一次请求/下一次 LiveView 挂载
- 因此用户切换页面、触发导航时，上下文不会丢失

---

## 4. Router 侧的 session 聚合

`lib/ash_admin/router.ex` 中的 `__session__/3` 也会把这些 cookie 重新合并进 session：

```elixir
Enum.reduce(@cookies_to_replicate, session, fn cookie, session ->
  case conn.req_cookies[cookie] do
    value when value in [nil, "", "null"] ->
      Map.put(session, cookie, nil)

    value ->
      Map.put(session, cookie, value)
  end
end)
```

这里的作用是：

- 帮助 LiveView 在挂载时拿到当前上下文
- 同时把无效值（比如 `null` / 空字符串）标准化成 `nil`

---

## 5. 转成 assigns 的关键逻辑

`lib/ash_admin/actor_plug/plug.ex` 中的 `actor_assigns/2` 负责把 session 中的值整理成 socket assigns：

```elixir
[
  actor: actor_from_session(socket.endpoint, session),
  actor_domain: actor_domain_from_session(socket.endpoint, session),
  actor_resources: actor_resources(domains),
  actor_paused: session_bool(session["actor_paused"], true),
  actor_tenant: session["actor_tenant"],
  authorizing: session_bool(session["actor_authorizing"], false),
  tenant: session["tenant"]
]
```

这里 `session_bool/2` 会把字符串布尔值转换成真实的 Elixir boolean：

- `"true"` -> `true`
- `"false"` -> `false`
- `"undefined"` -> `false`
- `nil` -> default

这个转换是必要的，因为 cookie/session 中的值通常是字符串，而 UI 和 Ash 查询需要布尔值。

---

## 6. `actor_paused` 的语义

在 `lib/ash_admin/pages/page_live.ex` 中，当加载单条记录时：

```elixir
actor =
  if socket.assigns.actor_paused do
    nil
  else
    socket.assigns.actor
  end
```

这表示：

- 如果 `actor_paused == true`，当前 actor 不生效
- `actor` 会被临时设为 `nil`
- 后续读取数据时，系统就不会以该 actor 身份执行查询

对应 UI 中的状态：

- Actor 点亮状态为 green：active
- 灰色状态：paused

见 `lib/ash_admin/components/sidebar.ex`。

---

## 7. `actor_authorizing` 的语义

`authorizing` 会被直接传给 Ash 的查询和加载：

```elixir
Ash.Query.for_read(
  show_action,
  %{},
  actor: actor,
  authorize?: socket.assigns.authorizing
)
```

以及：

```elixir
Ash.load(record, rel,
  actor: actor,
  domain: socket.assigns.domain,
  tenant: socket.assigns[:tenant],
  authorize?: socket.assigns.authorizing
)
```

这里的意思是：

- `authorize?: true`：执行 Ash 的 authorization / policy 检查
- `authorize?: false`：绕过权限校验

这和侧边栏中的文案一致：

- `Auth enforced`
- `Auth bypassed`

---

## 8. 两者的区别

这是最关键的理解：

### `actor_paused`

控制“当前 actor 是否生效”，等价于：

- 是否拿到真实 actor 上下文

通常会导致：

```elixir
actor = nil
```

### `actor_authorizing`

控制“是否执行权限检查”，等价于：

- 是否让 Ash 走 policy 逻辑

通常会导致：

```elixir
authorize?: false
```

因此：

- `actor_paused` 影响“身份上下文”
- `actor_authorizing` 影响“授权策略”

两者完全是两个不同维度。

---

## 9. UI 中的切换入口

`lib/ash_admin/components/sidebar.ex` 中有两个按钮：

### Actor toggle

- `phx-click="toggle_actor_paused"`
- 用来暂停/恢复 actor

### Authorization toggle

- `phx-click="toggle_authorizing"`
- 用来切换是否启用权限限制

对应事件在 `lib/ash_admin/pages/page_live.ex`：

```elixir
def handle_event("toggle_authorizing", _, socket) do
  {:noreply,
   socket
   |> assign(:authorizing, !socket.assigns.authorizing)
   |> push_event("toggle_authorizing", %{authorizing: to_string(!socket.assigns.authorizing)})}
end

def handle_event("toggle_actor_paused", _, socket) do
  {:noreply,
   socket
   |> assign(:actor_paused, !socket.assigns.actor_paused)
   |> push_event("toggle_actor_paused", %{actor_paused: to_string(!socket.assigns.actor_paused)})}
end
```

另外在 `clear_actor` 中，项目还会同步清理状态：

```elixir
socket
|> assign(:actor, nil)
|> assign(:actor_paused, true)
|> assign(:authorizing, false)
```

这表示：

- 清空 actor
- 暂停当前 actor
- 关闭权限校验

用于快速切回“无 actor / 调试状态”。

---

## 10. 实际的数据流总结

可以把完整链路概括为：

```text
用户在 UI 选择 Actor
  -> set_actor 事件
  -> 保存 actor_resource / actor_domain / actor_action / actor_primary_key / actor_tenant
  -> session / cookie 持久化
  -> 下次请求时恢复
  -> ActorPlug.actor_assigns/2 组装 assigns
  -> LiveView 读数据时
       actor = if actor_paused, do: nil, else: actor
       authorize?: authorizing
  -> Ash 查询/加载执行对应授权逻辑
```

也就是说：

`actor_*` 这些字段并不是孤立的设置项，而是一整套“当前 admin 会话上下文”的状态容器。

---

## 11. 一句话结论

这个项目里 `actor_*` 字段的核心职责是：

- 维护当前管理员/模拟用户身份
- 维持跨页面的会话上下文
- 控制是否真正执行权限策略

它们共同构成了 Ash Admin 的“调试与演示模式”基础能力。
