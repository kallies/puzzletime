# ManageModule is a Module that may be mixed into Controllers that want to provide
# management functionality for their represented objects. This includes listing,
# creating, updating and deleting entries. 
# 
# The class of the managed objects is called a Model. Several managed objects can belong to 
# a certain group, e.g., projects belong to one client.
#
# Client controllers must implement modelClass, editFields
# and may implement groupClass, listFields, listActions, formatColumn, initFormData
# 
# Models must extend Manageable and implement self.labels (see Manageable)
module ManageModule

  # Sets up the controller that mixed this Module in.
  def self.included(controller)
    controller.helper :manage  
    controller.helper_method :group, :modelClass, :formatColumn, :listFields, :editFields
   
    # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
    controller.verify :method => :post, :only => [ :create, :update, :delete ],
         :redirect_to => { :action => :list }
         
    controller.hide_action :modelClass, :groupClass, :group, :formatColumn,
                           :editFields, :listFields, :listActions
  end     
  
  # Main Action. Redirects to list.
  def index
    redirectToList
  end
  
  # Action to list all available entries from the database. 
  # The entries are paginated into NO_OF_OVERVIEW_ROWS entries per page.
  def list
    @entry_pages = ActionController::Pagination::Paginator.new(
       self, modelClass.count(:conditions => conditions), NO_OF_OVERVIEW_ROWS, params[:page] )
    @entries = modelClass.list(
                          :conditions => conditions,
                          :limit => @entry_pages.items_per_page,
                          :offset => @entry_pages.current.offset)  
    renderManage :action => 'list'                      
  end
    
  # Action to add a new entry.  
  def add
    @entry = modelClass.new
    initFormData
    renderManage :action => 'add'
  end
  
  # Action to create an added entry in the database.
  def create
    @entry = modelClass.new(params[:entry])
    @entry.send("#{groupClass.to_s.downcase}_id=".to_sym, params[:group_id]) if group?
    if @entry.save
      flash[:notice] = classLabel + ' wurde erfasst'
      redirectToList
    else
      initFormData
      renderManage :action => 'add'
    end
  end
  
  # Action to edit an entry.
  def edit
    setEntryFromId
    initFormData
    renderManage :action => 'edit'
  end
  
  # Action to update an edited entry in the database.
  def update
    setEntryFromId
    if @entry.update_attributes(params[:entry])
      flash[:notice] = classLabel + ' wurde aktualisiert'
      redirectToList
    else      
      flash[:notice] = classLabel + ' konnte nicht aktualisiert werden'
      initFormData
      renderManage :action => 'edit'
    end
  end
  
  # Action to confirm the deletion of an entry.
  def confirmDelete
    setEntryFromId
    renderManage :action => 'confirmDelete' 
  end
  
  # Action to delete an entry from the database.
  def delete
    begin
       modelClass.destroy(params[:id])
       flash[:notice] = classLabel + ' wurde entfernt'
    rescue Exception => err
       flash[:notice] = err.message
    end   
    redirectToList
  end
  
  ####### helper methods, not actions ##########
  
  # The Class of the managed entries. 
  # This method must be overriden by mixin classes.
  def modelClass
    nil
  end
  
  # Links that appear for each entry in the list action.
  # Returns an Array of 3-element Arrays with the following elements:
  # [label, controller, action]
  # Every created link holds the id of the entry as parameter.
  def listActions
    []
  end
  
  # The fields of an entry object that are displayed in the list action.
  # Defaults to all editable fields.
  def listFields
    editFields
  end
  
  # The fields of an entry object that may be edited.
  # Must overwrite in mixin class.
  def editFields
    []
  end
    
  # The group entry for the currently active entry.
  # This object is determined over the parameter group_id.
  def group
    groupClass.find(params[:group_id]) if group?
  end
  
  # Formats the value for the field attribute.
  def formatColumn(attribute, value)    
    case modelClass.columnType(attribute)
      when :date then value.strftime(LONG_DATE_FORMAT) if value
      when :float then "%01.2f" % value if value
      when :integer then value
      when :boolean then value ? 'ja' : 'nein'
      else value.to_s
      end
  end
  
protected
  
  # The group class the represented entry objects belong to.
  # E.g., the group of a Project is a Client. Default is nil.
  def groupClass
    nil
  end
  
  # Initializes the data for editing an entry. 
  # Is currently used to set default values. 
  def initFormData
  
  end  
  
private

  # Sets the instance variable entry from the HTTP parameter.
  def setEntryFromId
    @entry = modelClass.find(params[:id])
  end

  # Redirects a request to the list action.
  def redirectToList
    redirect_to :action => 'list', 
                :page => params[:page], 
                :group_id => params[:group_id],
                :group_page => params[:group_page]
  end
  
  # Custom render method that renders the local template if found,
  # and the general one if none is available.
  def renderManage(options)
    template = options[:action]
    if template && ! template_exists?("#{self.class.controller_path}/#{template}")
      options[:action] = "../manage/#{template}"
    end    
    render options  
  end  
  
  # Label with article of the model class.
  def classLabel
    modelClass.article + ' ' + modelClass.label
  end
    
  # SQL WHERE conditions for the entries displayed in the list action.
  # May return nil.  
  def conditions
    ["#{groupClass.to_s.downcase}_id = ?", params[:group_id]] if group?
  end
  
  # Returns whether a group is defined for the current request.
  def group?
    groupClass && params[:group_id]
  end
  
end