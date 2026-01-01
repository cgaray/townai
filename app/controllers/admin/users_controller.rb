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
        # Log admin action
        AuditLogJob.perform_later(
          user: current_user,
          action: "user_create",
          resource_type: "User",
          resource_id: @user.id,
          new_state: { email: @user.email, admin: @user.admin }.to_json,
          ip_address: request.remote_ip
        )

        # Send invitation email with magic link
        begin
          @user.send_magic_link
          redirect_to admin_users_path, notice: "User invited successfully. A login link has been sent to #{@user.email}."
        rescue StandardError => e
          Rails.logger.error("Failed to send magic link to #{@user.email}: #{e.message}")
          redirect_to admin_users_path, notice: "User created successfully.", alert: "Failed to send login link. Please try sending it manually."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user == current_user && params[:user].key?(:admin)
        admin_value = ActiveModel::Type::Boolean.new.cast(params[:user][:admin])
        if admin_value == false
          redirect_to admin_users_path, alert: "You cannot remove your own admin privileges."
          return
        end
      end

      previous_state = { email: @user.email, admin: @user.admin }
      assign_user_attributes(@user)
      if @user.save
        new_state = { email: @user.email, admin: @user.admin }

        # Log admin action
        AuditLogJob.perform_later(
          user: current_user,
          action: "user_update",
          resource_type: "User",
          resource_id: @user.id,
          previous_state: previous_state.to_json,
          new_state: new_state.to_json,
          ip_address: request.remote_ip
        )

        redirect_to admin_users_path, notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
      else
        previous_state = { email: @user.email, admin: @user.admin }

        @user.destroy

        # Log admin action
        AuditLogJob.perform_later(
          user: current_user,
          action: "user_delete",
          resource_type: "User",
          resource_id: @user.id,
          previous_state: previous_state.to_json,
          ip_address: request.remote_ip
        )

        redirect_to admin_users_path, notice: "User deleted successfully."
      end
    end

    def send_magic_link
      @user.send_magic_link

      AuditLogJob.perform_later(
        user: current_user,
        action: "user_magic_link",
        resource_type: "User",
        resource_id: @user.id,
        ip_address: request.remote_ip
      )

      redirect_to admin_users_path, notice: "Login link sent to #{@user.email}."
    rescue StandardError => e
      Rails.logger.error("Failed to send magic link to #{@user.email}: #{e.message}")
      redirect_to admin_users_path, alert: "Failed to send login link. Please try again."
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
