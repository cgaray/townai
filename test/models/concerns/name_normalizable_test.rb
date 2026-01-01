# frozen_string_literal: true

require "test_helper"

class NameNormalizableTest < ActiveSupport::TestCase
  # Create a test model to test the concern
  class TestModel
    include ActiveModel::Model
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include NameNormalizable

    attr_accessor :name, :normalized_name

    def name_changed?
      @name_changed ||= false
    end

    def self.strip_titles_on_normalize?
      true
    end
  end

  test "normalize_name with strip_titles true removes titles" do
    assert_equal "john smith", TestModel.normalize_name("Dr. John Smith Jr.", strip_titles: true)
    assert_equal "jane doe", TestModel.normalize_name("Mrs. Jane Doe III", strip_titles: true)
    assert_equal "bob wilson", TestModel.normalize_name("Mr. Bob Wilson", strip_titles: true)
    assert_equal "mary johnson", TestModel.normalize_name("Ms. Mary Johnson Sr.", strip_titles: true)
  end

  test "normalize_name with strip_titles false preserves titles" do
    assert_equal "dr. john smith jr.", TestModel.normalize_name("Dr. John Smith Jr.", strip_titles: false)
    assert_equal "mrs. jane doe iii", TestModel.normalize_name("Mrs. Jane Doe III", strip_titles: false)
  end

  test "normalize_name removes hyphens" do
    assert_equal "mary jane smith", TestModel.normalize_name("Mary-Jane Smith", strip_titles: true)
    assert_equal "jean pierre", TestModel.normalize_name("Jean-Pierre", strip_titles: true)
  end

  test "normalize_name removes non-alpha characters except spaces" do
    assert_equal "john smith", TestModel.normalize_name("John (Smith)", strip_titles: true)
    assert_equal "janedoe", TestModel.normalize_name("Jane_Doe!", strip_titles: true)
    assert_equal "bobwilson", TestModel.normalize_name("Bob@Wilson#123", strip_titles: true)
  end

  test "normalize_name handles extra whitespace" do
    assert_equal "john smith", TestModel.normalize_name("  John   Smith  ", strip_titles: true)
    assert_equal "jane doe", TestModel.normalize_name("\tJane\nDoe\r", strip_titles: true)
  end

  test "normalize_name handles edge cases" do
    assert_equal "", TestModel.normalize_name(nil, strip_titles: true)
    assert_equal "", TestModel.normalize_name("", strip_titles: true)
    assert_equal "", TestModel.normalize_name("   ", strip_titles: true)
  end

  test "normalize_name is case insensitive" do
    assert_equal "john smith", TestModel.normalize_name("JOHN SMITH", strip_titles: true)
    assert_equal "john smith", TestModel.normalize_name("john smith", strip_titles: true)
    assert_equal "john smith", TestModel.normalize_name("JoHn SmItH", strip_titles: true)
  end

  test "normalize_name handles complex title combinations" do
    assert_equal "john smith", TestModel.normalize_name("Dr. John Smith Jr. III", strip_titles: true)
    assert_equal "jane doe", TestModel.normalize_name("Mrs. Dr. Jane Doe Sr.", strip_titles: true)
  end

  test "set_normalized_name is called before validation when name is present" do
    model = TestModel.new
    model.name = "John Smith"
    model.instance_variable_set(:@name_changed, true)

    model.valid?

    assert_equal "john smith", model.normalized_name
  end

  test "set_normalized_name is not called when name is blank" do
    model = TestModel.new
    model.name = ""

    model.valid?

    assert_nil model.normalized_name
  end

  test "strip_titles_on_normalize? returns false by default" do
    # Test directly on models that use the concern (Person, Attendee, GoverningBody)
    # GoverningBody doesn't strip titles
    assert_equal false, GoverningBody.strip_titles_on_normalize?
  end

  test "normalize_name uses strip_titles_on_normalize? when not explicitly provided" do
    # GoverningBody doesn't strip titles by default
    result = GoverningBody.normalize_name("Dr. John Smith")
    assert_equal "dr. john smith", result
  end

  test "models can override strip_titles_on_normalize?" do
    # Person strips titles
    assert_equal true, Person.strip_titles_on_normalize?
    result = Person.normalize_name("Dr. John Smith")
    assert_equal "john smith", result

    # Attendee also strips titles
    assert_equal true, Attendee.strip_titles_on_normalize?
    result = Attendee.normalize_name("Dr. John Smith")
    assert_equal "john smith", result
  end
end
