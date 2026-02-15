defmodule FiveSongs.Tracks do
  @moduledoc """
  Filter, Cleaning und Zufallsauswahl für Spotify-Tracks.
  """

  alias Exspotify.Structs.Track

  def filter_valid(tracks) when is_list(tracks) do
    Enum.filter(tracks, &valid?/1)
  end

  defp valid?(%Track{name: name, artists: artists, album: album}) do
    is_binary(name) and name != "" and
      is_list(artists) and length(artists) > 0 and
      album != nil and release_year(album) != nil
  end

  defp valid?(_), do: false

  defp release_year(nil), do: nil
  defp release_year(%{release_date: nil}), do: nil
  defp release_year(%{release_date: date}) when is_binary(date) do
    case String.split(date, "-") do
      [y | _] when byte_size(y) == 4 -> y
      _ -> nil
    end
  end
  defp release_year(_), do: nil

  def pick_random_track([]), do: nil
  def pick_random_track(tracks), do: Enum.random(tracks)

  def reveal_data(%Track{name: name, artists: artists, album: album, external_urls: urls}) do
    %{
      title: clean_title(name),
      artist: artist_names(artists),
      year: release_year(album),
      spotify_url: urls && urls.spotify,
      cover_url: album_cover_url(album)
    }
  end

  # Mittleres Bild (~300px) bevorzugen, sonst das erste verfügbare
  defp album_cover_url(%{images: images}) when is_list(images) and images != [] do
    mid = Enum.find(images, fn img -> img.width && img.width <= 300 end)
    (mid || List.first(images)).url
  end
  defp album_cover_url(_), do: nil

  defp artist_names(nil), do: ""
  defp artist_names(artists) when is_list(artists) do
    artists
    |> Enum.map(& &1.name)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp clean_title(title) when is_binary(title) do
    title
    |> String.replace(~r/\s*\(.*[Rr]emaster[^)]*\)\s*/u, "")
    |> String.replace(~r/\s*-\s*[Rr]emastered.*$/u, "")
    |> String.replace(~r/\s*\(\d{4}\s*[Rr]emaster[^)]*\)\s*/u, "")
    |> String.trim()
  end
  defp clean_title(_), do: ""
end
