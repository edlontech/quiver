defmodule Quiver.Error.Invalid do
  @moduledoc """
  Caller-side mistakes where fixing the input resolves the error.
  """

  use Splode.ErrorClass, class: :invalid
end

defmodule Quiver.Error.InvalidScheme do
  @moduledoc """
  URL with unsupported URI scheme.
  """

  use Splode.Error, fields: [:scheme], class: :invalid
  @type t :: Splode.Error.t()

  def message(%{scheme: scheme}), do: "unsupported URI scheme: #{scheme}"
end

defmodule Quiver.Error.MalformedHeaders do
  @moduledoc """
  Unparseable HTTP header line.
  """

  use Splode.Error, fields: [:message], class: :invalid
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.InvalidContentLength do
  @moduledoc """
  Non-numeric or conflicting content-length value.
  """

  use Splode.Error, fields: [:message], class: :invalid
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.InvalidPoolOpts do
  @moduledoc """
  Pool options failed Zoi validation.
  """

  use Splode.Error, fields: [:errors], class: :invalid
  @type t :: Splode.Error.t()

  def message(%{errors: errors}) do
    "invalid pool options: #{Enum.join(errors, ", ")}"
  end
end

defmodule Quiver.Error.InvalidPoolRule do
  @moduledoc """
  Pool config key could not be parsed as a valid origin pattern.
  """

  use Splode.Error, fields: [:rule, :reason], class: :invalid
  @type t :: Splode.Error.t()

  def message(%{rule: rule, reason: reason}) do
    "invalid pool rule #{inspect(rule)}: #{reason}"
  end
end
