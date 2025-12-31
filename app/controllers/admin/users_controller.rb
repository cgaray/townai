# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy send_magic_link]

    def index
      @users = User.order(created_at: :desc)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new
      assign_user_attributes(@user)

      if @user.save
        # Send invitation email with magic link
        @user.send_magic_link
        redirect_to admin_users_path, notice: "User invited successfully. A login link has been sent to #{@user.email}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user == current_user && params[:user][:admin] == "0"
        redirect_to admin_users_path, alert: "You cannot remove your own admin privileges."
        return
      end

      assign_user_attributes(@user)
      if @user.save
        redirect_to admin_users_path, notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
      else
        @user.destroy
        redirect_to admin_users_path, notice: "User deleted successfully."
      end
    end

    def send_magic_link
      @user.send_magic_link
      redirect_to admin_users_path, notice: "Login link sent to #{@user.email}."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def assign_user_attributes(user)
      user.email = params[:user][:email] if params[:user].key?(:email)
      user.admin = ActiveModel::Type::Boolean.new.cast(params[:user][:admin]) if params[:user].key?(:admin)
    end
  end
end
