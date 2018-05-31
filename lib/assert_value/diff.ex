defmodule AssertValue.Diff do

  @prefixes %{eq: " ", ins: "+", del: "-", hunk: ""}

  def diff(a, b) when is_binary(a) and is_binary(b) do
    a = AssertValue.StringTools.to_lines(a)
    b = AssertValue.StringTools.to_lines(b)
    List.myers_difference(a, b)
    |> to_hunks
    |> format_diff
  end

  # Algorithm below iterates over Myers difference edit scripts
  # and replaces big chunks of equal lines with hunk headers and contexts
  #
  # Input:
  #
  # {eq: ["foo", "foo", "foo", "foo", "foo", "foo", "foo", "foo"]},
  # {del: ["foo", "bar"]},
  # {ins: ["bar"]},
  # {eq: ["foo", "foo", "foo", "foo", "foo", "foo", "foo", "foo"]}
  #
  # Output:
  #
  # {hunk: ["@@ -4,5 +4,8 @@"],    # hunk header
  # {eq: ["foo", "foo", "foo"]},   # context (eq1)
  # {del: ["foo", "bar"]},
  # {ins: ["bar"]},
  # {eq: ["foo", "foo", "foo"]}    # context (eq2)
  #
  # And in terms of diff:
  #
  #  before:             after:
  #
  #  ...   |                  +--- left (position in left value)
  #  ...   |                  | +- eq + del (length in left value)
  #  ...   | skip             | |  +------ right (position in right value)
  #  ...   |                  | |  | +---- eq + ins (length in right value)
  #  ... --+              @@ -4,5 +4,8 @@
  #  foo --+               foo
  #  foo   | eq1           foo
  #  foo --+               foo
  # -foo                  -foo
  # -bar                  -bar
  # +baz                  +baz
  #  foo --+               foo
  #  foo   | eq2           foo
  #  foo --+               foo
  #  ... --+
  #  ...   | skip
  #  ...   |
  #  ...   |
  #
  #
  # In any other languages we would use variables and loop, but in Elixir
  # we have to use Enum.reduce and accumulator map with counters
  defp to_hunks(diff) do
    context_len = 3
    acc = %{
      result: [],
      hunk:   [],
      left:   1,
      right:  1,
      eq:     0,
      del:    0,
      ins:    0,
    }

    diff
    |> Enum.reduce(acc, fn(script = {op, lines}, acc) ->
      cond do
        op == :del ->
          %{acc |
            del: acc.del + length(lines),
            hunk: [acc.hunk, script]
          }
        op == :ins ->
          %{acc |
            ins: acc.ins + length(lines),
            hunk: [acc.hunk, script]
          }
        op == :eq and length(lines) <= context_len * 2 ->
          %{acc |
            eq: acc.eq + length(lines),
            hunk: [acc.hunk, script]
          }
        op == :eq and length(lines) > context_len * 2 ->
          skip_cnt = length(lines) - context_len * 2
          eq1 = Enum.take(lines,  context_len)
          eq2 = Enum.take(lines, -context_len)
          acc = %{acc |
            eq: acc.eq + context_len,
            hunk: [acc.hunk, {:eq, eq1}]
          }
          |> push_current_hunk()
          # calculates position of new hunk and reset counters
          %{acc |
            left: acc.left + acc.eq + acc.del + skip_cnt,
            right: acc.right + acc.eq + acc.ins + skip_cnt,
            eq: context_len,
            del: 0,
            ins: 0,
            hunk: [{:eq, eq2}] # start new hunk
          }
      end
    end)
    |> push_current_hunk()
    |> Map.get(:result)
    |> List.flatten
  end

  defp push_current_hunk(acc) do
    if length(acc.hunk) > 0 and (acc.del > 0 or acc.ins > 0) do
      %{acc | result: [acc.result, {:hunk, [hunk_header(acc)]}, acc.hunk]}
    else
      acc
    end
  end

  defp hunk_header(acc) do
    "@@ " <>
    "-#{acc.left},#{acc.eq + acc.del} " <>
    "+#{acc.right},#{acc.eq + acc.ins} " <>
    "@@"
  end

  defp format_diff(diff) do
    diff
    |> Enum.map(fn({k, v}) ->
        Enum.map(v, fn(s) ->
          @prefixes[k] <> s
        end)
      end)
    |> List.flatten
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

end
