# (c) Puzzle itc, Berne
# Diplomarbeit 2149, Xavier Hayoz

class WorktimeController < ApplicationController
 
  include ApplicationHelper
  
  # Checks if employee came from login or from direct url.
  before_filter :authenticate

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :deleteTime, :createTime, :updateTime, :updateProject ],
         :redirect_to => { :action => :listTime }
         
  FINISH = 'Abschliessen'       
   
  def index
    listTime
  end 
   
  #List the time.
  def listTime
    eval = 'userProjects'
    if @worktime != nil && @worktime.absence? 
      @user.absences(true)      #true forces reload
      eval = 'userAbsences'
    end  
    redirect_to :controller => 'evaluator', :action => eval
  end
  
  # Shows the addAbsence page.
  def addAbsence
    createDefaultWorktime
    @accounts = Absence.list
    render :action => 'addTime'
  end
  
  # Shows the addTime page.
  def addTime
    createDefaultWorktime   
    if params.has_key? :absence_id
      @worktime.absence_id = params[:absence_id] 
    else
      @worktime.project_id = params[:project_id] || DEFAULT_PROJECT_ID
    end  
    setWorktimeAccounts
  end  
      
  # Stores the new time the data on DB.
  def createTime
    @worktime = Worktime.new
    @worktime.employee = @user    
    setWorktimeParams
    if @worktime.save      
      flash[:notice] = 'Die Arbeitszeit wurde erfasst'
      if params[:commit] != FINISH        
        @worktime = @worktime.template
        setWorktimeAccounts
        render :action => 'addTime'
      else
        listDetailTime  
      end
    else
      setWorktimeAccounts
      render :action => 'addTime'
    end  
  end  
  
  # Shows the edit page for the selected time.
  def editTime    
    @worktime = Worktime.find(params[:id])   
    setWorktimeAccounts
  end
  
    
  # Update the selected worktime on DB.
  def updateTime       
    @worktime = Worktime.find(params[:worktime_id])
    if @worktime.employee != @user
      createWorktimeEdit 
      return
    end  
    setWorktimeParams
    if @worktime.save
      flash[:notice] = 'Die Arbeitszeit wurde aktualisiert'
      listDetailTime
    else
      setWorktimeAccounts
      render :action => 'editTime'
    end  
  end
  
  def createWorktimeEdit
    @edit = session[:edit]
    if @edit.nil?
      @worktime = Worktime.find(params[:worktime_id])
      @edit = WorktimeEdit.new(@worktime.clone)
    else  
      @worktime = @edit.worktimeTemplate
    end    
    setWorktimeParams
    done = false
    if @worktime.valid?
      if @edit.addWorktime(@worktime)
        if @edit.incomplete?
          session[:edit] = @edit
          @worktime = @edit.worktimeTemplate
        else
          @edit.save
          session[:edit] = nil
          done = true
          flash[:notice] = 'Die Arbeitszeit wurde angepasst'
          redirect_to evaluation_detail_params.merge!({
                        :controller => 'evaluator',
                        :action => 'details' }) 
        end
      end  
    end
    if ! done
      @accounts = @worktime.employee.projects 
      render :action => 'worktimeEdit'
    end     
  end
 

  # Show the change project page.
  def changeProject
    @worktime = Worktime.find(params[:worktime_id])
    #@projects = @user.management? ? Project.list : @user.managed_projects 
    @projects = @worktime.employee.projects   
  end
  
  def updateProject
    @worktime = Worktime.find(params[:worktime_id])
    if @worktime.update_attributes(params[:worktime])
      flash[:notice] = 'Das Projekt wurde angepasst'
      redirect_to evaluation_detail_params.merge!({
                        :controller => 'evaluator',
                        :action => 'details' }) 
    else
      render :action => 'changeProject'
    end
  end
  
  def confirmDeleteTime
    @worktime = Worktime.find(params[:id])
  end
  
  def deleteTime
    worktime = Worktime.find(params[:id])
    worktime.destroy if worktime.employee == @user
    redirect_to evaluation_detail_params.merge!({
                  :controller => 'evaluator', 
                  :action => 'details'})
  end
  
  def addMultiAbsence
    @accounts = Absence.list
    @multiabsence = MultiAbsence.new
  end
    
  def createMultiAbsence
    @multiabsence = MultiAbsence.new
    @multiabsence.employee = @user    
    @multiabsence.attributes = params[:multiabsence]
    if @multiabsence.valid?
      count = @multiabsence.save      
      flash[:notice] = "#{count} Absenzen wurden erfasst"
      @worktime = @multiabsence.worktime
      session[:period] = @multiabsence.period if session[:period].nil?
      listDetailTime  
    else
      @accounts = Absence.list
      render :action => 'addMultiAbsence'
    end  
  end
  
protected

  #List the time.
  def listDetailTime
    eval = 'userProjects'
    @worktime ||= Worktime.new
    if @worktime.absence? 
      @user.absences(true)      #true forces reload
      eval = 'userAbsences'
    end  
    periodParam = {}
    if session[:period].nil? || 
        ! session[:period].include?(@worktime.work_date)
      period = Period.weekFor(@worktime.work_date)
      periodParam = {:start_date => period.startDate, :end_date => period.endDate}
    end
    redirect_to periodParam.merge!({
                :controller => 'evaluator', 
                :action => 'details', 
                :evaluation => eval, 
                :category_id => @user.id })
  end

  def createDefaultWorktime
    @worktime = Worktime.new
    @worktime.from_start_time = Time.now.change(:hour => 8)
    @worktime.report_type = Worktime::TYPE_HOURS_DAY
    period = session[:period]
    @worktime.work_date = (period != nil && period.length == 1) ?
       period.startDate : Date.today
  end
  
  def setWorktimeAccounts
    @accounts = @worktime.absence? ? Absence.list : @user.projects 
  end
  
  def setWorktimeParams
    begin
      @worktime.attributes = params[:worktime]
    # Catch the exception from AR::Base
    rescue ActiveRecord::MultiparameterAssignmentErrors => ex
      # Iterarate over the exceptions and remove the invalid field components from the input
      ex.errors.each { |err| params[:worktime].delete_if { |key, value| key =~ /^#{err.attribute}/ } }
      # Recreate the Model with the bad input fields removed
      @worktime.attributes = params[:worktime]
      # remove manually as @worktime already had a valid work_date, we want an error to be thrown
      @worktime.work_date = nil     
    end
  end

end
