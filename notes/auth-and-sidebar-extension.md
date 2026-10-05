# Admin 认证与 Sidebar 扩展

AshAdmin 负责提供管理界面和可组合的 Sidebar；登录、管理员判定、Sign out 路由以及业务链接由宿主应用负责。不要让 AshAdmin 依赖特定认证库或用户模型。

认证用户与 Actor selector 也应保持区分：

- `current_user` 是宿主应用认证后的用户，可由 LiveView `on_mount` hook assign。
- Actor 是 Ash 操作的上下文，可能用于模拟 actor 或权限检查；隐藏 Actor 控件不会改变 Ash 操作的授权行为。

## Router 配置

```elixir
ash_admin "/admin",
  on_mount: [{MyAppWeb.AdminAuth, :require_admin}],
  show_actor_selector: false,
  sidebar_links: [
    %{label: "Users", url: "/admin/users", navigate: true},
    %{label: "Reports", url: "/reports"},
    %{label: "Documentation", url: "https://example.com/docs", new_tab: true}
  ],
  sidebar_footer: MyAppWeb.AdminSidebar
```

- `show_actor_selector: false` 隐藏 Actor selector 与授权状态控件，不替代路由访问控制或 Ash policies。
- `sidebar_links` 是应用快捷链接列表，每项配置 `label`、`url` 和可选行为。无需自行定义样式或高亮逻辑。
- `sidebar_footer` 是可选的 footer 扩展模块；一般静态导航不需要它。

## 简单配置：应用快捷链接

简单的静态导航无需编写组件。链接显示在内置 Domain/Resource 导航之后，分隔线和“Application links”标题用于区分资源管理导航与宿主应用快捷入口。Home 是默认的第一条链接，始终指向宿主应用前台主页 `/`；应用配置项按给定顺序接在 Home 后面。

每项链接需要 `label` 和 `url`：

- 默认使用普通 `href`，适合宿主应用的其它页面。
- AshAdmin 当前 LiveView session 内的相对路径可设 `navigate: true`，例如 `%{label: "Users", url: "/admin/users", navigate: true}`。
- HTTP(S) 链接可设 `new_tab: true`，会通过 `target="_blank"` 和 `rel="noopener noreferrer"` 在新标签打开。
- `navigate: true` 与 `new_tab: true` 不能同时设置。URL 只接受以 `/` 开头的站内路径或 HTTP(S) 绝对 URL；不接受 `javascript:` 等协议。

`url` 可包含 query string；当前页高亮按 URL path 匹配，因此忽略 query string 和结尾斜杠。AshAdmin 统一提供低调的链接样式、当前页高亮和 `aria-current="page"`，宿主应用不需要自行实现。

## 高级定制：Sidebar hook

Sidebar footer 扩展用于展示认证用户和 Sign out 等内容。普通链接始终使用 `sidebar_links` 数据配置。未设置 `sidebar_footer` 时，AshAdmin 使用默认的空 Phoenix function component。自定义模块只需 `use Phoenix.Component` 并定义 `user_panel/1`；组件收到 `current_user`、`prefix`、`current_path` 和 `variant`（`:mobile` 或 `:desktop`）。以下示例假设认证 hook 已设置 `current_user`，用户有 `email` 字段，宿主应用提供 `DELETE /sign-out` 路由：

```elixir
defmodule MyAppWeb.AdminSidebarFooter do
  use Phoenix.Component

  attr :current_user, :any, default: nil
  attr :prefix, :string, required: true
  attr :current_path, :string, default: nil
  attr :variant, :atom, required: true

  def user_panel(assigns) do
    ~H"""
    <div id={"admin-sidebar-footer-#{@variant}"} class="space-y-2 text-sm text-slate-300">
      <div class="truncate">{@current_user.email}</div>
      <.link href="/sign-out" method={:delete} class="text-slate-400 hover:text-white">
        Sign out
      </.link>
    </div>
    """
  end

end
```

`user_panel/1` 在移动端和桌面端各渲染一次。认证 hook 应验证当前用户及其管理员权限；Sign out 路由负责清理认证状态，并按应用需求跳转到登录页或主页。示例中的用户字段和登出路径需替换为宿主应用的实际定义。
