# (c) Puzzle itc, Berne
# Diplomarbeit 2149, Xavier Hayoz

class EvaluatorController < ApplicationController
 
 
  # Checks if employee came from login or from direct url.
  before_filter :authenticate
  before_filter :authorize, :only => [:clients, :employees, :overtime,
                                      :clientProjects, :employeeProjects, :employeeAbsences ]
  before_filter :setPeriod
  
  def index
    overview
  end
  
  def overview
    setEvaluation
    setNavigationLevels
    @notifications = UserNotification.list_during(@period)
    render :action => (params[:evaluation] =~ /^user/ ? 'userOverview' : 'overview' )
  end
  
  def details  
    redirect_to :action => 'absencedetails' if params[:evaluation] == 'absencedetails'
    setEvaluation
    setNavigationLevels
    setEvaluationDetails
    paginateTimes                          
  end
  
  def attendanceDetails
    setEvaluation
    setNavigationLevels
    @evaluation = AttendanceEval.new(params[:category_id] || @user.id)
    setEvaluationDetails
    paginateTimes    
    render :action => 'details' 
  end

  def absencedetails
    session[:evalLevels] = Array.new
    params[:evaluation] = 'absencedetails'
    setEvaluation
    @period ||= Period.comingMonth Date.today, 'Kommender Monat'
    @notifications = UserNotification.list_during(@period)
    paginateTimes
  end
  
  # Shows overtimes of employees
  def overtime
    session[:evalLevels] = Array.new
    @employees = Employee.list
  end
  
  def graph
    redirect_to :controller => 'graph', :action => 'graph'
  end
  
  
  ########################  DETAIL ACTIONS  #########################
  
  def report
    setEvaluation
    setEvaluationDetails
    options = params[:only_billable] ? { :conditions => [ "billable = 't'" ] } : {}
    @times = @evaluation.times(@period, options.dup)
    @times_total_sum = @evaluation.sum_times(@period, nil, options.dup)
    render :layout => false
  end
  
  def exportCSV
    setEvaluation
    setEvaluationDetails
    filename = "puzzletime_" + csvLabel(@evaluation.category) + "-" +
               csvLabel(@evaluation.division) + ".csv"
    setExportHeader(filename)
    send_data(@evaluation.csvString(@period),
              :type => 'text/csv; charset=utf-8; header=present',
              :filename => filename)  
  end
    
  ######################  OVERVIEW ACTIONS  #####################3

  def completeProject
    pm = @user.projectmemberships.find(:first, 
            :conditions => ["project_id = ?", params[:project_id]])
    pm.update_attributes(:last_completed => Date.today)
    flash[:notice] = "Das Datum der kompletten Erfassung aller Zeiten " +
                     "für das Projekt #{pm.project.label_verbose} wurde aktualisiert."
    redirectToOverview
  end
  
  ########################  PERIOD ACTIONS  #########################
  
  def selectPeriod
    @period = Period.new()
  end
  
  def currentPeriod
    session[:period] = nil
    redirectToOverview
  end
  
  def changePeriod
    @period = Period.retrieve(params[:period][:startDate], 
                         params[:period][:endDate],
                         params[:period][:label])  
    raise ArgumentError, "Start Datum nach End Datum" if @period.negative?   
    session[:period] = [@period.startDate.to_s, @period.endDate.to_s,  @period.label]  
    redirectToOverview             
  rescue ArgumentError => ex        # ArgumentError from Period.new or if period.negative?
    flash[:notice] = "Ung&uuml;ltige Zeitspanne: " + ex
    render :action => 'selectPeriod'
    #redirect_to :action => :selectPeriod, 
 #               :evaluation => params[:evaluation],
#                :category_id => params[:category_id]      
  end
  
  
  # Dispatches evaluation names used as actions
  def method_missing(action, *args)
    params[:evaluation] = action.to_s
    overview
  end
  
private  

  def setEvaluation
    params[:evaluation] ||= 'userprojects'
    @evaluation = case params[:evaluation].downcase
        when 'managed' then ManagedProjectsEval.new(@user)
        when 'managedabsences' then ManagedAbsencesEval.new(@user)
        when 'absencedetails' then AbsenceDetailsEval.new
        when 'userprojects' then EmployeeProjectsEval.new(@user.id)
        when 'userabsences' then EmployeeAbsencesEval.new(@user.id)        
        when 'projectemployees' then ProjectEmployeesEval.new(params[:category_id])
        when 'attendance' then AttendanceEval.new(params[:category_id] || @user.id)
        else nil
        end
    if @user.management && @evaluation.nil?
      @evaluation = case params[:evaluation].downcase
        when 'clients' then ClientsEval.new
        when 'employees' then EmployeesEval.new
        when 'clientprojects' then ClientProjectsEval.new(params[:category_id])
        when 'employeeprojects' then EmployeeProjectsEval.new(params[:category_id])  
        when 'absences' then AbsencesEval.new
        when 'employeeabsences' then EmployeeAbsencesEval.new(params[:category_id])      
        else nil
        end  
    end
    if @evaluation.nil?
      @evaluation = EmployeeProjectsEval.new(@user.id)
    end 
  end
  
  def setEvaluationDetails
    @evaluation.set_division_id(params[:division_id])    
    if params[:start_date] != nil
      @period = params[:start_date] == "0" ? nil :
                   Period.retrieve(params[:start_date], params[:end_date])     
    end     
  end
  
  def setNavigationLevels
      # set session evaluation levels
    session[:evalLevels] = Array.new if params[:clear]
    levels = session[:evalLevels]
    current = [params[:evaluation], @evaluation.category_id, @evaluation.title]
    levels.pop while levels.any? { |level| level[0] == current[0] }  
    levels.push current
  end
  
  def paginateTimes
    @time_pages = Paginator.new self, @evaluation.count_times(@period), NO_OF_DETAIL_ROWS, params[:page]
    @times = @evaluation.times(@period, 
                               :limit => @time_pages.items_per_page,
                               :offset => @time_pages.current.offset) 
  end

  def setExportHeader(filename)
    if request.env['HTTP_USER_AGENT'] =~ /msie/i
      headers['Pragma'] = 'public'
      headers['Content-type'] = 'text/plain'
      headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      headers['Expires'] = '0'
    else
      headers['Content-Type'] ||= 'text/csv'
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
    end
  end
  
  def redirectToOverview
    redirect_to :action => params[:evaluation],
                :category_id => params[:category_id]
  end
  
  def csvLabel(item)
    item.nil? || !item.respond_to?(:label) ? '' : 
      item.label.downcase.gsub(/[^0-9a-z]/, "_") 
  end
  
end
