# IntervalMap

*WORK IN PROGRESS*

IntervalMap is an interval-bucketizing map. Given a key, you can ask for the interval in which it falls, intervals do not have to be contiguous.

Intervals are "bounded, left open, right closed". That is, all intervals are finite, and "left < n <= right". Intervals may not overlap.

You can use any term types to specify interval bounds, just take care to make sure it's meaningful, see the "Term ordering" section of Elixir's [Operators](https://hexdocs.pm/elixir/operators.html) documentation.

IntervalMap is implemented as a `:gb_tree`, where the "right" value is used as the storage key, this should give us O(log n) for get/put.

## Example

```elixir
map =
  IntervalMap.new()
  |> IntervalMap.put({0, 100}, :a_bucket)
  |> IntervalMap.put({200, 300}, :another_bucket)

IntervalMap.get(map, 55)
# => %IntervalMap.Interval{left: 0, right: 100, value: :a_bucket}

IntervalMap.get(map, 250)
# => %IntervalMap.Interval{left: 200, right: 300, value: :another_bucket}
```

## Installation

The package can be installed by adding `interval_map` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:interval_map, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/interval_map](https://hexdocs.pm/interval_map).
