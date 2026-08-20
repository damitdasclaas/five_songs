defmodule FiveSongs.SpotifyTokens do
  @moduledoc """
  Hilfen für Spotify-Access-Token-Laufzeit.

  Access-Tokens gelten ca. 1h. Wir refreshen 15 Min vorher, damit
  API-Calls und der Web Playback SDK nicht mit einem toten Token laufen.
  """

  @default_expires_in 3600
  @refresh_skew_sec 15 * 60
  @min_refresh_delay_sec 30

  def expires_at(body) when is_map(body) do
    System.system_time(:second) + expires_in(body)
  end

  def expires_in(body) when is_map(body) do
    parse_expires_in(body["expires_in"] || body[:expires_in])
  end

  def parse_expires_in(val) when is_integer(val) and val > 0, do: val
  def parse_expires_in(val) when is_float(val) and val > 0, do: trunc(val)

  def parse_expires_in(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} when int > 0 -> int
      _ -> @default_expires_in
    end
  end

  def parse_expires_in(_), do: @default_expires_in

  @doc """
  Millisekunden bis zum nächsten proaktiven Refresh.
  Fehlt `expires_at` (alte Sessions), fallen wir auf 45 Minuten zurück.
  """
  def refresh_in_ms(expires_at) when is_integer(expires_at) do
    now = System.system_time(:second)
    delay_sec = max(expires_at - now - @refresh_skew_sec, @min_refresh_delay_sec)
    delay_sec * 1000
  end

  def refresh_in_ms(_), do: 45 * 60 * 1000

  def refresh_soon?(expires_at) when is_integer(expires_at) do
    expires_at - System.system_time(:second) <= @refresh_skew_sec
  end

  def refresh_soon?(_), do: false
end
