defmodule IntervalMap.OverlappingIntervalsError do
  alias IntervalMap.Interval

  defexception [:message, :existing, :requested]

  @type t :: %__MODULE__{
    message: String.t,
    requested: Interval.t,
    existing: Interval.t
  }

  @impl true
  def exception(requested: requested, existing: existing) do
    msg = "Overlapping intervals requested."
    %__MODULE__{message: msg, requested: requested, existing: existing}
  end
end

defmodule IntervalMap.InvalidIntervalError do
  defexception [:message, :left, :right]

  @type bound :: IntervalMap.bound

  @type t :: %__MODULE__{
    message: String.t,
    left: bound,
    right: bound
  }

  @impl true
  def exception({left, right}) do
    msg = "Invalid interval, left must be less than right"
    %__MODULE__{message: msg, left: left, right: right}
  end
end
