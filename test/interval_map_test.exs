defmodule IntervalMapTest do
  use ExUnit.Case
  use PropCheck

  import IntervalMap.Generators

  alias IntervalMap.Interval
  alias IntervalMap.InvalidIntervalError
  alias IntervalMap.OverlappingIntervalsError

  # doctest IntervalMap

  property "support non-integer bounds" do
    forall left <- binary() do
      key = left <> "a"
      right = left <> "aa"

      map =
        IntervalMap.new()
        |> IntervalMap.put({left, right}, :thing)

      %Interval{value: value} = IntervalMap.get(map, key)

      value == :thing
    end
  end

  property "put/3 -> to_list/1 -> delete/2 round trip always ends with an empty map" do
    forall map <- interval_map() do
      IntervalMap.new() ==
        map
        |> IntervalMap.to_list
        |> Enum.reduce(map, fn interval, map ->
          IntervalMap.delete(map, interval)
        end)
    end
  end

  describe "get/2 + key_member?/2" do
    property "finds the correct interval in a contiguous map" do
      forall {map, left..right} <- contiguous_interval_map() do
        forall key <- range(left+1, right) do
          %Interval{left: found_left, right: found_right} = IntervalMap.get(map, key)

          assert IntervalMap.key_member?(map, key)

          found_left < key and key <= found_right
        end
      end
    end

    property "returns :not_found when the key doesn't lie inside an interval" do
      forall {map, left..right} <- contiguous_interval_map() do
        forall key <- range(:inf, left) do
          refute IntervalMap.key_member?(map, key)

          :not_found == IntervalMap.get(map, key)
        end

        forall key <- range(right+1, :inf) do
          refute IntervalMap.key_member?(map, key)

          :not_found == IntervalMap.get(map, key)
        end
      end
    end
  end

  test "get_value/2" do
    map =
      IntervalMap.new()
      |> IntervalMap.put({0, 10}, :thing)

    assert {:value, :thing} == IntervalMap.get_value(map, 5)
    assert :not_found == IntervalMap.get_value(map, 0)
  end

  describe "bounds_member?/2" do
    property "returns true when the given range lies within the same interval" do
      forall map <- interval_map() do
        %Interval{left: left, right: right} =
          map
          |> IntervalMap.to_list()
          |> Enum.random()

        assert IntervalMap.bounds_member?(map, {left+1, right})
      end
    end

    property "returns false when the range lies outside a single interval" do
      forall map <- interval_map() do
        %Interval{left: left, right: right} =
          map
          |> IntervalMap.to_list()
          |> Enum.random()

        refute IntervalMap.bounds_member?(map, {left, right})
        refute IntervalMap.bounds_member?(map, {left+1, right+1})
        refute IntervalMap.bounds_member?(map, {left, left+1})
        refute IntervalMap.bounds_member?(map, {right, right+1})

        true
      end
    end
  end

  describe "put/3" do
    test "stores a user-defined value alongside the interval" do
      assert %Interval{left: 1, right: 2, value: :thing} =
        IntervalMap.new()
        |> IntervalMap.put({1, 2}, :thing)
        |> IntervalMap.get(2)
    end

    property "rejects overlapping intervals" do
      forall [{left, right} <- integer_interval(),
              {new_left, new_right} <- integer_interval()] do
        map =
          IntervalMap.new()
          |> IntervalMap.put({left, right})

        if Range.disjoint?(left+1..right, new_left+1..new_right) do
          match?(%IntervalMap{}, IntervalMap.put(map, {new_left, new_right}))
        else
          match?({:error, %OverlappingIntervalsError{}}, IntervalMap.put(map, {new_left, new_right}))
        end
      end
    end

    property "rejects invalid intervals" do
      forall left <- integer() do
        return =
          IntervalMap.new()
          |> IntervalMap.put({left, left - 1})

        match?({:error, %InvalidIntervalError{}}, return)
      end
    end
  end

  describe "delete/2" do
    property "removes the given bounds from the map" do
      forall {map, map_left..map_right, {left, right} = bounds} <- interval_map_and_random_bounds() do
        deleted_map = IntervalMap.delete(map, bounds)

        left_outside_keys =
          if map_left < left do
            map_left+1..left
          else
            []
          end

        right_outside_keys =
          if right < map_right do
            right+1..map_right
          else
            []
          end

        Enum.each(left_outside_keys, fn i ->
          assert IntervalMap.key_member?(deleted_map, i) == IntervalMap.key_member?(map, i)
        end)

        Enum.each(right_outside_keys, fn i ->
          assert IntervalMap.key_member?(deleted_map, i) == IntervalMap.key_member?(map, i)
        end)

        Enum.each(left+1..right, fn i ->
          refute IntervalMap.key_member?(deleted_map, i)
        end)

        true
      end
    end
  end

  describe "to_list/1" do
    property "returns an in-order list of intervals" do
      forall {intervals, _range} <- integer_intervals() do
        map = intervals_to_map(intervals)

        # the generator already produces a sorted list
        intervals ==
          map
          |> IntervalMap.to_list
          |> Enum.map(fn %Interval{left: left, right: right} -> {left, right} end)
      end
    end
  end

  describe "range/1" do
    property "returns the leftmost and rightmost members of the map" do
      forall {map, left..right} <- contiguous_interval_map() do
        %Interval{left: left, right: right} == IntervalMap.range(map)
      end
    end
end

  describe "contiguous?/1" do
    property "returns true for a contiguous map" do
      forall {map, _range} <- contiguous_interval_map() do
        IntervalMap.contiguous?(map)
        # forall key <- range(left+1, right) do
        #   %Interval{left: found_left, right: found_right} = IntervalMap.get(map, key)

        #   found_left < key and key <= found_right
        # end
      end
    end

    property "returns false for a non-contiguous map" do
      gen = such_that {map, _range} <- contiguous_interval_map(),
              when: map |> IntervalMap.to_list |> length > 1

      forall {map, _range} <- gen do
        %Interval{left: left, right: right} = first_interval =
          map
          |> IntervalMap.to_list
          |> List.first

        false ==
          map
          |> IntervalMap.delete(first_interval)
          |> IntervalMap.put({left - 1, right - 1})
          |> IntervalMap.contiguous?
      end
    end
  end
end
