defmodule NeXbox.Scraper do
  @xbox_newegg_seller_list "https://www.newegg.com/p/pl?d=xbox+series+x&N=8000"
  @item_type %{:xsx => ~r/Xbox Series X/i, :xss => ~r/Xbox Series S/i}
  @item_excluded %{
    :no_stock => ~r/OUT OF Stock/i,
    promo: ~r/This item can only be purchased with a combo/i
  }

  alias NeXbox.Item

  # TODO
  # Detectar cuando hay una o mas paginas y extraer items de esas paginas
  # En teoria deberia poder ser llamando nuevament la secuencia de metodos
  # aca usados.
  def run do
    request_and_parse()
    |> get_item_cell()
    |> get_available_items()
    |> exclude_promo()
    |> format()
  end

  defp request_and_parse do
    {:ok, %Finch.Response{body: body}} =
      Finch.build(:get, @xbox_newegg_seller_list)
      |> Finch.request(MyFinch)

    {:ok, document} = Floki.parse_document(body)
    document
  end

  defp get_item_cell(document) do
    Floki.find(document, ".item-cell")
  end

  defp get_available_items(document) do
    [available, _unavailable] =
      Enum.filter(document, &filter_requested_item(&1, @item_type[:xss]))
      |> Enum.chunk_by(&available_unavailable(&1))

    available
  end

  defp exclude_promo(document) do
    [_excluded, clean] = Enum.chunk_by(document, &promo_excluder/1)
    clean
  end

  defp filter_requested_item(item, type) do
    Floki.find(item, ".item-info a.item-title")
    |> Floki.text()
    |> String.match?(type)
  end

  defp available_unavailable(item) do
    Floki.find(item, ".item-info .item-promo")
    |> Floki.text()
    |> String.match?(@item_excluded[:no_stock])
  end

  defp promo_excluder(item) do
    Floki.find(item, ".item-info .item-promo")
    |> Floki.text()
    |> String.match?(@item_excluded[:promo])
  end

  defp format(document) do
    Enum.map(document, &item_to_struct/1)
  end

  defp item_to_struct(item) do
    %Item{name: title_scraper(item) , link: link_scraper(item), price: price_scraper(item)}
  end

  defp title_scraper(item) do
    item
    |> Floki.find(".item-info a")
    |> Floki.text()
  end

  defp link_scraper(item) do
    [link] = item
    |> Floki.find(".item-info a.item-title")
    |> Floki.attribute("href")
    link
  end

  defp price_scraper(item) do
    item
    |> Floki.find(".item-action ul.price li.price-current")
    |> Floki.text()
    |> String.split(~r"[^\d]", trim: true)
    |> Enum.join(".")
    |> String.to_float()
  end
end
