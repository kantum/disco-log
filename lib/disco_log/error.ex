defmodule DiscoLog.Error do
  @moduledoc """
  Struct for error or exception.
  """

  alias __MODULE__
  alias DiscoLog.Stacktrace

  defstruct ~w(kind reason source_line source_function context stacktrace fingerprint)a

  def new(exception, stacktrace, context) do
    {kind, reason} = normalize_exception(exception, stacktrace)
    stacktrace = Stacktrace.new(stacktrace)
    source = Stacktrace.source(stacktrace)

    source_line =
      if not is_nil(source.file) and source.file != "",
        do: "#{source.file}:#{source.line}",
        else: "nofile"

    source_function = "#{source.module}.#{source.function}/#{source.arity}"

    %Error{
      kind: kind,
      reason: reason,
      source_line: source_line,
      source_function: source_function,
      context: context,
      stacktrace: stacktrace,
      fingerprint: fingerprint(kind, source_line, source_function)
    }
  end

  defp normalize_exception(%struct{} = ex, _stacktrace) when is_exception(ex) do
    {to_string(struct), Exception.message(ex)}
  end

  defp normalize_exception({kind, ex}, stacktrace) do
    case Exception.normalize(kind, ex, stacktrace) do
      %struct{} = ex ->
        {to_string(struct), Exception.message(ex)}

      other ->
        {to_string(kind), to_string(other)}
    end
  end

  # Fingerprint is used to group the similar errors together
  # Original implementation from https://github.com/elixir-error-tracker/error-tracker/blob/main/lib/error_tracker/schemas/error.ex#L40
  defp fingerprint(kind, source_line, source_function) do
    values = Enum.join([kind, source_line, source_function])
    hash = :crypto.hash(:sha256, values)
    Base.encode16(hash) |> binary_part(0, 16)
  end

  @doc """
  Used to compare errors for deduplication original implementation from Sentry Elixir
  https://github.com/getsentry/sentry-elixir/blob/69ac8d0e3f33ff36ab1092bbd346fdb99cf9d061/lib/sentry/event.ex#L613
  """
  def hash(%Error{} = error) do
    :erlang.phash2([
      error.kind,
      error.reason,
      error.stacktrace,
      error.context
    ])
  end
end
