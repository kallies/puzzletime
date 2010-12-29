class Planning < ActiveRecord::Base

  validates_presence_of :employee_id, :project_id, :start_week
  
  belongs_to :project
  belongs_to :employee
  
  def start_week_date
    Week::from_integer(start_week).to_date if valid_week?(start_week)
  end

  def end_week_date
      Week::from_integer(end_week).to_date if !end_week.nil? && valid_week?(end_week)
  end
  
  def repeat_type_no?
    end_week == start_week
  end
  
  def repeat_type_until?
    end_week.present? && end_week > start_week
  end
  
  def repeat_type_forever?
    end_week.nil?  
  end
  
  def planned_during?(period)
    if repeat_type_forever?
      return period.endDate >= start_week_date
    end
    !((period.startDate < start_week_date && period.endDate < start_week_date) || (period.startDate > end_week_date && period.endDate > end_week_date))
  end

  def validate
    errors.add(:start_week, "Von Format ist ung&uuml;ltig") if !valid_week?(start_week)
    errors.add(:end_week, "Bis Format ist ung&uuml;ltig") if end_week && !valid_week?(end_week)
    errors.add(:end_week, "Bis Datum ist ung&uuml;ltig") if end_week && (end_week < start_week)
    
    halfday_selected = (monday_am || monday_pm || tuesday_am || tuesday_pm || wednesday_am || wednesday_pm || thursday_am || thursday_pm || friday_am || friday_pm)

    if !is_abstract && !halfday_selected
      errors.add(:start_date, "Mindestens ein halber Tag muss selektiert werden")
    end
    
    if (is_abstract && abstract_amount>0 && halfday_selected)
      errors.add(:start_date, "Abstrakte Planungen entweder mit der Selektion von Halbtagen oder durch Auswählen des Umfangs (Dropdown-Box) spezifizieren (nicht beides).")
    end
    
    if (abstract_amount==0 && !halfday_selected)
      errors.add(:start_date, "Entweder Halbtag selektieren oder Umfang auswählen (Dropdown-Box).")
    end
    
    existing_plannings = Planning.find(:all, :conditions => ['project_id = ? and employee_id = ? and is_abstract=false', project_id, employee_id]) #todo: limit search result by date
    existing_plannings_abstr = Planning.find(:all, :conditions => ['project_id = ? and employee_id = ? and is_abstract=true', project_id, employee_id]) #todo: limit search result by date
    
    if self.is_abstract==false
      existing_plannings.each do |planning|
        if overlaps?(planning)
          errors.add(:start_date, "Dieses Projekt ist in diesem Zeitraum bereits geplant")
          break
        end
      end
    end
    
    if self.is_abstract
      existing_plannings_abstr.each do |planning|
        if overlaps?(planning)
          errors.add(:start_date, "Dieses Projekt ist in diesem Zeitraum bereits abstrakt geplant")
          break
        end
      end
    else
      
    end
  end
  
  def monday
    monday_am && monday_pm
  end
  
  def tuesday
    tuesday_am && tuesday_pm
  end
  
  def wednesday
    wednesday_am && wednesday_pm
  end

  def thursday
    thursday_am && thursday_pm
  end
  
  def friday
    friday_am && friday_pm
  end
  
  def percent
    result = 0
    result += 10 if monday_am
    result += 10 if monday_pm
    result += 10 if tuesday_am
    result += 10 if tuesday_pm
    result += 10 if wednesday_am
    result += 10 if wednesday_pm
    result += 10 if thursday_am
    result += 10 if thursday_pm
    result += 10 if friday_am
    result += 10 if friday_pm
    result += abstract_amount
    result
  end

private
  def overlaps?(other_planning)
    return false if other_planning == self
    return true if self.repeat_type_forever? && other_planning.repeat_type_forever?
    
    # sort plannings so that p1 starts before or in same week as p2
    p1_end_week = (self.start_week <= other_planning.start_week) ? self.end_week : other_planning.end_week
    p2_start_week = (self.start_week <= other_planning.start_week) ? other_planning.start_week : self.start_week
    
    # set end_week to a very late date
    p1_end_week ||= 999950
    
    return p1_end_week >= p2_start_week
    
  end
  
  def valid_week?(week)
    Week::valid?(week)
  end
end