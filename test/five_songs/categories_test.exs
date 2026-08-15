defmodule FiveSongs.CategoriesTest do
  use ExUnit.Case, async: true

  alias FiveSongs.Categories

  @all_ids Categories.ids() |> Enum.sort()

  test "a full bag cycle yields each category exactly once" do
    {picked, remaining} = take(5, [], nil)

    assert remaining == []
    assert picked |> Enum.map(& &1.id) |> Enum.sort() == @all_ids
  end

  test "exhausted bag refills with all five categories again" do
    {_first, empty_bag} = take(5, [], nil)
    {picked, remaining} = take(5, empty_bag, nil)

    assert remaining == []
    assert picked |> Enum.map(& &1.id) |> Enum.sort() == @all_ids
  end

  test "new bag does not start with the previous category" do
    for _ <- 1..80 do
      {picked, bag} = take(5, [], nil)
      last_id = hd(picked).id
      {next, _} = Categories.pick_next(bag, last_id)
      assert next.id != last_id
    end
  end

  test "ignores unknown and duplicate ids in the remaining bag" do
    {category, remaining} = Categories.pick_next(["nope", "artist", "artist", "title"], nil)

    assert category.id == "artist"
    assert remaining == ["title"]
  end

  test "treats a non-list remaining bag as empty" do
    {category, remaining} = Categories.pick_next(nil, nil)

    assert category.id in Categories.ids()
    assert is_list(remaining)
    assert length(remaining) == 4
  end

  defp take(n, bag, last_id) do
    Enum.reduce(1..n, {[], bag, last_id}, fn _, {acc, bag, last_id} ->
      {category, remaining} = Categories.pick_next(bag, last_id)
      {[category | acc], remaining, category.id}
    end)
    |> then(fn {picked, remaining, _} -> {picked, remaining} end)
  end
end
