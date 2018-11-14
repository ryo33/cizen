defmodule Cizen.SagaCase do
  @moduledoc """
  Run test with sagas.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      use Cizen.Effectful
      use Cizen.Effects
      use Cizen.Test
    end
  end
end
