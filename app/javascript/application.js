// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

// Rich text is text only: no file uploads in the editor.
document.addEventListener("trix-file-accept", (event) => event.preventDefault())
