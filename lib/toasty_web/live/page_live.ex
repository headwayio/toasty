defmodule ToastyWeb.PageLive do
  use ToastyWeb, :live_view
  import ToastyWeb.ToastComponent

  @impl true
  def mount(params, _session, socket) do
    user_id =
      case params["user_id"] do
        nil ->
          1

        "" ->
          1

        value ->
          {result, _} = Integer.parse(value)
          result
      end

    initialize_toasts_component(socket, user_id)
    {:ok, assign(socket, current_user: %{id: user_id})}
  end

  @impl true
  def handle_event("push_toast", params, socket) do
    expires_in =
      case params["expires_in"] do
        "" ->
          nil

        string ->
          {result, _} = Integer.parse(string)
          result
      end

    {user_id, _} = params["user_id"] |> Integer.parse()
    type = [:info, :success, :error, :progress] |> Enum.find(&(to_string(&1) == params["type"]))

    toast = %Toasty.Toast{
      ref: make_ref(),
      message: params["message"],
      expires_in: expires_in,
      user_id: user_id,
      type: type
    }

    Toasty.ToastServer.add(toast)

    {:noreply, socket}
  end

  attach_toast_handlers("toasts")
end
