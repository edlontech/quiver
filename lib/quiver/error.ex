defmodule Quiver.Error do
  @moduledoc """
  Structured error system for Quiver.

  Errors are classified by recoverability:
  - `:transient` -- temporary failures, retry may succeed
  - `:invalid` -- caller-side mistake, fix input and retry
  - `:unrecoverable` -- infrastructure broken, escalate
  """

  use Splode,
    error_classes: [
      transient: Quiver.Error.Transient,
      invalid: Quiver.Error.Invalid,
      unrecoverable: Quiver.Error.Unrecoverable
    ],
    unknown_error: Quiver.Error.Unknown
end
