# Fat Free CRM
# Copyright (C) 2008-2010 by Michael Dvorkin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------

ContactsController.class_eval do

  # PUT /contacts/1/merge/2                                                AJAX
  #----------------------------------------------------------------------------
  def merge
    # Find which fields we want to ignore from the duplicate contact.
    ignored_merge_fields = params[:ignore].select{|k,v| v == "yes" }.map{|a| a[0] }

    @contact = Contact.my(@current_user).find(params[:id])
    @master_contact = Contact.my(@current_user).find(params[:master_id])

    unless @contact.merge_with(@master_contact, ignored_merge_fields)
      @contact.errors.add_to_base(t('merge_error'))
    end
    respond_to do |format|
      format.js
    end

    rescue ActiveRecord::RecordNotFound
      respond_to_not_found(:js, :xml)
  end


  # GET /contacts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  def edit
    @contact  = Contact.my(@current_user).find(params[:id])

    # 'master_contact' lookup for a merge request.
    @master_contact = Contact.my(@current_user).find(params[:merge_into]) if params[:merge_into]

    @users    = User.except(@current_user).all
    @account  = @contact.account || Account.new(:user => @current_user)
    @accounts = Account.my(@current_user).all(:order => "name")
    if params[:previous] =~ /(\d+)\z/
      @previous = Contact.my(@current_user).find($1)
    end

  rescue ActiveRecord::RecordNotFound
    @previous ||= $1.to_i
    respond_to_not_found(:js) unless @contact
  end


  # GET /contacts/1
  # GET /contacts/1.xml                                                    HTML
  #----------------------------------------------------------------------------
  def show
    @contact = Contact.my(@current_user).find(contact_alias_or_default(params[:id]))
    @stage = Setting.unroll(:opportunity_stage)
    @comment = Comment.new

    @timeline = Timeline.find(@contact)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @contact }
    end

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:html, :xml)
  end

  # PUT /contacts/1
  # PUT /contacts/1.xml                                                    AJAX
  #----------------------------------------------------------------------------
  def update
    @contact = Contact.my(@current_user).find(contact_alias_or_default(params[:id]))

    respond_to do |format|
      if @contact.update_with_account_and_permissions(params)
        format.js
        format.xml  { head :ok }
      else
        @users = User.except(@current_user).all
        @accounts = Account.my(@current_user).all(:order => "name")
        if @contact.account
          @account = Account.find(@contact.account.id)
        else
          @account = Account.new(:user => @current_user)
        end
        format.js
        format.xml  { render :xml => @contact.errors, :status => :unprocessable_entity }
      end
    end

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:js, :xml)
  end

  private

  # Looks up the ContactAlias table to see if the requested id
  # matches a previously merged contact.
  # Returns the new id if it does,
  def contact_alias_or_default(contact_id)
    if contact_alias = ContactAlias.find_by_destroyed_contact_id(contact_id)
      contact_alias.contact_id
    else
      contact_id
    end
  end

end

