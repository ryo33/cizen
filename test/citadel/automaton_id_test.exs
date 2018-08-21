defmodule Citadel.AutomatonIDTest do
  use ExUnit.Case
  doctest Citadel.AutomatonID

  alias Citadel.AutomatonID

  test "returns unique IDs" do
    assert AutomatonID.new() != AutomatonID.new()
  end

  test "returns an encodable ID" do
    id = AutomatonID.new()
    encoded = Poison.encode!(id)
    decoded = Poison.decode!(encoded)
    assert id == decoded
  end
end
