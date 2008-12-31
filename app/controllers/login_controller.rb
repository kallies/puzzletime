# (c) Puzzle itc, Berne
# Diplomarbeit 2149, Xavier Hayoz


class LoginController < ApplicationController

  # Checks if employee came from login or from direct url
  before_filter :authenticate, :except => :login
  verify :method => :post, :only => [ :logout ], 
         :redirect_to => { :controller => 'projecttime', :action => 'list' }
  
  def index
    redirect_to :action => "login"
  end
 
  # Login procedure for user
  def login
    if request.get?      
      session[:user_id] = nil
    else 
      puts blackout_hash(params, 'pwd').inspect
      logged_in = Employee.login(params[:employee][:shortname], params[:employee][:pwd])
      if logged_in
        reset_session
        session[:user_id] = logged_in.id
        redirect_to :controller => 'projecttime', :action => 'list'
      else
        flash[:notice] = "Ung&uuml;ltige Benutzerdaten"
      end
    end
  end
  
  #Logout procedure for user    
  def logout
    reset_session
    flash[:notice] = "Sie wurden ausgeloggt"
    redirect_to :action => "login"
  end

end
