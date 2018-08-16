defmodule CitadelX.Event do
  @moduledoc """
  Helpers to handle events
  """

  @type t :: struct

  @spec type(t) :: __MODULE__.Type.t()
  def type(event), do: event.__struct__

  defmodule Type do
    @moduledoc false
    @type t :: module
  end
end
