class PublicProfilesController < ApplicationController
  def show
    @user = User.includes(profile: [ { profile_links: :link }, :social_links, avatar_attachment: :blob ])
      .find_by!(username: params[:username].to_s.downcase)
    @profile = @user.profile
    raise ActiveRecord::RecordNotFound unless @profile.public_enabled?

    @profile_links = @profile.profile_links
    @social_links = @profile.social_links
  end
end
