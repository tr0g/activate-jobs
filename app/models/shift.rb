class Shift < ActiveRecord::Base

  delegate :loc_group, :to => 'location'
  belongs_to :calendar
  belongs_to :repeating_event
  belongs_to :department
  belongs_to :user
  belongs_to :location
  has_one :report, :dependent => :destroy
  has_many :sub_requests, :dependent => :destroy
  before_update :disassociate_from_repeating_event

  validates_presence_of :user
  validates_presence_of :location
  validates_presence_of :start
  validate :is_within_calendar
  before_save :set_active

#TODO: remove all to_sql calls except where needed for booleans
  named_scope :active, lambda {{:conditions => {:active => true}}}
  named_scope :for_user, lambda {|usr| { :conditions => {:user_id => usr.id }}}
  named_scope :on_day, lambda {|day| { :conditions => ["#{:start.to_sql_column} >= #{day.beginning_of_day.utc.to_sql} and #{:start.to_sql_column} < #{day.end_of_day.utc.to_sql}"]}}
  named_scope :on_days, lambda {|start_day, end_day| { :conditions => ["#{:start.to_sql_column} >= #{start_day.beginning_of_day.utc.to_sql} and #{:start.to_sql_column} < #{end_day.end_of_day.utc.to_sql}"]}}
  named_scope :between, lambda {|start, stop| { :conditions => ["#{:start.to_sql_column} >= #{start.utc.to_sql} and #{:start.to_sql_column} < #{stop.utc.to_sql}"]}}
  named_scope :overlaps, lambda {|start, stop| { :conditions => ["#{:end.to_sql_column} > #{start.utc.to_sql} and #{:start.to_sql_column} < #{stop.utc.to_sql}"]}}
  named_scope :in_location, lambda {|loc| {:conditions => {:location_id => loc.id}}}
  named_scope :in_locations, lambda {|loc_array| {:conditions => { :location_id => loc_array }}}
  named_scope :in_calendars, lambda {|calendar_array| {:conditions => { :calendar_id => calendar_array }}}
  named_scope :scheduled, lambda {{ :conditions => {:scheduled => true}}}
  named_scope :super_search, lambda {|start,stop, incr,locs| {:conditions => ["((#{:start.to_sql_column} >= #{start.utc.to_sql} and #{:start.to_sql_column} < #{(stop.utc - incr).to_sql}) or (#{:end.to_sql_column} > #{(start.utc + incr).to_sql} and #{:end.to_sql_column} <= #{(stop.utc).to_sql})) and #{:scheduled.to_sql_column} = #{true.to_sql} and #{:location_id.to_sql_column} IN (#{true.to_sql})"], :order => "#{:location_id.to_sql_column}, #{:start.to_sql}" }}
  named_scope :hidden_search, lambda {|start,stop,day_start,day_end,locs| {:conditions => ["((#{:start.to_sql_column} >= #{day_start.utc.to_sql} and #{:end.to_sql_column} < #{start.utc.to_sql}) or (#{:start.to_sql_column} >= #{stop.utc.to_sql} and #{:start.to_sql_column} < #{day_end.utc.to_sql})) and #{:scheduled.to_sql_column} = #{true.to_sql} and #{:location_id.to_sql_column} IN (#{locs.to_sql})"], :order => "#{:location_id.to_sql}, #{:start.to_sql}" }}

  #TODO: clean this code up -- maybe just one call to shift.scheduled?
  validates_presence_of :end, :if => Proc.new{|shift| shift.scheduled?}
  validates_presence_of :user
  
  before_validation :adjust_end_time_if_in_early_morning, :if => Proc.new{|shift| shift.scheduled?}
  validate :start_less_than_end, :if => Proc.new{|shift| shift.scheduled?}
  validate :shift_is_within_time_slot, :if => Proc.new{|shift| shift.scheduled?}
  validate :user_does_not_have_concurrent_shift, :if => Proc.new{|shift| shift.scheduled?}
  validate_on_create :not_in_the_past, :if => Proc.new{|shift| shift.scheduled?}
  validate :restrictions
  validate :does_not_exceed_max_concurrent_shifts_in_location, :if => Proc.new{|shift| !shift.power_signed_up?}
#  validate :adjust_sub_requests # TODO: can be deleted after bugfix#171 is accepted -ben
  before_save :adjust_sub_requests
  after_save :combine_with_surrounding_shifts #must be after, or reports can be lost

  #
  # Class methods
  #

  def self.delete_part_of_shift(shift, start_of_delete, end_of_delete)
    #Used for taking sub requests
    if !(start_of_delete.between?(shift.start, shift.end) && end_of_delete.between?(shift.start, shift.end))
      raise "You can\'t delete more than the entire shift"
    elsif start_of_delete >= end_of_delete
      raise "Start of the deletion should be before end of deletion"
    elsif start_of_delete == shift.start && end_of_delete == shift.end
      shift.destroy
    elsif start_of_delete == shift.start
      shift.start=end_of_delete
      shift.save!
    elsif end_of_delete == shift.end
      shift.end=start_of_delete
      shift.save!
    else
      later_shift = shift.clone
      later_shift.user = shift.user
      later_shift.location = shift.location
      shift.end = start_of_delete
      later_shift.start = end_of_delete
      shift.save!
      later_shift.save!
      shift.sub_requests.each do |s|
        if s.start >= later_shift.start
          s.shift = later_shift
          s.save!
        end
      end
    end
  end


  #This method takes a list of shifts and deletes them, all their subrequests,
  # and all the relevant UserSinksUserSource entries. Necessary for conflict
  #wiping in repeating_event and calendars, as well as wiping a date range -Mike
  def self.mass_delete_with_dependencies(shifts_to_erase)
    array_of_shift_arrays = shifts_to_erase.batch(450)
    array_of_shift_arrays.each do |shifts|
      subs_to_erase = SubRequest.find(:all, :conditions => [shifts.collect{|shift| "(#{:shift_id.to_sql_column} = #{shift.to_sql})"}.join(" OR ")] )
      array_of_sub_arrays = subs_to_erase.batch(450)
      array_of_sub_arrays.each do |subs|
        UserSinksUserSource.delete_all([subs.collect{|sub| "(#{:user_sink_type.to_sql_column} = #{'SubRequest'.to_sql} AND #{:user_sink_id.to_sql_column} = #{sub.to_sql})"}.join(" OR ")])
        SubRequest.delete_all([subs.collect{|sub| "(#{:id.to_sql_column} = #{sub.to_sql})"}.join(" OR ")])
      end
      Shift.delete_all([shifts.collect{|shift| "(#{:id.to_sql_column} = #{shift.to_sql})"}.join(" OR ")])
    end
  end



  #This method creates the multitude of shifts required for repeating_events to work
  #in order to work efficiently, it makes a few GIANT sql insert calls -mike
  def self.make_future(end_date, cal_id, r_e_id, days, loc_id, start_time, end_time, user_id, department_id, active, wipe)
    #We need several inner arrays with one big outer one, b/c sqlite freaks out
    #if the sql insert call is too big. The "make" arrays are then used for making
    #the shifts, and the "test" for finding conflicts.
    outer_make = []
    inner_make = []
    outer_test = []
    inner_test = []
    diff = end_time - start_time
    #Take each day and build an arrays containing the pieces of the sql queries
    days.each do |day|
      seed_start_time = (start_time.wday == day ? start_time : start_time.next(day))
      seed_end_time = seed_start_time+diff
      while seed_end_time <= end_date
        if active
          inner_test.push "(#{:user_id.to_sql_column} = #{user_id.to_sql} AND #{:active.to_sql_column} = #{true.to_sql} AND #{:department_id.to_sql_column} = #{department_id.to_sql} AND #{:start.to_sql_column} <= #{seed_end_time.utc.to_sql} AND #{:end.to_sql_column} >= #{seed_start_time.utc.to_sql})"
        else
          inner_test.push "(#{:user_id.to_sql_column} = #{user_id.to_sql} AND #{:calendar_id.to_sql_column} = #{cal_id.to_sql} AND #{:department_id.to_sql_column} = #{department_id.to_sql} AND #{:start.to_sql_column} <= #{seed_end_time.utc.to_sql} AND #{:end.to_sql_column} >= #{seed_start_time.utc.to_sql})"
        end
        inner_make.push "#{loc_id.to_sql}, #{cal_id.to_sql}, #{r_e_id.to_sql}, #{seed_start_time.utc.to_sql}, #{seed_end_time.utc.to_sql}, #{Time.now.utc.to_sql}, #{Time.now.utc.to_sql}, #{user_id.to_sql}, #{department_id.to_sql}, #{active.to_sql}"
        #Once the array becomes big enough that the sql call will insert 450 rows, start over w/ a new array
        #without this bit, sqlite freaks out if you are inserting a larger number of rows. Might need to be changed
        #for other databases (it can probably be higher for other ones I think, which would result in faster execution)
        if inner_make.length > 450
          outer_make.push inner_make
          inner_make = []
          outer_test.push inner_test
          inner_test = []
        end
         seed_start_time = seed_start_time.next(day)
         seed_end_time = seed_start_time + diff
      end
      #handle leftovers or the case where there are less than 450 rows to be inserted
    end
      outer_make.push inner_make unless inner_make.empty?
      outer_test.push inner_test unless inner_test.empty?
    #Look for conflicts, delete them if wipe is on, and either complain about
    #conflicts or make the new shifts
    if wipe
        outer_test.each do |sh|
          Shift.mass_delete_with_dependencies(Shift.find(:all, :conditions => [sh.join(" OR ")]))
        end
        outer_make.each do |s|
          sql = "INSERT INTO shifts (#{:location_id.to_sql_column}, #{:calendar_id.to_sql_column}, #{:repeating_event_id.to_sql_column}, #{:start.to_sql_column}, #{:end.to_sql_column}, #{:created_at.to_sql_column}, #{:updated_at.to_sql_column}, #{:user_id.to_sql_column}, #{:department_id.to_sql_column}, #{:active.to_sql_column}) SELECT #{s.join(" UNION ALL SELECT ")};"
          ActiveRecord::Base.connection.execute sql
        end
      return false
    else
      out = []
        outer_test.each do |s|
          out += Shift.find(:all, :conditions => [s.join(" OR ")])
        end
      if out.empty?
          outer_make.each do |s|
            sql = "INSERT INTO shifts (#{:location_id.to_sql_column}, #{:calendar_id.to_sql_column}, #{:repeating_event_id.to_sql_column}, #{:start.to_sql_column}, #{:end.to_sql_column}, #{:created_at.to_sql_column}, #{:updated_at.to_sql_column}, #{:user_id.to_sql_column}, #{:department_id.to_sql_column}, #{:active.to_sql_column}) SELECT #{s.join(" UNION ALL SELECT ")};"
            ActiveRecord::Base.connection.execute sql
          end
        return false
      end
      return out.collect{|t| "The shift for "+t.to_message_name+" conflicts. Use wipe to fix."}.join(",")
    end
  end


  #Used for activating calendars, check/wipe conflicts -Mike
  def self.check_for_conflicts(shifts, wipe)
    #big_array is just an array of arrays, the inner arrays being less than 450
    #elements so sql doesn't freak
    big_array = shifts.batch(450)
    if big_array.empty?
      ""
    elsif wipe
      big_array.each do |sh|
        Shift.mass_delete_with_dependencies(Shift.find(:all, :conditions => [sh.collect{|s| "(#{:user_id.to_sql_column} = #{s.user_id.to_sql} AND #{:active.to_sql_column} = #{true.to_sql} AND #{:department_id.to_sql_column} = #{s.department_id.to_sql} AND #{:start.to_sql_column} <= #{s.end.utc.to_sql} AND #{:end.to_sql_column} >= #{s.start.utc.to_sql})"}.join(" OR ")]))
      end
      return ""
    else
      out=big_array.collect do |sh|
        Shift.find(:all, :conditions => [sh.collect{|s| "(#{:user_id.to_sql_column} = #{s.user_id.to_sql} AND #{:active.to_sql_column} = #{true.to_sql} AND #{:department_id.to_sql_column} = #{s.department_id.to_sql} AND #{:start.to_sql_column} <= #{s.end.utc.to_sql} AND #{:end.to_sql_column} >= #{s.start.utc.to_sql})"}.join(" OR ")]).collect{|t| "The shift for "+t.to_message_name+"."}.join(",")
      end
      out.join(",")+","
    end
  end

  # ==================
  # = Object methods =
  # ==================

  def duration
    self.end - self.start
  end

  def css_class(current_user = nil)
    if current_user and self.user == current_user
      css_class = "user"
    else
      css_class = "shift"
    end
    if missed?
      css_class += "_missed"
    elsif (self.report.nil? ? Time.now : self.report.arrived) > start + department.department_config.grace_period*60 #seconds
      css_class += "_late"
    end
    css_class
  end

  def too_early?
    self.start > 30.minutes.from_now
  end

  def missed?
    self.has_passed? and !self.report
  end

  def late?
    self.report && (self.report.arrived - self.start > $department.department_config.grace_period*60)
    #seconds
  end

  #a shift has been signed in to if it has a report
  # NOTE: this evaluates whether a shift is CURRENTLY signed in
  def signed_in?
    self.report && !self.report.departed
  end

  #a shift has been signed in to if its shift report has been submitted
  def submitted?
    self.report and self.report.departed
  end

  #TODO: subs!
  #check if a shift has a *pending* sub request and that sub is not taken yet
  def has_sub?
    #note: if the later part of a shift has been taken, self.sub still returns true so we also need to check self.sub.new_user.nil?
    !self.sub_requests.empty? #and sub.new_user.nil? #new_user in sub is only set after sub is taken.  shouldn't check new_shift bcoz a shift can be deleted from db. -H
  end

  def has_passed?
    self.end < Time.now
  end

  def has_started?
    self.start < Time.now
  end

  # If new shift runs up against another compatible shift, combine them and save,
  # preserving the earlier shift's information
  def combine_with_surrounding_shifts
    if (shift_later = Shift.find(:first, :conditions => {:start => self.end, :user_id => self.user_id, :location_id => self.location_id, :calendar_id => self.calendar.id}))
      self.end = shift_later.end
      shift_later.sub_requests.each { |s| s.shift = self }
      shift_later.destroy
      self.save!
    end
    if (shift_earlier = Shift.find(:first, :conditions => {:end => self.start, :user_id => self.user_id, :location_id => self.location_id, :calendar_id => self.calendar.id}))
      self.start = shift_earlier.start
      shift_earlier.sub_requests.each {|s| s.shift = self}
      unless shift_earlier.report.nil?
        shift_earlier.report.shift = nil
        shift_earlier.report.save! #we have to disassociate the report first, or it will be destroyed too
        self.report = shift_earlier.report
        shift_earlier.report = nil
      end
      self.signed_in = shift_earlier.signed_in
      shift_earlier.destroy
      self.save!
      # the below doesn't work...
      # shift_earlier.end = self.end
      # self.sub_requests.each {|s| s.shift = shift_earlier}
      # shift_earlier.report = self.report if shift_earlier.report.nil? #only replace report if it doesn't exist
      #shift_earlier.save!
      #return false
      #self.destroy #how do we cancel creation of this shift but return success?
    end
  end

  def exceeds_max_staff?
    count = 0
    shifts_in_period = []
    Shift.find(:all, :conditions => {:location_id => self.location_id, :scheduled => true}).each do |shift|
      shifts_in_period << shift if (self.start..self.end).overlaps?(shift.start..shift.end) && self.end != shift.start && self.start != shift.end
    end
    increment = self.department.department_config.time_increment
    time = self.start + (increment / 2)
    while (self.start..self.end).include?(time)
      concurrent_shifts = 0
      shifts_in_period.each do |shift|
        concurrent_shifts += 1 if (shift.start..shift.end).include?(time)
      end
      count = concurrent_shifts if concurrent_shifts > count
      time += increment
    end
    count + 1 > self.location.max_staff
  end


  # ===================
  # = Display helpers =
  # ===================
  def short_display
      "#{location.short_name}, #{start.to_s(:just_date)} #{time_string}"
  end

  def to_message_name
    "#{user.name} in #{location.short_name} from #{start.to_s(:am_pm_long_no_comma)} to #{self.end.to_s(:am_pm_long_no_comma)}"
  end

  def short_name
    "#{location.short_name}, #{user.name}, #{time_string}, #{start.to_s(:just_date)}"
  end

  def time_string
    scheduled? ? "#{start.to_s(:am_pm)} - #{self.end.to_s(:am_pm)}" : "unscheduled"
  end

  def sub_request
    SubRequest.find_by_shift_id(self.id)
  end

  private

  # ======================
  # = Validation helpers =
  # ======================
  def restrictions
    unless self.power_signed_up
      errors.add(:user, "is required") and return if self.user.nil?
      self.user.restrictions.each do |restriction|
        if restriction.max_hours
          relevant_shifts = Shift.between(restriction.starts,restriction.expires).for_user(self.user)
          hours_sum = relevant_shifts.map{|shift| shift.end - shift.start}.flatten.sum / 3600.0
          hours_sum += (self.end - self.start) / 3600.0
          if hours_sum > restriction.max_hours
            errors.add(:max_hours, "have been exceeded by #{hours_sum - restriction.max_hours}.")
          end
        end
      end
      self.location.restrictions.each do |restriction|
        if restriction.max_hours
          relevant_shifts = Shift.between(restriction.starts,restriction.expires).in_location(self.location)
          hours_sum = relevant_shifts.map{|shift| shift.end - shift.start}.flatten.sum / 3600.0
          hours_sum += (self.end - self.start) / 3600.0
          if hours_sum > restriction.max_hours
            errors.add(:max_hours, "have been exceeded by #{hours_sum - restriction.max_hours}.")
          end
        end
      end
    end
  end

  def start_less_than_end
    errors.add(:start, "must be earlier than end time") if (self.end <= start)
  end

  def shift_is_within_time_slot
    unless self.power_signed_up
      c = TimeSlot.count(:all, :conditions => ["#{:location_id.to_sql_column} = #{self.location_id.to_sql} AND #{:start.to_sql_column} <= #{self.start.to_sql} AND #{:end.to_sql_column} >= #{self.end.to_sql} AND #{:active.to_sql_column} = #{true.to_sql}"])
      errors.add_to_base("You can only sign up for a shift during a time slot!") if c == 0
    end
  end

  def user_does_not_have_concurrent_shift
    if self.calendar.active
      c = Shift.count(:all, :conditions => ["#{:user_id.to_sql_column} = #{self.user_id.to_sql} AND #{:start.to_sql_column} < #{self.end.to_sql} AND #{:end.to_sql_column} > #{self.start.to_sql} AND #{:department_id.to_sql_column} = #{self.department.to_sql} AND #{:active.to_sql_column} = #{true.to_sql}"])
    else
      c = Shift.count(:all, :conditions => ["#{:user_id.to_sql_column} = #{self.user_id.to_sql} AND #{:start.to_sql_column} < #{self.end.to_sql} AND #{:end.to_sql_column} > #{self.start.to_sql} AND #{:department_id.to_sql_column} = #{self.department.to_sql} AND #{:calendar_id.to_sql_column} = #{self.calendar.to_sql}"])
    end
    unless c.zero?
      errors.add_to_base("#{self.user.name} has an overlapping shift in that period") unless (self.id and c==1)
    end
  end

  def not_in_the_past
    errors.add_to_base("Can't sign up for a shift that has already passed!") if self.start <= Time.now
  end

  def does_not_exceed_max_concurrent_shifts_in_location
    if self.scheduled?
      max_concurrent = self.location.max_staff
      shifts = Shift.active.scheduled.in_location(self.location).overlaps(self.start, self.end)
      shifts.delete_if{|shift| shift.id = self.id} unless self.new_record?
      time_increment = self.department.department_config.time_increment

      #how many people are in this location?
      people_count = {}
      people_count.default = 0
      unless shifts.nil?
        shifts.each do |shift|
          time = shift.start
          time = time.hour*60+time.min
          end_time = shift.end
          end_time = end_time.hour*60+end_time.min
          while (time < end_time)
            people_count[time] += 1
            time += time_increment
          end
        end
      end

      errors.add_to_base("#{self.location.name} only allows #{max_concurrent} concurrent shifts.") if people_count.values.select{|n| n >= max_concurrent}.size > 0
    end
  end

  #TODO: catch exceptions
  def adjust_sub_requests
    self.sub_requests.each do |sub|
      if sub.start > self.end || sub.end < self.start
        sub.destroy
      else
        sub.start = self.start if sub.start < self.start
        sub.mandatory_start = self.start if sub.mandatory_start < self.start
        sub.end = self.end if sub.end > self.end
        sub.mandatory_end = self.end if sub.mandatory_end > self.end
        sub.save(false)
      end
    end
  end

  def set_active
    self.active = self.calendar.active
    return true
  end

  def is_within_calendar
    unless self.calendar.default
      errors.add_to_base("Shift start and end dates must be within the range of the calendar!") if self.start < self.calendar.start_date || self.end > self.calendar.end_date
    end
  end

  def disassociate_from_repeating_event
    self.repeating_event_id = nil
  end
  
  def adjust_end_time_if_in_early_morning
    #increment end by one day in cases where the department is open past midnight
    self.end += 1.day if (self.end <= self.start and (self.end.hour * 60 + self.end.min) <= (self.department.department_config.schedule_end % 1440))
    #stopgap fix: don't allow shifts longer than 24 hours
    self.end -= 1.day if (self.end > self.start + 1.day)
  end

  class << columns_hash['start']
    def type
      :datetime
    end
  end
end

