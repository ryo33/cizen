defmodule Citadel.SagaIDTest do
  use ExUnit.Case
  doctest Citadel.SagaID

  alias Citadel.SagaID

  test "returns unique IDs" do
    assert SagaID.new() != SagaID.new()
  end

  test "returns an encodable ID" do
    id = SagaID.new()
    encoded = Poison.encode!(id)
    decoded = Poison.decode!(encoded)
    assert id == decoded
  end
end
