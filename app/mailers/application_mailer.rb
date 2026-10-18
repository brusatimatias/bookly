class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name(Rails.configuration.x.mail_from, "Bookly") }
  layout "mailer"
  helper MailerHelper
end
