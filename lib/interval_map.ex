defmodule IntervalMap do
  @moduledoc """
  IntervalMap is an interval-bucketizing map. Given a key, you can ask for the interval in which it falls, intervals do not have to be contiguous.

  Intervals are "bounded, left open, right closed". That is, all intervals are finite, and "left < n <= right". Intervals may not overlap.

  You can use any term types to specify interval bounds, just take care to make sure it's meaningful, see the "Term ordering" section of Elixir's [Operators](https://hexdocs.pm/elixir/operators.html) documentation.

  IntervalMap is implemented as a `:gb_tree`, where the "right" value is used as the storage key, this should give us O(log n) for get/put.
  """

  alias IntervalMap.OverlappingIntervalsError
  alias IntervalMap.InvalidIntervalError
  alias IntervalMap.Interval
  import IntervalMap.Interval, only: [in_interval: 3]

  defstruct tree: :gb_trees.empty()

  @type t :: %__MODULE__{
    tree: :gb_trees.tree(bound, Interval.t)
  }

  @type bound :: any
  @type bounds :: {bound, bound}
  @type key :: bound
  @type value :: any

  @doc "Creates a new Interval Map"
  @spec new :: t
  def new do
    %__MODULE__{}
  end

  @doc """
  Puts the given interval into the map, specified by the bounds `left` and `right``, and an optional value to store with the interval.
  """
  @spec put(t, bounds, value) :: t | {:error, OverlappingIntervalsError.t() | InvalidIntervalError.t()}
  def put(map, bounds, value \\ nil)

  def put(%__MODULE__{} = map, %Interval{left: left, right: right}, value), do: put(map, {left, right}, value)

  def put(%__MODULE__{tree: tree} = map, {left, right}, value) when left < right do
    interval = %Interval{left: left, right: right, value: value}

    case get_from_tree(tree, left) do
      :not_found ->
        :ok

      # we found an interval that ends exactly where our new interval starts (due to the fact that we store the `right` interval bounds)
      # so we need to get the next interval to see if it overlaps with our requested interval
      {%Interval{right: found_right}, iterator} when found_right == left ->
        case next(iterator) do
          {found, _iterator} ->
            found
          :not_found ->
            :ok
        end

      {found, _iterator} ->
        found
    end
    |> case do
         :ok ->
           :ok

         found ->
           if intervals_overlap?(interval, found) do
             {:error, OverlappingIntervalsError.exception(requested: interval, existing: found)}
           else
             :ok
           end
       end
    |> case do
         :ok ->
           %__MODULE__{map | tree: put_into_tree(tree, interval)}

         error ->
           error
       end
  end

  def put(_map, bounds, _value), do: {:error, InvalidIntervalError.exception(bounds)}


  @doc """
  Gets the interval in which the provided key resides.
  """
  @spec get(t, key) :: Interval.t() | :not_found
  def get(%__MODULE__{tree: tree}, key) do
    case get_from_tree(tree, key) do
      {%Interval{left: left, right: right} = interval, _iterator} when in_interval(key, left, right) ->
        interval

      _ ->
        :not_found
    end
  end

  @doc """
  Gets the value from the interval in which the provided key resides.
  """
  @spec get_value(t, key) :: {:value, value} | :not_found
  def get_value(%__MODULE__{} = map, key) do
    case get(map, key) do
      %Interval{value: value} ->
        {:value, value}

      :not_found ->
        :not_found
    end
  end

  @doc """
  Indicates if the given key falls into one of the map's intervals.
  """
  @spec key_member?(t, key) :: boolean()
  def key_member?(%__MODULE__{} = map, key) do
    case get(map, key) do
      %Interval{} ->
        true

      :not_found ->
        false
    end
  end

  @doc """
  Indicates if the given bounds fall within a single interval.
  """
  @spec bounds_member?(t, bounds) :: boolean()
  def bounds_member?(%__MODULE__{} = map, {left, right}) do
    with %Interval{} = left_interval <- get(map, left),
         %Interval{} = right_interval <- get(map, right) do

      left_interval == right_interval
    else
      _ ->
        false
    end
  end

  @doc """
  Removes the given `bounds_or_interval` from the `map`, removing or modifying any intervals necessary.

  O(n) at the moment, but could be made O(log(n)) for cases that only involve one or fewer intervals
  """
  @spec delete(t, bounds_or_interval :: bounds | Interval.t()) :: t
  def delete(%__MODULE__{} = map, %Interval{left: left, right: right}), do: delete(map, {left, right})

  def delete(%__MODULE__{tree: tree} = map, {left, right} = bounds) when left < right do
    tree =
      map
      |> to_list()
      |> Enum.reduce(tree, fn interval, tree ->
        delete_bounds_from_single_interval(tree, interval, bounds)
      end)

    %__MODULE__{map | tree: tree}
  end

  @doc """
  Returns an in-order list of intervals in the provided map.
  """
  @spec to_list(t) :: [Interval.t()]
  def to_list(%__MODULE__{tree: tree}) do
    :gb_trees.values(tree)
  end

  @doc """
  Returns the range of the map, that is, the leftmost and rightmost members.

  Remember, intervals are "left open, right closed".
  """
  @spec range(t) :: Interval.t()
  def range(%__MODULE__{} = map) do
    intervals = to_list(map)
    %Interval{left: min} = Enum.min_by(intervals, fn %Interval{left: left} -> left end)
    %Interval{right: max} = Enum.max_by(intervals, fn %Interval{right: right} -> right end)

    %Interval{left: min, right: max}
  end

  @doc """
  Indicates if the given intervals form a continuous range (no gaps between any intervals)
  """
  @spec contiguous?(t) :: boolean
  def contiguous?(%__MODULE__{} = map) do
    map
    |> to_list
    |> do_contiguous?
  end

  defp do_contiguous?([_interval]), do: true
  defp do_contiguous?([%Interval{left: _left, right: next_left}, %Interval{left: next_left, right: _next_right} = next | rest]), do: do_contiguous?([next | rest])
  defp do_contiguous?([%Interval{}, %Interval{} | _rest]), do: false

  defp get_from_tree(tree, key) do
    key
    |> :gb_trees.iterator_from(tree)
    |> next
  end

  defp next(iterator) do
    iterator
    |> :gb_trees.next()
    |> case do
      :none ->
        :not_found

      {_key, interval, iterator} ->
        {interval, iterator}
    end
  end

  defp put_into_tree(tree, %Interval{right: right} = interval) do
    :gb_trees.insert(right, interval, tree)
  end

  defp delete_from_tree(tree, %Interval{right: right}) do
    :gb_trees.delete(right, tree)
  end

  defp intervals_overlap?(%Interval{left: left, right: right},
                          %Interval{left: other_left, right: other_right}) when (left < other_left and right <= other_left)
                                                                             or (other_right <= left and other_right < right), do: false
  defp intervals_overlap?(_interval, _other_interval), do: true


  #                |--- interval ---|
  # |--- bounds ---|
  # bounds lie completely to the left of interval
  defp delete_bounds_from_single_interval(tree, %Interval{left: interval_left}, {_left, right}) when right <= interval_left do
    tree
  end


  # |--- interval ---|
  #                  |--- bounds ---|
  # bounds lie completely to the right of interval
  #
  defp delete_bounds_from_single_interval(tree, %Interval{right: interval_right}, {left, _right}) when interval_right <= left do
    tree
  end

  #   |--- interval ---|
  # |------ bounds -------|
  # interval is completely inside bounds
  defp delete_bounds_from_single_interval(tree, %Interval{left: interval_left, right: interval_right} = interval, {left, right}) when left <= interval_left and interval_right <= right do
    delete_from_tree(tree, interval)
  end

  # |--- interval ----|
  #   |-- bounds ---|
  # bounds are completely inside interval
  defp delete_bounds_from_single_interval(tree, %Interval{left: interval_left, right: interval_right} = interval, {left, right}) when interval_left < left and right < interval_right do
    left_interval = %Interval{interval | left: interval_left, right: left}
    right_interval = %Interval{interval | left: right, right: interval_right}

    tree
    |> delete_from_tree(interval)
    |> put_into_tree(left_interval)
    |> put_into_tree(right_interval)
  end

  #    |--- interval ---|
  # |--- bounds ---|
  # bounds start before or at interval start and ends inside the interval
  defp delete_bounds_from_single_interval(tree, %Interval{left: interval_left, right: interval_right} = interval, {left, right}) when left <= interval_left and right < interval_right do
    right_interval = %Interval{interval | left: right, right: interval_right}

    tree
    |> delete_from_tree(interval)
    |> put_into_tree(right_interval)
  end

  # |--- interval ----|
  #        |--- bounds ---|
  # bounds start inside interval and ends at or after interval end
  defp delete_bounds_from_single_interval(tree, %Interval{left: interval_left, right: interval_right} = interval, {left, right}) when interval_left < left and interval_right <= right do
    left_interval = %Interval{interval | left: interval_left, right: left}

    tree
    |> delete_from_tree(interval)
    |> put_into_tree(left_interval)
  end

  defp delete_bounds_from_single_interval(tree, interval, bounds) do
    :gb_trees.values(tree)
    |> IO.inspect
    IO.inspect bounds
    IO.inspect(interval, label: :FELL_THROUGH)
    raise "shit"
    tree
  end
end
