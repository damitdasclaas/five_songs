defmodule FiveSongs.SpotifyTokensTest do
  use ExUnit.Case, async: true

  alias FiveSongs.SpotifyTokens

  test "expires_at uses expires_in from the token body" do
    now = System.system_time(:second)
    assert_in_delta SpotifyTokens.expires_at(%{"expires_in" => 3600}), now + 3600, 2
  end

  test "expires_in falls back to one hour" do
    assert SpotifyTokens.expires_in(%{}) == 3600
    assert SpotifyTokens.parse_expires_in("3600") == 3600
    assert SpotifyTokens.parse_expires_in(nil) == 3600
  end

  test "refresh_soon? is true within the 15 minute skew" do
    soon = System.system_time(:second) + 5 * 60
    later = System.system_time(:second) + 40 * 60

    assert SpotifyTokens.refresh_soon?(soon)
    refute SpotifyTokens.refresh_soon?(later)
    refute SpotifyTokens.refresh_soon?(nil)
  end

  test "refresh_in_ms keeps a minimum delay" do
    already_expired = System.system_time(:second) - 10
    assert SpotifyTokens.refresh_in_ms(already_expired) == 30_000
    assert SpotifyTokens.refresh_in_ms(nil) == 45 * 60 * 1000
  end
end
