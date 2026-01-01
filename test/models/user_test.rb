require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "password is not required for magic link authentication" do
    user = User.new(email: "test@example.com")
    assert_not user.password_required?
  end

  test "email is required" do
    user = User.new(email: "test@example.com")
    assert user.email_required?
  end

  test "admin? returns true when admin is true" do
    user = users(:admin)
    assert user.admin?
  end

  test "admin? returns false when admin is false" do
    user = users(:user)
    assert_not user.admin?
  end

  test "email must be unique" do
    existing_user = users(:admin)
    user = User.new(email: existing_user.email)
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "email must be valid format" do
    user = User.new(email: "invalid-email")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "email cannot be blank" do
    user = User.new(email: "")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "valid user can be created without password" do
    user = User.new(email: "newuser@example.com")
    assert user.valid?
  end

  test "admin defaults to false" do
    user = User.new(email: "newuser@example.com")
    assert_not user.admin?
  end
end
