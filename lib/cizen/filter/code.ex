defmodule Cizen.Filter.Code do
  alias Cizen.Filter
  @moduledoc false

  @additional_operators [:is_nil, :to_string, :to_charlist]

  def with_prefix({:access, keys}, prefix) do
    {:access, prefix ++ keys}
  end

  def with_prefix({op, args}, prefix) when is_atom(op) and is_list(args) do
    args = Enum.map(args, &with_prefix(&1, prefix))
    {op, args}
  end

  def with_prefix(node, _prefix), do: node

  def all([]), do: true
  def all([filter]), do: filter
  def all([filter | tail]), do: {:and, [filter, all(tail)]}

  def any([]), do: false
  def any([filter]), do: filter
  def any([filter | tail]), do: {:or, [filter, any(tail)]}

  defp get_keys({:=, _, [struct, {key, _, _}]}, prefix) do
    {keys, types} = get_keys(struct, prefix)
    {[{key, prefix} | keys], types}
  end

  defp get_keys({:%, _, [module, {:%{}, _, pairs}]}, prefix) do
    {keys_list, types_list} =
      pairs
      |> Enum.reduce({[], []}, fn {key, value}, {keys_acc, types_acc} ->
        prefix =
          prefix
          |> List.insert_at(-1, key)

        {keys, types} = get_keys(value, prefix)
        {[keys | keys_acc], [types | types_acc]}
      end)

    {List.flatten(keys_list), [{prefix, module} | List.flatten(types_list)]}
  end

  defp get_keys({value, _, _}, prefix), do: {[{value, prefix}], []}

  def generate({:fn, _, [{:->, _, [[arg], {:__block__, _, [expression]}]}]}, env) do
    do_generate(arg, expression, env)
  end

  def generate({:fn, _, [{:->, _, [[arg], expression]}]}, env) do
    do_generate(arg, expression, env)
  end

  defp do_generate(arg, expression, env) do
    {keys, types} = get_keys(arg, [])

    keys =
      keys
      |> Enum.into(%{})

    code =
      expression
      |> Macro.postwalk(&walk(&1, keys, env))

    types
    |> Enum.map(fn {prefix, module} ->
      {prefix, Macro.expand(module, env)}
    end)
    |> Enum.reverse()
    |> Enum.reduce(code, fn {keys, module}, rest ->
      # literal tuple
      keys = List.insert_at(keys, -1, :__struct__)
      {:and, [{:==, [{:access, keys}, module]}, rest]}
    end)
  end

  # Skip . operator
  defp walk({:., _, _} = node, _keys, _env), do: node

  # Additional operators
  defp walk({op, _, args} = node, _keys, _env) when op in @additional_operators do
    if Enum.any?(args, &has_access?(&1)) do
      # literal tuple
      {op, args}
    else
      node
    end
  end

  # Field access
  defp walk({{:., _, [{:access, keys}, key]}, _, []}, _keys, _env) do
    # literal tuple
    {:access, List.insert_at(keys, -1, key)}
  end

  defp walk({{:., _, [Access, :get]}, _, [{:access, keys}, key]}, _keys, _env) do
    # literal tuple
    {:access, List.insert_at(keys, -1, key)}
  end

  defp walk({{:., _, [module, function]}, _, args} = node, _keys, env) do
    expanded_module = Macro.expand(module, env)

    cond do
      expanded_module == Filter and function == :match? ->
        # Embedded filter
        [filter, {:access, keys}] = args

        quote do
          unquote(__MODULE__).with_prefix(unquote(filter).code, unquote(keys))
        end

      Enum.any?(args, &has_access?(&1)) ->
        # Function call
        # literal tuple
        {:call, [{module, function} | args]}

      true ->
        node
    end
  end

  # Access to value
  defp walk({first, _, third} = node, keys, _env) when is_atom(first) and not is_list(third) do
    if Map.has_key?(keys, first) do
      keys = Map.get(keys, first)

      # literal tuple
      {:access, keys}
    else
      node
    end
  end

  defp walk({first, _, third} = node, keys, env) when is_atom(first) do
    cond do
      Macro.operator?(first, length(third)) ->
        # Operator
        if Enum.any?(third, &has_access?(&1)) do
          op = first
          args = third

          # literal tuple
          {op, args}
        else
          node
        end

      third != [] ->
        # Function calls
        gen_call(node, keys, env)

      true ->
        node
    end
  end

  defp walk(node, _keys, _env), do: node

  defp has_access?(value) do
    {_node, has_access?} =
      Macro.prewalk(value, false, fn node, has_access? ->
        case node do
          {:access, _} ->
            {node, true}

          node ->
            {node, has_access?}
        end
      end)

    has_access?
  end

  defp gen_call({first, _, third} = node, _keys, env) do
    if Enum.any?(third, &has_access?(&1)) do
      arity = length(third)

      {module, _} =
        env.functions
        |> Enum.find({env.module, []}, fn {_module, functions} ->
          Enum.find(functions, fn
            {^first, ^arity} ->
              true

            _ ->
              false
          end)
        end)

      fun = {module, first}

      # literal tuple
      {:call, [fun | third]}
    else
      node
    end
  end
end
