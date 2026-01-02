# frozen_string_literal: true

class User < ApplicationRecord
  # Passwordless authentication via magic links
  # Only enabling modules we need to minimize attack surface:
  # - magic_link_authenticatable: Core magic link functionality
  # - rememberable: Session persistence
  # - timeoutable: Auto-logout after inactivity
  # - validatable: Email format validation
  devise :magic_link_authenticatable, :rememberable, :timeoutable, :validatable

  # Override Devise's password requirement since we use magic links
  def password_required?
    false
  end

  # Override Devise's email_required? for validatable module
  def email_required?
    true
  end

  def admin?
    admin
  end

  # Send Devise emails asynchronously via Active Job
  # This avoids blocking the request thread during SMTP handshake
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
