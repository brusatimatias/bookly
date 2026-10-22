# Email clients ignore stylesheets, so emails use inline styles. Emails to a
# business's customers wear its brand (the mailer sets @branded_business);
# the rest, Bookly's.
module MailerHelper
  BRAND_COLOR = BrandColor::DEFAULT

  def email_brand_color
    @branded_business&.brand_color || BRAND_COLOR
  end

  def email_button(label, url)
    link_to label, url, style: "display:inline-block;background:#{email_brand_color};color:#ffffff;font-weight:600;" \
      "font-size:14px;text-decoration:none;padding:12px 20px;border-radius:8px;"
  end
end
