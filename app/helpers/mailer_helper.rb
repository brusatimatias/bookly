# Email clients ignore stylesheets, so emails use inline styles.
module MailerHelper
  BRAND_COLOR = "#4f46e5" # brand-600 (indigo)

  def email_button(label, url)
    link_to label, url, style: "display:inline-block;background:#{BRAND_COLOR};color:#ffffff;font-weight:600;" \
      "font-size:14px;text-decoration:none;padding:12px 20px;border-radius:8px;"
  end
end
