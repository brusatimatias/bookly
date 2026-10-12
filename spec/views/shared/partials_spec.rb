require "rails_helper"

RSpec.describe "shared partials", type: :view do
  describe "form_errors" do
    it "lists the errors of the record" do
      record = Invitation.new
      record.errors.add(:email, :blank)
      record.errors.add(:role, :inclusion)

      render "shared/form_errors", record: record

      expect(rendered).to include("Hay 2 errores para corregir:", "Email no puede estar en blanco")
    end

    it "renders nothing without errors" do
      render "shared/form_errors", record: Invitation.new

      expect(rendered.strip).to be_empty
    end
  end

  describe "page_header" do
    it "renders the title, subtitle and actions" do
      render "shared/page_header", title: "Equipo", subtitle: "Miembros del negocio" do
        "<a href='/new'>Invitar</a>".html_safe
      end

      expect(rendered).to include("<h1", "Equipo", "Miembros del negocio", "Invitar")
    end

    it "works with only a title" do
      render "shared/page_header", title: "Equipo"

      expect(rendered).to include("Equipo")
    end
  end

  describe "empty_state" do
    it "renders the title, message and action" do
      render "shared/empty_state", icon: "users", title: "Sin invitaciones", message: "Invitá a tu equipo." do
        "<a href='/new'>Invitar</a>".html_safe
      end

      expect(rendered).to include("Sin invitaciones", "Invitá a tu equipo.", "Invitar")
    end
  end

  describe "flash" do
    it "renders alerts and notices with their roles" do
      flash[:alert] = "No tenés permiso."
      flash[:notice] = "Invitación enviada."

      render "shared/flash"

      expect(rendered).to include('role="alert"', "No tenés permiso.", 'role="status"', "Invitación enviada.")
    end
  end
end
