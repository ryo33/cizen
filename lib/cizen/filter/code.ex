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

  defp get_keys(arg, env), do: get_keys(arg, %{}, [], [], env)

  defp get_keys({:%, _, [module, {:%{}, _, pairs}]}, keys, operations, prefix, env) do
    module = Macro.expand(module, env)
    access = List.insert_at(prefix, -1, :__struct__)
    operations = [{:==, [{:access, access}, module]} | operations]

    pairs
    |> Enum.reduce({keys, operations}, fn {key, value}, {keys, operations} ->
      get_keys(value, keys, operations, List.insert_at(prefix, -1, key), env)
    end)
  end

  defp get_keys({:=, _, [struct, {var, meta, context}]}, keys, operations, prefix, env) do
    {keys, operations} = get_keys(struct, keys, operations, prefix, env)
    get_keys({var, meta, context}, keys, operations, prefix, env)
  end

  defp get_keys({:^, _, [var]}, keys, operations, prefix, _env) do
    operations = [{:==, [{:access, prefix}, var]} | operations]
    {keys, operations}
  end

  defp get_keys({var, _, _}, keys, operations, prefix, _env) do
    case Map.get(keys, var) do
      nil ->
        keys = Map.put(keys, var, prefix)
        {keys, operations}

      access ->
        operations = [{:==, [{:access, prefix}, {:access, access}]} | operations]
        {keys, operations}
    end
  end

  defp get_keys(value, keys, operations, prefix, _env) do
    operations = [{:==, [{:access, prefix}, value]} | operations]
    {keys, operations}
  end

  def generate({:fn, _, cases}, env) do
    do_generate(cases, [], env)
  end

  defp do_generate([fncase], guards, env) do
    {_, code} = with_guard(fncase, guards, env)
    code
  end

  defp do_generate([fncase | tail], guards, env) do
    {guard, code} = with_guard(fncase, guards, env)

    guards = List.insert_at(guards, -1, guard)
    tail_code = do_generate(tail, guards, env)

    # literal tuple
    {:or, [code, tail_code]}
  end

  defp with_guard(fncase, guards, env) do
    {guard, code} = gen(fncase, env)

    code =
      guards
      |> Enum.map(fn guard -> {:==, [guard, false]} end)
      |> List.insert_at(-1, guard)
      |> all()
      |> gen_and(code)

    {guard, code}
  end

  defp gen({:->, _, [[arg], {:__block__, _, [expression]}]}, env) do
    gen({:->, [], [[arg], expression]}, env)
  end

  defp gen({:->, _, [[arg], expression]}, env) do
    {keys, operations} = get_keys(arg, env)

    code =
      expression
      |> Macro.prewalk(&expand_embedded(&1, env))
      |> Macro.postwalk(&walk(&1, keys, env))

    guard =
      operations
      |> Enum.reverse()
      |> all()

    {guard, code}
  end

  defp expand_embedded(node, env) do
    case node do
      {{:., _, [{:__aliases__, _, [:Filter]}, :new]}, _, _} ->
        {filter, _} =
          node
          |> Code.eval_quoted([], env)

        filter

      node ->
        node
    end
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

  # Function call
  defp walk({{:., _, [module, function]}, _, args} = node, _keys, env) do
    expanded_module = Macro.expand(module, env)

    cond do
      expanded_module == Filter and function == :match? ->
        # Embedded filter
        case args do
          [%Filter{code: code}, {:access, keys}] ->
            quote do
              unquote(__MODULE__).with_prefix(unquote(code), unquote(keys))
            end

          [filter, {:access, keys}] ->
            quote do
              unquote(__MODULE__).with_prefix(unquote(filter).code, unquote(keys))
            end
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

  defp gen_and(true, arg2), do: arg2
  defp gen_and(arg1, true), do: arg1
  defp gen_and(arg1, arg2), do: {:and, [arg1, arg2]}
end
