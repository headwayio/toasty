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

  @impl true
  def handle_info({:remove, user_id, ref}, state) do
    remove_toast(user_id, ref, state)
  end

  @impl true
  def handle_cast({:add, toast}, state) do
    toast = process_toast(toast, state.max_expiration)

    Phoenix.PubSub.broadcast(
      Toasty.PubSub,
      "toasted:#{toast.user_id}",
      {:toast, :add, [toast]}
    )

    toasts = state.toasts[toast.user_id] || []
    {:noreply, %{state | toasts: Map.put(state.toasts, toast.user_id, [toast | toasts])}}
  end

  def handle_cast({:remove, user_id, ref}, state) do
    remove_toast(user_id, ref, state)
  end

  @impl true
  def handle_call({:get, user_id}, _from, state) do
    response = state.toasts[user_id] || []
    {:reply, response, state}
  end

  @spec add(Toast.t()) :: :ok
  def add(%Toast{} = toast) do
    GenServer.cast(__MODULE__, {:add, toast})
  end

  @spec remove(user_id :: integer(), ref :: reference()) :: :ok
  def remove(user_id, ref) do
    GenServer.cast(__MODULE__, {:remove, user_id, ref})
  end

  @spec get(user_id :: integer()) :: [Toast.t()]
  def get(user_id) do
    GenServer.call(__MODULE__, {:get, user_id})
  end

  @spec subscribe(user_id :: integer()) :: :ok | {:error, term()}
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(Toasty.PubSub, "toasted:#{user_id}")
  end

  defp remove_toast(user_id, ref, %{toasts: toasts} = state) do
    {keep, drop} =
      toasts[user_id]
      |> Kernel.||([])
      |> Enum.reverse()
      |> Enum.reduce({[], []}, fn toast, {keep, drop} ->
        if toast.ref == ref do
          {keep, [toast | drop]}
        else
          {[toast | keep], drop}
        end
      end)

    toasts =
      if keep == [] do
        Map.delete(toasts, user_id)
      else
        Map.put(toasts, user_id, keep)
      end

    if not Enum.empty?(drop) do
      for toast <- drop do
        :timer.cancel(toast.timer_ref)
      end

      Phoenix.PubSub.broadcast(
        Toasty.PubSub,
        "toasted:#{user_id}",
        {:toast, :remove, Enum.map(drop, & &1.ref)}
      )
    end

    {:noreply, %{state | toasts: toasts}}
  end

  @spec process_toast(Toast.t(), integer()) :: Toast.t()
  defp process_toast(%Toast{} = toast, max_expiration) do
    toast =
      toast
      |> validate_expiration(max_expiration)
      |> ensure_has_ref()

    clear_in = toast.expires_in || max_expiration
    {:ok, timer_ref} = :timer.send_after(clear_in, {:remove, toast.user_id, toast.ref})

    %{toast | timer_ref: timer_ref}
  end

  @spec validate_expiration(Toast.t(), integer()) :: Toast.t()
  defp validate_expiration(%Toast{expires_in: expires_in} = toast, max_expiration)
       when is_number(expires_in) and expires_in >= 0 and expires_in <= max_expiration,
       do: toast

  defp validate_expiration(%Toast{expires_in: nil} = toast, _max_expiration), do: toast
  defp validate_expiration(toast, max_expiration), do: %{toast | expires_in: max_expiration}

  defp ensure_has_ref(%Toast{ref: ref} = toast) when is_reference(ref), do: toast
  defp ensure_has_ref(toast), do: %{toast | ref: make_ref()}
end
