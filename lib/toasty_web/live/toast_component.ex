defmodule ToastyWeb.ToastComponent do
  @moduledoc """
  Component to display list of user toast messages

  ## Assigns:
    * id               - ID of the live component
    * current_user     - which user's toasts to show

  ## Usage
  In the parent liveviews mount function, call `initialize_toasts_component/2`

      def mount(_params, session, socket) do
        user = Account.get_user_by_session_token(session["user_token"])

        initialize_toasts_component(socket, user.id)

        {:ok, socket}
      end

  Use the `attach_toast_handlers/1` macro to attach message handlers.
  Use the same ID that is used to render the component

      def handle_info({:users, :join arg}, socket) do
        {:noreply, socket}
      end

      attach_toast_handlers("toasts")

      def handle_info(_, socket), do: {:noreply, socket}

  Render the component. The id should match the value passed into `attach_toast_handlers/1`

      <%= live_component @socket, ToastyWeb.ToastComponent, id: "toasts", current_user: @current_user %>

  """
  use ToastyWeb, :live_component
  alias Toasty.ToastServer

  @doc """
  Call this in parent LiveView's mount in order initialize the Toast component's
  subscription to the ToastServer
  """
  defmacro initialize_toasts_component(socket, user_id) do
    quote do
      if Phoenix.LiveView.connected?(unquote(socket)) do
        Phoenix.PubSub.subscribe(Toasty.PubSub, "toasted:#{unquote(user_id)}")
      end
    end
  end

  @doc """
  Create the `handle_info/2` functions in order to keep the Toast component
  updated when Toasts change
  """
  defmacro attach_toast_handlers(id) do
    quote do
      def handle_info({:toast, _, toasts}, socket) do
        send_update(ToastyWeb.ToastComponent,
          id: unquote(id),
          current_user: socket.assigns.current_user
        )

        {:noreply, socket}
      end
    end
  end

  def mount(socket) do
    {:ok, socket}
  end

  def update(%{current_user: user}, socket) do
    socket =
      socket
      |> assign(
        current_user: user,
        toasts: ToastServer.get(user.id)
      )

    {:ok, socket}
  end

  def handle_event(
        "clear-toast",
        %{"ref" => ref_string},
        %{assigns: %{toasts: toasts}} = socket
      ) do
    toast = Enum.find(toasts, fn %{ref: ref} -> inspect(ref) == ref_string end)

    ToastServer.remove(socket.assigns.current_user.id, toast.ref)

    {:noreply, socket}
  end

  # def handle_event("clear-toast", _, socket) do
  #   {:noreply, socket}
  # end

  def render(assigns) do
    ~L"""
      <div class="toast-container">
        <div class="toast-scroller">
          <%= for toast <- @toasts do %>
            <div class="toast">
              <div class="toast-content">
                <%= type_indicator(toast.type) %>
                <p role="alert"><%= toast.message %></p>
                <button phx-click="clear-toast" phx-value-ref="<%= inspect(toast.ref) %>" phx-target="<%= @myself %>">&times;</button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    """
  end

  defp type_indicator(:progress),
    do: ~E"""
    <div>&#8987;</div>
    """

  defp type_indicator(:success),
    do: ~E"""
    <div>&check;</div>
    """

  defp type_indicator(:error),
    do: ~E"""
    <div>&#9888;</div>
    """

  defp type_indicator(_), do: nil
end
