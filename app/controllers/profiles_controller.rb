class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @profile = current_user.profile
    load_public_profile_data
  end

  def update
    @profile = current_user.profile

    if @profile.update(profile_params)
      redirect_to edit_profile_path, notice: "Profile settings saved."
    else
      load_public_profile_data
      render :edit, status: :unprocessable_content
    end
  end

  def destroy_avatar
    current_user.profile.avatar.purge
    redirect_to edit_profile_path, notice: "Avatar removed."
  end

  private

  def profile_params
    params.expect(profile: [ :first_name, :last_name, :bio, :timezone, :public_enabled, :avatar ])
  end

  def load_public_profile_data
    @profile_link = ProfileLink.new(profile: @profile)
    @social_link = SocialLink.new(profile: @profile)
    @available_links = current_user.account.links.where.not(id: @profile.profile_links.select(:link_id)).order(:name, :id)
  end
end
