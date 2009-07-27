class Report < ActiveRecord::Base
  belongs_to :shift
  delegate :user, :to => :shift
  has_many :report_items, :dependent => :destroy

  validates_uniqueness_of :shift_id

  def get_notices
    (self.shift.location.current_notices + self.shift.user.current_notices).uniq.sort_by{|n| n.start_time}.reverse
  end

  def data_objects
    self.shift.location.data_objects
  end
end

