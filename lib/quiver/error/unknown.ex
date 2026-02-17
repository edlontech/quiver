defmodule Quiver.Error.Unknown do
  @moduledoc false

  use Splode.ErrorClass, class: :unknown

  def exception(opts) do
    if opts[:error] do
      super(Keyword.update(opts, :errors, [opts[:error]], &[opts[:error] | &1]))
    else
      super(opts)
    end
  end
end
