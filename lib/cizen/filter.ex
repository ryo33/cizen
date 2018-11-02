defmodule Cizen.Filter do
  @moduledoc """
  Creates a filter.

  ## Basic

      Filter.new(
        fn %Event{body: %SomeEvent{field: value}} ->
          value == :a
        end
      )

  ## Matches specific struct

      Filter.new(
        fn %Event{body: %SomeEvent{}} -> true end
      )

  ## Uses other filter

      Filter.new(
        fn %Event{body: %SomeEvent{field: value}} ->
          Filter.match?(other_filter, value)
        end
      )
  """

  @type t :: %__MODULE__{}

  defstruct code: true

  alias Cizen.Filter.Code

  defmacro new(filter) do
    filter
    |> Macro.prewalk(fn
      {:->, meta, [args, _expression]} ->
        {:->, meta, [args, true]}

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
  Checks whether the given struct matches or not
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

  def eval({:is_nil, [arg]}, struct) do
    arg
    |> eval(struct)
    |> is_nil()
  end

  def eval({:and, [arg1, arg2]}, struct) do
    eval(arg1, struct) and eval(arg2, struct)
  end

  def eval({:or, [arg1, arg2]}, struct) do
    eval(arg1, struct) or eval(arg2, struct)
  end

  def eval({operator, args}, struct) do
    args = args |> Enum.map(&eval(&1, struct))
    apply(Kernel, operator, args)
  end

  def eval(value, _struct) do
    value
  end
end
