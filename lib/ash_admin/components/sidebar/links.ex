defmodule AshAdmin.Components.Sidebar.Links do
  use Phoenix.Component

  @moduledoc false

  attr :prefix, :string, required: true
  attr :current_path, :string, default: nil
  attr :links, :list, default: []

  def application_links(assigns) do
    application_links =
      application_links(assigns.prefix, assigns.current_path, assigns.links)

    assigns = assign(assigns, :application_links, application_links)

    ~H"""
    <section
      :if={@application_links != []}
      class="mt-3 border-t border-slate-700/50 pt-3"
    >
      <h2 class="px-3 pb-1 text-xs font-semibold text-slate-500 uppercase tracking-wider">
        Application links
      </h2>
      <div class="space-y-0.5">
        <.link
          :for={item <- @application_links}
          navigate={item.navigate}
          href={item.href}
          target={if item.new_tab, do: "_blank"}
          rel={if item.new_tab, do: "noopener noreferrer"}
          aria-current={if item.active, do: "page"}
          class={[
            "block px-3 py-1.5 text-sm rounded-md transition-colors",
            if(item.active,
              do: "bg-slate-800 text-slate-100 font-medium",
              else: "text-slate-400 hover:text-slate-200 hover:bg-slate-800/70"
            )
          ]}
        >
          {item.label}
        </.link>
      </div>
    </section>
    """
  end

  defp path_matches?(nil, _path), do: false
  defp path_matches?(_current_path, nil), do: false

  defp path_matches?(current_path, path) do
    normalize_path(current_path) == normalize_path(path)
  end

  defp application_links(prefix, current_path, links) do
    home = %{label: "Home", url: "/"}
    links = [home | links]

    Enum.map(links, &normalize_sidebar_link!(&1, prefix, current_path))
  end

  defp normalize_sidebar_link!(%{label: label, url: url} = link, prefix, current_path)
       when is_binary(label) and label != "" and is_binary(url) and url != "" do
    uri = URI.parse(url)
    navigate? = Map.get(link, :navigate, false)
    new_tab? = Map.get(link, :new_tab, false)

    validate_sidebar_link!(link, uri, navigate?, new_tab?, prefix)

    %{
      label: label,
      active: not new_tab? and path_matches?(current_path, uri.path),
      navigate: if(navigate?, do: url),
      href: if(navigate?, do: nil, else: url),
      new_tab: new_tab?
    }
  end

  defp normalize_sidebar_link!(invalid, _prefix, _current_path) do
    raise ArgumentError,
          "sidebar_links entries must include a non-empty string :label and :url, got: #{inspect(invalid)}"
  end

  defp validate_sidebar_link!(link, uri, navigate?, new_tab?, prefix) do
    valid_flags? = is_boolean(navigate?) and is_boolean(new_tab?) and not (navigate? and new_tab?)
    relative_path? = is_nil(uri.scheme) and is_nil(uri.host) and is_binary(uri.path)
    safe_absolute_url? = uri.scheme in ["http", "https"] and is_binary(uri.host)

    valid_url? =
      (relative_path? and String.starts_with?(uri.path, "/") and
         not String.starts_with?(uri.path, "//")) or safe_absolute_url?

    valid_navigate? =
      not navigate? or
        (relative_path? and String.starts_with?(uri.path, "/") and
           admin_path?(uri.path, prefix))

    valid_new_tab? = not new_tab? or safe_absolute_url?

    unless valid_flags? and valid_url? and valid_navigate? and valid_new_tab? do
      raise ArgumentError,
            "invalid sidebar link #{inspect(link)}; use a root-relative or HTTP(S) URL, " <>
              "navigate: true only for paths inside the AshAdmin LiveView, and new_tab: true " <>
              "only for HTTP(S) URLs (navigate and new_tab are mutually exclusive)"
    end
  end

  defp admin_path?(path, prefix) do
    prefix = normalize_path(prefix)
    path = normalize_path(path)
    prefix == "/" or path == prefix or String.starts_with?(path, prefix <> "/")
  end

  defp normalize_path(path) do
    case String.trim_trailing(path, "/") do
      "" -> "/"
      normalized -> normalized
    end
  end
end
