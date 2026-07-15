class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @profile = current_user.profile
  end

  def update
    @profile = current_user.profile

    if @profile.update(profile_params)
      redirect_to edit_profile_path, notice: "Profile settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.expect(profile: [ :first_name, :last_name, :timezone ])
  end
end
