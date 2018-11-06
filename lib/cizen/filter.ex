defmodule Cizen.Filter do
  @moduledoc """
  Creates a filter.

  ## Basic

      Filter.new(
        fn %Event{body: %SomeEvent{field: value}} ->
          value == :a
        end
      )

      Filter.new(
        fn %Event{body: %SomeEvent{field: :a}} -> true end
      )

      value = :a
      Filter.new(
        fn %Event{body: %SomeEvent{field: ^value}} -> true end
      )

  ## With guard

      Filter.new(
        fn %Event{source_saga_id: source} when not is_nil(source) -> true end
      )

  ## Matches all

      Filter.new(fn _ -> true end)

  ## Matches the specific type of struct

      Filter.new(
        fn %Event{source_saga: %SomeSaga{}} -> true end
      )

  ## Compose filters

      Filter.new(
        fn %Event{body: %SomeEvent{field: value}} ->
          Filter.match?(other_filter, value)
        end
      )

  ## Multiple filters

      Filter.any([
        Filter.new(fn %Event{body: %Resolve{id: id}} -> id == "some id" end),
        Filter.new(fn %Event{body: %Reject{id: id}} -> id == "some id" end)
      ])

  ## Multiple cases

      Filter.new(fn
        %Event{body: %SomeEvent{field: :ignore}} -> false
        %Event{body: %SomeEvent{field: value}} -> true
      end)
  """

  @type t :: %__MODULE__{}

  defstruct code: true

  alias Cizen.Filter.Code

  @doc """
  Creates a filter with the given anonymous function.
  """
  defmacro new(filter) do
    filter
    |> Macro.prewalk(fn
      {:when, _, [args, _guard]} ->
        args

      {:->, meta, [args, _expression]} ->
        {:->, meta, [args, true]}

      {:^, _, [{_var, _, _}]} ->
        {:_, [], nil}

      {_var, _, args} when not is_list(args) ->
        {:_, [], nil}

      node ->
        node
    end)
    |> Elixir.Code.eval_quoted([], __CALLER__)

    code = Code.generate(filter, __CALLER__)

    quote do
      %unquote(__MODULE__){
        code: unquote(code)
      }
    end
  end

  @doc """
  Checks whether the given struct matches or not.
  """
  @spec match?(t, term) :: boolean
  def match?(%__MODULE__{code: code}, struct) do
    if eval(code, struct), do: true, else: false
  end

  @doc """
  Joins the given filters with `and`.
  """
  @spec all([t()]) :: t()
  def all(filters) do
    code = filters |> Enum.map(& &1.code) |> Code.all()
    %__MODULE__{code: code}
  end

  @doc """
  Joins the given filters with `or`.
  """
  @spec any([t()]) :: t()
  def any(filters) do
    code = filters |> Enum.map(& &1.code) |> Code.any()
    %__MODULE__{code: code}
  end

  def eval({:access, keys}, struct) do
    Enum.reduce(keys, struct, fn key, struct ->
      Map.get(struct, key)
    end)
  end

  def eval({:call, [{module, fun} | args]}, struct) do
    args = args |> Enum.map(&eval(&1, struct))
    apply(module, fun, args)
  end

  @macro_unary_operators [:is_nil, :to_string, :to_charlist, :not, :!]
  for operator <- @macro_unary_operators do
    def eval({unquote(operator), [arg]}, struct) do
      Kernel.unquote(operator)(eval(arg, struct))
    end
  end

  @macro_binary_operators [:and, :&&, :or, :||, :in, :.., :<>]
  for operator <- @macro_binary_operators do
    def eval({unquote(operator), [arg1, arg2]}, struct) do
      Kernel.unquote(operator)(eval(arg1, struct), eval(arg2, struct))
    end
  end

  def eval({operator, args}, struct) do
    args = args |> Enum.map(&eval(&1, struct))
    apply(Kernel, operator, args)
  end

  def eval(value, _struct) do
    value
  end
end
