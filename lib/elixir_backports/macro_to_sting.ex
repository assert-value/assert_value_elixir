defmodule ElixirBackports.MacroToString do

  # Backport Elixir's Macro.to_string fixed in commit
  # https://github.com/elixir-lang/elixir/commit/f20774547b945d6a8756f2fd7bdb56208084ab4c

  # File source:
  # https://raw.githubusercontent.com/elixir-lang/elixir/f20774547b945d6a8756f2fd7bdb56208084ab4c/lib/elixir/lib/macro.ex
  #
  # Lines 562 - 1072

  @moduledoc false

  alias Code.Identifier

  def to_string(tree, fun \\ fn _ast, string -> string end)

  # Variables
  def to_string({var, _, atom} = ast, fun) when is_atom(atom) do
    fun.(ast, Atom.to_string(var))
  end

  # Aliases
  def to_string({:__aliases__, _, refs} = ast, fun) do
    fun.(ast, Enum.map_join(refs, ".", &call_to_string(&1, fun)))
  end

  # Blocks
  def to_string({:__block__, _, [expr]} = ast, fun) do
    fun.(ast, to_string(expr, fun))
  end

  def to_string({:__block__, _, _} = ast, fun) do
    block = adjust_new_lines(block_to_string(ast, fun), "\n  ")
    fun.(ast, "(\n  " <> block <> "\n)")
  end

  # Bits containers
  def to_string({:<<>>, _, parts} = ast, fun) do
    if interpolated?(ast) do
      fun.(ast, interpolate(ast, fun))
    else
      result =
        Enum.map_join(parts, ", ", fn part ->
          str = bitpart_to_string(part, fun)

          if :binary.first(str) == ?< or :binary.last(str) == ?> do
            "(" <> str <> ")"
          else
            str
          end
        end)

      fun.(ast, "<<" <> result <> ">>")
    end
  end

  # Tuple containers
  def to_string({:{}, _, args} = ast, fun) do
    tuple = "{" <> Enum.map_join(args, ", ", &to_string(&1, fun)) <> "}"
    fun.(ast, tuple)
  end

  # Map containers
  def to_string({:%{}, _, args} = ast, fun) do
    map = "%{" <> map_to_string(args, fun) <> "}"
    fun.(ast, map)
  end

  def to_string({:%, _, [struct_name, map]} = ast, fun) do
    {:%{}, _, args} = map
    struct = "%" <> to_string(struct_name, fun) <> "{" <> map_to_string(args, fun) <> "}"
    fun.(ast, struct)
  end

  # Fn keyword
  def to_string({:fn, _, [{:->, _, [_, tuple]}] = arrow} = ast, fun)
      when not is_tuple(tuple) or elem(tuple, 0) != :__block__ do
    fun.(ast, "fn " <> arrow_to_string(arrow, fun) <> " end")
  end

  def to_string({:fn, _, [{:->, _, _}] = block} = ast, fun) do
    fun.(ast, "fn " <> block_to_string(block, fun) <> "\nend")
  end

  def to_string({:fn, _, block} = ast, fun) do
    block = adjust_new_lines(block_to_string(block, fun), "\n  ")
    fun.(ast, "fn\n  " <> block <> "\nend")
  end

  # left -> right
  def to_string([{:->, _, _} | _] = ast, fun) do
    fun.(ast, "(" <> arrow_to_string(ast, fun, true) <> ")")
  end

  # left when right
  def to_string({:when, _, [left, right]} = ast, fun) do
    right =
      if right != [] and Keyword.keyword?(right) do
        kw_list_to_string(right, fun)
      else
        fun.(ast, op_to_string(right, fun, :when, :right))
      end

    fun.(ast, op_to_string(left, fun, :when, :left) <> " when " <> right)
  end

  # Splat when
  def to_string({:when, _, args} = ast, fun) do
    {left, right} = split_last(args)

    result =
      "(" <> Enum.map_join(left, ", ", &to_string(&1, fun)) <> ") when " <> to_string(right, fun)

    fun.(ast, result)
  end

  # Capture
  def to_string({:&, _, [{:/, _, [{name, _, ctx}, arity]}]} = ast, fun)
      when is_atom(name) and is_atom(ctx) and is_integer(arity) do
    result = "&" <> Atom.to_string(name) <> "/" <> to_string(arity, fun)
    fun.(ast, result)
  end

  def to_string({:&, _, [{:/, _, [{{:., _, [mod, name]}, _, []}, arity]}]} = ast, fun)
      when is_atom(name) and is_integer(arity) do
    result =
      "&" <> to_string(mod, fun) <> "." <> Atom.to_string(name) <> "/" <> to_string(arity, fun)

    fun.(ast, result)
  end

  def to_string({:&, _, [arg]} = ast, fun) when not is_integer(arg) do
    fun.(ast, "&(" <> to_string(arg, fun) <> ")")
  end

  # left not in right
  def to_string({:not, _, [{:in, _, [left, right]}]} = ast, fun) do
    fun.(ast, to_string(left, fun) <> " not in " <> to_string(right, fun))
  end

  # Access
  def to_string({{:., _, [Access, :get]}, _, [left, right]} = ast, fun) do
    if op_expr?(left) do
      fun.(ast, "(" <> to_string(left, fun) <> ")" <> to_string([right], fun))
    else
      fun.(ast, to_string(left, fun) <> to_string([right], fun))
    end
  end

  # foo.{bar, baz}
  def to_string({{:., _, [left, :{}]}, _, args} = ast, fun) do
    fun.(ast, to_string(left, fun) <> ".{" <> args_to_string(args, fun) <> "}")
  end

  # All other calls
  def to_string({target, _, args} = ast, fun) when is_list(args) do
    with :error <- unary_call(ast, fun),
         :error <- binary_call(ast, fun),
         :error <- sigil_call(ast, fun) do
      {list, last} = split_last(args)

      result =
        case kw_blocks?(last) do
          true -> call_to_string_with_args(target, list, fun) <> kw_blocks_to_string(last, fun)
          false -> call_to_string_with_args(target, args, fun)
        end

      fun.(ast, result)
    else
      {:ok, value} -> value
    end
  end

  # Two-element tuples
  def to_string({left, right}, fun) do
    to_string({:{}, [], [left, right]}, fun)
  end

  # Lists
  def to_string(list, fun) when is_list(list) do
    result =
      cond do
        list == [] ->
          "[]"

        :io_lib.printable_list(list) ->
          {escaped, _} = Identifier.escape(IO.chardata_to_string(list), ?')
          IO.iodata_to_binary([?', escaped, ?'])

        Inspect.List.keyword?(list) ->
          "[" <> kw_list_to_string(list, fun) <> "]"

        true ->
          "[" <> Enum.map_join(list, ", ", &to_string(&1, fun)) <> "]"
      end

    fun.(list, result)
  end

  # All other structures
  def to_string(other, fun) do
    fun.(other, inspect_no_limit(other))
  end

  defp inspect_no_limit(value) do
    Kernel.inspect(value, limit: :infinity, printable_limit: :infinity)
  end

  defp bitpart_to_string({:::, _, [left, right]} = ast, fun) do
    result =
      op_to_string(left, fun, :::, :left) <> "::" <> bitmods_to_string(right, fun, :::, :right)

    fun.(ast, result)
  end

  defp bitpart_to_string(ast, fun) do
    to_string(ast, fun)
  end

  defp bitmods_to_string({op, _, [left, right]} = ast, fun, _, _) when op in [:*, :-] do
    result =
      bitmods_to_string(left, fun, op, :left) <>
        Atom.to_string(op) <> bitmods_to_string(right, fun, op, :right)

    fun.(ast, result)
  end

  defp bitmods_to_string(other, fun, parent_op, side) do
    op_to_string(other, fun, parent_op, side)
  end

  # Block keywords
  kw_keywords = [:do, :rescue, :catch, :else, :after]

  defp kw_blocks?([{:do, _} | _] = kw) do
    Enum.all?(kw, &match?({x, _} when x in unquote(kw_keywords), &1))
  end

  defp kw_blocks?(_), do: false

  # Check if we have an interpolated string.
  defp interpolated?({:<<>>, _, [_ | _] = parts}) do
    Enum.all?(parts, fn
      {:::, _, [{{:., _, [Kernel, :to_string]}, _, [_]}, {:binary, _, _}]} -> true
      binary when is_binary(binary) -> true
      _ -> false
    end)
  end

  defp interpolated?(_) do
    false
  end

  defp interpolate({:<<>>, _, parts}, fun) do
    parts =
      Enum.map_join(parts, "", fn
        {:::, _, [{{:., _, [Kernel, :to_string]}, _, [arg]}, {:binary, _, _}]} ->
          "\#{" <> to_string(arg, fun) <> "}"

        binary when is_binary(binary) ->
          binary = inspect_no_limit(binary)
          :binary.part(binary, 1, byte_size(binary) - 2)
      end)

    <<?", parts::binary, ?">>
  end

  defp module_to_string(atom, _fun) when is_atom(atom) do
    inspect_no_limit(atom)
  end

  defp module_to_string({:&, _, [val]} = expr, fun) when not is_integer(val) do
    "(" <> to_string(expr, fun) <> ")"
  end

  defp module_to_string({:fn, _, _} = expr, fun) do
    "(" <> to_string(expr, fun) <> ")"
  end

  defp module_to_string({_, _, [_ | _] = args} = expr, fun) do
    if kw_blocks?(List.last(args)) do
      "(" <> to_string(expr, fun) <> ")"
    else
      to_string(expr, fun)
    end
  end

  defp module_to_string(expr, fun) do
    to_string(expr, fun)
  end

  defp unary_call({op, _, [arg]} = ast, fun) when is_atom(op) do
    case Identifier.unary_op(op) do
      {_, _} ->
        if op == :not or op_expr?(arg) do
          {:ok, fun.(ast, Atom.to_string(op) <> "(" <> to_string(arg, fun) <> ")")}
        else
          {:ok, fun.(ast, Atom.to_string(op) <> to_string(arg, fun))}
        end

      :error ->
        :error
    end
  end

  defp unary_call(_, _) do
    :error
  end

  defp binary_call({op, _, [left, right]} = ast, fun) when is_atom(op) do
    case Identifier.binary_op(op) do
      {_, _} ->
        left = op_to_string(left, fun, op, :left)
        right = op_to_string(right, fun, op, :right)
        op = if op in [:..], do: "#{op}", else: " #{op} "
        {:ok, fun.(ast, left <> op <> right)}

      :error ->
        :error
    end
  end

  defp binary_call(_, _) do
    :error
  end

  defp sigil_call({sigil, _, [{:<<>>, _, _} = parts, args]} = ast, fun)
       when is_atom(sigil) and is_list(args) do
    case Atom.to_string(sigil) do
      <<"sigil_", name>> when name in ?A..?Z ->
        {:<<>>, _, [binary]} = parts

        formatted =
          if :binary.last(binary) == ?\n do
            binary = String.replace(binary, ~s["""], ~s["\\""])
            <<?~, name, ~s["""\n], binary::binary, ~s["""], sigil_args(args, fun)::binary>>
          else
            {left, right} = select_sigil_container(binary)
            <<?~, name, left, binary::binary, right, sigil_args(args, fun)::binary>>
          end

        {:ok, fun.(ast, formatted)}

      <<"sigil_", name>> when name in ?a..?z ->
        {:ok, fun.(ast, "~" <> <<name>> <> interpolate(parts, fun) <> sigil_args(args, fun))}

      _ ->
        :error
    end
  end

  defp sigil_call(_other, _fun) do
    :error
  end

  defp select_sigil_container(binary) do
    cond do
      :binary.match(binary, ["\""]) == :nomatch -> {?", ?"}
      :binary.match(binary, ["\'"]) == :nomatch -> {?', ?'}
      :binary.match(binary, ["(", ")"]) == :nomatch -> {?(, ?)}
      :binary.match(binary, ["[", "]"]) == :nomatch -> {?[, ?]}
      :binary.match(binary, ["{", "}"]) == :nomatch -> {?{, ?}}
      :binary.match(binary, ["<", ">"]) == :nomatch -> {?<, ?>}
      true -> {?/, ?/}
    end
  end

  defp sigil_args([], _fun), do: ""
  defp sigil_args(args, fun), do: fun.(args, List.to_string(args))

  defp op_expr?(expr) do
    case expr do
      {op, _, [_, _]} ->
        Identifier.binary_op(op) != :error

      {op, _, [_]} ->
        Identifier.unary_op(op) != :error

      _ ->
        false
    end
  end

  defp call_to_string(atom, _fun) when is_atom(atom), do: Atom.to_string(atom)
  defp call_to_string({:., _, [arg]}, fun), do: module_to_string(arg, fun) <> "."

  defp call_to_string({:., _, [left, right]}, fun) when is_atom(right),
    do: module_to_string(left, fun) <> "." <> call_to_string_for_atom(right)

  defp call_to_string({:., _, [left, right]}, fun),
    do: module_to_string(left, fun) <> "." <> call_to_string(right, fun)

  defp call_to_string(other, fun), do: to_string(other, fun)

  defp call_to_string_with_args(target, args, fun) do
    target = call_to_string(target, fun)
    args = args_to_string(args, fun)
    target <> "(" <> args <> ")"
  end

  defp call_to_string_for_atom(atom) do
    Identifier.inspect_as_function(atom)
  end

  defp args_to_string(args, fun) do
    {list, last} = split_last(args)

    if last != [] and Inspect.List.keyword?(last) do
      prefix =
        case list do
          [] -> ""
          _ -> Enum.map_join(list, ", ", &to_string(&1, fun)) <> ", "
        end

      prefix <> kw_list_to_string(last, fun)
    else
      Enum.map_join(args, ", ", &to_string(&1, fun))
    end
  end

  defp kw_blocks_to_string(kw, fun) do
    Enum.reduce(unquote(kw_keywords), " ", fn x, acc ->
      case Keyword.has_key?(kw, x) do
        true -> acc <> kw_block_to_string(x, Keyword.get(kw, x), fun)
        false -> acc
      end
    end) <> "end"
  end

  defp kw_block_to_string(key, value, fun) do
    block = adjust_new_lines(block_to_string(value, fun), "\n  ")
    Atom.to_string(key) <> "\n  " <> block <> "\n"
  end

  defp block_to_string([{:->, _, _} | _] = block, fun) do
    Enum.map_join(block, "\n", fn {:->, _, [left, right]} ->
      left = comma_join_or_empty_paren(left, fun, false)
      left <> "->\n  " <> adjust_new_lines(block_to_string(right, fun), "\n  ")
    end)
  end

  defp block_to_string({:__block__, _, exprs}, fun) do
    Enum.map_join(exprs, "\n", &to_string(&1, fun))
  end

  defp block_to_string(other, fun), do: to_string(other, fun)

  defp map_to_string([{:|, _, [update_map, update_args]}], fun) do
    to_string(update_map, fun) <> " | " <> map_to_string(update_args, fun)
  end

  defp map_to_string(list, fun) do
    cond do
      Inspect.List.keyword?(list) -> kw_list_to_string(list, fun)
      true -> map_list_to_string(list, fun)
    end
  end

  defp kw_list_to_string(list, fun) do
    Enum.map_join(list, ", ", fn {key, value} ->
      Identifier.inspect_as_key(key) <> " " <> to_string(value, fun)
    end)
  end

  defp map_list_to_string(list, fun) do
    Enum.map_join(list, ", ", fn
      {key, value} -> to_string(key, fun) <> " => " <> to_string(value, fun)
      other -> to_string(other, fun)
    end)
  end

  defp wrap_in_parenthesis(expr, fun) do
    "(" <> to_string(expr, fun) <> ")"
  end

  defp op_to_string({op, _, [_, _]} = expr, fun, parent_op, side) when is_atom(op) do
    case Identifier.binary_op(op) do
      {_, prec} ->
        {parent_assoc, parent_prec} = Identifier.binary_op(parent_op)

        cond do
          parent_prec < prec -> to_string(expr, fun)
          parent_prec > prec -> wrap_in_parenthesis(expr, fun)
          parent_assoc == side -> to_string(expr, fun)
          true -> wrap_in_parenthesis(expr, fun)
        end

      :error ->
        to_string(expr, fun)
    end
  end

  defp op_to_string(expr, fun, _, _), do: to_string(expr, fun)

  defp arrow_to_string(pairs, fun, paren \\ false) do
    Enum.map_join(pairs, "; ", fn {:->, _, [left, right]} ->
      left = comma_join_or_empty_paren(left, fun, paren)
      left <> "-> " <> to_string(right, fun)
    end)
  end

  defp comma_join_or_empty_paren([], _fun, true), do: "() "
  defp comma_join_or_empty_paren([], _fun, false), do: ""

  defp comma_join_or_empty_paren(left, fun, _) do
    Enum.map_join(left, ", ", &to_string(&1, fun)) <> " "
  end

  defp split_last([]) do
    {[], []}
  end

  defp split_last(args) do
    {left, [right]} = Enum.split(args, -1)
    {left, right}
  end

  defp adjust_new_lines(block, replacement) do
    for <<x <- block>>, into: "" do
      case x == ?\n do
        true -> replacement
        false -> <<x>>
      end
    end
  end

end
