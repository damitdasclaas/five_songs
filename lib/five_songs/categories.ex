defmodule FiveSongs.Categories do
  @moduledoc """
  Die 5 Spiel-Kategorien mit id, label und Farbe für die UI.

  Kategorien werden per Shuffle-Bag gezogen: alle 5 einmal mischen,
  nacheinander ausgeben, bei leerem Beutel neu mischen. Der erste Zug
  eines neuen Beutels ist nie dieselbe Kategorie wie der letzte des alten.
  """

  @categories [
    %{id: "exact_year", label: "Genaues Erscheinungsjahr", color: "#EC4899"},
    %{id: "decade", label: "Jahrzehnt", color: "#8B5CF6"},
    %{id: "year_pm3", label: "Erscheinungsjahr ±3", color: "#3B82F6"},
    %{id: "artist", label: "Interpret", color: "#F59E0B"},
    %{id: "title", label: "Titel", color: "#10B981"}
  ]

  @ids Enum.map(@categories, & &1.id)

  def list, do: @categories

  def ids, do: @ids

  def get(id), do: Enum.find(@categories, &(&1.id == id))

  @doc """
  Zieht die nächste Kategorie aus `remaining` (Liste von Category-IDs).

  `last_id` ist die zuletzt gespielte Kategorie; sie wird nur beim
  Auffüllen eines neuen Beutels berücksichtigt, damit an der Naht
  nicht dieselbe Farbe zweimal hintereinander kommt.

  Gibt `{category, remaining_ids}` zurück.
  """
  def pick_next(remaining, last_id \\ nil) do
    remaining
    |> normalize_bag()
    |> do_pick(valid_id(last_id))
  end

  defp do_pick([], last_id), do: do_pick(new_bag(last_id), last_id)

  defp do_pick([id | rest], last_id) do
    case get(id) do
      nil -> do_pick(rest, last_id)
      category -> {category, rest}
    end
  end

  defp new_bag(last_id) do
    case Enum.shuffle(@ids) do
      [^last_id] ->
        [last_id]

      [^last_id | rest] ->
        i = Enum.random(0..(length(rest) - 1))
        {left, [swap_with | right]} = Enum.split(rest, i)
        [swap_with | left] ++ [last_id | right]

      bag ->
        bag
    end
  end

  defp normalize_bag(remaining) when is_list(remaining) do
    valid = MapSet.new(@ids)

    remaining
    |> Enum.filter(&MapSet.member?(valid, &1))
    |> Enum.uniq()
  end

  defp normalize_bag(_), do: []

  defp valid_id(id) when id in @ids, do: id
  defp valid_id(_), do: nil
end
