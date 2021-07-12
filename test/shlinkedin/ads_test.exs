defmodule Shlinkedin.AdsTest do
  use Shlinkedin.DataCase
  import Shlinkedin.ProfilesFixtures
  import Shlinkedin.PointsFixtures
  alias Shlinkedin.Ads
  alias Shlinkedin.Ads.Ad
  alias Shlinkedin.Profiles

  describe "ads" do
    @valid_ad %{
      body: "micromisoft",
      company: "facebook",
      product: "computer",
      price: "1",
      gif_url: "test"
    }
    @update_attrs %{
      body: "update body",
      product: "new product",
      gif_url: "test2"
    }
    @invalid_attrs %{body: nil}

    def ad_fixture(profile, attrs \\ %{}) do
      {:ok, ad} = Ads.create_ad(profile, %Ad{}, attrs |> Enum.into(@valid_ad))

      ad
    end

    setup do
      profile = profile_fixture()
      ad = ad_fixture(profile)
      transaction = transaction_fixture()
      %{profile: profile, ad: ad, transaction: transaction}
    end

    test "create_ad creates an ad", %{profile: profile} do
      assert {:ok, %Ad{} = ad} = Ads.create_ad(profile, %Ad{}, @valid_ad)

      assert ad.company == "facebook"
      assert ad.gif_url == "test"
    end

    test "update_ad/2 with valid data updates the endorsement", %{profile: profile} do
      ad = ad_fixture(profile)

      assert {:ok, %Ad{} = ad} = Ads.update_ad(ad, @update_attrs)

      assert ad.body == "update body"
      assert ad.product == "new product"
      assert ad.gif_url == "test2"
    end

    test "update_ad/2 with invalid data fails", %{profile: profile} do
      ad = ad_fixture(profile)

      assert {:error, %Ecto.Changeset{}} = Ads.update_ad(ad, @invalid_attrs)
    end

    test "create_owner adds a new row to the ad owner table", %{profile: profile, ad: ad} do
      transaction = transaction_fixture()
      {:ok, owner} = Ads.create_owner(ad, transaction, profile)
      assert owner.ad_id == ad.id
      assert owner.profile_id == profile.id
      assert owner.transaction_id == transaction.id
    end

    test "get_ad_owner gets latest owner", %{profile: profile, ad: ad, transaction: transaction} do
      # first txn
      {:ok, _owner} = Ads.create_owner(ad, transaction, profile)
      assert Ads.get_ad_owner(ad).id == profile.id
      {:error, _message} = Ads.check_ownership(ad, profile)

      # second txn
      new_profile = profile_fixture()
      {:ok, _owner} = Ads.create_owner(ad, transaction, new_profile)
      assert Ads.get_ad_owner(ad).id == new_profile.id
      {:error, _profile} = Ads.check_ownership(ad, new_profile)
      {:ok, _profile} = Ads.check_ownership(ad, profile)
    end

    test "test enough_points", %{ad: ad, profile: profile} do
      assert Ads.check_money(ad, profile) == {:ok, ad}
      {:ok, new_ad} = Ads.update_ad(ad, %{price: "100"})
      {:error, _message} = Ads.check_money(new_ad, profile)
    end

    test "test buy_ad success", %{profile: buyer} do
      creator = profile_fixture()
      ad = ad_fixture(creator)
      # presets
      assert Shlinkedin.Points.list_transactions(buyer) |> length() == 0
      assert Ads.get_ad_owner(ad).id != buyer.id

      # buy ad
      {:ok, ad} = Ads.buy_ad(ad, buyer)

      # changes
      new_buyer = Profiles.get_profile_by_profile_id(buyer.id)
      assert Shlinkedin.Points.list_transactions(new_buyer) |> length() == 1
      assert Ads.get_ad_owner(ad).id == new_buyer.id
      assert new_buyer.points.amount == buyer.points.amount - ad.price.amount
      [last_notification] = Profiles.list_notifications(creator.id, 1)
      assert last_notification.to_profile_id == creator.id
      assert last_notification.from_profile_id == new_buyer.id

      assert last_notification.action ==
               "#{new_buyer.persona_name} bought your ad for '#{ad.product}' for #{ad.price}"
    end

    test "test buying ad with not enough money", %{ad: ad, profile: profile} do
      {:ok, new_ad} = Ads.update_ad(ad, %{price: "100"})
      {:error, "You are too poor"} = Ads.buy_ad(new_ad, profile)
    end

    test "test buy ad that you already own", %{ad: ad, profile: profile, transaction: transaction} do
      {:ok, _owner} = Ads.create_owner(ad, transaction, profile)

      {:error, "You cannot own more than 1 of an ad, you greedy capitalist!"} =
        Ads.buy_ad(ad, profile)
    end

    test "test buy_ad a second time success", %{profile: profile} do
      random_profile = profile_fixture()
      ad = ad_fixture(random_profile)
      # presets
      assert Shlinkedin.Points.list_transactions(profile) |> length() == 0
      assert Ads.get_ad_owner(ad).id != profile.id

      # buy ad
      {:ok, ad} = Ads.buy_ad(ad, profile)
      random_profile = Shlinkedin.Profiles.get_profile_by_profile_id(random_profile.id)
      assert random_profile.points.amount == 200

      # og profile buys it back
      {:ok, ad} = Ads.buy_ad(ad, random_profile)
      new_random_profile = Shlinkedin.Profiles.get_profile_by_profile_id(random_profile.id)
      assert Shlinkedin.Points.list_transactions(random_profile) |> length() == 2
      assert Ads.get_ad_owner(ad).id == new_random_profile.id
      assert new_random_profile.points.amount == random_profile.points.amount - ad.price.amount

      [last_notification] = Profiles.list_notifications(profile.id, 1)
      assert last_notification.to_profile_id == profile.id
      assert last_notification.from_profile_id == new_random_profile.id

      assert last_notification.action ==
               "#{new_random_profile.persona_name} bought your ad for '#{ad.product}' for #{ad.price}"
    end
  end
end
