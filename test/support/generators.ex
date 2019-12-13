defmodule IntervalMap.Generators do
  use PropCheck

  def integer_interval(left_gen \\ integer()) do
    let [left <- left_gen, length <- pos_integer()] do
      {left, left + length}
    end
  end

  def interval_map do
    let {intervals, _range} <- integer_intervals() do
      intervals_to_map(intervals)
    end
  end

  def interval_map_and_range do
    let {intervals, range} <- integer_intervals() do
      {intervals_to_map(intervals), range}
    end
  end

  def interval_map_and_random_bounds do
    let {intervals, range} <- integer_intervals() do
      map = intervals_to_map(intervals)

      [bounds_left, bounds_right] =
        range
        |> Enum.take_random(2)
        |> Enum.sort()

      {map, range, {bounds_left, bounds_right}}
    end
  end

  def contiguous_interval_map do
    let {intervals, range} <- integer_intervals(0) do
      {intervals_to_map(intervals), range}
    end
  end

  def intervals_to_map(intervals) do
    Enum.reduce(intervals, IntervalMap.new(), fn {left, right}, map ->
      IntervalMap.put(map, {left, right})
    end)
  end

  def integer_intervals(distance_to_next_interval \\ non_neg_integer()) do
    let first_interval <- integer_interval() do
      integer_intervals([first_interval], distance_to_next_interval)
    end
  end

  defp integer_intervals([{_last_left, last_right} | _rest] = list, distance_to_next_interval) do
    frequency([
      {1, lazy(intervals_with_range(list))},
      {50,
       let distance <- distance_to_next_interval do
         let interval <- integer_interval(last_right + distance) do
           integer_intervals([interval | list], distance_to_next_interval)
         end
       end}
    ])
  end

  defp intervals_with_range([{_last_left, last_right} | _rest] = reversed_intervals) do
    intervals = Enum.reverse(reversed_intervals)
    [{first_left, _first_right} | _rest] = intervals
    {intervals, first_left..last_right}
  end
end
