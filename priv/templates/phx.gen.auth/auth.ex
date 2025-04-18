defmodule <%= inspect auth_module %> do
  use <%= inspect context.web_module %>, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias <%= inspect context.module %>
  alias <%= inspect scope_config.scope.module %>

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in <%= inspect schema.alias %>Token.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_<%= web_app_name %>_<%= schema.singular %>_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the <%= schema.singular %> in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.

  In case the <%= schema.singular %> re-authenticates for sudo mode,
  the existing remember_me setting is kept, writing a new remember_me cookie.
  """
  def log_in_<%= schema.singular %>(conn, <%= schema.singular %>, params \\ %{}) do
    token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
    <%= schema.singular %>_return_to = get_session(conn, :<%= schema.singular %>_return_to)
    remember_me = get_session(conn, :<%= schema.singular %>_remember_me)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
    |> redirect(to: <%= schema.singular %>_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:<%= schema.singular %>_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the <%= schema.singular %> out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_<%= schema.singular %>(conn) do
    <%= schema.singular %>_token = get_session(conn, :<%= schema.singular %>_token)
    <%= schema.singular %>_token && <%= inspect context.alias %>.delete_<%= schema.singular %>_session_token(<%= schema.singular %>_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      <%= inspect(endpoint_module) %>.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the <%= schema.singular %> by looking into the session
  and remember me token.
  """
  def fetch_current_scope_for_<%= schema.singular %>(conn, _opts) do
    {<%= schema.singular %>_token, conn} = ensure_<%= schema.singular %>_token(conn)
    <%= schema.singular %> = <%= schema.singular %>_token && <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    assign(conn, :current_scope, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
  end

  defp ensure_<%= schema.singular %>_token(conn) do
    if token = get_session(conn, :<%= schema.singular %>_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  <%= if live? do %>@doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on <%= schema.singular %>_token, or nil if
      there's no <%= schema.singular %>_token or no matching <%= schema.singular %>.

    * `:require_authenticated` - Authenticates the <%= schema.singular %> from the session,
      and assigns the current_scope to socket assigns based
      on <%= schema.singular %>_token.
      Redirects to login page if there's no logged <%= schema.singular %>.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule <%= inspect context.web_module %>.PageLive do
        use <%= inspect context.web_module %>, :live_view

        on_mount {<%= inspect auth_module %>, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{<%= inspect auth_module %>, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.<%= schema.singular %> do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"<%= schema.route_prefix %>/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if <%= inspect context.alias %>.sudo_mode?(socket.assigns.current_scope.<%= schema.singular %>, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"<%= schema.route_prefix %>/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      <%= schema.singular %> =
        if <%= schema.singular %>_token = session["<%= schema.singular %>_token"] do
          <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
        end

      <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>)
    end)
  end

  <% else %>@doc """
  Used for routes that require sudo mode.
  """
  def require_sudo_mode(conn, _opts) do
    if <%= inspect context.alias %>.sudo_mode?(conn.assigns.current_scope.<%= schema.singular %>, -10) do
      conn
    else
      conn
      |> put_flash(:error, "You must re-authenticate to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
      |> halt()
    end
  end

  @doc """
  Used for routes that require the <%= schema.singular %> to not be authenticated.
  """
  def redirect_if_<%= schema.singular %>_is_authenticated(conn, _opts) do
    if conn.assigns.current_scope do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  <% end %>@doc """
  Used for routes that require the <%= schema.singular %> to be authenticated.

  If you want to enforce the <%= schema.singular %> email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_<%= schema.singular %>(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.<%= schema.singular %> do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
      |> halt()
    end
  end

  <%= if live? do %>defp put_token_in_session(conn, token) do
    conn
    |> put_session(:<%= schema.singular %>_token, token)
    |> put_session(:live_socket_id, <%= schema.singular %>_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      <%= inspect endpoint_module %>.broadcast(<%= schema.singular %>_session_topic(token), "disconnect", %{})
    end)
  end

  defp <%= schema.singular %>_session_topic(token), do: "<%= schema.plural %>_sessions:#{Base.url_encode64(token)}"

  <% else %>defp put_token_in_session(conn, token) do
    put_session(conn, :<%= schema.singular %>_token, token)
  end

  <% end %>defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :<%= schema.singular %>_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  <%= if live? do %>@doc "Returns the path to redirect to after log in."
  # the <%= schema.singular %> was already logged in, redirect to settings
  def signed_in_path(%Plug.Conn{assigns: %{current_scope: %<%= inspect scope_config.scope.alias %>{<%= schema.singular %>: %<%= inspect context.alias %>.<%= inspect schema.alias %>{}}}}) do
    ~p"<%= schema.route_prefix %>/settings"
  end

  def signed_in_path(_), do: ~p"/"<% else %>defp signed_in_path(_conn), do: ~p"/"<% end %>
end
