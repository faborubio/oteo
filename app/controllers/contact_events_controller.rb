class ContactEventsController < ApplicationController
  def create
    @business = Business.find(params[:business_id])
    @contact_event = @business.contact_events.new(contact_event_params)

    if @contact_event.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @business, notice: "Registrado." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_content }
        format.html { redirect_to @business, alert: "No se pudo registrar el evento." }
      end
    end
  end

  private

  def contact_event_params
    params.require(:contact_event).permit(:event_type, :product, :body)
  end
end
