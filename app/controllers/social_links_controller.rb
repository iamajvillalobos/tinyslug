class SocialLinksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_profile
  before_action :set_social_link, only: %i[destroy move_up move_down]

  def create
    social_link = SocialLinks::Create.call(profile: @profile, attributes: social_link_params)

    if social_link.persisted?
      redirect_to edit_profile_path(anchor: "social-links"), notice: "Social link added."
    else
      render_profile_errors(social_link)
    end
  end

  def destroy
    OrderedProfileItems.destroy(record: @social_link, profile: @profile)
    redirect_to edit_profile_path(anchor: "social-links"), notice: "Social link removed."
  end

  def move_up
    move(:up)
  end

  def move_down
    move(:down)
  end

  private

  def set_profile
    @profile = current_user.profile
  end

  def set_social_link
    @social_link = @profile.social_links.find(params[:id])
  end

  def social_link_params
    params.expect(social_link: %i[label url])
  end

  def move(direction)
    OrderedProfileItems.move(record: @social_link, profile: @profile, direction:)
    redirect_to edit_profile_path(anchor: "social-links"), notice: "Social links reordered."
  end

  def render_profile_errors(social_link)
    @social_link = social_link
    @profile_link = ProfileLink.new(profile: @profile)
    @available_links = current_user.account.links.where.not(id: @profile.profile_links.select(:link_id)).order(:name, :id)
    flash.now[:alert] = social_link.errors.full_messages.to_sentence
    render "profiles/edit", status: :unprocessable_content
  end
end
