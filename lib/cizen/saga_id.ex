defmodule Cizen.SagaID do
  @moduledoc """
  Each saga has a unique saga-id.
  """

  @type t :: String.t()

  @doc """
  Create new saga id.
  """
  @spec new :: t
  def new do
    UUID.uuid4()
  end
end
