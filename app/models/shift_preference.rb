class ShiftPreference < ActiveRecord::Base
	belongs_to :user
	has_many :locations_shift_preferences
	has_many :locations, :through => :locations_shift_preferences
	belongs_to :template
	
	validate :max_total_hours_greater_than_min
	validate :max_continuous_hours_greater_than_min
	validate :max_number_of_shifts_greater_than_min
	validate :max_hours_per_day_greater_than_continuous
  validate :feasibility_of_preferences
	
	protected
	def max_hours_per_day_greater_than_continuous
		errors.add("Maximum hours per day must be greater or equal to than maximum continuous hours") if self.max_hours_per_day <= self.max_continuous_hours
	end

	def max_total_hours_greater_than_min
	  errors.add("Maximum total hours must be greater minimum total hours") if (self.max_total_hours < self.min_total_hours)
  end
  
  def max_continuous_hours_greater_than_min
    errors.add("Maximum continuous hours must be greater minimum continuous hours") if (self.max_continuous_hours < self.min_continuous_hours)
  end
  
  def max_number_of_shifts_greater_than_min
    errors.add("Maximum number of shifts must be greater minimum number of shifts") if (self.max_number_of_shifts < self.min_number_of_shifts)
  end
  
  def feasibility_of_preferences
    errors.add(:min_total_hours, "max number of shifts at max continuous hours do not produce min total hours") if ((self.max_continuous_hours*self.max_number_of_shifts < self.min_total_hours))
    errors.add(:max_total_hours, "min number of shifts at min continuous hours exceed max total hours") if ((self.min_continuous_hours*self.min_number_of_shifts > self.max_total_hours))
  end
	
end
