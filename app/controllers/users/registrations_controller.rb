module Users
  class RegistrationsController < Devise::RegistrationsController
    def destroy
      self.resource = current_user
      resource.account.destroy!
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      set_flash_message! :notice, :destroyed
      redirect_to after_sign_out_path_for(resource_name), status: :see_other
    end
  end
end
