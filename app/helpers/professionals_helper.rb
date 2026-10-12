module ProfessionalsHelper
  # Photo of the professional, or their initials when there is none. Images are
  # shown as uploaded (no variants yet) and cropped with CSS.
  def professional_avatar(professional, size: "size-10")
    if professional.photo.attached? && professional.photo.blob.persisted?
      image_tag rails_blob_path(professional.photo, only_path: true), alt: professional.name,
        class: "#{size} shrink-0 rounded-full object-cover ring-1 ring-gray-900/5"
    else
      tag.span initials(professional.name), class: "#{size} inline-flex shrink-0 items-center justify-center rounded-full bg-brand-100 text-sm font-semibold text-brand-700"
    end
  end
end
