# SPDX-FileCopyrightText: 2020 ash_admin contributors <https://github.com/ash-project/ash_admin/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshAdmin.Test.Router do
  use Phoenix.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_query_params)
  end

  scope "/api" do
    pipe_through(:browser)
    import AshAdmin.Router

    csp_full = %{
      img: :img_csp_nonce,
      style: :style_csp_nonce,
      script: :script_csp_nonce
    }

    ash_admin("/admin")

    ash_admin("/csp/admin",
      live_session_name: :ash_admin_csp,
      csp_nonce_assign_key: :csp_nonce_value
    )

    ash_admin("/csp-full/admin",
      live_session_name: :ash_admin_csp_full,
      csp_nonce_assign_key: csp_full
    )

    ash_admin("/sidebar-extension/admin",
      live_session_name: :ash_admin_sidebar_extension,
      show_actor_selector: false,
      sidebar_footer: AshAdmin.Test.SidebarHooks,
      sidebar_links: [
        %{
          label: "Reports",
          url: "/api/sidebar-extension/admin?tab=reports",
          navigate: true
        },
        %{label: "Docs", url: "https://example.com/docs", new_tab: true}
      ],
      on_mount: [{AshAdmin.Test.AdminUserOnMount, :assign_admin_user}]
    )
  end
end

defmodule AshAdmin.Test.SidebarHooks do
  use Phoenix.Component

  attr :variant, :atom, required: true

  def user_panel(assigns) do
    ~H"""
    <div id={"custom-sidebar-footer-#{@variant}"}>{@current_user.email}</div>
    """
  end
end

defmodule AshAdmin.Test.AdminUserOnMount do
  def on_mount(:assign_admin_user, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_user, %{email: "admin@example.com"})}
  end
end
