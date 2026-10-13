require "rails_helper"

RSpec.describe "Admin time blocks", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:tomorrow) { Time.find_zone!(business.time_zone).tomorrow }

  def member(role)
    create(:membership, business: business, role: role).user
  end

  def in_business(&block)
    with_business(business, &block)
  end

  def local(date, hour)
    Time.find_zone!(business.time_zone).local(date.year, date.month, date.day, hour)
  end

  def blocks_of(professional)
    in_business { professional.time_blocks.order(:starts_at).to_a }
  end

  let(:sofia) { in_business { create(:professional, name: "Sofía Torres") } }
  let(:pablo) { in_business { create(:professional, name: "Pablo Paz") } }

  describe "as a manager" do
    before { sign_in_as(member(:admin)) }

    it "lists ongoing and upcoming blocks of every professional" do
      in_business do
        create(:time_block, professional: sofia, starts_at: local(tomorrow, 16), ends_at: local(tomorrow, 19), reason: "Trámite")
        create(:time_block, professional: pablo, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        create(:time_block, professional: pablo, starts_at: 3.hours.ago, ends_at: 2.hours.ago, reason: "Pasado")
      end

      get admin_time_blocks_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sofía Torres", "Trámite", "16:00 – 19:00", "Pablo Paz", "En curso", "Nuevo bloqueo")
      expect(response.body).not_to include("Pasado")
    end

    it "filters by professional" do
      in_business do
        create(:time_block, professional: sofia, reason: "De Sofía")
        create(:time_block, professional: pablo, reason: "De Pablo")
      end

      get admin_time_blocks_path(business, professional_id: sofia.id)

      expect(response.body).to include("De Sofía")
      expect(response.body).not_to include("De Pablo")
    end

    it "shows an empty state" do
      get admin_time_blocks_path(business)

      expect(response.body).to include("No hay bloqueos próximos.", new_admin_time_block_path(business))
    end

    it "offers the active professionals" do
      sofia
      in_business { create(:professional, :inactive, name: "Ana Ruiz") }

      get new_admin_time_block_path(business)

      expect(response.body).to include("Sofía Torres", "En hora de Buenos Aires.")
      expect(response.body).not_to include("Ana Ruiz")
    end

    it "creates a block with times, in the business's time zone" do
      post admin_time_blocks_path(business), params: { time_block: {
        professional_id: sofia.id, starts_at: "#{tomorrow}T16:00", ends_at: "#{tomorrow}T19:00", reason: "Trámite"
      } }

      expect(response).to redirect_to(admin_time_blocks_path(business))
      expect(flash[:notice]).to eq("Bloqueamos la agenda de Sofía Torres.")
      expect(blocks_of(sofia).map(&:range)).to eq([ local(tomorrow, 16)...local(tomorrow, 19) ])
    end

    it "creates a whole days block" do
      post admin_time_blocks_path(business), params: { time_block: {
        professional_id: sofia.id, all_day: "1", start_date: tomorrow, end_date: tomorrow + 2
      } }

      expect(blocks_of(sofia).map(&:range)).to eq([ local(tomorrow, 0)...local(tomorrow + 3, 0) ])
    end

    it "shows the errors of an overlapping block" do
      in_business { create(:time_block, professional: sofia, starts_at: local(tomorrow, 16), ends_at: local(tomorrow, 19)) }

      post admin_time_blocks_path(business), params: { time_block: {
        professional_id: sofia.id, all_day: "1", start_date: tomorrow, end_date: tomorrow
      } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Se superpone con otro bloqueo del mismo profesional")
      expect(blocks_of(sofia).size).to eq(1)
    end

    it "requires a professional of the business" do
      other = with_business(create(:business)) { create(:professional) }

      post admin_time_blocks_path(business), params: { time_block: {
        professional_id: other.id, starts_at: "#{tomorrow}T16:00", ends_at: "#{tomorrow}T19:00"
      } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(in_business { TimeBlock.count }).to eq(0)
    end

    it "opens whole days blocks with their days" do
      time_block = in_business { create(:time_block, professional: sofia, starts_at: local(tomorrow, 0), ends_at: local(tomorrow + 2, 0)) }

      get edit_admin_time_block_path(business, time_block)

      expect(response.body).to include('checked="checked"', %(value="#{tomorrow}"), %(value="#{tomorrow + 1}"))
    end

    it "updates and deletes a block" do
      time_block = in_business { create(:time_block, professional: sofia, starts_at: local(tomorrow, 16), ends_at: local(tomorrow, 19)) }

      patch admin_time_block_path(business, time_block), params: { time_block: {
        professional_id: pablo.id, starts_at: "#{tomorrow}T10:00", ends_at: "#{tomorrow}T12:00"
      } }
      expect(response).to redirect_to(admin_time_blocks_path(business))
      expect(blocks_of(pablo).map(&:range)).to eq([ local(tomorrow, 10)...local(tomorrow, 12) ])

      delete admin_time_block_path(business, time_block)
      expect(response).to redirect_to(admin_time_blocks_path(business))
      expect(blocks_of(pablo)).to be_empty
    end

    it "cannot touch blocks of another business" do
      other = create(:business)
      time_block = with_business(other) { create(:time_block) }

      delete admin_time_block_path(business, time_block)

      expect(response).to have_http_status(:not_found)
      expect(with_business(other) { TimeBlock.exists?(time_block.id) }).to be(true)
    end
  end

  describe "as a professional" do
    let(:user) { member(:professional) }

    before { sign_in_as(user) }

    context "with a profile" do
      let!(:own) { in_business { create(:professional, user: user, name: "Martín Gómez") } }

      it "only lists their own blocks" do
        in_business do
          create(:time_block, professional: own, reason: "Mío")
          create(:time_block, professional: sofia, reason: "De Sofía")
        end

        get admin_time_blocks_path(business)

        expect(response.body).to include("Mío", "Períodos en los que no recibís turnos")
        expect(response.body).not_to include("De Sofía", "professional_id")
      end

      it "blocks their own profile, whatever professional is sent" do
        post admin_time_blocks_path(business), params: { time_block: {
          professional_id: sofia.id, starts_at: "#{tomorrow}T16:00", ends_at: "#{tomorrow}T19:00"
        } }

        expect(response).to redirect_to(admin_time_blocks_path(business))
        expect(blocks_of(own).size).to eq(1)
        expect(blocks_of(sofia)).to be_empty
      end

      it "cannot edit or delete other professionals' blocks" do
        time_block = in_business { create(:time_block, professional: sofia) }

        get edit_admin_time_block_path(business, time_block)
        expect(response).to have_http_status(:not_found)

        delete admin_time_block_path(business, time_block)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without a profile" do
      it "explains that a profile is needed" do
        get admin_time_blocks_path(business)

        expect(response.body).to include("No tenés un perfil de profesional.")
        expect(response.body).not_to include(new_admin_time_block_path(business))
      end

      it "cannot create blocks" do
        get new_admin_time_block_path(business)

        expect(response).to redirect_to(admin_time_blocks_path(business))
        expect(flash[:alert]).to eq("Necesitás un perfil de profesional para cargar bloqueos.")
      end
    end
  end
end
