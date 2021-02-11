defmodule Toasty.Toast do
  @type t() :: %__MODULE__{
          # Unique reference assigned by ToastServer to identify an individual toast
          ref: nil | reference(),
          # Reference to a timer that will clean up this toast
          timer_ref: nil | :timer.tref(),
          # Id of the user to whom this toast belongs too
          user_id: integer(),
          # Message to display
          message: String.t(),
          # What type of information does this toast display
          type: :info | :success | :error | :progress,
          # This toast will expire after this amount of milliseconds
          # if nil, ToastServer will expire the toast after the max
          # expiration time
          expires_in: nil | integer()
        }

  @enforce_keys [:ref, :user_id, :message, :type]
  defstruct [:ref, :timer_ref, :user_id, :message, :type, :expires_in]
end
