defmodule Cizen.EffectsTest do
  use ExUnit.Case

  test "aliases all effects" do
    use Cizen.Effects
    assert Code.ensure_loaded?(All)
    assert Code.ensure_loaded?(Chain)
    assert Code.ensure_loaded?(Dispatch)
    assert Code.ensure_loaded?(End)
    assert {:module, Cizen.Effects.Map} == Code.ensure_loaded(Map)
    assert Code.ensure_loaded?(Monitor)
    assert Code.ensure_loaded?(Race)
    assert Code.ensure_loaded?(Receive)
    assert Code.ensure_loaded?(Request)
    assert Code.ensure_loaded?(Start)
    assert Code.ensure_loaded?(Subscribe)
  end

  test "aliases only specified effects" do
    use Cizen.Effects, only: [Chain, Dispatch, End]
    refute Code.ensure_loaded?(All)
    assert Code.ensure_loaded?(Chain)
    assert Code.ensure_loaded?(Dispatch)
    assert Code.ensure_loaded?(End)
    assert {:module, Elixir.Map} == Code.ensure_loaded(Map)
    refute Code.ensure_loaded?(Monitor)
    refute Code.ensure_loaded?(Race)
    refute Code.ensure_loaded?(Receive)
    refute Code.ensure_loaded?(Request)
    refute Code.ensure_loaded?(Start)
    refute Code.ensure_loaded?(Subscribe)
  end
end
