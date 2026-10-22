# A business's brand color, as #rrggbb. Buttons put white text on it, so it
# must contrast with white at least as much as WCAG AA asks for normal text.
class BrandColor
  FORMAT = /\A#\h{6}\z/
  MIN_CONTRAST = 4.5
  # Bookly's own (brand-600), for businesses that don't pick one.
  DEFAULT = "#4f46e5"

  attr_reader :hex

  def initialize(hex)
    @hex = hex
  end

  # The WCAG contrast ratio against white, from 1 (white) to 21 (black).
  def contrast_with_white
    1.05 / (luminance + 0.05)
  end

  def readable_with_white_text?
    contrast_with_white >= MIN_CONTRAST
  end

  private
    # WCAG relative luminance: each sRGB channel linearized, then weighted.
    def luminance
      red, green, blue = hex.delete_prefix("#").scan(/\h{2}/).map do |channel|
        value = channel.hex / 255.0
        value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end
end
