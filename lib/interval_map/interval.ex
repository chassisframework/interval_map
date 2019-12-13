defmodule IntervalMap.Interval do
  defstruct [:left, :right, :value]

  @type bound :: IntervalMap.bound

  @type t :: %__MODULE__{
    left: bound,
    right: bound,
    value: any
  }

  defguard in_interval(key, left, right) when left < key and key <= right
end
