class ProfileLinksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_profile
  before_action :set_profile_link, only: %i[destroy move_up move_down]

  def create
    link = current_user.account.links.find(params.expect(:link_id))
    profile_link = ProfileLinks::Create.call(profile: @profile, link:)

    if profile_link.persisted?
      redirect_to edit_profile_path(anchor: "public-profile-links"), notice: "Link added to your public profile."
    else
      render_profile_errors(profile_link)
    end
  end

  def destroy
    OrderedProfileItems.destroy(record: @profile_link, profile: @profile)
    redirect_to edit_profile_path(anchor: "public-profile-links"), notice: "Link removed from your public profile."
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

  def set_profile_link
    @profile_link = @profile.profile_links.find(params[:id])
  end

  def move(direction)
    OrderedProfileItems.move(record: @profile_link, profile: @profile, direction:)
    redirect_to edit_profile_path(anchor: "public-profile-links"), notice: "Public links reordered."
  end

  def render_profile_errors(profile_link)
    @profile_link = profile_link
    @social_link = SocialLink.new(profile: @profile)
    @available_links = current_user.account.links.where.not(id: @profile.profile_links.select(:link_id)).order(:name, :id)
    flash.now[:alert] = profile_link.errors.full_messages.to_sentence
    render "profiles/edit", status: :unprocessable_content
  end
end
