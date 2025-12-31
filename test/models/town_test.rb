# frozen_string_literal: true

require "test_helper"

class TownTest < ActiveSupport::TestCase
  test "should require name" do
    town = Town.new
    assert_not town.valid?
    assert_includes town.errors[:name], "can't be blank"
  end

  test "should auto-set normalized_name from name" do
    town = Town.new(name: "Town of Arlington")
    town.valid?
    assert_equal "town of arlington", town.normalized_name
  end

  test "should auto-generate slug from name" do
    town = Town.new(name: "Town of Arlington")
    town.valid?
    assert_equal "town-of-arlington", town.slug
  end

  test "should generate unique slug when duplicate exists" do
    Town.create!(name: "Unique Town", slug: "unique-town")
    # Don't set slug - let it auto-generate and handle conflict
    town = Town.new(name: "Unique Town")
    town.valid?
    # Should get unique-town-1 since unique-town already exists
    assert town.slug.present?
    assert_match(/^unique-town-\d+$/, town.slug)
  end

  test "should validate slug format" do
    town = Town.new(name: "Test", slug: "Invalid Slug!")
    assert_not town.valid?
    assert_includes town.errors[:slug], "only allows lowercase letters, numbers, and hyphens"
  end

  test "should validate slug uniqueness" do
    existing = towns(:arlington)
    town = Town.new(name: "Another Town", slug: existing.slug)
    assert_not town.valid?
    assert_includes town.errors[:slug], "has already been taken"
  end

  test "should validate normalized_name uniqueness" do
    existing = towns(:arlington)
    town = Town.new(name: existing.name)
    assert_not town.valid?
    assert_includes town.errors[:normalized_name], "has already been taken"
  end

  test "to_param returns slug" do
    town = towns(:arlington)
    assert_equal town.slug, town.to_param
  end

  test "alphabetical scope orders by name ascending" do
    towns = Town.alphabetical
    names = towns.map(&:name)
    assert_equal names.sort, names
  end

  test "has many governing_bodies" do
    town = towns(:arlington)
    assert town.governing_bodies.any?
  end

  test "has many people" do
    town = towns(:arlington)
    assert town.people.any?
  end

  test "has many documents through governing_bodies" do
    town = towns(:arlington)
    assert town.respond_to?(:documents)
  end

  test "destroying town destroys associated governing_bodies" do
    town = Town.create!(name: "Temp Town")
    GoverningBody.create!(name: "Temp Board", town: town)

    assert_difference "GoverningBody.count", -1 do
      town.destroy
    end
  end

  test "destroying town destroys associated people" do
    town = Town.create!(name: "Temp Town")
    Person.create!(name: "Temp Person", town: town)

    assert_difference "Person.count", -1 do
      town.destroy
    end
  end
end
