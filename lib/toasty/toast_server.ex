defmodule Toasty.ToastServer do
  use GenServer
  alias Toasty.Toast

  # 10 minutes
  @default_max_expiration 10 * 60 * 1_000

  @impl true
  def init(%{max_expiration: max_expiration}) do
    {:ok, %{max_expiration: max_expiration, toasts: %{}}}
  end

  def start_link(opts) do
    initial_state = opts[:initial_state] || %{max_expiration: @default_max_expiration}
    GenServer.start_link(__MODULE__, initial_state, opts)
  end
end
