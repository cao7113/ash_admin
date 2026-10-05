defmodule AshAdmin.Components.Sidebar.Footer do
  use Phoenix.Component

  @moduledoc """
  Default function component for the AshAdmin sidebar footer.

  Configure an application-owned Phoenix component module with the
  `:sidebar_footer` router option to customize the footer.
  """

  attr :current_user, :any, default: nil
  attr :prefix, :string, default: nil
  attr :current_path, :string, default: nil
  attr :variant, :atom, default: :desktop

  def user_panel(assigns), do: ~H""
end
